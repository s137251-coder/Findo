import 'dart:io';

import 'package:findo/managers/reminder_manager.dart';
import 'package:findo/managers/review_manager.dart';
import 'package:findo/managers/save_manager.dart';
import 'package:findo/ui/tutorial_overlay.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the testers' report asked for: a guided first hunt, a rating ask at
/// the right moment, a reminder that does not nag, and a save that follows
/// the player to a new phone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SaveManager> freshSave([Map<String, Object> values = const {}]) async {
    SharedPreferences.setMockInitialValues(values);
    return SaveManager.load();
  }

  group('the guided first hunt', () {
    test('walks the steps in order, each on the player doing it', () {
      final tutorial = TutorialController();
      expect(tutorial.step, TutorialStep.meet);
      tutorial.did(TutorialStep.meet);
      expect(tutorial.step, TutorialStep.drag);
      tutorial.did(TutorialStep.drag);
      expect(tutorial.step, TutorialStep.zoom);
      tutorial.did(TutorialStep.zoom);
      expect(tutorial.step, TutorialStep.hint);
      tutorial.did(TutorialStep.hint);
      expect(tutorial.step, TutorialStep.find);
      tutorial.did(TutorialStep.find);
      expect(tutorial.active, isFalse);
    });

    test('a gesture done early is not taught again', () {
      final tutorial = TutorialController()..did(TutorialStep.meet);
      // Pinching while asked to drag.
      tutorial.did(TutorialStep.zoom);
      expect(tutorial.step, TutorialStep.drag);
      tutorial.did(TutorialStep.drag);
      expect(tutorial.step, TutorialStep.hint, reason: 'zoom was already done');
    });

    test('tapping her early does not skip the hint lesson', () {
      final tutorial = TutorialController()..did(TutorialStep.meet);
      tutorial.did(TutorialStep.find);
      expect(tutorial.step, TutorialStep.drag);
    });

    test('skipping ends it at once', () {
      final tutorial = TutorialController()..skip();
      expect(tutorial.active, isFalse);
      tutorial.did(TutorialStep.meet);
      expect(tutorial.step, TutorialStep.done);
    });

    test('every step has its words in both languages', () {
      for (final code in ['en', 'he']) {
        final text = File('assets/locales/$code.json').readAsStringSync();
        for (final step in TutorialStep.values.where((s) => s != TutorialStep.done)) {
          expect(text, contains('"tutorial.${step.name}.title"'), reason: '$code ${step.name}');
          expect(text, contains('"tutorial.${step.name}.body"'), reason: '$code ${step.name}');
        }
      }
    });
  });

  group('asking for a rating', () {
    test('never on a weak clear or before the first milestone', () {
      expect(ReviewManager.shouldAsk(levelIndex: 3, stars: 1, alreadyAskedAt: 0), isFalse);
      expect(ReviewManager.shouldAsk(levelIndex: 2, stars: 3, alreadyAskedAt: 0), isFalse);
    });

    test('at a milestone, or the next good clear after one', () {
      expect(ReviewManager.shouldAsk(levelIndex: 3, stars: 2, alreadyAskedAt: 0), isTrue);
      expect(ReviewManager.shouldAsk(levelIndex: 5, stars: 3, alreadyAskedAt: 0), isTrue);
    });

    test('once per milestone', () {
      expect(ReviewManager.shouldAsk(levelIndex: 4, stars: 3, alreadyAskedAt: 3), isFalse);
      expect(ReviewManager.shouldAsk(levelIndex: 7, stars: 3, alreadyAskedAt: 3), isFalse);
      expect(ReviewManager.shouldAsk(levelIndex: 8, stars: 3, alreadyAskedAt: 3), isTrue);
    });

    test('replaying an early level after being asked does not ask again', () {
      expect(ReviewManager.shouldAsk(levelIndex: 3, stars: 3, alreadyAskedAt: 9), isFalse);
    });
  });

  group('the Daily Hunt reminder', () {
    test('this evening and the next ones when today is still to play', () {
      final now = DateTime(2026, 10, 25, 9);
      final times = ReminderManager.evenings(now, playedToday: false);
      expect(times, [
        DateTime(2026, 10, 25, ReminderManager.hour),
        DateTime(2026, 10, 26, ReminderManager.hour),
        DateTime(2026, 10, 27, ReminderManager.hour),
      ]);
    });

    test('nothing tonight once today is played', () {
      final now = DateTime(2026, 10, 25, 9);
      final times = ReminderManager.evenings(now, playedToday: true);
      expect(times.first, DateTime(2026, 10, 26, ReminderManager.hour));
      expect(times.length, ReminderManager.daysAhead);
    });

    test('nothing in the past', () {
      final now = DateTime(2026, 10, 25, 21);
      final times = ReminderManager.evenings(now, playedToday: false);
      expect(times.every((time) => time.isAfter(now)), isTrue);
    });

    test('across the end of a month', () {
      final times = ReminderManager.evenings(DateTime(2026, 10, 31, 20), playedToday: false);
      expect(times.first, DateTime(2026, 11, 1, ReminderManager.hour));
    });
  });

  group('the save that follows the player', () {
    test('merging keeps the better of each', () async {
      final save = await freshSave();
      await save.recordResult(levelId: 'level_1', score: 900, stars: 2);
      await save.recordResult(levelId: 'level_2', score: 500, stars: 1);
      await save.unlockLevel(3);

      await save.mergeProgress({
        'unlocked': 6,
        'levels': {
          'level_1': {'bestScore': 700, 'stars': 3},
          'level_5': {'bestScore': 1200, 'stars': 3},
        },
        'hints': 12,
        'starHints': 1,
        'rankSeen': 0,
        'finaleSeen': false,
        'adsRemoved': true,
        'tutorialDone': true,
      });

      expect(save.unlockedLevelIndex, 6);
      expect(save.progressFor('level_1').bestScore, 900);
      expect(save.progressFor('level_1').stars, 3);
      expect(save.progressFor('level_2').stars, 1);
      expect(save.progressFor('level_5').bestScore, 1200);
      expect(save.hintCount, 12);
      expect(save.starHintsGranted, 1);
      expect(save.adsRemoved, isTrue);
      expect(save.tutorialDone, isTrue);
    });

    test('a save from an older phone never takes anything away', () async {
      final save = await freshSave();
      await save.unlockLevel(10);
      await save.setAdsRemoved(true);
      await save.setHintCount(20);
      await save.mergeProgress({
        'unlocked': 2,
        'levels': <String, Object>{},
        'hints': 1,
        'adsRemoved': false,
      });
      expect(save.unlockedLevelIndex, 10);
      expect(save.adsRemoved, isTrue);
      expect(save.hintCount, 20);
    });

    test('a save with junk in it is ignored, not fatal', () async {
      final save = await freshSave();
      await save.mergeProgress({'levels': 'nonsense', 'unlocked': 'x', 'hints': null});
      await save.mergeProgress({
        'levels': {
          'level_1': {'bestScore': 'lots', 'stars': 3},
          'level_2': {'bestScore': 10, 'stars': 99},
        },
      });
      expect(save.progressFor('level_1').isPlayed, isFalse);
      expect(save.progressFor('level_2').isPlayed, isFalse);
      expect(save.unlockedLevelIndex, 1);
      expect(save.hintCount, SaveManager.startingHints);
    });

    test('the rules accept exactly the fields the game writes', () async {
      final save = await freshSave();
      final rules = File('firestore.rules').readAsStringSync();
      final block = rules.substring(rules.indexOf('match /saves'), rules.indexOf('Nothing else'));
      for (final field in [...save.exportProgress().keys, 'at']) {
        expect(block, contains("'$field'"), reason: 'the rules would refuse $field');
      }
    });
  });
}
