import 'package:flutter/material.dart';

import '../managers/localization_manager.dart';
import 'settings_dialog.dart';
import 'widgets/common.dart';

/// Shown while the level is frozen, with a way into settings and out of the
/// level.
class PauseModal extends StatelessWidget {
  const PauseModal({
    super.key,
    required this.onResume,
    required this.onQuit,
  });

  static const overlayId = 'pause';

  final VoidCallback onResume;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ModalScrim(
      child: FindoPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.t('pause.title'),
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onResume,
                child: Text(l10n.t('pause.resume')),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => showSettingsDialog(context),
                child: Text(l10n.t('settings.title')),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onQuit,
                child: Text(l10n.t('pause.quit')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
