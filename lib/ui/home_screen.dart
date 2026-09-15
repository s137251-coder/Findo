import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_services.dart';
import '../managers/audio_manager.dart';
import '../managers/localization_manager.dart';
import '../models/rank.dart';
import '../theme.dart';
import 'level_select_screen.dart';
import 'motion.dart';
import 'rank_screen.dart';
import 'safe_area_wrapper.dart';
import 'rules_screen.dart';
import 'settings_dialog.dart';
import 'update_prompt.dart';

/// The title screen: play, open settings, or (on Android) leave the game.
///
/// It also owns what happens at launch. A new player is shown the rules before
/// anything else, once, and can reach them again from Settings; after that,
/// every launch asks Google Play whether a newer version is out.
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      if (!services.save.introSeen) {
        // Marked before showing, so a player who kills the app mid-read is not
        // shown it again on every launch.
        await services.save.markIntroSeen();
        if (mounted) {
          await showRules(context, isFirstRun: true);
        }
      }
      // Once per launch, and after the rules rather than on top of them.
      if (mounted) {
        await offerUpdateIfAvailable(context);
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
              const SizedBox(height: 26),
              // Rebuilt from the level manager, which notifies on every cleared
              // level, so coming back from a promotion shows the new rank.
              ListenableBuilder(
                listenable: services.levels,
                builder: (context, _) => _RankBadge(
                  rank: Rank.earnedBy(services.save.unlockedLevelIndex),
                ),
              ),
              const SizedBox(height: 26),
              FilledButton.icon(
                onPressed: () {
                  services.audio.play(GameSound.tap);
                  services.audio.startRandomMusic();
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
              // Android only. An iOS app is not meant to close itself, and App
              // Review rejects ones that do; there, the home gesture is the exit.
              if (Theme.of(context).platform == TargetPlatform.android) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () async {
                    // Stopped first, so the track cannot outlive the screen by
                    // the moment the activity takes to finish.
                    await services.audio.stopMusic();
                    await SystemNavigator.pop();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: FindoColors.textMuted,
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 22),
                  label: Text(l10n.t('menu.exit')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The player's rank, or the promise of one before level 10 is cleared.
class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final Rank? rank;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rank = this.rank;
    if (rank == null) {
      return Text(
        l10n.t('rank.locked'),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, color: FindoColors.textMuted),
      );
    }

    final radius = BorderRadius.circular(FindoMetrics.radiusPanel);
    return Material(
      color: FindoColors.surface,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: () {
          AppServices.of(context).audio.playPromotion();
          showRankCeremony(context, rank);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: FindoColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${rank.number}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: FindoColors.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.t('rank.yours'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: FindoColors.textMuted,
                      ),
                    ),
                    Text(
                      l10n.t(rank.nameKey),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: FindoColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
