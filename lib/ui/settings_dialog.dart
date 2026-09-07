import 'package:flutter/material.dart';

import '../app_services.dart';
import '../managers/localization_manager.dart';
import '../managers/monetization_manager.dart';
import '../theme.dart';
import 'rules_screen.dart';
import 'widgets/common.dart';

/// Opens the settings sheet. Returns once it is dismissed.
Future<void> showSettingsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0xB3050710),
    builder: (context) => const SettingsDialog(),
  );
}

/// Audio toggles, the language picker, and the store entry points.
///
/// Switching language rebuilds the whole app through the localization
/// notifier, so the dialog itself flips to the new text and direction while it
/// is still open.
class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);
    final l10n = context.l10n;

    return ListenableBuilder(
      listenable: services.monetization,
      builder: (context, _) {
        final messageKey = services.monetization.takeStoreMessageKey();
        if (messageKey != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              SnackBar(content: Text(l10n.t(messageKey))),
            );
          });
        }

        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: FindoPanel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.t('settings.title'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 18),
                    _ToggleRow(
                      icon: Icons.music_note_rounded,
                      label: l10n.t('settings.music'),
                      value: services.audio.musicEnabled,
                      onChanged: (value) async {
                        await services.audio.setMusicEnabled(value);
                        if (mounted) {
                          setState(() {});
                        }
                      },
                    ),
                    _ToggleRow(
                      icon: Icons.volume_up_rounded,
                      label: l10n.t('settings.sfx'),
                      value: services.audio.sfxEnabled,
                      onChanged: (value) async {
                        await services.audio.setSfxEnabled(value);
                        if (mounted) {
                          setState(() {});
                        }
                      },
                    ),
                    const Divider(height: 26, color: FindoColors.surfaceRaised),
                    Text(
                      l10n.t('settings.language'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: FindoColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (final code in LocalizationManager.supportedLanguageCodes) ...[
                          Expanded(
                            child: _LanguageChip(
                              label: l10n.t('settings.language.$code'),
                              selected: services.localization.languageCode == code,
                              onTap: () => services.localization.setLanguage(code),
                            ),
                          ),
                          if (code != LocalizationManager.supportedLanguageCodes.last)
                            const SizedBox(width: 10),
                        ],
                      ],
                    ),
                    const Divider(height: 26, color: FindoColors.surfaceRaised),
                    if (services.monetization.adsRemoved)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.verified_rounded,
                              color: FindoColors.success, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            l10n.t('settings.adsRemoved'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: FindoColors.success,
                            ),
                          ),
                        ],
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _run(services.monetization.buyRemoveAds),
                        icon: const Icon(Icons.block_rounded, size: 20),
                        label: Text(
                          _priceLabel(
                            services.monetization,
                            StoreProducts.removeAds,
                            l10n.t('settings.removeAds'),
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed:
                          _busy ? null : () => _run(services.monetization.buyHintPack),
                      icon: const Icon(Icons.lightbulb_rounded, size: 20),
                      label: Text(
                        _priceLabel(
                          services.monetization,
                          StoreProducts.hintPack,
                          l10n.t('hint.buyPack'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _run(services.monetization.restorePurchases),
                      icon: const Icon(Icons.restore_rounded, size: 20),
                      label: Text(l10n.t('settings.restore')),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _run(services.monetization.showPrivacyOptions),
                      icon: const Icon(Icons.privacy_tip_outlined, size: 20),
                      label: Text(l10n.t('settings.privacy')),
                    ),
                    const SizedBox(height: 10),
                    // The rules are shown once on a first run; this is how a
                    // player gets back to them afterwards.
                    OutlinedButton.icon(
                      onPressed: () => showRules(context, isFirstRun: false),
                      icon: const Icon(Icons.help_outline_rounded, size: 20),
                      label: Text(l10n.t('settings.howToPlay')),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.t('settings.close')),
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

  /// Appends the store price when the product was resolved, so the button says
  /// what it will cost instead of guessing at a currency.
  String _priceLabel(MonetizationManager monetization, String productId, String fallback) {
    final product = monetization.productById(productId);
    return product == null ? fallback : '$fallback  ${product.price}';
  }

  Future<void> _run(Future<Object?> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 20, color: FindoColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 16)),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? FindoColors.primary : FindoColors.surfaceRaised,
      borderRadius: BorderRadius.circular(FindoMetrics.radiusControl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FindoMetrics.radiusControl),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: selected ? FindoColors.onPrimary : FindoColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
