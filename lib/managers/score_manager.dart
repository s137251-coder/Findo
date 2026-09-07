import 'package:flutter/foundation.dart';

import '../models/level_definition.dart';

/// Scoring, the countdown and the combo streak for the level being played.
///
/// The Flame game drives [update]; the HUD listens for repaints.
class ScoreManager extends ChangeNotifier {
  /// Points for finding an item, before the combo multiplier.
  static const basePoints = 100;

  /// Points lost for tapping somewhere with nothing to find.
  static const misclickPenalty = 15;

  /// Seconds lost for the same mistake.
  static const misclickTimePenalty = 3.0;

  /// A find within this many seconds of the previous one extends the streak.
  static const comboWindowSeconds = 3.0;

  /// Points awarded per second still on the clock when the level is cleared.
  static const timeBonusPerSecond = 10;

  /// The streak stops growing here, so scores stay in a readable range.
  static const maxMultiplier = 3;

  double _timeLimit = 0;
  double _timeRemaining = 0;
  int _baseScore = 0;
  int _penalty = 0;
  int _streak = 0;
  double _sinceLastFind = 0;
  bool _running = false;

  double get timeRemaining => _timeRemaining;

  double get timeLimit => _timeLimit;

  /// 0..1, for the timer bar.
  double get timeFraction => _timeLimit <= 0 ? 0 : (_timeRemaining / _timeLimit).clamp(0.0, 1.0);

  /// Live score, never negative.
  int get score {
    final value = _baseScore - _penalty;
    return value < 0 ? 0 : value;
  }

  int get baseScore => _baseScore;

  int get penalty => _penalty;

  /// 1 while there is no streak, then 2 and 3 as finds chain together.
  int get multiplier {
    if (_streak < 2) {
      return 1;
    }
    return _streak >= 4 ? maxMultiplier : 2;
  }

  bool get comboActive => multiplier > 1;

  bool get isRunning => _running;

  bool get isTimeUp => _timeRemaining <= 0;

  void startLevel(LevelDefinition level) {
    _timeLimit = level.timeLimitSeconds.toDouble();
    _timeRemaining = _timeLimit;
    _baseScore = 0;
    _penalty = 0;
    _streak = 0;
    _sinceLastFind = comboWindowSeconds;
    _running = true;
    notifyListeners();
  }

  void pause() {
    if (!_running) {
      return;
    }
    _running = false;
    notifyListeners();
  }

  void resume() {
    if (_running || isTimeUp) {
      return;
    }
    _running = true;
    notifyListeners();
  }

  /// Advances the clock and expires the combo window. Returns true on the tick
  /// that the timer runs out, so the caller can end the level exactly once.
  bool update(double dt) {
    if (!_running) {
      return false;
    }
    _sinceLastFind += dt;
    if (_sinceLastFind > comboWindowSeconds && _streak != 0) {
      _streak = 0;
      notifyListeners();
    }
    _timeRemaining -= dt;
    if (_timeRemaining <= 0) {
      _timeRemaining = 0;
      _running = false;
      notifyListeners();
      return true;
    }
    notifyListeners();
    return false;
  }

  /// Registers a found item and returns the points it was worth.
  int registerFind() {
    final chained = _sinceLastFind <= comboWindowSeconds;
    _streak = chained ? _streak + 1 : 1;
    _sinceLastFind = 0;
    final awarded = basePoints * multiplier;
    _baseScore += awarded;
    notifyListeners();
    return awarded;
  }

  void registerMisclick() {
    _penalty += misclickPenalty;
    _streak = 0;
    _timeRemaining -= misclickTimePenalty;
    if (_timeRemaining < 0) {
      _timeRemaining = 0;
      _running = false;
    }
    notifyListeners();
  }

  /// Freezes the clock and works out the final tally for [level].
  LevelResult finish({
    required LevelDefinition level,
    required bool found,
    required bool isNewBest,
  }) {
    _running = false;
    final bonus = found ? _timeRemaining.floor() * timeBonusPerSecond : 0;
    final total = score + bonus;
    notifyListeners();
    return LevelResult(
      levelId: level.id,
      found: found,
      baseScore: _baseScore,
      penalty: _penalty,
      timeBonus: bonus,
      stars: found ? level.starThresholds.starsFor(total) : 0,
      isNewBest: isNewBest,
      secondsTaken: (_timeLimit - _timeRemaining).round(),
    );
  }

  /// The tally used to decide a personal best, before it is stored.
  int projectedTotal({required bool cleared}) =>
      score + (cleared ? _timeRemaining.floor() * timeBonusPerSecond : 0);
}
