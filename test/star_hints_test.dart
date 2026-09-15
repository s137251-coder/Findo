import 'package:flutter_test/flutter_test.dart';
import 'package:findo/managers/save_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every ten stars banked pay for one free hint, and each is paid only once.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SaveManager> freshSave() async {
    SharedPreferences.setMockInitialValues({});
    return SaveManager.load();
  }

  Future<void> rate(SaveManager save, int level, int stars) => save.recordResult(
        levelId: 'level_$level',
        score: 100,
        stars: stars,
      );

  test('nine stars pay nothing', () async {
    final save = await freshSave();
    for (var level = 1; level <= 3; level++) {
      await rate(save, level, 3);
    }
    expect(save.totalStars, 9);
    expect(await save.claimStarHints(), 0);
    expect(save.hintCount, SaveManager.startingHints);
  });

  test('ten stars pay one hint, and only once', () async {
    final save = await freshSave();
    for (var level = 1; level <= 3; level++) {
      await rate(save, level, 3);
    }
    await rate(save, 4, 1);
    expect(await save.claimStarHints(), 1);
    expect(save.hintCount, SaveManager.startingHints + 1);
    expect(await save.claimStarHints(), 0);
    expect(save.hintCount, SaveManager.startingHints + 1);
  });

  test('a better replay adds stars, a worse one takes none away', () async {
    final save = await freshSave();
    await rate(save, 1, 1);
    await rate(save, 1, 3);
    await rate(save, 1, 0);
    expect(save.totalStars, 3);
  });

  test('stars banked earlier are paid all at once', () async {
    final save = await freshSave();
    for (var level = 1; level <= 11; level++) {
      await rate(save, level, 3);
    }
    expect(save.totalStars, 33);
    expect(await save.claimStarHints(), 3);
    expect(save.starHintsGranted, 3);
  });

  test('distance to the next hint', () {
    expect(SaveManager.starsToNextHint(0), 10);
    expect(SaveManager.starsToNextHint(9), 1);
    expect(SaveManager.starsToNextHint(10), 10);
    expect(SaveManager.starsToNextHint(47), 3);
  });
}
