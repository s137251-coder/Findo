import 'package:flutter/material.dart';

import '../game/findo_game.dart';
import '../managers/level_manager.dart';
import '../managers/localization_manager.dart';
import '../managers/monetization_manager.dart';
import '../managers/score_manager.dart';
import '../models/level_definition.dart';
import '../theme.dart';
import 'safe_area_wrapper.dart';
import 'widgets/common.dart';

/// The heads-up display drawn over the Flame canvas: score and timer on top,
/// the list of things still to find along the bottom.
class HudOverlay extends StatelessWidget {
  const HudOverlay({
    super.key,
    required this.game,
    required this.monetization,
    required this.onPause,
    required this.onHint,
  });

  static const overlayId = 'hud';

  final FindoGame game;
  final MonetizationManager monetization;
  final VoidCallback onPause;
  final VoidCallback onHint;

  @override
  Widget build(BuildContext context) {
    return SafeAreaEdges(
      minimum: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          _TopBar(
            scoreManager: game.scoreManager,
            level: game.level,
            onPause: onPause,
          ),
          const Spacer(),
          _SearchBar(
            levelManager: game.levelManager,
            monetization: monetization,
            onHint: onHint,
          ),
        ],
      ),
    );
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
                          color: lowOnTime ? FindoColors.danger : FindoColors.textPrimary,
                        ),
                      ),
                      if (scoreManager.comboActive) ...[
                        const SizedBox(width: 10),
                        Text(
                          l10n.t('hud.combo',
                              params: {'multiplier': scoreManager.multiplier}),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: FindoColors.success,
                          ),
                        ),
                      ],
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

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.levelManager,
    required this.monetization,
    required this.onHint,
  });

  final LevelManager levelManager;
  final MonetizationManager monetization;
  final VoidCallback onHint;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: Listenable.merge([levelManager, monetization]),
      builder: (context, _) {
        final level = levelManager.current;
        if (level == null) {
          return const SizedBox.shrink();
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xE61E2333),
            borderRadius: BorderRadius.circular(FindoMetrics.radiusPanel),
            border: Border.all(color: FindoColors.surfaceRaised),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.t('hud.find'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: FindoColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 64,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: level.items.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final item = level.items[index];
                          return _SearchChip(
                            item: item,
                            found: levelManager.foundIds.contains(item.id),
                          );
                        },
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
      },
    );
  }
}

class _SearchChip extends StatelessWidget {
  const _SearchChip({required this.item, required this.found});

  final LevelItem item;
  final bool found;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: found ? 0.35 : 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: FindoColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: found ? FindoColors.success : FindoColors.surfaceRaised,
                    width: 2,
                  ),
                ),
                child: Image.asset(
                  'assets/images/${item.sprite}',
                  filterQuality: FilterQuality.medium,
                ),
              ),
              if (found)
                const Icon(Icons.check_rounded, color: FindoColors.success, size: 26),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            context.l10n.t(item.nameKey),
            style: const TextStyle(fontSize: 11, color: FindoColors.textMuted),
          ),
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
              padding: EdgeInsets.all(12),
              child: Icon(Icons.lightbulb_rounded,
                  color: FindoColors.onPrimary, size: 26),
            ),
          ),
        ),
        const SizedBox(height: 4),
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
  }
}
