import 'package:flutter/material.dart';

import '../managers/localization_manager.dart';
import '../managers/monetization_manager.dart';
import '../theme.dart';
import 'widgets/common.dart';

/// What the player chose in the hint sheet.
enum HintChoice { useStored, watchAd, cancel }

/// Asks how the player wants to pay for a hint. Spending a stored hint is
/// offered only when they have one; the ad option only when one is loaded.
Future<HintChoice> showHintDialog(
  BuildContext context,
  MonetizationManager monetization,
) async {
  final l10n = context.l10n;
  final choice = await showDialog<HintChoice>(
    context: context,
    barrierColor: const Color(0xB3050710),
    builder: (context) {
      return Dialog(
        insetPadding: const EdgeInsets.all(20),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: FindoPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.t('hint.title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.t('hint.body'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: FindoColors.textMuted),
                ),
                const SizedBox(height: 14),
                Text(
                  l10n.t('hint.remaining',
                      params: {'count': monetization.hintCount}),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: FindoColors.primary,
                  ),
                ),
                const SizedBox(height: 18),
                if (monetization.hintCount > 0)
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(HintChoice.useStored),
                    icon: const Icon(Icons.lightbulb_rounded, size: 20),
                    label: Text(l10n.t('hint.use')),
                  ),
                if (monetization.hintCount > 0) const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: monetization.rewardedAdReady
                      ? () => Navigator.of(context).pop(HintChoice.watchAd)
                      : null,
                  icon: const Icon(Icons.play_circle_outline_rounded, size: 20),
                  label: Text(
                    monetization.rewardedAdReady
                        ? l10n.t('hint.watchAd')
                        : l10n.t('hint.unavailable'),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(HintChoice.cancel),
                  child: Text(
                    l10n.t('common.cancel'),
                    style: const TextStyle(color: FindoColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  return choice ?? HintChoice.cancel;
}
