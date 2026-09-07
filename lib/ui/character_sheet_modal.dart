import 'package:flutter/material.dart';

import '../managers/localization_manager.dart';
import '../theme.dart';
import 'motion.dart';
import 'widgets/common.dart';

/// Findo shown large, opened by tapping her portrait in the objective bar.
///
/// Mid-hunt a player forgets exactly what they are looking for, and squinting
/// at a 54 px thumbnail does not help. This gives them her at a useful size
/// with her three signature traits named, then gets out of the way.
///
/// The clock is stopped while it is open. Without that a player could park
/// here for free, and taps meant for the panel would fall through to the map.
class CharacterSheetModal extends StatelessWidget {
  const CharacterSheetModal({super.key, required this.onClose});

  static const overlayId = 'characterSheet';

  /// Called after the closing animation has finished.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AnimatedPanel(
      builder: (context, close) {
        void dismiss() => close(onClose);
        return GestureDetector(
          onTap: dismiss,
          behavior: HitTestBehavior.opaque,
          child: ModalScrim(
            maxContentWidth: 380,
            child: GestureDetector(
              // Taps inside the card must not reach the scrim behind it.
              onTap: () {},
              child: FindoPanel(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.t('sheet.title'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: FindoColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(FindoMetrics.radiusPanel),
                        border: Border.all(color: FindoColors.primary, width: 2),
                      ),
                      child: Image.asset(
                        'assets/images/targets/findo.png',
                        height: 230,
                        filterQuality: FilterQuality.high,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _Trait(swatch: Color(0xFF784A28), labelKey: 'sheet.trait.braids'),
                    const _Trait(swatch: Color(0xFFFACE3E), labelKey: 'sheet.trait.top'),
                    const _Trait(swatch: Color(0xFF923EA8), labelKey: 'sheet.trait.skirt'),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: dismiss,
                        child: Text(l10n.t('sheet.close')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Trait extends StatelessWidget {
  const _Trait({required this.swatch, required this.labelKey});

  final Color swatch;
  final String labelKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 18,
            decoration: BoxDecoration(
              color: swatch,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: FindoColors.surfaceRaised),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.t(labelKey),
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
