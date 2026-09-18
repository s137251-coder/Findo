import 'dart:async';

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

/// How long until the next hunt opens, in words: "7 hours and 12 minutes".
///
/// Rounded to whole minutes, because this is shown to someone deciding
/// whether to wait, not timing anything.
String formatUntilNextHunt(LocalizationManager l10n, Duration left) {
  final minutes = left.inMinutes.clamp(0, 24 * 60);
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) {
    return l10n.t('daily.next.minutes', params: {'minutes': rest});
  }
  if (rest == 0) {
    return l10n.t('daily.next.hours', params: {'hours': hours});
  }
  return l10n.t(
    'daily.next.hoursMinutes',
    params: {'hours': hours, 'minutes': rest},
  );
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

    final next = formatUntilNextHunt(
      l10n,
      DailyHunt.untilNextHunt(DateTime.now()),
    );
    final String status;
    if (!outcome.official) {
      status = l10n.t('daily.done.body', params: {'time': next});
    } else if (!outcome.found) {
      status = l10n.t('daily.result.officialMissed', params: {'time': next});
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
  /// The hunt turns over while the app is open -- at ten in the morning for a
  /// player in Israel, not at their midnight -- and the countdown below it
  /// runs down meanwhile. Without this the button kept yesterday's answer
  /// until something else happened to rebuild it.
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

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
    // Once today's hunt is spent, the useful thing to tell the player is when
    // the next one arrives -- their own midnight is not the answer.
    final String? countdown = started
        ? l10n.t('daily.cta.next', params: {
            'time': formatUntilNextHunt(
              l10n,
              DailyHunt.untilNextHunt(DateTime.now()),
            ),
          })
        : null;

    // In the accent blue, not Play's gold: the second thing on the screen
    // to look at, and plainly a different kind of thing from Play.
    final radius = BorderRadius.circular(FindoMetrics.radiusControl);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: FindoColors.accent.withValues(alpha: 0.22),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: FindoColors.accent, width: 1.6),
            gradient: LinearGradient(
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
              colors: [
                FindoColors.accent.withValues(alpha: 0.30),
                FindoColors.surface.withValues(alpha: 0.92),
              ],
            ),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: () => _open(services, hunt, level, started: started),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: FindoColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.today_rounded, size: 24, color: FindoColors.background),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.t('daily.title'),
                          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: FindoColors.accent,
                          ),
                        ),
                        if (countdown != null)
                          Text(
                            countdown,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: FindoColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Pointing onwards in the reading direction.
                  Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.chevron_left_rounded
                        : Icons.chevron_right_rounded,
                    color: FindoColors.accent,
                  ),
                ],
              ),
            ),
          ),
        ),
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
        ? l10n.t('daily.done.body', params: {
            'time': formatUntilNextHunt(
              l10n,
              DailyHunt.untilNextHunt(DateTime.now()),
            ),
          })
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
