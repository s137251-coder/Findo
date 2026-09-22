import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every query the leaderboard makes has to be one the server can answer.
///
/// Firestore serves a filter and a sort on the same field by itself, but a
/// filter on one field and a sort on another needs a composite index declared
/// in advance. Nothing says so until a real query runs against a real server:
/// the week tab shipped, and answered "we could not load the table" on the
/// only screen that used it, because `weekKey == this week` sorted by
/// `weekBestMs` had no index. The app cannot test that for itself, so this
/// checks the far smaller thing it can -- that the index file still declares
/// what the service still asks for.
void main() {
  final service = File('lib/managers/leaderboard_service.dart')
      .readAsStringSync();
  final indexes = jsonDecode(File('firestore.indexes.json').readAsStringSync())
      as Map<String, dynamic>;

  /// Every (collection, filtered field, sorted field) the index file covers.
  Set<String> declared() {
    final out = <String>{};
    for (final index in indexes['indexes'] as List) {
      final fields = (index['fields'] as List)
          .map((f) => (f as Map)['fieldPath'] as String)
          .where((name) => name != '__name__')
          .toList();
      for (var i = 1; i < fields.length; i++) {
        out.add('${index['collectionGroup']}:${fields[0]}:${fields[i]}');
      }
    }
    return out;
  }

  test('the week\'s table has the index its query needs', () {
    // The query in the service, in as many words.
    expect(service, contains("where('weekKey'"),
        reason: 'the week query changed; this test is checking the wrong thing');
    expect(service, contains("'weekBestMs'"));

    expect(declared(), contains('players:weekKey:weekBestMs'),
        reason: 'the week tab will answer with an error on a real server');
  });

  test('both directions are covered, because the rows above a player are '
      'read backwards', () {
    final orders = <String>{};
    for (final index in indexes['indexes'] as List) {
      final fields = (index['fields'] as List).cast<Map>();
      if (fields.first['fieldPath'] == 'weekKey') {
        orders.add(fields[1]['order'] as String);
      }
    }
    expect(orders, containsAll(['ASCENDING', 'DESCENDING']));
  });

  test('the index file is the one Firebase deploys', () {
    final config = jsonDecode(File('firebase.json').readAsStringSync())
        as Map<String, dynamic>;
    expect((config['firestore'] as Map)['indexes'], 'firestore.indexes.json',
        reason: 'the indexes are written but never sent');
    expect((config['firestore'] as Map)['rules'], 'firestore.rules');
  });

  test('a query that needs no index is not declared as needing one', () {
    // Today's table and the all-time table sort a whole collection by one
    // field, which Firestore indexes on its own. Declaring those would be
    // noise that hides the one that matters.
    expect(declared().length, lessThanOrEqualTo(2));
  });
}
