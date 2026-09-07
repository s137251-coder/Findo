import 'package:flutter/material.dart';

import '../app_services.dart';
import '../managers/audio_manager.dart';
import '../managers/localization_manager.dart';
import '../models/level_definition.dart';
import '../theme.dart';
import 'motion.dart';
import 'widgets/common.dart';

/// The end-of-level summary: what the score was made of, the stars it earned,
/// and where the player goes next.
///
/// This is the emotional peak of a level, so it is the one panel that takes
/// its time: the stars land one at a time with a rising chime, and the totals
/// count up rather than arriving finished.
class WinModal extends StatelessWidget {
  const WinModal({
    super.key,
    required this.result,
    required this.hasNextLevel,
    required this.onNext,
    required this.onReplay,
    required this.onLevelList,
  });

  static const overlayId = 'win';

  final LevelResult result;
  final bool hasNextLevel;
  final VoidCallback onNext;
  final VoidCallback onReplay;
  final VoidCallback onLevelList;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AnimatedPanel(
      builder: (context, close) {
        return ModalScrim(
          child: FindoPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.t('win.title'),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                const FindoPortrait(size: 76),
                const SizedBox(height: 12),
                _LandingStars(stars: result.stars),
                const SizedBox(height: 8),
                Text(
                  l10n.t('win.time', params: {'seconds': result.secondsTaken}),
                  style: const TextStyle(fontSize: 14, color: FindoColors.textMuted),
                ),
                const SizedBox(height: 14),
                _SummaryRow(
                  label: l10n.t('win.baseScore'),
                  value: result.baseScore,
                  prefix: '+',
                ),
                if (result.penalty > 0)
                  _SummaryRow(
                    label: l10n.t('win.penalty'),
                    value: result.penalty,
                    prefix: '-',
                    color: FindoColors.danger,
                  ),
                _SummaryRow(
                  label: l10n.t('win.timeBonus'),
                  value: result.timeBonus,
                  prefix: '+',
                  color: FindoColors.accent,
                ),
                const Divider(height: 26, color: FindoColors.surfaceRaised),
                _SummaryRow(
                  label: l10n.t('win.total'),
                  value: result.total,
                  emphasised: true,
                ),
                if (result.isNewBest) ...[
                  const SizedBox(height: 10),
                  Text(
                    l10n.t('win.newBest'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: FindoColors.success,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                if (hasNextLevel)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => close(onNext),
                      child: Text(l10n.t('win.next')),
                    ),
                  ),
                if (hasNextLevel) const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => close(onReplay),
                        child: Text(l10n.t('win.replay')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => close(onLevelList),
                        child: Text(l10n.t('win.menu')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Stars that arrive one at a time, each with its own chime.
///
/// A row of stars that is simply drawn tells the player their rating. A row
/// that lands tells them they earned it, and the beat between each one is what
/// makes a third star feel different from a second.
class _LandingStars extends StatefulWidget {
  const _LandingStars({required this.stars});

  final int stars;

  @override
  State<_LandingStars> createState() => _LandingStarsState();
}

class _LandingStarsState extends State<_LandingStars> {
  int _shown = 0;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    if (Motion.reduced(context) || widget.stars == 0) {
      _shown = widget.stars;
      return;
    }
    _land(AppServices.of(context).audio);
  }

  Future<void> _land(AudioManager audio) async {
    // A short beat before the first one, so it reads as a reward rather than
    // part of the panel appearing.
    await Future<void>.delayed(const Duration(milliseconds: 320));
    for (var i = 0; i < widget.stars; i++) {
      if (!mounted) {
        return;
      }
      setState(() => _shown = i + 1);
      // Later stars sound louder, so three reads as better than two even
      // before the panel is read.
      audio.play(GameSound.star, volume: 0.55 + 0.2 * i);
      await Future<void>.delayed(Motion.starStagger);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        final earned = index < _shown;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: AnimatedScale(
            scale: earned ? 1.0 : 0.72,
            duration: Motion.scale(context, const Duration(milliseconds: 320)),
            curve: Curves.elasticOut,
            child: AnimatedOpacity(
              opacity: earned ? 1.0 : 0.35,
              duration: Motion.scale(context, const Duration(milliseconds: 180)),
              child: Icon(
                earned ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 40,
                color: earned ? FindoColors.primary : FindoColors.locked,
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Shown when the clock runs out before Findo is found.
class TimeUpModal extends StatelessWidget {
  const TimeUpModal({
    super.key,
    required this.onRetry,
    required this.onLevelList,
  });

  static const overlayId = 'timeUp';

  final VoidCallback onRetry;
  final VoidCallback onLevelList;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AnimatedPanel(
      builder: (context, close) {
        return ModalScrim(
          child: FindoPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_off_rounded, size: 44, color: FindoColors.danger),
                const SizedBox(height: 12),
                Text(
                  l10n.t('lose.title'),
                  style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.t('lose.body'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: FindoColors.textMuted),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => close(onRetry),
                    child: Text(l10n.t('lose.retry')),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => close(onLevelList),
                    child: Text(l10n.t('win.menu')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.prefix = '',
    this.color = FindoColors.textPrimary,
    this.emphasised = false,
  });

  final String label;
  final int value;
  final String prefix;
  final Color color;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: emphasised ? 20 : 16,
      fontWeight: emphasised ? FontWeight.w700 : FontWeight.w500,
      color: emphasised ? FindoColors.primary : color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: style.copyWith(
              color: emphasised ? FindoColors.textPrimary : FindoColors.textMuted,
            ),
          ),
          CountUp(value: value, prefix: prefix, style: style),
        ],
      ),
    );
  }
}
