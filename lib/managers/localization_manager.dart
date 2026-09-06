import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'save_manager.dart';

/// Loads the JSON dictionaries in `assets/locales/` and exposes lookups.
///
/// Changing the language notifies listeners, which rebuilds the whole app
/// through the [ListenableBuilder] in `main.dart` -- text and layout direction
/// flip together, without restarting the game.
class LocalizationManager extends ChangeNotifier {
  LocalizationManager(this._saveManager);

  static const supportedLanguageCodes = ['en', 'he'];

  static const supportedLocales = [Locale('en'), Locale('he')];

  static const _rightToLeftCodes = {'he'};

  final SaveManager _saveManager;

  Map<String, String> _strings = const {};
  String _languageCode = 'en';

  String get languageCode => _languageCode;

  Locale get locale => Locale(_languageCode);

  TextDirection get textDirection =>
      _rightToLeftCodes.contains(_languageCode) ? TextDirection.rtl : TextDirection.ltr;

  bool get isRightToLeft => textDirection == TextDirection.rtl;

  /// Resolves the starting language: an explicit choice wins, otherwise the
  /// device locale if we speak it, otherwise English.
  Future<void> initialize(Locale deviceLocale) async {
    final saved = _saveManager.languageCode;
    final resolved = saved != null && supportedLanguageCodes.contains(saved)
        ? saved
        : supportedLanguageCodes.contains(deviceLocale.languageCode)
            ? deviceLocale.languageCode
            : 'en';
    await _load(resolved);
  }

  Future<void> setLanguage(String code) async {
    if (!supportedLanguageCodes.contains(code) || code == _languageCode) {
      return;
    }
    await _load(code);
    await _saveManager.setLanguageCode(code);
  }

  Future<void> _load(String code) async {
    final raw = await rootBundle.loadString('assets/locales/$code.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    _strings = decoded.map((key, value) => MapEntry(key, value as String));
    _languageCode = code;
    notifyListeners();
  }

  /// Looks up [key] and substitutes `{name}` placeholders from [params].
  ///
  /// A missing key returns the key itself, which makes the gap obvious on
  /// screen instead of rendering an empty box.
  String t(String key, {Map<String, Object>? params}) {
    var value = _strings[key] ?? key;
    if (params != null) {
      params.forEach((name, replacement) {
        value = value.replaceAll('{$name}', '$replacement');
      });
    }
    return value;
  }
}

/// Gives widgets `context.l10n.t('some.key')` without threading the manager
/// through every constructor.
class LocalizationScope extends InheritedNotifier<LocalizationManager> {
  const LocalizationScope({
    super.key,
    required LocalizationManager manager,
    required super.child,
  }) : super(notifier: manager);

  static LocalizationManager of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LocalizationScope>();
    assert(scope != null, 'No LocalizationScope found above this widget.');
    return scope!.notifier!;
  }
}

extension LocalizationContext on BuildContext {
  LocalizationManager get l10n => LocalizationScope.of(this);
}
