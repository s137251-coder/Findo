import 'dart:convert';
import 'dart:io';

import 'package:flame/components.dart';

import 'package:findo/game/components/drift_layer_component.dart';
import 'package:findo/models/level_definition.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reads the shipped level metadata rather than a fixture: the curve is data,
/// and a regression in it is a data change nobody would otherwise notice.
List<Map<String, dynamic>> _levels() {
  final dir = Directory('assets/images/maps/meta');
  final index = jsonDecode(File('${dir.path}/index.json').readAsStringSync())
      as Map<String, dynamic>;
  return (index['levels'] as List<dynamic>)
      .map((id) => jsonDecode(File('${dir.path}/$id.json').readAsStringSync())
          as Map<String, dynamic>)
      .toList();
}

void main() {
  group('difficulty curve', () {
    final levels = _levels();

    test('the clock never loosens as levels go on', () {
      // Level 21 used to jump from 70 seconds back to 115 -- easier than
      // level 9 -- because levels past 20 were authored on a separate curve.
      var previous = 1 << 30;
      for (final level in levels) {
        final time = level['timeLimitSeconds'] as int;
        expect(time, lessThanOrEqualTo(previous),
            reason: 'level ${level['index']} gives more time than the one before');
        previous = time;
      }
    });

    test('Findo never grows back', () {
      var previous = 1 << 30;
      for (final level in levels) {
        final height = (level['targets'] as List).first['height'] as int;
        expect(height, lessThanOrEqualTo(previous),
            reason: 'level ${level['index']} draws her larger than the one before');
        previous = height;
      }
    });

    test('she stays big enough to tap', () {
      for (final level in levels) {
        final height = (level['targets'] as List).first['height'] as int;
        expect(height, greaterThanOrEqualTo(68),
            reason: 'level ${level['index']} shrinks her past the fair limit');
      }
    });

    test('motion only starts once size has run out, and then rises', () {
      var previous = -1.0;
      for (final level in levels) {
        final index = level['index'] as int;
        final motion = ((level['motion'] as num?) ?? 0).toDouble();
        if (index <= 20) {
          expect(motion, 0,
              reason: 'level $index should teach the game without distraction');
        } else {
          expect(motion, greaterThan(0));
        }
        expect(motion, greaterThanOrEqualTo(previous),
            reason: 'level $index is calmer than the one before it');
        expect(motion, lessThanOrEqualTo(1.0));
        previous = motion;
      }
    });

    test('star thresholds stay reachable inside the time allowed', () {
      for (final level in levels) {
        final time = level['timeLimitSeconds'] as int;
        final three = (level['starThresholds'] as Map)['three'] as int;
        // Score is 100 for the find plus 10 a second left on the clock.
        final ceiling = 100 + time * 10;
        expect(three, lessThan(ceiling),
            reason: 'level ${level['index']} cannot be three-starred at all');
      }
    });
  });

  group('drift', () {
    test('every shipped level maps to a drift that suits it', () {
      expect(DriftKind.forLevel('level.snow'), DriftKind.snow);
      expect(DriftKind.forLevel('level.skibase'), DriftKind.snow);
      expect(DriftKind.forLevel('level.aquarium'), DriftKind.bubble);
      expect(DriftKind.forLevel('level.nightfest'), DriftKind.confetti);
      expect(DriftKind.forLevel('level.farm'), DriftKind.leaf);
      // Anything unlisted still gets motion rather than a free pass.
      expect(DriftKind.forLevel('level.somewhere-new'), DriftKind.dust);
    });

    test('bubbles rise and snow falls', () {
      expect(DriftKind.bubble.fallSpeed, lessThan(0));
      expect(DriftKind.snow.fallSpeed, greaterThan(0));
    });

    test('a level with no motion builds no layer', () {
      final level = LevelDefinition.fromJson(_levels().first);
      expect(level.motion, 0);
      expect(
          driftLayerFor(level, Vector2(level.mapWidth, level.mapHeight)),
          isNull,
        );
    });
  });
}
