import 'package:flutter/material.dart';

import '../app_services.dart';
import '../managers/audio_manager.dart';
import '../managers/localization_manager.dart';
import '../theme.dart';
import 'motion.dart';
import 'safe_area_wrapper.dart';
import 'widgets/common.dart';

/// The rules, shown once on a first run and reachable from Settings after
/// that.
///
/// It is a screen rather than a dialog because it is the first thing a new
/// player sees, and because the five rules do not fit a phone dialog in
/// Hebrew without scrolling inside a box inside a box.
class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key, required this.isFirstRun});

  /// On a first run the button starts the game; opened from Settings it just
  /// closes.
  final bool isFirstRun;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final services = AppServices.of(context);

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
          maxContentWidth: 520,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      Text(
                        l10n.t('rules.title'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: FindoColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const FindoPortrait(size: 92),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              l10n.t('rules.who'),
                              style: const TextStyle(
                                fontSize: 16,
                                color: FindoColors.textPrimary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const _Rule(
                        icon: Icons.touch_app_rounded,
                        titleKey: 'rules.find',
                        bodyKey: 'rules.find.body',
                        tone: FindoColors.primary,
                      ),
                      const _Rule(
                        icon: Icons.zoom_in_rounded,
                        titleKey: 'rules.move',
                        bodyKey: 'rules.move.body',
                        tone: FindoColors.accent,
                      ),
                      const _Rule(
                        icon: Icons.remove_circle_outline_rounded,
                        titleKey: 'rules.wrong',
                        bodyKey: 'rules.wrong.body',
                        tone: FindoColors.danger,
                      ),
                      const _Rule(
                        icon: Icons.timer_rounded,
                        titleKey: 'rules.fast',
                        bodyKey: 'rules.fast.body',
                        tone: FindoColors.success,
                      ),
                      const _Rule(
                        icon: Icons.lightbulb_rounded,
                        titleKey: 'rules.hint',
                        bodyKey: 'rules.hint.body',
                        tone: FindoColors.primary,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () {
                  services.audio.play(GameSound.tap);
                  Navigator.of(context).pop();
                },
                child: Text(
                  l10n.t(isFirstRun ? 'rules.start' : 'rules.close'),
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({
    required this.icon,
    required this.titleKey,
    required this.bodyKey,
    required this.tone,
  });

  final IconData icon;
  final String titleKey;
  final String bodyKey;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: FindoColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: FindoColors.surfaceRaised),
            ),
            child: Icon(icon, size: 21, color: tone),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t(titleKey),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: FindoColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  l10n.t(bodyKey),
                  style: const TextStyle(
                    fontSize: 14,
                    color: FindoColors.textMuted,
                    height: 1.42,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the rules, animated like every other screen change.
Future<void> showRules(BuildContext context, {required bool isFirstRun}) {
  return Navigator.of(context).push(
    findoRoute<void>(RulesScreen(isFirstRun: isFirstRun)),
  );
}
