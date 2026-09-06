import 'package:findo/managers/score_manager.dart';
import 'package:findo/models/level_definition.dart';
import 'package:flutter_test/flutter_test.dart';

LevelDefinition _level({int timeLimit = 100}) {
  return LevelDefinition(
    id: 'test_level',
    index: 1,
    nameKey: 'level.test',
    background: 'levels/park.png',
    worldWidth: 2048,
    worldHeight: 1536,
    timeLimitSeconds: timeLimit,
    starThresholds: const StarThresholds(one: 100, two: 400, three: 900),
    items: const [
      LevelItem(id: 'apple', sprite: 'items/apple.png', x: 10, y: 10, size: 100, angle: 0),
      LevelItem(id: 'key', sprite: 'items/key.png', x: 20, y: 20, size: 100, angle: 0),
    ],
  );
}

void main() {
  group('ScoreManager', () {
    test('awards the base score for an isolated find', () {
      final manager = ScoreManager()..startLevel(_level());

      expect(manager.registerFind(), ScoreManager.basePoints);
      expect(manager.score, ScoreManager.basePoints);
      expect(manager.multiplier, 1);
    });

    test('raises the multiplier while finds stay inside the combo window', () {
      final manager = ScoreManager()..startLevel(_level());

      manager.registerFind();
      expect(manager.registerFind(), ScoreManager.basePoints * 2);
      manager.registerFind();
      expect(manager.registerFind(), ScoreManager.basePoints * 3);
      expect(manager.multiplier, ScoreManager.maxMultiplier);
    });

    test('drops the streak once the combo window lapses', () {
      final manager = ScoreManager()..startLevel(_level());

      manager.registerFind();
      manager.registerFind();
      expect(manager.comboActive, isTrue);

      manager.update(ScoreManager.comboWindowSeconds + 0.1);
      expect(manager.comboActive, isFalse);
      expect(manager.registerFind(), ScoreManager.basePoints);
    });

    test('a misclick costs points and time and breaks the streak', () {
      final manager = ScoreManager()..startLevel(_level(timeLimit: 60));

      manager.registerFind();
      manager.registerFind();
      final timeBefore = manager.timeRemaining;

      manager.registerMisclick();

      expect(manager.score, ScoreManager.basePoints * 3 - ScoreManager.misclickPenalty);
      expect(manager.timeRemaining, timeBefore - ScoreManager.misclickTimePenalty);
      expect(manager.multiplier, 1);
    });

    test('never reports a negative score', () {
      final manager = ScoreManager()..startLevel(_level());

      for (var i = 0; i < 5; i++) {
        manager.registerMisclick();
      }

      expect(manager.score, 0);
    });

    test('reports the tick that the timer runs out, and only that tick', () {
      final manager = ScoreManager()..startLevel(_level(timeLimit: 1));

      expect(manager.update(0.5), isFalse);
      expect(manager.update(0.6), isTrue);
      expect(manager.isTimeUp, isTrue);
      expect(manager.update(1.0), isFalse, reason: 'the clock has already stopped');
    });

    test('converts the remaining time into a bonus when the level is cleared', () {
      final level = _level(timeLimit: 100);
      final manager = ScoreManager()..startLevel(level);

      manager.registerFind();
      manager.registerFind();
      manager.update(10);

      final result = manager.finish(
        level: level,
        cleared: true,
        foundCount: 2,
        isNewBest: true,
      );

      expect(result.timeBonus, 90 * ScoreManager.timeBonusPerSecond);
      expect(result.total, result.baseScore - result.penalty + result.timeBonus);
      expect(result.stars, 3);
    });

    test('a failed level earns no time bonus and no stars', () {
      final level = _level(timeLimit: 10);
      final manager = ScoreManager()..startLevel(level);

      manager.registerFind();
      final result = manager.finish(
        level: level,
        cleared: false,
        foundCount: 1,
        isNewBest: false,
      );

      expect(result.timeBonus, 0);
      expect(result.stars, 0);
    });
  });

  group('StarThresholds', () {
    const thresholds = StarThresholds(one: 100, two: 400, three: 900);

    test('maps a score onto the right number of stars', () {
      expect(thresholds.starsFor(0), 0);
      expect(thresholds.starsFor(99), 0);
      expect(thresholds.starsFor(100), 1);
      expect(thresholds.starsFor(399), 1);
      expect(thresholds.starsFor(400), 2);
      expect(thresholds.starsFor(900), 3);
      expect(thresholds.starsFor(5000), 3);
    });
  });
}
