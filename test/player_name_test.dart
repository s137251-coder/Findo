import 'dart:math';

import 'package:findo/models/player_name.dart';
import 'package:flutter_test/flutter_test.dart';

/// The name a player wears on a table everyone can see.
void main() {
  test('a Hebrew name agrees with the gender of its creature', () {
    // Every name the generator can make, checked against the two words that
    // must never meet: a feminine creature with a masculine adjective reads
    // as broken Hebrew, and it would be on a public table.
    final seen = <String>{};
    for (var seed = 0; seed < 4000; seed++) {
      seen.add(PlayerName.create('he', random: Random(seed)));
    }
    expect(seen.length, greaterThan(500), reason: 'the names barely vary');

    // Feminine creatures in the list, and the ending their adjective takes.
    const feminine = ['לטאה', 'חתולה', 'צבה', 'סנאית', 'זברה', 'נמלה',
                      'לביאה', 'דבורה', 'גירית', 'תנשמת', 'פרפרה', 'חוחית'];
    for (final name in seen) {
      final words = name.split(' ');
      final creature = words.first;
      final adjective = words[words.length - 2];
      if (feminine.contains(creature)) {
        expect(
          adjective.endsWith('ה') || adjective.endsWith('ת'),
          isTrue,
          reason: '"$name" gives a feminine creature a masculine adjective',
        );
      }
    }
  });

  test('an English name reads as one', () {
    final name = PlayerName.create('en', random: Random(1));
    expect(name, matches(RegExp(r'^[A-Za-z ]+ \d{3}$')));
  });

  test('a language it does not know falls back to English', () {
    final name = PlayerName.create('fr', random: Random(1));
    expect(name, matches(RegExp(r'^[A-Za-z ]+ \d{3}$')));
  });

  test('every name it makes is one it would accept back', () {
    for (var seed = 0; seed < 500; seed++) {
      for (final language in ['he', 'en']) {
        final name = PlayerName.create(language, random: Random(seed));
        expect(PlayerName.isWellFormed(name), isTrue, reason: name);
      }
    }
  });

  test('anything a player could have typed instead is refused', () {
    // A modified client writing its own name is the thing this guards, so the
    // check has to refuse what such a client would want to write.
    const refused = [
      '',
      'Tiger',
      'Tiger 12',           // two digits, not three
      'Tiger 1000',         // out of range
      'Tiger abc',
      'Swift Tiger 042',    // a leading zero is not a number it makes
      ' Swift Tiger 123',   // padded
      'Swift Tiger 123 ',
      'Buy cheap coins 123',  // right shape, words from nowhere
      'Tiger Swift 123',      // the right words, the wrong way round
      'לטאה סקרן 123',        // a feminine creature with a masculine adjective
      'Swift T1ger 123',    // a digit smuggled into a word
      'Swift <b>Tiger</b> 123',
      'Swift Tiger 123!',
    ];
    for (final name in refused) {
      expect(PlayerName.isWellFormed(name), isFalse, reason: '"$name" passed');
    }
  });

  test('there are enough names that two players rarely share one', () {
    // A thousand players on one table should be about a one-in-three chance of
    // any two matching at all -- rare, and harmless when it happens.
    expect(PlayerName.variety, greaterThan(700000));
  });
}
