import 'package:flutter/widgets.dart';

import 'managers/account_service.dart';
import 'managers/audio_manager.dart';
import 'managers/leaderboard_service.dart';
import 'managers/level_manager.dart';
import 'managers/localization_manager.dart';
import 'managers/monetization_manager.dart';
import 'managers/reminder_manager.dart';
import 'managers/review_manager.dart';
import 'managers/save_manager.dart';

/// The long-lived managers, built once in `main.dart` and reachable from any
/// widget through `AppServices.of(context)`.
class AppServices {
  const AppServices({
    required this.save,
    required this.localization,
    required this.audio,
    required this.levels,
    required this.monetization,
    required this.table,
    required this.account,
    required this.review,
    required this.reminder,
  });

  final SaveManager save;
  final LocalizationManager localization;
  final AudioManager audio;
  final LevelManager levels;
  final MonetizationManager monetization;

  /// The daily hunt's table: one table for every phone, Android or iPhone.
  final LeaderboardService table;

  /// Signing in with Google, and the save that follows the player.
  final AccountService account;

  /// Play's rating card, and the "Rate Findo" button.
  final ReviewManager review;

  /// The evening reminder for a Daily Hunt not yet played.
  final ReminderManager reminder;

  static AppServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppServicesScope>();
    assert(scope != null, 'No AppServicesScope found above this widget.');
    return scope!.services;
  }
}

class AppServicesScope extends InheritedWidget {
  const AppServicesScope({
    super.key,
    required this.services,
    required super.child,
  });

  final AppServices services;

  @override
  bool updateShouldNotify(AppServicesScope oldWidget) =>
      oldWidget.services != services;
}
