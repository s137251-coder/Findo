import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/level_definition.dart';
import 'save_manager.dart';

/// Loads level metadata from `assets/images/maps/meta/` and tracks the hunt in
/// progress: whether Findo has been spotted on the current map.
class LevelManager extends ChangeNotifier {
  LevelManager(this._saveManager);

  static const _metaDirectory = 'assets/images/maps/meta';
  static const _indexPath = '$_metaDirectory/index.json';

  final SaveManager _saveManager;
  final Random _random = Random();

  /// Where she hid last time, per level, so a replay moves her.
  final Map<String, int> _lastSpot = {};

  List<LevelDefinition> _levels = const [];
  LevelDefinition? _current;
  bool _found = false;

  List<LevelDefinition> get levels => List.unmodifiable(_levels);

  LevelDefinition? get current => _current;

  /// True once Findo has been tapped on the current map.
  bool get isFound => _found;

  bool get isCleared => _current != null && _found;

  /// Reads every level named in the manifest, ordered by [LevelDefinition.index].
  Future<void> loadCatalogue() async {
    final manifest =
        jsonDecode(await rootBundle.loadString(_indexPath)) as Map<String, dynamic>;
    final ids = (manifest['levels'] as List<dynamic>).cast<String>();
    final loaded = <LevelDefinition>[];
    for (final id in ids) {
      final source = await rootBundle.loadString('$_metaDirectory/$id.json');
      loaded.add(LevelDefinition.parse(source));
    }
    loaded.sort((a, b) => a.index.compareTo(b.index));
    _levels = loaded;
    notifyListeners();
  }

  bool isUnlocked(LevelDefinition level) =>
      level.index <= _saveManager.unlockedLevelIndex;

  LevelProgress progressOf(LevelDefinition level) =>
      _saveManager.progressFor(level.id);

  LevelDefinition? levelAfter(LevelDefinition level) {
    final next = _levels.where((candidate) => candidate.index == level.index + 1);
    return next.isEmpty ? null : next.first;
  }

  /// Chooses where Findo hides this time.
  ///
  /// Levels carry several spots and this avoids repeating the one used on the
  /// previous attempt, because the star rating is earned by replaying a level
  /// faster. If she were always in the same place, the second run would be
  /// recall rather than a search and the whole loop would collapse.
  LevelTarget pickTarget(LevelDefinition level) {
    final spots = level.targets;
    if (spots.length < 2) {
      return spots.first;
    }
    final previous = _lastSpot[level.id];
    var index = _random.nextInt(spots.length);
    if (index == previous) {
      // Step to any of the others, so the repeat is impossible rather than
      // merely unlikely.
      index = (index + 1 + _random.nextInt(spots.length - 1)) % spots.length;
    }
    _lastSpot[level.id] = index;
    return spots[index];
  }

  void startLevel(LevelDefinition level) {
    _current = level;
    _found = false;
    notifyListeners();
  }

  /// Marks Findo as found. Returns false if she already was, which keeps a
  /// double tap from scoring twice.
  bool markFound() {
    if (_found) {
      return false;
    }
    _found = true;
    notifyListeners();
    return true;
  }

  /// Persists the outcome and opens the following level when it was cleared.
  Future<bool> recordResult({
    required LevelDefinition level,
    required int score,
    required int stars,
    required bool cleared,
  }) async {
    final isNewBest = await _saveManager.recordResult(
      levelId: level.id,
      score: score,
      stars: stars,
    );
    if (cleared) {
      await _saveManager.unlockLevel(level.index + 1);
    }
    notifyListeners();
    return isNewBest;
  }

  void clearCurrent() {
    _current = null;
    _found = false;
    notifyListeners();
  }
}
