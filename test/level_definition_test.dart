import 'dart:convert';
import 'dart:io';

import 'package:findo/models/level_definition.dart';
import 'package:flutter_test/flutter_test.dart';

/// The map is authored outside the app and registered by `tool/level_data.py`.
/// These tests are the guard rail on that hand-off: a map that does not exist,
/// is too small to zoom into, or claims Findo is somewhere she is not, fails
/// here rather than in a player's hands.
void main() {
  const metaDir = 'assets/images/maps/meta';

  List<String> levelIds() {
    final manifest =
        jsonDecode(File('$metaDir/index.json').readAsStringSync())
            as Map<String, dynamic>;
    return (manifest['levels'] as List<dynamic>).cast<String>();
  }

  LevelDefinition load(String id) =>
      LevelDefinition.parse(File('$metaDir/$id.json').readAsStringSync());

  group('LevelDefinition', () {
    test('parses every registered level', () {
      final ids = levelIds();
      expect(ids, isNotEmpty);

      for (final id in ids) {
        final level = load(id);
        expect(level.id, id);
        expect(level.timeLimitSeconds, greaterThan(0));
        expect(level.mapWidth, greaterThan(0));
        expect(level.mapHeight, greaterThan(0));
      }
    });

    test('every level points at a map image that exists', () {
      for (final id in levelIds()) {
        final level = load(id);
        expect(
          File('assets/images/${level.map}').existsSync(),
          isTrue,
          reason: '${level.id} references a missing map',
        );
      }
    });

    test('maps are big enough to stay sharp at full zoom', () {
      for (final id in levelIds()) {
        final level = load(id);
        // The camera magnifies up to 3.2x the fit-to-screen zoom.
        expect(level.mapWidth, greaterThanOrEqualTo(2048),
            reason: '${level.id} is too narrow');
        expect(level.mapHeight, greaterThanOrEqualTo(2048),
            reason: '${level.id} is too short');
      }
    });

    test('every hiding spot is inside its map and big enough to tap', () {
      for (final id in levelIds()) {
        final level = load(id);
        expect(level.targets, isNotEmpty, reason: '${level.id} hides her nowhere');

        for (final t in level.targets) {
          expect(t.x, greaterThanOrEqualTo(0));
          expect(t.y, greaterThanOrEqualTo(0));
          expect(t.x + t.width, lessThanOrEqualTo(level.mapWidth));
          expect(t.y + t.height, lessThanOrEqualTo(level.mapHeight));
          expect(t.width, greaterThanOrEqualTo(24),
              reason: '${level.id} spot too narrow');
          expect(t.height, greaterThanOrEqualTo(24),
              reason: '${level.id} spot too short');
        }
      }
    });

    test('levels offer more than one hiding spot', () {
      // With a single spot a replay is recall rather than a search, and the
      // star rating is earned by replaying a level faster -- so this is the
      // difference between a game loop and a memory test.
      for (final id in levelIds()) {
        final level = load(id);
        expect(level.targets.length, greaterThanOrEqualTo(2),
            reason: '${level.id} always hides her in the same place');
      }
    });

    test('hiding spots on a map are far enough apart to be different hunts', () {
      for (final id in levelIds()) {
        final level = load(id);
        for (var i = 0; i < level.targets.length; i++) {
          for (var j = i + 1; j < level.targets.length; j++) {
            final a = level.targets[i];
            final b = level.targets[j];
            final dx = a.centerX - b.centerX;
            final dy = a.centerY - b.centerY;
            expect(dx * dx + dy * dy, greaterThan(400 * 400),
                reason: '${level.id} spots $i and $j are nearly the same place');
          }
        }
      }
    });

    test('the target centre is derived from the box', () {
      const target = LevelTarget(x: 100, y: 200, width: 40, height: 120);
      expect(target.centerX, 120);
      expect(target.centerY, 260);
    });

    test('levels are numbered from one, without gaps', () {
      final indexes = levelIds().map((id) => load(id).index).toList()..sort();
      expect(indexes, List.generate(indexes.length, (i) => i + 1));
    });

    test('the character sprite the maps hide is present', () {
      expect(File('assets/images/targets/findo.png').existsSync(), isTrue);
    });
  });
}
