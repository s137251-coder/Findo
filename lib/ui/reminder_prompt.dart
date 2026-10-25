import 'package:flutter/material.dart';

import '../app_services.dart';
import '../managers/localization_manager.dart';
import '../theme.dart';
import 'widgets/common.dart';

/// Asks, once, whether the player would like the Daily Hunt reminder.
///
/// The game's own question comes before Android's: a system prompt out of
/// nowhere is easy to refuse and cannot be asked again, while a player who
/// has just said "yes" to this one knows what the next one is for.
Future<void> offerDailyReminder(BuildContext context, AppServices services) async {
  final l10n = context.l10n;
  await services.save.markReminderAsked();
  if (!context.mounted) {
    return;
  }
  final yes = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0xB3050710),
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(20),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: FindoPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.notifications_active_rounded,
                  size: 38, color: FindoColors.accent),
              const SizedBox(height: 10),
              Text(
                l10n.t('reminder.ask.title'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.t('reminder.ask.body'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: FindoColors.textMuted,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.t('reminder.ask.yes')),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(foregroundColor: FindoColors.textMuted),
                child: Text(l10n.t('reminder.ask.no')),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await services.reminder.setEnabled(
    yes ?? false,
    title: l10n.t('reminder.title'),
    body: l10n.t('reminder.body'),
  );
}
