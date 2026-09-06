import 'dart:convert';

/// One collectable placed on a level's map.
class LevelItem {
  const LevelItem({
    required this.id,
    required this.sprite,
    required this.x,
    required this.y,
    required this.size,
    required this.angle,
  });

  /// Stable identifier, also the suffix of its `item.<id>` translation key.
  final String id;

  /// Path relative to `assets/images/`, which is Flame's image cache prefix.
  final String sprite;

  final double x;
  final double y;
  final double size;
  final double angle;

  String get nameKey => 'item.$id';

  factory LevelItem.fromJson(Map<String, dynamic> json) {
    return LevelItem(
      id: json['id'] as String,
      sprite: json['sprite'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      size: (json['size'] as num).toDouble(),
      angle: (json['angle'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Score needed for each star rating at the end of a level.
class StarThresholds {
  const StarThresholds({required this.one, required this.two, required this.three});

  final int one;
  final int two;
  final int three;

  /// Stars earned for [score], from 0 (level failed the lowest bar) to 3.
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

/// A playable map: its artwork, its collectables and its scoring rules.
class LevelDefinition {
  const LevelDefinition({
    required this.id,
    required this.index,
    required this.nameKey,
    required this.background,
    required this.worldWidth,
    required this.worldHeight,
    required this.timeLimitSeconds,
    required this.starThresholds,
    required this.items,
  });

  final String id;

  /// 1-based position in the level list; also drives unlock order.
  final int index;

  final String nameKey;

  /// Path relative to `assets/images/`.
  final String background;

  final double worldWidth;
  final double worldHeight;
  final int timeLimitSeconds;
  final StarThresholds starThresholds;
  final List<LevelItem> items;

  factory LevelDefinition.fromJson(Map<String, dynamic> json) {
    final size = json['worldSize'] as Map<String, dynamic>;
    return LevelDefinition(
      id: json['id'] as String,
      index: (json['index'] as num).toInt(),
      nameKey: json['nameKey'] as String,
      background: json['background'] as String,
      worldWidth: (size['width'] as num).toDouble(),
      worldHeight: (size['height'] as num).toDouble(),
      timeLimitSeconds: (json['timeLimitSeconds'] as num).toInt(),
      starThresholds:
          StarThresholds.fromJson(json['starThresholds'] as Map<String, dynamic>),
      items: (json['items'] as List<dynamic>)
          .map((item) => LevelItem.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  static LevelDefinition parse(String source) =>
      LevelDefinition.fromJson(jsonDecode(source) as Map<String, dynamic>);
}

/// What the player walked away from a level with.
class LevelResult {
  const LevelResult({
    required this.levelId,
    required this.cleared,
    required this.foundCount,
    required this.totalCount,
    required this.baseScore,
    required this.penalty,
    required this.timeBonus,
    required this.stars,
    required this.isNewBest,
  });

  final String levelId;
  final bool cleared;
  final int foundCount;
  final int totalCount;

  /// Points from finding items, combo multipliers included.
  final int baseScore;

  /// Points lost to wrong taps, as a positive number.
  final int penalty;

  final int timeBonus;
  final int stars;
  final bool isNewBest;

  int get total => baseScore - penalty + timeBonus;
}
