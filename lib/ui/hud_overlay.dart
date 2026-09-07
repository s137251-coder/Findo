import 'package:flutter/material.dart';

import '../game/findo_game.dart';
import '../managers/localization_manager.dart';
import '../managers/monetization_manager.dart';
import '../managers/score_manager.dart';
import '../models/level_definition.dart';
import '../theme.dart';
import 'safe_area_wrapper.dart';
import 'widgets/common.dart';

/// The heads-up display drawn over the Flame canvas: score and timer on top,
/// the single objective along the bottom.
class HudOverlay extends StatelessWidget {
  const HudOverlay({
    super.key,
    required this.game,
    required this.monetization,
    required this.onPause,
    required this.onHint,
    required this.onOpenCharacter,
  });

  static const overlayId = 'hud';

  final FindoGame game;
  final MonetizationManager monetization;
  final VoidCallback onPause;
  final VoidCallback onHint;

  /// Opens Findo full size. Reached by tapping her portrait in the bar.
  final VoidCallback onOpenCharacter;

  @override
  Widget build(BuildContext context) {
    return _HudInsetReporter(
      game: game,
      panelKey: _panelKey,
      child: SafeAreaEdges(
        minimum: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            _TopBar(
              scoreManager: game.scoreManager,
              level: game.level,
              onPause: onPause,
            ),
            const Spacer(),
            KeyedSubtree(
              key: _panelKey,
              // Orientation, not LayoutBuilder: inside a Column the builder
              // is handed an unbounded height, so comparing its constraints
              // would call every screen portrait.
              //
              // Turned sideways the short dimension is height, and every
              // logical pixel this panel takes is map the player cannot see.
              // The compact form drops the subtitle and shrinks the portrait.
              child: _ObjectiveBar(
                monetization: monetization,
                onHint: onHint,
                onOpenCharacter: onOpenCharacter,
                compact: MediaQuery.orientationOf(context) == Orientation.landscape,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One key per HUD, created once so the panel's render object is findable
/// across rebuilds.
final GlobalKey _panelKey = GlobalKey(debugLabel: 'findo.hud.objectivePanel');

/// Measures how much of the bottom of the game canvas the objective panel
/// covers and reports it to the game, which then keeps the map above it.
///
/// Measurement is relative to this widget's own box rather than to
/// `MediaQuery`: the overlay sits inside the game widget, where the media
/// query's height has already had the system navigation bar taken out of it,
/// which under-reports the inset by exactly the height of that bar.
///
/// The check repeats every frame. It is two render-object lookups and a
/// comparison, and it keeps the camera correct through rotation or a changed
/// text scale.
class _HudInsetReporter extends StatefulWidget {
  const _HudInsetReporter({
    required this.game,
    required this.panelKey,
    required this.child,
  });

  final FindoGame game;
  final GlobalKey panelKey;
  final Widget child;

  @override
  State<_HudInsetReporter> createState() => _HudInsetReporterState();
}

class _HudInsetReporterState extends State<_HudInsetReporter> {
  final GlobalKey _rootKey = GlobalKey(debugLabel: 'findo.hud.root');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_measure);
  }

  void _measure(Duration _) {
    if (!mounted) {
      return;
    }
    final root = _rootKey.currentContext?.findRenderObject() as RenderBox?;
    final panel = widget.panelKey.currentContext?.findRenderObject() as RenderBox?;
    if (root != null && panel != null && root.hasSize && panel.hasSize) {
      final panelTop = root.globalToLocal(panel.localToGlobal(Offset.zero)).dy;
      widget.game.hudBottomInset = root.size.height - panelTop;
    }
    WidgetsBinding.instance.addPostFrameCallback(_measure);
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _rootKey, child: widget.child);
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.scoreManager,
    required this.level,
    required this.onPause,
  });

  final ScoreManager scoreManager;
  final LevelDefinition level;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: scoreManager,
      builder: (context, _) {
        final lowOnTime = scoreManager.timeRemaining <= 15;
        return Row(
          children: [
            StatChip(
              icon: Icons.stars_rounded,
              value: '${scoreManager.score}',
              color: FindoColors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: lowOnTime ? FindoColors.danger : FindoColors.textMuted,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        formatSeconds(scoreManager.timeRemaining),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: lowOnTime
                              ? FindoColors.danger
                              : FindoColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: scoreManager.timeFraction,
                      minHeight: 6,
                      backgroundColor: FindoColors.surfaceRaised,
                      valueColor: AlwaysStoppedAnimation(
                        lowOnTime ? FindoColors.danger : FindoColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StarRow(
              stars: level.starThresholds
                  .starsFor(scoreManager.projectedTotal(cleared: true)),
              size: 20,
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: onPause,
              tooltip: l10n.t('hud.pause'),
              icon: const Icon(Icons.pause_circle_filled_rounded),
              color: FindoColors.textPrimary,
              iconSize: 30,
            ),
          ],
        );
      },
    );
  }
}

/// The single objective: who to look for, and the hint button.
///
/// Deliberately short. Every logical pixel this panel occupies is a pixel of
/// map the player cannot see, because the camera stops above it.
class _ObjectiveBar extends StatelessWidget {
  const _ObjectiveBar({
    required this.monetization,
    required this.onHint,
    required this.onOpenCharacter,
    required this.compact,
  });

  final MonetizationManager monetization;
  final VoidCallback onHint;
  final VoidCallback onOpenCharacter;

  /// Set when the screen is wider than it is tall.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 7 : 10),
      decoration: BoxDecoration(
        color: const Color(0xE61E2333),
        borderRadius: BorderRadius.circular(FindoMetrics.radiusPanel),
        border: Border.all(color: FindoColors.surfaceRaised),
      ),
      child: Row(
        children: [
          FindoPortrait(size: compact ? 40 : 54, onTap: onOpenCharacter),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.t('hud.find'),
                  style: TextStyle(
                    fontSize: compact ? 16 : 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!compact) const SizedBox(height: 2),
                if (!compact)
                  Text(
                    l10n.t('hud.objective'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: FindoColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _HintButton(monetization: monetization, onHint: onHint),
        ],
      ),
    );
  }
}

class _HintButton extends StatelessWidget {
  const _HintButton({required this.monetization, required this.onHint});

  final MonetizationManager monetization;
  final VoidCallback onHint;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: monetization,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: FindoColors.primary,
              borderRadius: BorderRadius.circular(FindoMetrics.radiusControl),
              child: InkWell(
                onTap: onHint,
                borderRadius: BorderRadius.circular(FindoMetrics.radiusControl),
                child: const Padding(
                  padding: EdgeInsets.all(11),
                  child: Icon(Icons.lightbulb_rounded,
                      color: FindoColors.onPrimary, size: 24),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${monetization.hintCount}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: FindoColors.textMuted,
              ),
            ),
          ],
        );
      },
    );
  }
}
