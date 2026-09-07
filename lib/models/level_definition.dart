import 'dart:convert';
import 'dart:ui' show Color;

/// One place Findo may be hiding on a map, in map pixels.
///
/// A level carries several of these and the game picks one when it opens, so
/// replaying a level is another search rather than a memory test. The boxes
/// come from `tool/build_level.py`, which finds crowded, well-separated spots
/// in the artwork, so they are measured rather than eyeballed.
class LevelTarget {
  const LevelTarget({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  double get centerX => x + width / 2;

  double get centerY => y + height / 2;

  factory LevelTarget.fromJson(Map<String, dynamic> json) {
    return LevelTarget(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
    );
  }
}

/// Score needed for each star rating at the end of a level.
class StarThresholds {
  const StarThresholds({required this.one, required this.two, required this.three});

  final int one;
  final int two;
  final int three;

  /// Stars earned for [score], from 0 (below the lowest bar) to 3.
  int starsFor(int score) {
    if (score >= three) {
      return 3;
    }
    if (score >= two) {
      return 2;
    }
    if (score >= one) {
      return 1;
    }
    return 0;
  }

  factory StarThresholds.fromJson(Map<String, dynamic> json) {
    return StarThresholds(
      one: (json['one'] as num).toInt(),
      two: (json['two'] as num).toInt(),
      three: (json['three'] as num).toInt(),
    );
  }
}

/// One playable map: the artwork, where Findo is in it, and the scoring rules.
class LevelDefinition {
  const LevelDefinition({
    required this.id,
    required this.index,
    required this.nameKey,
    required this.map,
    required this.mapWidth,
    required this.mapHeight,
    required this.timeLimitSeconds,
    required this.starThresholds,
    required this.targets,
    this.tint,
  });

  final String id;

  /// 1-based position in the level list; also drives unlock order.
  final int index;

  final String nameKey;

  /// Path relative to `assets/images/`, which is Flame's image cache prefix.
  final String map;

  final double mapWidth;
  final double mapHeight;
  final int timeLimitSeconds;
  final StarThresholds starThresholds;

  /// Every place she may be. Never empty.
  final List<LevelTarget> targets;

  /// Multiplied over her sprite so she is lit like the map she stands in.
  /// Null on maps shot in ordinary daylight.
  final Color? tint;

  factory LevelDefinition.fromJson(Map<String, dynamic> json) {
    final size = json['mapSize'] as Map<String, dynamic>;
    return LevelDefinition(
      id: json['id'] as String,
      index: (json['index'] as num).toInt(),
      nameKey: json['nameKey'] as String,
      map: json['map'] as String,
      mapWidth: (size['width'] as num).toDouble(),
      mapHeight: (size['height'] as num).toDouble(),
      timeLimitSeconds: (json['timeLimitSeconds'] as num).toInt(),
      starThresholds:
          StarThresholds.fromJson(json['starThresholds'] as Map<String, dynamic>),
      targets: (json['targets'] as List<dynamic>)
          .map((spot) => LevelTarget.fromJson(spot as Map<String, dynamic>))
          .toList(growable: false),
      tint: _tintFromJson(json['tint'] as Map<String, dynamic>?),
    );
  }

  static LevelDefinition parse(String source) =>
      LevelDefinition.fromJson(jsonDecode(source) as Map<String, dynamic>);
}

/// The tint is stored as per-channel gain around 1.0. It is carried as a
/// [Color] because that is what `BlendMode.modulate` multiplies by.
Color? _tintFromJson(Map<String, dynamic>? json) {
  if (json == null) {
    return null;
  }
  int channel(String key) =>
      ((json[key] as num).toDouble() * 255).round().clamp(0, 255);
  return Color.fromARGB(255, channel('r'), channel('g'), channel('b'));
}

/// What the player walked away from a level with.
class LevelResult {
  const LevelResult({
    required this.levelId,
    required this.found,
    required this.baseScore,
    required this.penalty,
    required this.timeBonus,
    required this.stars,
    required this.isNewBest,
    required this.secondsTaken,
  });

  final String levelId;

  /// Whether Findo was spotted before the clock ran out.
  final bool found;

  /// Points for finding her.
  final int baseScore;

  /// Points lost to wrong taps, as a positive number.
  final int penalty;

  final int timeBonus;
  final int stars;
  final bool isNewBest;

  /// How long the hunt took, for the summary line.
  final int secondsTaken;

  int get total => baseScore - penalty + timeBonus;
}
