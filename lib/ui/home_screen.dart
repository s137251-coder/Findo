import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_services.dart';
import '../managers/audio_manager.dart';
import '../managers/localization_manager.dart';
import '../models/rank.dart';
import '../theme.dart';
import 'daily_hunt_ui.dart';
import 'level_select_screen.dart';
import 'motion.dart';
import 'rank_screen.dart';
import 'safe_area_wrapper.dart';
import 'rules_screen.dart';
import 'settings_dialog.dart';
import 'title_findo.dart';
import 'title_stage.dart';
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

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  bool _checkedFirstRun = false;

  /// The opening: the title screen assembles itself rather than appearing all
  /// at once, so the eye is led from the glass to the name to Play.
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  );

  /// The screen's resting pulse -- the glass breathing, the shine crossing
  /// the name, the glow under Play. Slow enough to be felt and not watched.
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );

  @override
  void initState() {
    super.initState();
    _enter.forward();
    _idle.repeat();
  }

  @override
  void dispose() {
    _enter.dispose();
    _idle.dispose();
    super.dispose();
  }

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

    // Reduced motion: the screen is composed, not performed.
    final still = MediaQuery.disableAnimationsOf(context);
    if (still) {
      _enter.value = 1;
      if (_idle.isAnimating) {
        _idle.stop();
        _idle.value = 0;
      }
    }

    return Scaffold(
      body: TitleStage(
        child: SafeAreaWrapper(
          maxContentWidth: 420,
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 20),
          // A title screen does not scroll. On a phone too short for the
          // menu -- a navigation bar, a larger system font -- it is scaled
          // down a little to fit instead.
          child: _FitToHeight(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The glass and the girl it is looking for, side by side: the
                // whole game in the first thing on the screen.
                _Rise(
                  controller: _enter,
                  from: 0.0,
                  to: 0.45,
                  lift: 26,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Glass(idle: _idle, still: still),
                      const SizedBox(width: 18),
                      const TitleFindo(height: 150),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _Rise(
                  controller: _enter,
                  from: 0.12,
                  to: 0.58,
                  child: _Wordmark(text: l10n.t('app.title'), idle: _idle, still: still),
                ),
                const SizedBox(height: 6),
                _Rise(
                  controller: _enter,
                  from: 0.24,
                  to: 0.70,
                  child: Text(
                    l10n.t('app.tagline'),
                    textAlign: TextAlign.center,
                    // A shadow so the line holds up over the brighter crowd.
                    style: const TextStyle(
                      fontSize: 16,
                      color: FindoColors.textPrimary,
                      shadows: [
                        Shadow(color: Color(0xCC000000), blurRadius: 10, offset: Offset(0, 2)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                // Rebuilt from the level manager, which notifies on every
                // cleared level, so coming back from a promotion shows the
                // new rank.
                _Rise(
                  controller: _enter,
                  from: 0.36,
                  to: 0.82,
                  child: ListenableBuilder(
                    listenable: services.levels,
                    builder: (context, _) => _RankBadge(
                      rank: Rank.earnedBy(services.save.unlockedLevelIndex),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _Rise(
                  controller: _enter,
                  from: 0.48,
                  to: 0.92,
                  child: _Breathing(
                    idle: _idle,
                    still: still,
                    child: FilledButton.icon(
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
                  ),
                ),
                const SizedBox(height: 12),
                // Second only to Play: the one thing on the screen that is
                // different every day.
                _Rise(
                  controller: _enter,
                  from: 0.53,
                  to: 0.96,
                  child: const DailyHuntButton(),
                ),
                const SizedBox(height: 12),
                _Rise(
                  controller: _enter,
                  from: 0.58,
                  to: 1.0,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      services.audio.play(GameSound.tap);
                      showSettingsDialog(context);
                    },
                    icon: const Icon(Icons.settings_rounded, size: 22),
                    label: Text(l10n.t('menu.settings')),
                  ),
                ),
                // Android only. An iOS app is not meant to close itself, and
                // App Review rejects ones that do; there, the home gesture is
                // the exit.
                if (Theme.of(context).platform == TargetPlatform.android) ...[
                  const SizedBox(height: 8),
                  _Rise(
                    controller: _enter,
                    from: 0.66,
                    to: 1.0,
                    child: TextButton.icon(
                      onPressed: () async {
                        // Stopped first, so the track cannot outlive the screen
                        // by the moment the activity takes to finish.
                        await services.audio.stopMusic();
                        await SystemNavigator.pop();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: FindoColors.textMuted,
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 22),
                      label: Text(l10n.t('menu.exit')),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Centres [child] at the width it is given, and scales it down, never up,
/// when it is taller than the space it has.
class _FitToHeight extends StatelessWidget {
  const _FitToHeight({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(width: constraints.maxWidth, child: child),
        ),
      ),
    );
  }
}

/// Fades a piece of the title screen up into place over its own slice of the
/// opening, so the screen arrives in order rather than all at once.
class _Rise extends StatelessWidget {
  const _Rise({
    required this.controller,
    required this.from,
    required this.to,
    required this.child,
    this.lift = 16,
  });

  final AnimationController controller;
  final double from;
  final double to;
  final double lift;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(
      parent: controller,
      curve: Interval(from, to, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curve,
      child: child,
      builder: (context, child) => Opacity(
        opacity: curve.value,
        child: Transform.translate(
          offset: Offset(0, lift * (1 - curve.value)),
          child: child,
        ),
      ),
    );
  }
}

/// The magnifier over the title: it hangs, tilts, and carries a halo, the way
/// it does when the player is holding it over a crowd.
class _Glass extends StatelessWidget {
  const _Glass({required this.idle, required this.still});

  final AnimationController idle;
  final bool still;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: idle,
      builder: (context, _) {
        final angle = idle.value * pi * 2;
        final tilt = still ? 0.0 : sin(angle) * 0.055;
        final bob = still ? 0.0 : sin(angle * 2 + 0.6) * 3.5;
        final halo = 0.22 + (still ? 0.0 : 0.10 * (0.5 + 0.5 * sin(angle * 2)));
        return Transform.translate(
          offset: Offset(0, bob),
          child: Transform.rotate(
            angle: tilt,
            child: Container(
              height: 80,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: FindoColors.primary.withValues(alpha: halo),
                    blurRadius: 42,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.search_rounded,
                  size: 70, color: FindoColors.primary),
            ),
          ),
        );
      },
    );
  }
}

/// The game's name, with a shine that crosses it once a cycle.
///
/// The sweep is the same gesture as the glass passing over the crowd, which is
/// why it suits the word: the title is found rather than printed.
class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.text, required this.idle, required this.still});

  final String text;
  final AnimationController idle;
  final bool still;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 46,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.5,
      color: FindoColors.textPrimary,
      shadows: [
        Shadow(color: Color(0x99000000), blurRadius: 18, offset: Offset(0, 4)),
      ],
    );
    final label = Text(text, textAlign: TextAlign.center, style: style);
    if (still) {
      return label;
    }
    return AnimatedBuilder(
      animation: idle,
      child: label,
      builder: (context, child) {
        // The shine crosses in the first fifth of the cycle and is absent for
        // the rest: a highlight that never leaves reads as a gradient.
        final pass = (idle.value / 0.22).clamp(0.0, 1.0);
        final centre = -0.4 + pass * 1.8;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: const [
              Colors.transparent,
              Color(0x59FFFFFF),
              Colors.transparent,
            ],
            stops: [
              (centre - 0.16).clamp(0.0, 1.0),
              centre.clamp(0.0, 1.0),
              (centre + 0.16).clamp(0.0, 1.0),
            ],
          ).createShader(rect),
          child: child,
        );
      },
    );
  }
}

/// A slow swell under the one button the screen wants pressed.
class _Breathing extends StatelessWidget {
  const _Breathing({
    required this.idle,
    required this.still,
    required this.child,
  });

  final AnimationController idle;
  final bool still;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (still) {
      return child;
    }
    return AnimatedBuilder(
      animation: idle,
      child: child,
      builder: (context, child) {
        final swell = 0.5 + 0.5 * sin(idle.value * pi * 2 * 2);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FindoMetrics.radiusControl),
            boxShadow: [
              BoxShadow(
                color: FindoColors.primary.withValues(alpha: 0.10 + 0.16 * swell),
                blurRadius: 20 + 12 * swell,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );
      },
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
