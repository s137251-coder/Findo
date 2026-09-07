import 'package:flutter/material.dart';

import '../app_services.dart';
import '../managers/audio_manager.dart';
import '../managers/localization_manager.dart';
import '../theme.dart';
import 'level_select_screen.dart';
import 'motion.dart';
import 'safe_area_wrapper.dart';
import 'rules_screen.dart';
import 'settings_dialog.dart';

/// The title screen: play, or open settings.
///
/// It also owns the first-run moment. A new player is shown the rules before
/// anything else, once, and can reach them again from Settings.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _checkedFirstRun = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checkedFirstRun) {
      return;
    }
    _checkedFirstRun = true;
    final services = AppServices.of(context);
    if (services.save.introSeen) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      // Marked before showing, so a player who kills the app mid-read is not
      // shown it again on every launch.
      await services.save.markIntroSeen();
      if (mounted) {
        await showRules(context, isFirstRun: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);
    final l10n = context.l10n;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B2236), FindoColors.background],
          ),
        ),
        child: SafeAreaWrapper(
          maxContentWidth: 420,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.search_rounded, size: 84, color: FindoColors.primary),
              const SizedBox(height: 14),
              Text(
                l10n.t('app.title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 46,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.t('app.tagline'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: FindoColors.textMuted),
              ),
              const SizedBox(height: 40),
              FilledButton.icon(
                onPressed: () {
                  services.audio.play(GameSound.tap);
                  services.audio.startMusic();
                  Navigator.of(context).push(
                    findoRoute<void>(const LevelSelectScreen()),
                  );
                },
                icon: const Icon(Icons.play_arrow_rounded, size: 26),
                label: Text(l10n.t('menu.play')),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  services.audio.play(GameSound.tap);
                  showSettingsDialog(context);
                },
                icon: const Icon(Icons.settings_rounded, size: 22),
                label: Text(l10n.t('menu.settings')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
