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
  _weekGroup();

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

  group('when the next hunt opens', () {
    test('is the next midnight Pacific', () {
      // 17 Sep 2026, 12:00 UTC is 05:00 in California; the hunt turns over 19
      // hours later, which is ten in the morning in Israel.
      expect(
        DailyHunt.nextReset(DateTime.utc(2026, 9, 17, 12)),
        DateTime.utc(2026, 9, 18, 7),
      );
      expect(
        DailyHunt.untilNextHunt(DateTime.utc(2026, 9, 17, 12)),
        const Duration(hours: 19),
      );
    });

    test('is the next midnight in winter too, an hour later by UTC', () {
      expect(
        DailyHunt.nextReset(DateTime.utc(2026, 1, 15, 12)),
        DateTime.utc(2026, 1, 16, 8),
      );
    });

    test('follows the clocks when they change in between', () {
      // The Sunday the US goes forward: the day that starts at 08:00 UTC ends
      // at 07:00 UTC, because an hour of it was skipped.
      expect(
        DailyHunt.nextReset(DateTime.utc(2026, 3, 8, 12)),
        DateTime.utc(2026, 3, 9, 7),
      );
      // And the Sunday it goes back, the day is an hour longer.
      expect(
        DailyHunt.nextReset(DateTime.utc(2026, 11, 1, 12)),
        DateTime.utc(2026, 11, 2, 8),
      );
    });

    test('never promises a hunt more than a day away', () {
      for (var hour = 0; hour < 24 * 400; hour++) {
        final instant = DateTime.utc(2026).add(Duration(hours: hour));
        final left = DailyHunt.untilNextHunt(instant);
        expect(left, greaterThan(Duration.zero), reason: '$instant');
        expect(left, lessThanOrEqualTo(const Duration(hours: 25)),
            reason: '$instant');
        // And the hunt on the far side of it is a different one.
        expect(
          DailyHunt.at(instant.add(left)).day,
          isNot(DailyHunt.at(instant).day),
          reason: '$instant',
        );
      }
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

/// Weeks, for the table that ranks a player's best of seven hunts.
void _weekGroup() {
  group('the week a hunt belongs to', () {
    test('is named by the Sunday it started on', () {
      // 22 Sep 2026 is a Tuesday; its week began on Sunday the 20th.
      expect(DailyHunt.pacificWeek(DateTime.utc(2026, 9, 22, 20)), '2026-09-20');
      expect(DailyHunt.pacificWeek(DateTime.utc(2026, 9, 20, 20)), '2026-09-20');
      // The Saturday is the last day of that week.
      expect(DailyHunt.pacificWeek(DateTime.utc(2026, 9, 26, 20)), '2026-09-20');
      // And the Sunday after starts the next one.
      expect(DailyHunt.pacificWeek(DateTime.utc(2026, 9, 27, 20)), '2026-09-27');
    });

    test('turns over with the hunt, not with the phone', () {
      // Seven in the morning UTC on a Sunday is still Saturday in California,
      // so it is still the old week -- the same edge the day itself has.
      expect(DailyHunt.pacificWeek(DateTime.utc(2026, 9, 27, 6)), '2026-09-20');
      expect(DailyHunt.pacificWeek(DateTime.utc(2026, 9, 27, 7)), '2026-09-27');
    });

    test('a week holds exactly the seven days of its own hunts', () {
      final weeks = <String, Set<String>>{};
      for (var i = 0; i < 70; i++) {
        final instant = DateTime.utc(2026, 9, 1, 20).add(Duration(days: i));
        weeks
            .putIfAbsent(DailyHunt.pacificWeek(instant), () => <String>{})
            .add(DailyHunt.pacificDay(instant));
      }
      // The first and last may be part weeks; every whole one has seven days.
      final whole = weeks.values.where((days) => days.length != 7).length;
      expect(whole, lessThanOrEqualTo(2), reason: '$weeks');
    });
  });
}
