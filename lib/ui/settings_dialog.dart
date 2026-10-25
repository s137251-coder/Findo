import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_services.dart';
import '../managers/account_service.dart';
import '../managers/localization_manager.dart';
import '../managers/monetization_manager.dart';
import '../theme.dart';
import 'rules_screen.dart';
import 'share.dart';
import 'widgets/common.dart';

/// The published privacy policy, in both languages.
const privacyPolicyUrl =
    'https://s137251-coder.github.io/Findo/privacy-policy.html';

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
      listenable: Listenable.merge([services.monetization, services.account]),
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
                    if (services.reminder.supported)
                      _ToggleRow(
                        icon: Icons.notifications_active_rounded,
                        label: l10n.t('settings.reminder'),
                        value: services.save.dailyReminder,
                        onChanged: (value) async {
                          final allowed = await services.reminder.setEnabled(
                            value,
                            title: l10n.t('reminder.title'),
                            body: l10n.t('reminder.body'),
                          );
                          if (!mounted) {
                            return;
                          }
                          setState(() {});
                          if (value && !allowed) {
                            _say(l10n.t('reminder.blocked'));
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
                    if (services.account.available) ...[
                      const Divider(height: 26, color: FindoColors.surfaceRaised),
                      _AccountSection(
                        account: services.account,
                        onSay: _say,
                        onRestore: services.monetization.restorePurchases,
                      ),
                    ],
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
                          : () => _openPrivacy(services.monetization),
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
                    const SizedBox(height: 10),
                    // Straight to the store page's reviews: a player who asks
                    // to rate should always land somewhere they can.
                    OutlinedButton.icon(
                      onPressed: services.review.openStorePage,
                      icon: const Icon(Icons.star_rate_rounded, size: 20),
                      label: Text(l10n.t('settings.rate')),
                    ),
                    const SizedBox(height: 10),
                    Builder(
                      builder: (buttonContext) => OutlinedButton.icon(
                        onPressed: () =>
                            shareText(buttonContext, l10n.t('share.app')),
                        icon: const Icon(Icons.share_rounded, size: 20),
                        label: Text(l10n.t('settings.share')),
                      ),
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

  /// The consent form where one exists; otherwise a panel that says why there
  /// is nothing to change and links to the policy.
  Future<void> _openPrivacy(MonetizationManager monetization) async {
    var shown = false;
    setState(() => _busy = true);
    try {
      shown = await monetization.showPrivacyOptions();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
    if (shown || !mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      barrierColor: const Color(0xB3050710),
      builder: (context) => const _PrivacyInfoDialog(),
    );
  }

  void _say(String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message)),
    );
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

class _PrivacyInfoDialog extends StatelessWidget {
  const _PrivacyInfoDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
              const Icon(Icons.privacy_tip_outlined,
                  size: 36, color: FindoColors.primary),
              const SizedBox(height: 10),
              Text(
                l10n.t('settings.privacy'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.t('privacy.body'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: FindoColors.textMuted,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(privacyPolicyUrl),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 20),
                label: Text(l10n.t('privacy.policy')),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  l10n.t('settings.close'),
                  style: const TextStyle(color: FindoColors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

/// Signing in with Google, or who is signed in and the way out.
class _AccountSection extends StatelessWidget {
  const _AccountSection({
    required this.account,
    required this.onSay,
    required this.onRestore,
  });

  final AccountService account;
  final ValueChanged<String> onSay;

  /// Asks the store for the player's purchases again. A new phone signed in
  /// to the account should get its ads purchase back without a second tap.
  final Future<void> Function() onRestore;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final busy = account.busy;
    const heading = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: FindoColors.textMuted,
    );

    if (!account.isSignedIn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.t('account.title'), style: heading),
          const SizedBox(height: 6),
          Text(
            l10n.t('account.pitch'),
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: busy
                ? null
                : () async {
                    final outcome = await account.signInWithGoogle();
                    switch (outcome) {
                      case AccountOutcome.signedIn:
                        onSay(l10n.t('account.welcome'));
                        await onRestore();
                      case AccountOutcome.cancelled:
                        break;
                      case AccountOutcome.failed:
                      case AccountOutcome.unavailable:
                        onSay(l10n.t('account.failed'));
                    }
                  },
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : const Icon(Icons.account_circle_rounded, size: 22),
            label: Text(l10n.t('account.signIn')),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.t('account.title'), style: heading),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.cloud_done_rounded, color: FindoColors.success, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.t('account.signedInAs', params: {'email': account.email ?? ''}),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l10n.t('account.synced'),
          style: const TextStyle(fontSize: 13, color: FindoColors.textMuted),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: busy ? null : account.signOut,
                child: Text(l10n.t('account.signOut')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: busy ? null : () => _confirmDelete(context),
                style: OutlinedButton.styleFrom(foregroundColor: FindoColors.danger),
                child: Text(l10n.t('account.delete')),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = context.l10n;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FindoColors.surface,
        title: Text(l10n.t('account.delete.title')),
        content: Text(l10n.t('account.delete.body'), style: const TextStyle(height: 1.45)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: FindoColors.danger,
              foregroundColor: FindoColors.background,
            ),
            child: Text(l10n.t('account.delete.confirm')),
          ),
        ],
      ),
    );
    if (sure != true) {
      return;
    }
    final deleted = await account.deleteAccount();
    onSay(l10n.t(deleted ? 'account.deleted' : 'account.failed'));
  }
}
