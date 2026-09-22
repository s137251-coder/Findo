import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/daily_hunt.dart';
import '../models/leaderboard.dart';
import '../models/player_name.dart';
import 'save_manager.dart';

/// The Daily Hunt's table, the same one on every phone.
///
/// Play Games could only ever show Android players to each other, and only
/// those signed in to a Google account. This table is one table: an iPhone
/// and an Android phone read and write the same rows, and nobody signs in to
/// anything -- each install gets an anonymous identity the first time it has
/// a time to post.
///
/// What that costs is honest to say: an identity with no account behind it
/// lives on one phone, so a player who loses theirs loses their place.
///
/// Every call is allowed to fail. A player with no network still plays the
/// hunt; only the table is missing, and the result screen says so.
class LeaderboardService {
  LeaderboardService(this._save);

  final SaveManager _save;

  /// Rows a table shows, and how many around the player when they rank below
  /// them.
  static const topCount = 20;
  static const aroundCount = 2;

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  bool get isSignedIn => _auth.currentUser != null;

  /// This install's identity, made on first use.
  ///
  /// Anonymous: no e-mail, no account, nothing the player has to think about.
  /// Firebase gives the install a stable id and that is the whole of it.
  Future<String?> _uid() async {
    final existing = _auth.currentUser;
    if (existing != null) {
      return existing.uid;
    }
    try {
      final credential = await _auth.signInAnonymously();
      return credential.user?.uid;
    } catch (error) {
      _log('could not sign in: $error');
      return null;
    }
  }

  /// Signs in so the table can be read. Used by the screen's sign-in button,
  /// which for this table means only "try again".
  Future<bool> signIn() async => (await _uid()) != null;

  /// The language a new name is made in: the one the player chose, or the
  /// one the phone is set to when they have chosen nothing.
  String get _language =>
      _save.languageCode ?? PlatformDispatcher.instance.locale.languageCode;

  /// The name this player appears under, made once and kept.
  Future<String> playerName() async {
    final existing = _save.playerName;
    if (existing != null && PlayerName.isWellFormed(existing)) {
      return existing;
    }
    final made = PlayerName.create(_language);
    await _save.setPlayerName(made);
    return made;
  }

  /// Gives this player a different name, on the tables as well as here.
  ///
  /// The rows already posted carry the old name until they are written again,
  /// except the all-time row, which is updated now -- that is the one the
  /// player is most likely to be looking at when they press the button.
  Future<String> rerollName() async {
    final made = PlayerName.create(_language);
    await _save.setPlayerName(made);
    final uid = await _uid();
    if (uid != null) {
      try {
        await _db.collection('players').doc(uid).update({
          'name': made,
          'at': FieldValue.serverTimestamp(),
        });
      } catch (error) {
        // No row yet, or no network. The next time posted carries the name.
        _log('name not published: $error');
      }
    }
    return made;
  }

  /// Posts today's time. False when it did not go through.
  ///
  /// The day's row is written once and cannot be changed -- the rules refuse a
  /// second write -- so a second attempt is simply rejected, which is what
  /// makes "one attempt a day" true for an app that has been modified.
  Future<bool> submitDailyTime({
    required String day,
    required int milliseconds,
  }) async {
    final uid = await _uid();
    if (uid == null) {
      return false;
    }
    final name = await playerName();
    try {
      await _db
          .collection('daily')
          .doc(day)
          .collection('scores')
          .doc(uid)
          .set({
        'name': name,
        'ms': milliseconds,
        'at': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      _log('time not posted: $error');
      return false;
    }
    // The week and all-time rows are a convenience, not the record: a failure
    // here does not lose the time that matters.
    unawaited(_updateBests(uid: uid, name: name, milliseconds: milliseconds));
    return true;
  }

  Future<void> _updateBests({
    required String uid,
    required String name,
    required int milliseconds,
  }) async {
    final week = DailyHunt.pacificWeek(DateTime.now());
    final doc = _db.collection('players').doc(uid);
    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(doc);
        if (!snapshot.exists) {
          transaction.set(doc, {
            'name': name,
            'bestMs': milliseconds,
            'weekKey': week,
            'weekBestMs': milliseconds,
            'at': FieldValue.serverTimestamp(),
          });
          return;
        }
        final data = snapshot.data() ?? const <String, dynamic>{};
        final bestMs = (data['bestMs'] as num?)?.toInt() ?? milliseconds;
        final sameWeek = data['weekKey'] == week;
        final weekBest = (data['weekBestMs'] as num?)?.toInt() ?? milliseconds;
        transaction.update(doc, {
          'name': name,
          'bestMs': milliseconds < bestMs ? milliseconds : bestMs,
          'weekKey': week,
          'weekBestMs': sameWeek
              ? (milliseconds < weekBest ? milliseconds : weekBest)
              : milliseconds,
          'at': FieldValue.serverTimestamp(),
        });
      });
    } catch (error) {
      _log('bests not updated: $error');
    }
  }

  /// The player's place on today's table, or null when it cannot be told.
  Future<int?> todaysRank(String day) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return null;
    }
    try {
      final scores = _db.collection('daily').doc(day).collection('scores');
      final mine = await scores.doc(uid).get();
      final ms = (mine.data()?['ms'] as num?)?.toInt();
      if (ms == null) {
        return null;
      }
      return await _placeOf(scores.where('ms', isLessThan: ms));
    } catch (error) {
      _log('rank unavailable: $error');
      return null;
    }
  }

  /// One more than however many are ahead.
  ///
  /// Counted on the server rather than by reading the rows: a table with ten
  /// thousand players on it should cost the same to rank in as one with ten.
  Future<int> _placeOf(Query<Map<String, dynamic>> ahead) async {
    final count = await ahead.count().get();
    return (count.count ?? 0) + 1;
  }

  /// The table for [span].
  Future<LeaderboardLoad> loadTable(LeaderboardSpan span) async {
    final uid = await _uid();
    if (uid == null) {
      return const LeaderboardLoad.signedOut();
    }
    try {
      final (query, field, mine) = _queryFor(span, uid);
      final top = await query.orderBy(field).limit(topCount).get();
      final rows = <LeaderboardRow>[];
      for (var i = 0; i < top.docs.length; i++) {
        rows.add(_rowAt(top.docs[i], i + 1, uid, field));
      }
      if (rows.any((row) => row.isMe)) {
        return LeaderboardLoad.ok(top: rows);
      }
      return LeaderboardLoad.ok(
        top: rows,
        aroundMe: await _neighbours(query, field, uid, mine),
      );
    } catch (error) {
      _log('table not loaded: $error');
      return const LeaderboardLoad.failed();
    }
  }

  /// Which rows a period reads, the field they are ranked by, and where this
  /// player's own row lives.
  ///
  /// Today is a day's own rows. The week and all-time tables read one row per
  /// player instead, because a week's best is a player's best of seven hunts,
  /// not their seven times listed separately.
  ///
  /// The player's row comes back as a reference rather than as another query:
  /// asking a filtered collection for one document by its id is a second thing
  /// for the server to index, and it is the same document either way.
  (Query<Map<String, dynamic>>, String, DocumentReference<Map<String, dynamic>>)
      _queryFor(LeaderboardSpan span, String uid) {
    final now = DateTime.now();
    final players = _db.collection('players');
    return switch (span) {
      LeaderboardSpan.today => () {
          final day = _db
              .collection('daily')
              .doc(DailyHunt.pacificDay(now))
              .collection('scores');
          return (day, 'ms', day.doc(uid));
        }(),
      LeaderboardSpan.week => (
          players.where('weekKey', isEqualTo: DailyHunt.pacificWeek(now)),
          'weekBestMs',
          players.doc(uid),
        ),
      LeaderboardSpan.allTime => (players, 'bestMs', players.doc(uid)),
    };
  }

  /// The player and the rows either side, for when they are not in the top.
  Future<List<LeaderboardRow>> _neighbours(
    Query<Map<String, dynamic>> query,
    String field,
    String uid,
    DocumentReference<Map<String, dynamic>> mine,
  ) async {
    final me = await mine.get();
    final ms = (me.data()?[field] as num?)?.toInt();
    if (ms == null) {
      return const [];
    }
    final place = await _placeOf(query.where(field, isLessThan: ms));
    final ahead = await query
        .where(field, isLessThan: ms)
        .orderBy(field, descending: true)
        .limit(aroundCount)
        .get();
    final behind = await query
        .where(field, isGreaterThan: ms)
        .orderBy(field)
        .limit(aroundCount)
        .get();

    final rows = <LeaderboardRow>[];
    for (var i = ahead.docs.length - 1; i >= 0; i--) {
      rows.add(_rowAt(ahead.docs[i], place - 1 - i, uid, field));
    }
    rows.add(_rowOf(me.data() ?? const {}, place, isMe: true, field: field));
    for (var i = 0; i < behind.docs.length; i++) {
      rows.add(_rowAt(behind.docs[i], place + 1 + i, uid, field));
    }
    return rows;
  }

  LeaderboardRow _rowAt(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    int rank,
    String uid,
    String field,
  ) =>
      _rowOf(doc.data(), rank, isMe: doc.id == uid, field: field);

  LeaderboardRow _rowOf(
    Map<String, dynamic> data,
    int rank, {
    required bool isMe,
    required String field,
  }) =>
      LeaderboardRow(
        rank: rank,
        name: (data['name'] as String?) ?? '?',
        milliseconds: (data[field] as num?)?.toInt() ?? 0,
        isMe: isMe,
      );

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[table] $message');
    }
  }
}
