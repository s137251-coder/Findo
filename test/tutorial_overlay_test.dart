import 'dart:io';

import 'package:findo/game/findo_game.dart';
import 'package:findo/managers/audio_manager.dart';
import 'package:findo/managers/level_manager.dart';
import 'package:findo/managers/localization_manager.dart';
import 'package:findo/managers/save_manager.dart';
import 'package:findo/managers/score_manager.dart';
import 'package:findo/models/level_definition.dart';
import 'package:findo/ui/tutorial_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The coach card is drawn over a live game on whatever phone the player
/// has, in Hebrew or English. A card that overflows on a small screen hides
/// the very instruction the player needs, so every step is laid out on a
/// small phone in both languages.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(LocalizationManager, FindoGame)> setUpFor(String code) async {
    SharedPreferences.setMockInitialValues({'findo.language': code});
    final save = await SaveManager.load();
    final localization = LocalizationManager(save);
    await localization.initialize(Locale(code));
    final level = LevelDefinition.parse(
      File('assets/images/maps/meta/level_01.json').readAsStringSync(),
    );
    final game = FindoGame(
      level: level,
      target: level.targets.first,
      scoreManager: ScoreManager(),
      levelManager: LevelManager(save),
      audioManager: AudioManager(save),
      onLevelCleared: () {},
      onTimeUp: () {},
    );
    return (localization, game);
  }

  for (final code in ['en', 'he']) {
    testWidgets('every step fits a small phone in $code', (tester) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      final (localization, game) = await tester.runAsync(() => setUpFor(code)) ??
          (throw StateError('setup did not finish'));
      final tutorial = TutorialController();
      await tester.pumpWidget(
        LocalizationScope(
          manager: localization,
          child: MaterialApp(
            home: Directionality(
              textDirection: localization.textDirection,
              child: Scaffold(
                body: TutorialOverlay(game: game, controller: tutorial),
              ),
            ),
          ),
        ),
      );

      for (final step in TutorialStep.values.where((s) => s != TutorialStep.done)) {
        expect(tutorial.step, step);
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull, reason: '$code ${step.name}');
        expect(find.text(localization.t('tutorial.${step.name}.title')), findsOneWidget);
        expect(find.text(localization.t('tutorial.skip')), findsOneWidget);
        if (step == TutorialStep.meet) {
          await tester.tap(find.text(localization.t('tutorial.next')));
        } else {
          tutorial.did(step);
        }
        await tester.pump();
      }
      expect(tutorial.active, isFalse);
      expect(find.text(localization.t('tutorial.skip')), findsNothing);
    });
  }
}
