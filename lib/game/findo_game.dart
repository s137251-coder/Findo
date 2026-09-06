import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';

import '../managers/audio_manager.dart';
import '../managers/level_manager.dart';
import '../managers/score_manager.dart';
import '../models/level_definition.dart';
import 'components/item_target_component.dart';
import 'components/map_background_component.dart';

/// The Flame side of a level: the map, the collectables, the camera the player
/// drags around, and the rules that fire when they tap.
///
/// Everything the HUD shows lives in [ScoreManager] and [LevelManager]; this
/// class only drives them and reports the two moments the UI has to react to,
/// [onLevelCleared] and [onTimeUp].
class FindoGame extends FlameGame with ScaleDetector {
  FindoGame({
    required this.level,
    required this.scoreManager,
    required this.levelManager,
    required this.audioManager,
    required this.onLevelCleared,
    required this.onTimeUp,
  });

  /// How far past the fit-to-screen zoom the player may pinch in.
  static const maxZoomFactor = 3.2;

  /// Seconds a hinted item keeps glowing.
  static const hintDurationSeconds = 3.0;

  final LevelDefinition level;
  final ScoreManager scoreManager;
  final LevelManager levelManager;
  final AudioManager audioManager;
  final VoidCallback onLevelCleared;
  final VoidCallback onTimeUp;

  final Map<String, ItemTargetComponent> _targets = {};

  double _minZoom = 1.0;
  double _zoomAtScaleStart = 1.0;
  bool _accepting = true;
  bool _finished = false;

  Vector2 get worldSize => Vector2(level.worldWidth, level.worldHeight);

  /// False while a modal is up, so taps behind it cannot score or penalise.
  bool get isAccepting => _accepting;

  @override
  Color backgroundColor() => const Color(0xFF10131C);

  @override
  Future<void> onLoad() async {
    final backgroundSprite = Sprite(await images.load(level.background));
    world.add(
      MapBackgroundComponent(sprite: backgroundSprite, worldSize: worldSize),
    );

    for (final item in level.items) {
      final sprite = Sprite(await images.load(item.sprite));
      final target = ItemTargetComponent(item: item, sprite: sprite);
      _targets[item.id] = target;
      world.add(target);
    }

    camera.setBounds(
      Rectangle.fromLTRB(0, 0, worldSize.x, worldSize.y),
      considerViewport: true,
    );
    _applyZoomLimits();
    camera.viewfinder.zoom = _minZoom;
    camera.viewfinder.position = worldSize / 2;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) {
      _applyZoomLimits();
      // A rotation or a split-screen resize can leave the old zoom too far out
      // for the new viewport; pull it back to something legal.
      camera.viewfinder.zoom = camera.viewfinder.zoom.clamp(_minZoom, _maxZoom);
    }
  }

  /// The world must always cover the viewport, otherwise the clamped bounds
  /// would fight the camera and the map would jitter at the edges.
  void _applyZoomLimits() {
    final viewportSize = camera.viewport.size;
    if (viewportSize.x <= 0 || viewportSize.y <= 0) {
      return;
    }
    _minZoom = math.max(viewportSize.x / worldSize.x, viewportSize.y / worldSize.y);
  }

  double get _maxZoom => _minZoom * maxZoomFactor;

  @override
  void update(double dt) {
    super.update(dt);
    if (_finished || !_accepting) {
      return;
    }
    if (scoreManager.update(dt)) {
      _finished = true;
      audioManager.play(GameSound.misclick, volume: 0.7);
      onTimeUp();
    }
  }

  // -- gestures ------------------------------------------------------------

  @override
  void onScaleStart(ScaleStartInfo info) {
    _zoomAtScaleStart = camera.viewfinder.zoom;
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    final pointers = info.raw.pointerCount;
    if (pointers >= 2) {
      camera.viewfinder.zoom =
          (_zoomAtScaleStart * info.raw.scale).clamp(_minZoom, _maxZoom);
      return;
    }
    // One finger drags the map: screen delta divided by zoom is world delta.
    final delta = info.raw.focalPointDelta;
    final zoom = camera.viewfinder.zoom;
    camera.viewfinder.position += Vector2(-delta.dx / zoom, -delta.dy / zoom);
  }

  // -- rules ---------------------------------------------------------------

  /// Called by an item that was tapped. Returns false when the tap should be
  /// ignored, which stops a double tap from scoring twice.
  bool registerFind(LevelItem item) {
    if (_finished || !_accepting) {
      return false;
    }
    if (!levelManager.markFound(item.id)) {
      return false;
    }
    final awarded = scoreManager.registerFind();
    audioManager.play(
      scoreManager.comboActive ? GameSound.combo : GameSound.found,
    );
    _showFloatingScore(Vector2(item.x, item.y), awarded, scoreManager.multiplier);

    if (levelManager.isCleared) {
      _finished = true;
      audioManager.play(GameSound.win);
      onLevelCleared();
    }
    return true;
  }

  /// Called by the background when the tap hit nothing.
  void registerMisclick(Vector2 worldPosition) {
    if (_finished || !_accepting) {
      return;
    }
    scoreManager.registerMisclick();
    audioManager.play(GameSound.misclick, volume: 0.8);
    _showFloatingScore(worldPosition, -ScoreManager.misclickPenalty, 1);
    if (scoreManager.isTimeUp) {
      _finished = true;
      onTimeUp();
    }
  }

  /// Pans to the next uncollected item and makes it glow.
  void revealHint(LevelItem item) {
    final target = _targets[item.id];
    if (target == null || target.isFound) {
      return;
    }
    audioManager.play(GameSound.hint);
    camera.viewfinder.add(
      MoveToEffect(
        Vector2(item.x, item.y),
        EffectController(duration: 0.45, curve: Curves.easeOutCubic),
      ),
    );
    target.highlight(seconds: hintDurationSeconds);
  }

  /// Freezes gameplay while an overlay is up.
  void setAccepting(bool value) {
    _accepting = value;
    if (value) {
      scoreManager.resume();
    } else {
      scoreManager.pause();
    }
  }

  void _showFloatingScore(Vector2 position, int amount, int multiplier) {
    final positive = amount >= 0;
    final label = positive ? '+$amount' : '$amount';
    final text = TextComponent(
      text: multiplier > 1 && positive ? '$label  x$multiplier' : label,
      position: position.clone()..y -= 40,
      anchor: Anchor.center,
      priority: 100,
      textRenderer: TextPaint(
        style: TextStyle(
          fontFamily: 'Findo',
          fontSize: 44,
          fontWeight: FontWeight.w700,
          color: positive ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
          shadows: const [
            Shadow(color: Color(0xCC101828), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
      ),
    );
    text.add(
      MoveByEffect(Vector2(0, -70), EffectController(duration: 0.75, curve: Curves.easeOut)),
    );
    text.add(OpacityEffect.fadeOut(EffectController(startDelay: 0.3, duration: 0.45)));
    text.add(RemoveEffect(delay: 0.8));
    world.add(text);
  }
}
