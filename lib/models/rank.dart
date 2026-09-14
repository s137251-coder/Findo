/// The ten ranks a player moves through, one for every ten levels.
///
/// A rank is a function of the level number rather than a stored table: the
/// hundred-level ladder is divided evenly, so there is nothing to keep in
/// sync. Only the names and the descriptions live outside the code, in the
/// translation files, because they have to exist in both languages.
class Rank {
  const Rank(this.number);

  /// Levels covered by one rank.
  static const levelsPerRank = 10;

  /// How many ranks the ladder defines.
  static const count = 10;

  /// 1 to [count].
  final int number;

  /// The rank a level belongs to. Level 1 is rank 1, level 100 is rank 10.
  factory Rank.forLevel(int levelIndex) {
    final n = ((levelIndex - 1) ~/ levelsPerRank) + 1;
    return Rank(n.clamp(1, count));
  }

  int get firstLevel => (number - 1) * levelsPerRank + 1;

  int get lastLevel => number * levelsPerRank;

  /// Translation keys. The strings themselves are in `assets/locales`.
  String get nameKey => 'chapter.$number.name';

  String get blurbKey => 'chapter.$number.blurb';

  /// The rank earned by having unlocked [unlockedLevelIndex].
  ///
  /// A rank counts bands *finished*, not the band you are standing in: the
  /// first is earned by clearing level 10, which opens level 11. Earning one
  /// on level 1 would make it a participation badge rather than something the
  /// player worked ten levels for.
  static Rank? earnedBy(int unlockedLevelIndex) {
    final finished = (unlockedLevelIndex - 1) ~/ levelsPerRank;
    if (finished < 1) {
      return null;
    }
    return Rank(finished.clamp(1, count));
  }

  @override
  bool operator ==(Object other) => other is Rank && other.number == number;

  @override
  int get hashCode => number.hashCode;

  @override
  String toString() => 'Rank($number)';
}
