import 'package:flutter/material.dart';

import '../app_services.dart';
import '../managers/audio_manager.dart';
import '../managers/localization_manager.dart';
import '../managers/save_manager.dart';
import '../models/level_definition.dart';
import '../theme.dart';
import 'game_screen.dart';
import 'motion.dart';
import 'safe_area_wrapper.dart';
import 'settings_dialog.dart';
import 'widgets/common.dart';

/// The level grid: every map, its best score and its stars, with the ones the
/// player has not reached yet locked.
class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);
    final l10n = context.l10n;

    return Scaffold(
      body: SafeAreaWrapper(
        maxContentWidth: 720,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: ListenableBuilder(
          listenable: services.levels,
          builder: (context, _) {
            final levels = services.levels.levels;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.t('level.select.title'),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => showSettingsDialog(context),
                      icon: const Icon(Icons.settings_rounded),
                      color: FindoColors.textMuted,
                      iconSize: 28,
                      tooltip: l10n.t('settings.title'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // One card per row on a phone, two once there is room.
                      final columns = constraints.maxWidth >= 560 ? 2 : 1;
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 2.4,
                        ),
                        itemCount: levels.length,
                        itemBuilder: (context, index) {
                          final level = levels[index];
                          return _LevelCard(
                            level: level,
                            unlocked: services.levels.isUnlocked(level),
                            progress: services.levels.progressOf(level),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.unlocked,
    required this.progress,
  });

  final LevelDefinition level;
  final bool unlocked;
  final LevelProgress progress;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Opacity(
      opacity: unlocked ? 1 : 0.55,
      child: Material(
        color: FindoColors.surface,
        borderRadius: BorderRadius.circular(FindoMetrics.radiusPanel),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: unlocked
              ? () {
                  AppServices.of(context).audio.play(GameSound.tap);
                  Navigator.of(context).push(
                    findoRoute<void>(GameScreen(level: level)),
                  );
                }
              : null,
          child: Row(
            children: [
              SizedBox(
                width: 118,
                height: double.infinity,
                child: Image.asset(
                  'assets/images/${level.map}',
                  fit: BoxFit.cover,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l10n.t('level.number', params: {'index': level.index}),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: FindoColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.t(level.nameKey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (unlocked)
                        Row(
                          children: [
                            StarRow(stars: progress.stars, size: 18),
                            const SizedBox(width: 10),
                            if (progress.bestScore > 0)
                              Text(
                                l10n.t('level.best',
                                    params: {'score': progress.bestScore}),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: FindoColors.textMuted,
                                ),
                              ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            const Icon(Icons.lock_rounded,
                                size: 16, color: FindoColors.textMuted),
                            const SizedBox(width: 6),
                            Text(
                              l10n.t('level.locked'),
                              style: const TextStyle(
                                fontSize: 13,
                                color: FindoColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                // Not swapped by hand for Hebrew: Flutter already mirrors the
                // chevron icons in an RTL context, so choosing the left one
                // there flipped it a second time and the arrow pointed back
                // out of the level it opens.
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: FindoColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
