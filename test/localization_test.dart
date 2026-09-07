import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The dictionaries are loaded at runtime by key, so a key that exists in one
/// language and not the other shows up as raw text on screen. These tests keep
/// the two files in lockstep.
void main() {
  Map<String, dynamic> load(String code) =>
      jsonDecode(File('assets/locales/$code.json').readAsStringSync())
          as Map<String, dynamic>;

  test('English and Hebrew define exactly the same keys', () {
    final en = load('en').keys.toSet();
    final he = load('he').keys.toSet();

    expect(en.difference(he), isEmpty, reason: 'missing Hebrew translations');
    expect(he.difference(en), isEmpty, reason: 'orphan Hebrew translations');
  });

  test('no translation is left empty', () {
    for (final code in ['en', 'he']) {
      load(code).forEach((key, value) {
        expect((value as String).trim(), isNotEmpty, reason: '$code:$key is blank');
      });
    }
  });

  test('placeholders match between the two languages', () {
    final en = load('en');
    final he = load('he');
    final placeholder = RegExp(r'\{(\w+)\}');

    for (final key in en.keys) {
      final enSlots = placeholder
          .allMatches(en[key] as String)
          .map((match) => match.group(1))
          .toSet();
      final heSlots = placeholder
          .allMatches(he[key] as String)
          .map((match) => match.group(1))
          .toSet();

      expect(heSlots, enSlots, reason: 'placeholder mismatch on $key');
    }
  });

  test('every level name used by a map has a translation', () {
    final en = load('en');
    final he = load('he');
    final manifest =
        jsonDecode(File('assets/images/maps/meta/index.json').readAsStringSync())
            as Map<String, dynamic>;

    for (final id in (manifest['levels'] as List<dynamic>).cast<String>()) {
      final level =
          jsonDecode(File('assets/images/maps/meta/$id.json').readAsStringSync())
              as Map<String, dynamic>;

      final nameKey = level['nameKey'] as String;
      expect(en.containsKey(nameKey), isTrue, reason: 'en is missing $nameKey');
      expect(he.containsKey(nameKey), isTrue, reason: 'he is missing $nameKey');
    }
  });

  test('the strings the objective panel needs are present', () {
    for (final code in ['en', 'he']) {
      final d = load(code);
      for (final key in ['hud.find', 'hud.objective', 'target.findo', 'win.time']) {
        expect(d.containsKey(key), isTrue, reason: '$code is missing $key');
      }
    }
  });
}
