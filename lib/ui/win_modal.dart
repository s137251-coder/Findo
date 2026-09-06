import 'package:flutter/material.dart';

import '../managers/localization_manager.dart';
import '../models/level_definition.dart';
import '../theme.dart';
import 'widgets/common.dart';

/// The end-of-level summary: what the score was made of, the stars it earned,
/// and where the player goes next.
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
            StarRow(stars: result.stars, size: 40),
            const SizedBox(height: 18),
            _SummaryRow(
              label: l10n.t('win.baseScore'),
              value: '+${result.baseScore}',
            ),
            if (result.penalty > 0)
              _SummaryRow(
                label: l10n.t('win.penalty'),
                value: '-${result.penalty}',
                color: FindoColors.danger,
              ),
            _SummaryRow(
              label: l10n.t('win.timeBonus'),
              value: '+${result.timeBonus}',
              color: FindoColors.accent,
            ),
            const Divider(height: 26, color: FindoColors.surfaceRaised),
            _SummaryRow(
              label: l10n.t('win.total'),
              value: '${result.total}',
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
                  onPressed: onNext,
                  child: Text(l10n.t('win.next')),
                ),
              ),
            if (hasNextLevel) const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReplay,
                    child: Text(l10n.t('win.replay')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onLevelList,
                    child: Text(l10n.t('win.menu')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the clock runs out before the map is clear.
class TimeUpModal extends StatelessWidget {
  const TimeUpModal({
    super.key,
    required this.foundCount,
    required this.totalCount,
    required this.onRetry,
    required this.onLevelList,
  });

  static const overlayId = 'timeUp';

  final int foundCount;
  final int totalCount;
  final VoidCallback onRetry;
  final VoidCallback onLevelList;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
              l10n.t('lose.body',
                  params: {'found': foundCount, 'total': totalCount}),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: FindoColors.textMuted),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onRetry,
                child: Text(l10n.t('lose.retry')),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onLevelList,
                child: Text(l10n.t('win.menu')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.color = FindoColors.textPrimary,
    this.emphasised = false,
  });

  final String label;
  final String value;
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
          Text(label, style: style.copyWith(color: emphasised ? FindoColors.textPrimary : FindoColors.textMuted)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
