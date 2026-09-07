import 'package:findo/managers/score_manager.dart';
import 'package:findo/models/level_definition.dart';
import 'package:flutter_test/flutter_test.dart';

LevelDefinition _level({int timeLimit = 100}) {
  return LevelDefinition(
    id: 'test_level',
    index: 1,
    nameKey: 'level.test',
    map: 'maps/level_01.png',
    mapWidth: 2048,
    mapHeight: 2048,
    timeLimitSeconds: timeLimit,
    starThresholds: const StarThresholds(one: 100, two: 400, three: 900),
    targets: const [LevelTarget(x: 500, y: 600, width: 44, height: 118)],
  );
}

void main() {
  group('ScoreManager', () {
    test('awards the base score for finding Findo', () {
      final manager = ScoreManager()..startLevel(_level());

      expect(manager.registerFind(), ScoreManager.basePoints);
      expect(manager.score, ScoreManager.basePoints);
    });

    test('a misclick costs points and time', () {
      final manager = ScoreManager()..startLevel(_level(timeLimit: 60));
      manager.registerFind();
      final timeBefore = manager.timeRemaining;

      manager.registerMisclick();

      expect(manager.score, ScoreManager.basePoints - ScoreManager.misclickPenalty);
      expect(manager.timeRemaining, timeBefore - ScoreManager.misclickTimePenalty);
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

    test('converts the remaining time into a bonus when Findo is found', () {
      final level = _level(timeLimit: 100);
      final manager = ScoreManager()..startLevel(level);

      manager.registerFind();
      manager.update(10);

      final result = manager.finish(level: level, found: true, isNewBest: true);

      expect(result.timeBonus, 90 * ScoreManager.timeBonusPerSecond);
      expect(result.total, result.baseScore - result.penalty + result.timeBonus);
      expect(result.stars, 3);
      expect(result.secondsTaken, 10);
    });

    test('a level where she is never found earns no bonus and no stars', () {
      final level = _level(timeLimit: 10);
      final manager = ScoreManager()..startLevel(level);

      manager.update(10);
      final result = manager.finish(level: level, found: false, isNewBest: false);

      expect(result.found, isFalse);
      expect(result.timeBonus, 0);
      expect(result.stars, 0);
    });

    test('pausing stops the clock', () {
      final manager = ScoreManager()..startLevel(_level(timeLimit: 60));
      manager.update(5);
      final atPause = manager.timeRemaining;

      manager.pause();
      manager.update(5);
      expect(manager.timeRemaining, atPause);

      manager.resume();
      manager.update(5);
      expect(manager.timeRemaining, closeTo(atPause - 5, 0.001));
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
