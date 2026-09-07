import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// What the player has achieved on one level.
class LevelProgress {
  const LevelProgress({this.bestScore = 0, this.stars = 0});

  final int bestScore;
  final int stars;

  bool get isPlayed => bestScore > 0 || stars > 0;

  Map<String, dynamic> toJson() => {'bestScore': bestScore, 'stars': stars};

  factory LevelProgress.fromJson(Map<String, dynamic> json) {
    return LevelProgress(
      bestScore: (json['bestScore'] as num?)?.toInt() ?? 0,
      stars: (json['stars'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Every value that has to survive an app restart lives here.
///
/// The rest of the app never touches [SharedPreferences] directly, so there is
/// a single place to audit what is written to the device.
class SaveManager {
  SaveManager._(this._prefs);

  static const _keyLanguage = 'findo.language';
  static const _keyMusic = 'findo.audio.music';
  static const _keySfx = 'findo.audio.sfx';
  static const _keyUnlocked = 'findo.progress.unlocked';
  static const _keyProgress = 'findo.progress.levels';
  static const _keyAdsRemoved = 'findo.iap.adsRemoved';
  static const _keyHints = 'findo.iap.hints';
  static const _keyIntroSeen = 'findo.intro.seen';

  /// Hints the player starts with, so the hint button is usable on day one.
  static const startingHints = 3;

  final SharedPreferences _prefs;

  static Future<SaveManager> load() async {
    final prefs = await SharedPreferences.getInstance();
    final manager = SaveManager._(prefs);
    if (!prefs.containsKey(_keyHints)) {
      await prefs.setInt(_keyHints, startingHints);
    }
    return manager;
  }

  // -- language ------------------------------------------------------------

  /// `null` until the player picks one, which means "follow the device".
  String? get languageCode => _prefs.getString(_keyLanguage);

  Future<void> setLanguageCode(String code) => _prefs.setString(_keyLanguage, code);

  // -- first run -----------------------------------------------------------

  /// False until the player has been shown the rules once.
  bool get introSeen => _prefs.getBool(_keyIntroSeen) ?? false;

  Future<void> markIntroSeen() => _prefs.setBool(_keyIntroSeen, true);

  // -- audio ---------------------------------------------------------------

  bool get musicEnabled => _prefs.getBool(_keyMusic) ?? true;

  Future<void> setMusicEnabled(bool value) => _prefs.setBool(_keyMusic, value);

  bool get sfxEnabled => _prefs.getBool(_keySfx) ?? true;

  Future<void> setSfxEnabled(bool value) => _prefs.setBool(_keySfx, value);

  // -- progress ------------------------------------------------------------

  /// Highest level index the player may enter. Level 1 is always open.
  int get unlockedLevelIndex => _prefs.getInt(_keyUnlocked) ?? 1;

  Future<void> unlockLevel(int index) async {
    if (index > unlockedLevelIndex) {
      await _prefs.setInt(_keyUnlocked, index);
    }
  }

  Map<String, LevelProgress> get allProgress {
    final raw = _prefs.getString(_keyProgress);
    if (raw == null || raw.isEmpty) {
      return const {};
    }
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (key, value) =>
          MapEntry(key, LevelProgress.fromJson(value as Map<String, dynamic>)),
    );
  }

  LevelProgress progressFor(String levelId) =>
      allProgress[levelId] ?? const LevelProgress();

  /// Keeps the better of the stored and the incoming result, and reports
  /// whether the incoming score was a personal best.
  Future<bool> recordResult({
    required String levelId,
    required int score,
    required int stars,
  }) async {
    final progress = Map<String, LevelProgress>.from(allProgress);
    final previous = progress[levelId] ?? const LevelProgress();
    final isNewBest = score > previous.bestScore;
    progress[levelId] = LevelProgress(
      bestScore: isNewBest ? score : previous.bestScore,
      stars: stars > previous.stars ? stars : previous.stars,
    );
    await _prefs.setString(
      _keyProgress,
      jsonEncode(progress.map((key, value) => MapEntry(key, value.toJson()))),
    );
    return isNewBest;
  }

  // -- entitlements --------------------------------------------------------

  bool get adsRemoved => _prefs.getBool(_keyAdsRemoved) ?? false;

  Future<void> setAdsRemoved(bool value) => _prefs.setBool(_keyAdsRemoved, value);

  int get hintCount => _prefs.getInt(_keyHints) ?? startingHints;

  Future<void> setHintCount(int value) =>
      _prefs.setInt(_keyHints, value < 0 ? 0 : value);

  Future<void> addHints(int amount) => setHintCount(hintCount + amount);

  /// Returns false when the player had none left, so the caller can offer an ad.
  Future<bool> consumeHint() async {
    final current = hintCount;
    if (current <= 0) {
      return false;
    }
    await setHintCount(current - 1);
    return true;
  }
}
