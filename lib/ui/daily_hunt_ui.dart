import 'package:flutter/material.dart';

import '../app_services.dart';
import '../managers/audio_manager.dart';
import '../managers/localization_manager.dart';
import '../models/daily_hunt.dart';
import '../models/level_definition.dart';
import '../theme.dart';
import 'game_screen.dart';
import 'leaderboard_screen.dart';
import 'motion.dart';
import 'widgets/common.dart';

/// "0:42.3" -- minutes, seconds, tenths. Tenths matter on a table where two
/// players a second apart are ten places apart.
String formatDailyTime(int milliseconds) {
  final tenths = (milliseconds / 100).round();
  final minutes = tenths ~/ 600;
  final seconds = (tenths ~/ 10) % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}.${tenths % 10}';
}

/// How a daily hunt went, for the result panel.
class DailyOutcome {
  const DailyOutcome({
    required this.found,
    required this.milliseconds,
    required this.official,
    this.posting = false,
    this.posted = false,
    this.rank,
  });

  final bool found;
  final int milliseconds;

  /// The first attempt of the day: the one that counts.
  final bool official;

  /// Waiting on Play Games.
  final bool posting;
  final bool posted;
  final int? rank;

  DailyOutcome settled({required bool posted, int? rank}) => DailyOutcome(
        found: found,
        milliseconds: milliseconds,
        official: official,
        posted: posted,
        rank: rank,
      );
}

/// The panel at the end of a daily hunt.
class DailyResultPanel extends StatelessWidget {
  const DailyResultPanel({
    super.key,
    required this.outcome,
    required this.onTable,
    required this.onHome,
  });

  static const overlayId = 'daily-result';

  final DailyOutcome outcome;
  final VoidCallback onTable;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final String headline = outcome.found
        ? l10n.t('daily.result.found', params: {'time': formatDailyTime(outcome.milliseconds)})
        : l10n.t('daily.result.missed');

    final String status;
    if (!outcome.official) {
      status = l10n.t('daily.done.body');
    } else if (!outcome.found) {
      status = l10n.t('daily.result.officialMissed');
    } else if (outcome.posting) {
      status = l10n.t('daily.result.posting');
    } else if (!outcome.posted) {
      status = l10n.t('daily.result.offline');
    } else if (outcome.rank != null) {
      status = l10n.t('daily.result.rank', params: {'rank': outcome.rank!});
    } else {
      status = l10n.t('daily.result.posted');
    }

    return ModalScrim(
      maxContentWidth: 420,
      child: FindoPanel(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.t('daily.title'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: FindoColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              headline,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              status,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.45,
                color: outcome.official && outcome.found && outcome.rank != null
                    ? FindoColors.success
                    : FindoColors.textMuted,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: onTable,
              icon: const Icon(Icons.leaderboard_rounded, size: 22),
              label: Text(l10n.t('daily.table')),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: onHome,
              child: Text(l10n.t('daily.home')),
            ),
          ],
        ),
      ),
    );
  }
}

/// The daily hunt's entry on the title screen.
///
/// It reads its state when shown and again after every trip into a hunt, so
/// coming back from today's attempt already shows today's time.
class DailyHuntButton extends StatefulWidget {
  const DailyHuntButton({super.key});

  @override
  State<DailyHuntButton> createState() => _DailyHuntButtonState();
}

class _DailyHuntButtonState extends State<DailyHuntButton> {
  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);
    final l10n = context.l10n;
    final hunt = DailyHunt.at(DateTime.now());
    final level = _levelFor(services, hunt);
    if (level == null) {
      return const SizedBox.shrink();
    }

    final started = services.save.dailyStarted(hunt.day);
    final time = services.save.dailyTimeFor(hunt.day);
    final String subtitle;
    if (!started) {
      subtitle = l10n.t('daily.cta.new');
    } else if (time != null && time >= 0) {
      subtitle = l10n.t('daily.cta.done', params: {'time': formatDailyTime(time)});
    } else {
      subtitle = l10n.t('daily.cta.missed');
    }

    return OutlinedButton(
      onPressed: () => _open(services, hunt, level, started: started),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      child: Row(
        children: [
          const Icon(Icons.today_rounded, size: 24, color: FindoColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.t('daily.title'),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: FindoColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  LevelDefinition? _levelFor(AppServices services, DailyHunt hunt) {
    for (final level in services.levels.levels) {
      if (level.index == hunt.levelIndex) {
        return level;
      }
    }
    return null;
  }

  Future<void> _open(
    AppServices services,
    DailyHunt hunt,
    LevelDefinition level, {
    required bool started,
  }) async {
    services.audio.play(GameSound.tap);
    final l10n = context.l10n;
    // One hunt a day. Once it is played there is nothing to start again,
    // only today's table to look at.
    final String body = started
        ? l10n.t('daily.done.body')
        : l10n.t('daily.intro.body');

    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: FindoColors.surface,
        title: Text(l10n.t('daily.title'), textAlign: TextAlign.center),
        content: Text(body, textAlign: TextAlign.center, style: const TextStyle(height: 1.5)),
        // Stacked and full width rather than left to overflow: three
        // buttons side by side do not fit, and Flutter's fallback stacked
        // them against one edge.
        actions: [
          SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (started)
                  FilledButton.icon(
                    onPressed: () => Navigator.of(dialogContext).pop('table'),
                    icon: const Icon(Icons.leaderboard_rounded, size: 20),
                    label: Text(l10n.t('daily.table')),
                  )
                else
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop('play'),
                    child: Text(l10n.t('daily.start')),
                  ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(started ? l10n.t('common.ok') : l10n.t('common.cancel')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (!mounted) {
      return;
    }
    if (choice == 'table') {
      await openLeaderboard(context);
    } else if (choice == 'play') {
      services.audio.startRandomMusic();
      await Navigator.of(context).push(
        findoRoute<void>(GameScreen(level: level, daily: hunt)),
      );
      if (mounted) {
        setState(() {});
      }
    }
  }
}
