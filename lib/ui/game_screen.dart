import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../game/findo_game.dart';
import '../managers/audio_manager.dart';
import '../managers/localization_manager.dart';
import '../managers/score_manager.dart';
import '../models/level_definition.dart';
import 'character_sheet_modal.dart';
import 'hint_dialog.dart';
import 'hud_overlay.dart';
import 'pause_modal.dart';
import 'win_modal.dart';

/// Hosts the Flame canvas and every Flutter overlay drawn on top of it.
///
/// The Flame side never navigates: it reports "cleared" or "time up", and this
/// widget decides which overlay to raise and what to persist.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.level});

  final LevelDefinition level;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final AppServices _services;
  late final ScoreManager _scoreManager;
  late FindoGame _game;

  LevelResult? _result;
  bool _servicesReady = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_servicesReady) {
      return;
    }
    _services = AppServices.of(context);
    _servicesReady = true;
    _scoreManager = ScoreManager();
    _startLevel(widget.level);
  }

  void _startLevel(LevelDefinition level) {
    _services.levels.startLevel(level);
    _scoreManager.startLevel(level);
    _result = null;
    _game = FindoGame(
      level: level,
      scoreManager: _scoreManager,
      levelManager: _services.levels,
      audioManager: _services.audio,
      onLevelCleared: _handleLevelCleared,
      onTimeUp: _handleTimeUp,
    );
  }

  @override
  void dispose() {
    _scoreManager.dispose();
    super.dispose();
  }

  // -- outcomes ------------------------------------------------------------

  Future<void> _handleLevelCleared() async {
    final level = _game.level;
    final projected = _scoreManager.projectedTotal(cleared: true);
    final stars = level.starThresholds.starsFor(projected);
    final isNewBest = await _services.levels.recordResult(
      level: level,
      score: projected,
      stars: stars,
      cleared: true,
    );
    final result = _scoreManager.finish(
      level: level,
      found: true,
      isNewBest: isNewBest,
    );
    if (!mounted) {
      return;
    }
    setState(() => _result = result);
    _game.setAccepting(false);
    _game.overlays.add(WinModal.overlayId);
  }

  Future<void> _handleTimeUp() async {
    final level = _game.level;
    await _services.levels.recordResult(
      level: level,
      score: _scoreManager.score,
      stars: 0,
      cleared: false,
    );
    if (!mounted) {
      return;
    }
    _game.setAccepting(false);
    _game.overlays.add(TimeUpModal.overlayId);
  }

  // -- navigation ----------------------------------------------------------

  /// Shows the interstitial that is due, then runs [next]. Ads never sit
  /// between the player and the result they just earned, only after it.
  Future<void> _leaveLevel(VoidCallback next) async {
    await _services.monetization.onLevelFinished();
    if (!mounted) {
      return;
    }
    next();
  }

  void _restart(LevelDefinition level) {
    setState(() {
      _game.overlays.clear();
      _startLevel(level);
    });
  }

  void _backToLevelList() {
    _services.levels.clearCurrent();
    Navigator.of(context).pop();
  }

  // -- pause and hints -----------------------------------------------------

  void _pause() {
    _services.audio.play(GameSound.tap);
    _game.setAccepting(false);
    _game.overlays.add(PauseModal.overlayId);
  }

  /// Opens Findo full size. The clock stops while she is up: otherwise the
  /// panel is free thinking time, and taps aimed at it fall through to the map.
  void _openCharacterSheet() {
    if (_game.overlays.isActive(CharacterSheetModal.overlayId)) {
      return;
    }
    _services.audio.play(GameSound.peek);
    _game.setAccepting(false);
    _game.overlays.add(CharacterSheetModal.overlayId);
  }

  void _closeCharacterSheet() {
    _game.overlays.remove(CharacterSheetModal.overlayId);
    _game.setAccepting(true);
  }

  void _resume() {
    _services.audio.play(GameSound.tap);
    _game.overlays.remove(PauseModal.overlayId);
    _game.setAccepting(true);
  }

  Future<void> _requestHint() async {
    if (_services.levels.isFound) {
      return;
    }
    _services.audio.play(GameSound.tap);
    _game.setAccepting(false);
    final choice = await showHintDialog(context, _services.monetization);
    if (!mounted) {
      return;
    }
    var granted = false;
    switch (choice) {
      case HintChoice.useStored:
        granted = await _services.monetization.consumeHint();
      case HintChoice.watchAd:
        granted = await _services.monetization.showRewardedForHint();
        if (granted) {
          // The reward is banked as a hint, so spend it straight away.
          granted = await _services.monetization.consumeHint();
        }
      case HintChoice.cancel:
        granted = false;
    }
    if (!mounted) {
      return;
    }
    _game.setAccepting(true);
    if (granted) {
      _game.revealHint();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        if (_game.overlays.isActive(CharacterSheetModal.overlayId)) {
          _closeCharacterSheet();
        } else if (_game.overlays.isActive(PauseModal.overlayId)) {
          _resume();
        } else if (_game.overlays.isActive(WinModal.overlayId) ||
            _game.overlays.isActive(TimeUpModal.overlayId)) {
          _leaveLevel(_backToLevelList);
        } else {
          _pause();
        }
      },
      child: Scaffold(
        body: GameWidget<FindoGame>(
          game: _game,
          loadingBuilder: (context) => Center(
            child: Text(
              context.l10n.t('common.loading'),
              style: const TextStyle(fontSize: 16),
            ),
          ),
          initialActiveOverlays: const [HudOverlay.overlayId],
          overlayBuilderMap: {
            HudOverlay.overlayId: (context, game) => HudOverlay(
                  game: game,
                  monetization: _services.monetization,
                  onPause: _pause,
                  onHint: _requestHint,
                  onOpenCharacter: _openCharacterSheet,
                ),
            CharacterSheetModal.overlayId: (context, game) =>
                CharacterSheetModal(onClose: _closeCharacterSheet),
            PauseModal.overlayId: (context, game) => PauseModal(
                  onResume: _resume,
                  onQuit: () => _leaveLevel(_backToLevelList),
                ),
            WinModal.overlayId: (context, game) {
              final result = _result;
              if (result == null) {
                return const SizedBox.shrink();
              }
              final next = _services.levels.levelAfter(game.level);
              return WinModal(
                result: result,
                hasNextLevel: next != null,
                onNext: () => _leaveLevel(() => _restart(next!)),
                onReplay: () => _leaveLevel(() => _restart(game.level)),
                onLevelList: () => _leaveLevel(_backToLevelList),
              );
            },
            TimeUpModal.overlayId: (context, game) => TimeUpModal(
                  onRetry: () => _leaveLevel(() => _restart(game.level)),
                  onLevelList: () => _leaveLevel(_backToLevelList),
                ),
          },
        ),
      ),
    );
  }
}
