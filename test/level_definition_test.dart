import 'dart:convert';
import 'dart:io';

import 'package:findo/models/level_definition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LevelDefinition', () {
    test('parses the shipped level files', () {
      final manifest =
          jsonDecode(File('assets/levels/index.json').readAsStringSync())
              as Map<String, dynamic>;
      final ids = (manifest['levels'] as List<dynamic>).cast<String>();

      expect(ids, isNotEmpty);

      for (final id in ids) {
        final level =
            LevelDefinition.parse(File('assets/levels/$id.json').readAsStringSync());

        expect(level.id, id);
        expect(level.items, isNotEmpty);
        expect(level.timeLimitSeconds, greaterThan(0));
        expect(level.worldWidth, greaterThan(0));
        expect(level.worldHeight, greaterThan(0));
      }
    });

    test('every level file points at artwork that exists', () {
      final manifest =
          jsonDecode(File('assets/levels/index.json').readAsStringSync())
              as Map<String, dynamic>;

      for (final id in (manifest['levels'] as List<dynamic>).cast<String>()) {
        final level =
            LevelDefinition.parse(File('assets/levels/$id.json').readAsStringSync());

        expect(
          File('assets/images/${level.background}').existsSync(),
          isTrue,
          reason: '${level.id} references a missing background',
        );
        for (final item in level.items) {
          expect(
            File('assets/images/${item.sprite}').existsSync(),
            isTrue,
            reason: '${level.id} references a missing sprite for ${item.id}',
          );
        }
      }
    });

    test('keeps collectables inside the map', () {
      final level = LevelDefinition.parse(
        File('assets/levels/level_01.json').readAsStringSync(),
      );

      for (final item in level.items) {
        expect(item.x, inInclusiveRange(0, level.worldWidth));
        expect(item.y, inInclusiveRange(0, level.worldHeight));
      }
    });

    test('gives no two collectables on a map the same id', () {
      final level = LevelDefinition.parse(
        File('assets/levels/level_03.json').readAsStringSync(),
      );

      final ids = level.items.map((item) => item.id).toSet();
      expect(ids.length, level.items.length);
    });
  });
}
