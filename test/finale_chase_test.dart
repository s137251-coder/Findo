import 'package:findo/managers/level_manager.dart';
import 'package:findo/managers/save_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the ending sends a player next.
///
/// Clearing every level is not finishing the game -- three stars on each is
/// what finishing means -- so the last screen points at the level the player
/// is closest to taking a third star from. Getting that wrong would send them
/// to their worst level instead of their most winnable one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(SaveManager, LevelManager)> game({required int unlocked}) async {
    SharedPreferences.setMockInitialValues({});
    final save = await SaveManager.load();
    await save.unlockLevel(unlocked);
    final levels = LevelManager(save);
    await levels.loadCatalogue();
    return (save, levels);
  }

  test('a two-star level beats a one-star level, however close that one is',
      () async {
    final (save, levels) = await game(unlocked: 6);
    final second = levels.levels[1];
    final third = levels.levels[2];
    // One star and a single point short of three.
    await save.recordResult(
      levelId: third.id,
      score: third.starThresholds.three - 1,
      stars: 1,
    );
    // Two stars, and further off.
    await save.recordResult(
      levelId: second.id,
      score: second.starThresholds.three - 400,
      stars: 2,
    );
    expect(levels.closestToThreeStars()?.id, second.id);
  });

  test('between two-star levels, the nearer score wins', () async {
    final (save, levels) = await game(unlocked: 6);
    final first = levels.levels[0];
    final second = levels.levels[1];
    await save.recordResult(
      levelId: first.id,
      score: first.starThresholds.three - 600,
      stars: 2,
    );
    await save.recordResult(
      levelId: second.id,
      score: second.starThresholds.three - 20,
      stars: 2,
    );
    expect(levels.closestToThreeStars()?.id, second.id);
  });

  test('a level already at three stars is not offered', () async {
    final (save, levels) = await game(unlocked: 2);
    final first = levels.levels[0];
    final second = levels.levels[1];
    await save.recordResult(
      levelId: first.id,
      score: first.starThresholds.three,
      stars: 3,
    );
    await save.recordResult(
      levelId: second.id,
      score: 10,
      stars: 0,
    );
    expect(levels.closestToThreeStars()?.id, second.id);
  });

  test('locked levels are never the suggestion', () async {
    final (_, levels) = await game(unlocked: 1);
    expect(levels.closestToThreeStars()?.id, levels.levels.first.id);
  });

  test('nothing to chase once every unlocked level has three', () async {
    final (save, levels) = await game(unlocked: 2);
    for (final level in levels.levels.take(2)) {
      await save.recordResult(
        levelId: level.id,
        score: level.starThresholds.three,
        stars: 3,
      );
    }
    expect(levels.closestToThreeStars(), isNull);
  });
}
