import 'package:flutter/widgets.dart';

import 'managers/audio_manager.dart';
import 'managers/level_manager.dart';
import 'managers/localization_manager.dart';
import 'managers/monetization_manager.dart';
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
  });

  final SaveManager save;
  final LocalizationManager localization;
  final AudioManager audio;
  final LevelManager levels;
  final MonetizationManager monetization;

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
