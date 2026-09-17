import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';

import '../models/daily_hunt.dart';

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

  /// Opens Play Games' own table, on today's scores. False when it could not.
  Future<bool> showTodaysTable() async {
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
        timeScope: TimeScope.today,
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
