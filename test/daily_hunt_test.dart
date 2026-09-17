import 'dart:convert';
import 'dart:io';

import 'package:findo/managers/save_manager.dart';
import 'package:findo/models/level_definition.dart';
import 'package:findo/models/daily_hunt.dart';
import 'package:findo/ui/daily_hunt_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The daily hunt only works if every phone agrees on the day, the level and
/// the hiding place, without asking a server. These tests pin that agreement.
void main() {
  group('the day', () {
    test('turns over at midnight Pacific standard time in winter', () {
      expect(DailyHunt.pacificDay(DateTime.utc(2026, 1, 15, 7, 59)), '2026-01-14');
      expect(DailyHunt.pacificDay(DateTime.utc(2026, 1, 15, 8, 0)), '2026-01-15');
    });

    test('turns over at midnight Pacific daylight time in summer', () {
      expect(DailyHunt.pacificDay(DateTime.utc(2026, 7, 1, 6, 59)), '2026-06-30');
      expect(DailyHunt.pacificDay(DateTime.utc(2026, 7, 1, 7, 0)), '2026-07-01');
    });

    test('follows the clocks changing in March and November', () {
      // Daylight time starts 8 March 2026: an hour after that night, 07:30 UTC
      // is already the ninth in California.
      expect(DailyHunt.pacificDay(DateTime.utc(2026, 3, 9, 7, 30)), '2026-03-09');
      // It ends 1 November 2026: 07:30 UTC the next morning is still the first.
      expect(DailyHunt.pacificDay(DateTime.utc(2026, 11, 2, 7, 30)), '2026-11-01');
    });

    test('does not depend on the phone\'s own time zone', () {
      final instant = DateTime.utc(2026, 9, 17, 12);
      expect(DailyHunt.pacificDay(instant.toLocal()), DailyHunt.pacificDay(instant));
    });
  });

  group('the pick', () {
    test('is pinned: changing it would split the table between app versions', () {
      // Computed independently of this code. If one of these fails, players on
      // the old and new builds are hunting in different places on the same day.
      DailyHunt at(String day) => DailyHunt.at(DateTime.parse('${day}T20:00:00Z'));
      expect(at('2026-09-17').levelIndex, 30);
      expect(at('2026-09-17').spotSeed, 563);
      expect(at('2026-12-25').levelIndex, 59);
      expect(at('2026-12-25').spotSeed, 572);
      expect(at('2027-03-01').levelIndex, 40);
      expect(at('2027-03-01').spotSeed, 664);
    });

    test('is the same all day long', () {
      final morning = DailyHunt.at(DateTime.utc(2026, 9, 17, 8, 5));
      final night = DailyHunt.at(DateTime.utc(2026, 9, 18, 6, 55));
      expect(night.day, morning.day);
      expect(night.levelIndex, morning.levelIndex);
      expect(night.spotSeed, morning.spotSeed);
    });

    test('stays inside the pool and uses most of it over a year', () {
      final used = <int, int>{};
      var instant = DateTime.utc(2026, 1, 1, 20);
      for (var i = 0; i < 365; i++) {
        final hunt = DailyHunt.at(instant);
        expect(hunt.levelIndex, inInclusiveRange(DailyHunt.firstLevel, DailyHunt.lastLevel));
        used[hunt.levelIndex] = (used[hunt.levelIndex] ?? 0) + 1;
        instant = instant.add(const Duration(days: 1));
      }
      expect(used.length, greaterThanOrEqualTo(26), reason: 'whole stretches of the pool never come up');
      expect(used.values.reduce((a, b) => a > b ? a : b), lessThan(30),
          reason: 'one level comes up far more often than the rest');
    });
  });

  group('the difficulty', () {
    test('every daily hunt runs on level 100\'s clock and drift, on its own map', () {
      final json = jsonDecode(File('assets/images/maps/meta/level_30.json').readAsStringSync())
          as Map<String, dynamic>;
      final level = LevelDefinition.fromJson(json);
      final hard = DailyHunt.harden(level);

      expect(hard.timeLimitSeconds, 45);
      expect(hard.motion, 1.0);
      expect(hard.map, level.map, reason: 'the map must not change');
      expect(hard.index, level.index);
      expect(hard.targets.length, level.targets.length);
      for (var i = 0; i < level.targets.length; i++) {
        expect(hard.targets[i].x, level.targets[i].x, reason: 'a hiding place moved');
        expect(hard.targets[i].height, greaterThanOrEqualTo(100),
            reason: 'Findo is smaller than the fair limit');
      }
    });
  });

  group('the time shown', () {
    test('reads as minutes, seconds and tenths', () {
      expect(formatDailyTime(42300), '0:42.3');
      expect(formatDailyTime(125049), '2:05.0');
      expect(formatDailyTime(59960), '1:00.0');
    });
  });

  group('the saved attempt', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('counts from the moment the hunt opens, and resets the next day', () async {
      SharedPreferences.setMockInitialValues({});
      final save = await SaveManager.load();
      expect(save.dailyStarted('2026-09-17'), isFalse);

      await save.markDailyStarted('2026-09-17');
      expect(save.dailyStarted('2026-09-17'), isTrue);
      expect(save.dailyTimeFor('2026-09-17'), isNull, reason: 'no result yet');

      await save.recordDailyTime(41800);
      expect(save.dailyTimeFor('2026-09-17'), 41800);

      expect(save.dailyStarted('2026-09-18'), isFalse);
      expect(save.dailyTimeFor('2026-09-18'), isNull);

      await save.markDailyStarted('2026-09-18');
      expect(save.dailyTimeFor('2026-09-18'), isNull, reason: 'yesterday\'s time carried over');
    });
  });
}
