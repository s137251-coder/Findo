import 'package:findo/app_services.dart';
import 'package:findo/managers/account_service.dart';
import 'package:findo/managers/audio_manager.dart';
import 'package:findo/managers/leaderboard_service.dart';
import 'package:findo/managers/level_manager.dart';
import 'package:findo/managers/localization_manager.dart';
import 'package:findo/managers/monetization_manager.dart';
import 'package:findo/managers/reminder_manager.dart';
import 'package:findo/managers/review_manager.dart';
import 'package:findo/managers/save_manager.dart';
import 'package:findo/ui/settings_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings grew a rating button and a way to tell a friend. It is a dialog
/// on a phone, so it is laid out on a small one in both languages.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final code in ['en', 'he']) {
    testWidgets('settings lays out on a small phone in $code', (tester) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      final services = await tester.runAsync(() async {
        SharedPreferences.setMockInitialValues({'findo.language': code});
        final save = await SaveManager.load();
        final localization = LocalizationManager(save);
        await localization.initialize(Locale(code));
        return AppServices(
          save: save,
          localization: localization,
          audio: AudioManager(save),
          levels: LevelManager(save),
          monetization: MonetizationManager(save),
          table: LeaderboardService(save),
          account: AccountService(save),
          review: ReviewManager(save),
          reminder: ReminderManager(save),
        );
      });

      await tester.pumpWidget(
        AppServicesScope(
          services: services!,
          child: LocalizationScope(
            manager: services.localization,
            child: MaterialApp(
              home: Directionality(
                textDirection: services.localization.textDirection,
                child: const Scaffold(body: SettingsDialog()),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final l10n = services.localization;
      await tester.scrollUntilVisible(find.text(l10n.t('settings.share')), 200);
      expect(find.text(l10n.t('settings.rate')), findsOneWidget);
      expect(find.text(l10n.t('settings.share')), findsOneWidget);
      // No Firebase in a test, so no account section to offer.
      expect(find.text(l10n.t('account.signIn')), findsNothing);
    });
  }
}
