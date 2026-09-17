import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';

import '../models/daily_hunt.dart';
import '../models/leaderboard.dart';

/// Google Play Games: signing the player in, and the daily hunt's table.
///
/// Every call is allowed to fail quietly. A player with no Play Games account,
/// no network or an install that did not come from the store still plays the
/// daily hunt; only the table is missing, and the result screen says so.
///
/// Android only for now. Game Center is not set up yet, so on iOS every call
/// answers as if the player were signed out.
class GamesServicesManager {
  bool get _supported => Platform.isAndroid;

  bool _signedIn = false;

  bool get isSignedIn => _signedIn;

  /// Play Games v2 signs a returning player in on its own; this asks once at
  /// launch, without a prompt, whether that has happened.
  Future<void> signInQuietly() async {
    if (!_supported) {
      return;
    }
    try {
      await GameAuth.signIn();
      _signedIn = await GameAuth.isSignedIn;
    } catch (error) {
      _log('sign-in unavailable: $error');
      _signedIn = false;
    }
  }

  /// Asks the player to sign in, showing Play Games' own prompt if needed.
  Future<bool> signIn() async {
    await signInQuietly();
    return _signedIn;
  }

  /// How many of the best times a table shows.
  static const topCount = 20;

  /// How many rows around the player are fetched when they rank below the
  /// top of the table.
  static const aroundCount = 5;

  /// The Daily Hunt's table for [span], read from Play Games for the game's
  /// own screen.
  Future<LeaderboardLoad> loadTable(LeaderboardSpan span) async {
    if (!_supported) {
      return const LeaderboardLoad.unsupported();
    }
    if (!_signedIn) {
      await signInQuietly();
      if (!_signedIn) {
        return const LeaderboardLoad.signedOut();
      }
    }
    final scope = switch (span) {
      LeaderboardSpan.today => TimeScope.today,
      LeaderboardSpan.week => TimeScope.week,
      LeaderboardSpan.allTime => TimeScope.allTime,
    };
    try {
      final top = await Leaderboards.loadLeaderboardScores(
            androidLeaderboardID: DailyHunt.androidLeaderboardId,
            scope: PlayerScope.global,
            timeScope: scope,
            maxResults: topCount,
            // A time posted a moment ago should be on the table the player
            // opens straight after it.
            forceRefresh: true,
          ) ??
          const [];

      // The player's own entry, if they have one for this period. Absent is
      // normal -- they may not have played this week -- and reads as null.
      LeaderboardScoreData? mine;
      try {
        mine = await Leaderboards.getPlayerScoreObject(
          androidLeaderboardID: DailyHunt.androidLeaderboardId,
          scope: PlayerScope.global,
          timeScope: scope,
        );
      } catch (_) {
        mine = null;
      }
      final myId = mine?.scoreHolder.playerID;

      LeaderboardRow row(LeaderboardScoreData entry) => LeaderboardRow(
            rank: entry.rank,
            name: entry.scoreHolder.displayName,
            milliseconds: entry.rawScore,
            avatarBase64: entry.scoreHolder.iconImage,
            isMe: myId != null && entry.scoreHolder.playerID == myId,
          );

      final topRows = top.map(row).toList();
      var aroundRows = const <LeaderboardRow>[];
      final myRank = mine?.rank ?? 0;
      if (myRank > 0 && !topRows.any((r) => r.isMe)) {
        final around = await Leaderboards.loadLeaderboardScores(
              androidLeaderboardID: DailyHunt.androidLeaderboardId,
              playerCentered: true,
              scope: PlayerScope.global,
              timeScope: scope,
              maxResults: aroundCount,
            ) ??
            const [];
        final shownRanks = topRows.map((r) => r.rank).toSet();
        aroundRows = around.map(row).where((r) => !shownRanks.contains(r.rank)).toList();
      }
      return LeaderboardLoad.ok(top: topRows, aroundMe: aroundRows);
    } catch (error) {
      _log('table not loaded: $error');
      return const LeaderboardLoad.failed();
    }
  }

  /// Posts the day's time, in milliseconds. False when it did not go through.
  Future<bool> submitDailyTime(int milliseconds) async {
    if (!_supported) {
      return false;
    }
    try {
      if (!_signedIn) {
        await signInQuietly();
      }
      if (!_signedIn) {
        return false;
      }
      await Leaderboards.submitScore(
        score: Score(
          androidLeaderboardID: DailyHunt.androidLeaderboardId,
          value: milliseconds,
        ),
      );
      return true;
    } catch (error) {
      _log('score not submitted: $error');
      return false;
    }
  }

  /// The player's place on today's table, or null when it cannot be told.
  Future<int?> todaysRank() async {
    if (!_supported || !_signedIn) {
      return null;
    }
    try {
      final score = await Leaderboards.getPlayerScoreObject(
        androidLeaderboardID: DailyHunt.androidLeaderboardId,
        scope: PlayerScope.global,
        timeScope: TimeScope.today,
      );
      final rank = score?.rank;
      return rank != null && rank > 0 ? rank : null;
    } catch (error) {
      _log('rank unavailable: $error');
      return null;
    }
  }

  /// Opens Play Games' own table for [span]. False when it could not.
  Future<bool> showTable(LeaderboardSpan span) async {
    if (!_supported) {
      return false;
    }
    try {
      if (!_signedIn) {
        await signInQuietly();
      }
      if (!_signedIn) {
        return false;
      }
      await Leaderboards.showLeaderboards(
        androidLeaderboardID: DailyHunt.androidLeaderboardId,
        timeScope: switch (span) {
          LeaderboardSpan.today => TimeScope.today,
          LeaderboardSpan.week => TimeScope.week,
          LeaderboardSpan.allTime => TimeScope.allTime,
        },
      );
      return true;
    } catch (error) {
      _log('table unavailable: $error');
      return false;
    }
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[games] $message');
    }
  }
}
