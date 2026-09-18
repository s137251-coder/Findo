import 'dart:convert';

import 'level_definition.dart';

/// The day's hunt: one level and one hiding place, the same for every player.
///
/// Nothing is fetched. The day is worked out from the clock and the level and
/// the spot from the day, with a hash that gives the same answer on every
/// phone -- so a player on Android and one on an iPhone, or two players who
/// never opened the game at the same moment, are all looking for Findo in the
/// same place.
class DailyHunt {
  const DailyHunt({required this.day, required this.levelIndex, required this.spotSeed});

  /// The pool the day's level is drawn from.
  ///
  /// Fixed on purpose, not "every level from 30 on". A player who has not
  /// updated would otherwise draw from a shorter list than one who has, get a
  /// different level on the same day, and post a time to the same table for a
  /// different hunt. Widening the pool splits the table between app versions,
  /// so do it only together with an update everyone is asked to install.
  static const firstLevel = 30;
  static const lastLevel = 59;

  /// The difficulty every daily hunt is played at, whatever map it draws:
  /// the top of the curve, level 100's clock and drift. Findo stays at the
  /// size the curve floors at, which is the fair limit for spotting her.
  ///
  /// Constants for the same reason as the pool: players on different builds
  /// have to be racing the same clock.
  static const timeLimitSeconds = 45;
  static const motion = 1.0;

  /// [level] as the daily hunt plays it.
  static LevelDefinition harden(LevelDefinition level) => LevelDefinition(
        id: level.id,
        index: level.index,
        nameKey: level.nameKey,
        map: level.map,
        mapWidth: level.mapWidth,
        mapHeight: level.mapHeight,
        timeLimitSeconds: timeLimitSeconds,
        starThresholds: level.starThresholds,
        targets: level.targets,
        tint: level.tint,
        motion: motion,
      );

  /// The Play Games leaderboard the day's times go to.
  static const androidLeaderboardId = 'CgkIkpfL0vcBEAIQAQ';

  /// `yyyy-MM-dd` on the US Pacific clock.
  final String day;

  /// Which level, by its number.
  final int levelIndex;

  /// Chooses the hiding place: taken modulo the level's number of spots.
  final int spotSeed;

  /// The hunt for the day that [instant] falls in.
  factory DailyHunt.at(DateTime instant) {
    final day = pacificDay(instant);
    final hash = _fnv1a('findo-daily:$day');
    final span = lastLevel - firstLevel + 1;
    return DailyHunt(
      day: day,
      levelIndex: firstLevel + hash % span,
      // A second draw from the same hash, so the spot does not simply follow
      // the level.
      spotSeed: (hash ~/ span) % 997,
    );
  }

  /// The calendar day on the US Pacific clock.
  ///
  /// Google's daily leaderboards turn over at midnight Pacific time, so the
  /// day's hunt does too: a hunt that changed at local midnight would, for
  /// most of the world, post the morning's times to yesterday's table.
  static String pacificDay(DateTime instant) {
    final utc = instant.toUtc();
    final offset = _isPacificDaylightTime(utc) ? 7 : 8;
    final local = utc.subtract(Duration(hours: offset));
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-${two(local.day)}';
  }

  /// How long until the next hunt opens.
  ///
  /// Players reasonably expect a daily thing to turn over at their own
  /// midnight, and this one does not -- it turns over with Google's table, so
  /// that everyone's time on the table belongs to the same hunt. The screen
  /// therefore has to say when, rather than leave a player to discover that
  /// their midnight changed nothing.
  static Duration untilNextHunt(DateTime instant) =>
      nextReset(instant).difference(instant.toUtc());

  /// The instant, in UTC, when the day's hunt is replaced.
  ///
  /// Found by asking [pacificDay] rather than by arithmetic on the offset: the
  /// clocks go forward or back in between twice a year, and a day worked out
  /// from today's offset was an hour wrong on both of those days -- once
  /// promising a new hunt that was still the old one. The offset is always a
  /// whole number of hours, so the turn is always on a whole hour, and at most
  /// twenty-five of them need asking.
  static DateTime nextReset(DateTime instant) {
    final utc = instant.toUtc();
    final today = pacificDay(utc);
    var hour = DateTime.utc(utc.year, utc.month, utc.day, utc.hour)
        .add(const Duration(hours: 1));
    while (pacificDay(hour) == today) {
      hour = hour.add(const Duration(hours: 1));
    }
    return hour;
  }

  /// US daylight saving: from 02:00 local on the second Sunday of March to
  /// 02:00 local on the first Sunday of November.
  static bool _isPacificDaylightTime(DateTime utc) {
    final year = utc.year;
    // 02:00 Pacific standard time is 10:00 UTC; 02:00 daylight time is 09:00.
    final starts = _nthSunday(year, 3, 2).add(const Duration(hours: 10));
    final ends = _nthSunday(year, 11, 1).add(const Duration(hours: 9));
    return !utc.isBefore(starts) && utc.isBefore(ends);
  }

  static DateTime _nthSunday(int year, int month, int n) {
    final first = DateTime.utc(year, month, 1);
    final toSunday = (DateTime.sunday - first.weekday) % 7;
    return DateTime.utc(year, month, 1 + toSunday + 7 * (n - 1));
  }

  /// 32-bit FNV-1a. Dart's own string hash is not promised to stay the same
  /// between releases, and this one has to agree across every phone forever.
  static int _fnv1a(String text) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(text)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash;
  }
}
