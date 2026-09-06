import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/level_definition.dart';
import 'save_manager.dart';

/// Loads level definitions from `assets/levels/` and tracks the hunt in
/// progress: which collectables are still missing on the current map.
class LevelManager extends ChangeNotifier {
  LevelManager(this._saveManager);

  static const _indexPath = 'assets/levels/index.json';

  final SaveManager _saveManager;

  List<LevelDefinition> _levels = const [];
  LevelDefinition? _current;
  final Set<String> _found = <String>{};

  List<LevelDefinition> get levels => List.unmodifiable(_levels);

  LevelDefinition? get current => _current;

  Set<String> get foundIds => Set.unmodifiable(_found);

  int get foundCount => _found.length;

  /// Items still to find, in their level order.
  List<LevelItem> get remainingItems =>
      _current == null
          ? const []
          : _current!.items.where((item) => !_found.contains(item.id)).toList(growable: false);

  bool get isCleared => _current != null && _found.length >= _current!.items.length;

  /// Reads every level named in the manifest, ordered by [LevelDefinition.index].
  Future<void> loadCatalogue() async {
    final manifest = jsonDecode(await rootBundle.loadString(_indexPath)) as Map<String, dynamic>;
    final ids = (manifest['levels'] as List<dynamic>).cast<String>();
    final loaded = <LevelDefinition>[];
    for (final id in ids) {
      final source = await rootBundle.loadString('assets/levels/$id.json');
      loaded.add(LevelDefinition.parse(source));
    }
    loaded.sort((a, b) => a.index.compareTo(b.index));
    _levels = loaded;
    notifyListeners();
  }

  bool isUnlocked(LevelDefinition level) => level.index <= _saveManager.unlockedLevelIndex;

  LevelProgress progressOf(LevelDefinition level) => _saveManager.progressFor(level.id);

  LevelDefinition? levelAfter(LevelDefinition level) {
    final next = _levels.where((candidate) => candidate.index == level.index + 1);
    return next.isEmpty ? null : next.first;
  }

  void startLevel(LevelDefinition level) {
    _current = level;
    _found.clear();
    notifyListeners();
  }

  /// Marks [itemId] as found. Returns false if it was already collected, which
  /// keeps a double tap from scoring twice.
  bool markFound(String itemId) {
    final added = _found.add(itemId);
    if (added) {
      notifyListeners();
    }
    return added;
  }

  /// The next item a hint should point at, or null once the map is clear.
  LevelItem? nextHintTarget() {
    final remaining = remainingItems;
    return remaining.isEmpty ? null : remaining.first;
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
    _found.clear();
    notifyListeners();
  }
}
