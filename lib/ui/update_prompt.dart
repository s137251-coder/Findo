import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';

import '../managers/localization_manager.dart';
import '../theme.dart';
import 'widgets/common.dart';

/// Findo's package name on Google Play.
const _packageName = 'com.findo.game';

/// Shows the prompt without asking Play, so the dialog can be seen on a build
/// that did not come from the store:
///
/// ```
/// flutter build apk --dart-define=FINDO_FAKE_UPDATE=true
/// ```
const _fakeUpdate = bool.fromEnvironment('FINDO_FAKE_UPDATE');

/// Asks Google Play whether a newer version is published and, if there is one,
/// offers to open Findo's store page.
///
/// Play only answers for an install that came from Play itself. A sideloaded
/// or emulator build gets an error, which is swallowed: an update check that
/// fails must never stand between the player and the game. iOS has no
/// equivalent API, so it is skipped there.
Future<void> offerUpdateIfAvailable(BuildContext context) async {
  if (!Platform.isAndroid) {
    return;
  }
  var available = _fakeUpdate;
  if (!available) {
    try {
      final info = await InAppUpdate.checkForUpdate();
      available = info.updateAvailability == UpdateAvailability.updateAvailable;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('update check unavailable: $error');
      }
      return;
    }
  }
  if (!available || !context.mounted) {
    return;
  }

  final wantsUpdate = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0xB3050710),
    builder: (context) => const _UpdateDialog(),
  );
  if (wantsUpdate == true) {
    await openStorePage();
  }
}

/// Opens Findo in the Play Store app, or on the web if the store app is not
/// there to take it.
Future<void> openStorePage() async {
  final store = Uri.parse('market://details?id=$_packageName');
  final web =
      Uri.parse('https://play.google.com/store/apps/details?id=$_packageName');
  try {
    if (await launchUrl(store, mode: LaunchMode.externalApplication)) {
      return;
    }
  } catch (_) {
    // No store app on this device; the web page does the same job.
  }
  await launchUrl(web, mode: LaunchMode.externalApplication);
}

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog();

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
              const Icon(Icons.system_update_rounded,
                  size: 40, color: FindoColors.primary),
              const SizedBox(height: 10),
              Text(
                l10n.t('update.title'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.t('update.body'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: FindoColors.textMuted,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.shop_rounded, size: 20),
                label: Text(l10n.t('update.now')),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  l10n.t('update.later'),
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
