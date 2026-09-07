import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';

import '../managers/audio_manager.dart';
import '../managers/level_manager.dart';
import '../managers/score_manager.dart';
import '../models/level_definition.dart';
import 'components/item_target_component.dart';
import 'components/map_background_component.dart';

/// The Flame side of a level: the map, the one character hidden in it, the
/// camera the player drags around, and the rules that fire when they tap.
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

  /// The character sheet, relative to Flame's image prefix. Used for the
  /// shape of her hit area, and by the HUD for her portrait.
  static const targetSprite = 'targets/findo.png';

  /// How far past the fit-to-screen zoom the player may pinch in. The maps are
  /// authored at 2048px square so this much magnification stays sharp.
  static const maxZoomFactor = 3.2;

  /// Seconds a hinted target keeps glowing.
  static const hintDurationSeconds = 3.0;

  final LevelDefinition level;
  final ScoreManager scoreManager;
  final LevelManager levelManager;
  final AudioManager audioManager;
  final VoidCallback onLevelCleared;
  final VoidCallback onTimeUp;

  ItemTargetComponent? _target;

  double _minZoom = 1.0;
  double _zoomAtScaleStart = 1.0;
  double _hudBottomInset = 0;
  bool _viewportDirty = true;
  bool _accepting = true;
  bool _finished = false;

  Vector2 get mapSize => Vector2(level.mapWidth, level.mapHeight);

  /// Height, in logical pixels, of the opaque HUD panel along the bottom.
  ///
  /// The camera viewport stops above it. Without this the bottom of the map
  /// renders underneath the panel, and because the bounds pin the map's bottom
  /// edge to the viewport's bottom edge at every zoom level, a Findo hidden
  /// down there could not be tapped at all -- the panel swallows the tap
  /// before it reaches the game. The HUD measures itself and reports here.
  set hudBottomInset(double value) {
    if ((value - _hudBottomInset).abs() < 0.5) {
      return;
    }
    _hudBottomInset = value;
    // Applied on the next tick rather than here: the HUD gets its first layout
    // before the game finishes loading, and a viewport set before then is
    // discarded. Deferring means the value always lands, whatever the order.
    _viewportDirty = true;
  }

  /// False while a modal is up, so taps behind it cannot score or penalise.
  bool get isAccepting => _accepting;

  @override
  Color backgroundColor() => const Color(0xFF10131C);

  @override
  Future<void> onLoad() async {
    final mapImage = await images.load(level.map);
    world.add(
      MapBackgroundComponent(sprite: Sprite(mapImage), mapSize: mapSize),
    );

    // Findo is already painted into the map. The character sheet is loaded
    // only so her silhouette can shape the hit area over her.
    final findoImage = await images.load(targetSprite);
    final target = ItemTargetComponent(
      target: level.target,
      silhouette: findoImage,
      alpha: await findoImage.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    _target = target;
    world.add(target);

    _applyViewport();
    _viewportDirty = false;
    camera.viewfinder.zoom = _minZoom;
    camera.viewfinder.position = mapSize / 2;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) {
      // A rotation or a split-screen resize can leave the old zoom too far out
      // for the new viewport; pull it back to something legal.
      _applyViewport();
    }
  }

  /// Sizes the camera viewport to the area the player can actually reach, then
  /// re-derives the zoom limits and bounds from it.
  void _applyViewport() {
    // Never give away more than a third of the screen, however tall the HUD
    // reports itself to be.
    final height = math.max(size.y - _hudBottomInset, size.y * 0.66);
    final viewport = camera.viewport;
    if (viewport is FixedSizeViewport) {
      viewport.size = Vector2(size.x, height);
    } else {
      camera.viewport = FixedSizeViewport(size.x, height)
        ..position = Vector2.zero()
        ..anchor = Anchor.topLeft;
    }
    _applyZoomLimits();
    camera.setBounds(
      Rectangle.fromLTRB(0, 0, mapSize.x, mapSize.y),
      considerViewport: true,
    );
    camera.viewfinder.zoom = camera.viewfinder.zoom.clamp(_minZoom, _maxZoom);
  }

  /// The map must always cover the viewport, otherwise the clamped bounds
  /// would fight the camera and the artwork would jitter at the edges.
  void _applyZoomLimits() {
    final viewportSize = camera.viewport.size;
    if (viewportSize.x <= 0 || viewportSize.y <= 0) {
      return;
    }
    _minZoom = math.max(viewportSize.x / mapSize.x, viewportSize.y / mapSize.y);
  }

  double get _maxZoom => _minZoom * maxZoomFactor;

  @override
  void update(double dt) {
    super.update(dt);
    if (_viewportDirty) {
      _viewportDirty = false;
      _applyViewport();
    }
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

  /// Called by the target when it was tapped. Returns false when the tap
  /// should be ignored, which stops a double tap from scoring twice.
  bool registerFind() {
    if (_finished || !_accepting) {
      return false;
    }
    if (!levelManager.markFound()) {
      return false;
    }
    final awarded = scoreManager.registerFind();
    audioManager.play(GameSound.found);
    _showFloatingScore(
      Vector2(level.target.centerX, level.target.y),
      awarded,
    );

    _finished = true;
    audioManager.play(GameSound.win);
    onLevelCleared();
    return true;
  }

  /// Called by the map when the tap hit nothing.
  void registerMisclick(Vector2 mapPosition) {
    if (_finished || !_accepting) {
      return;
    }
    scoreManager.registerMisclick();
    audioManager.play(GameSound.misclick, volume: 0.8);
    _showFloatingScore(mapPosition, -ScoreManager.misclickPenalty);
    if (scoreManager.isTimeUp) {
      _finished = true;
      onTimeUp();
    }
  }

  /// Pans towards Findo and makes her glow, without giving her away entirely:
  /// the camera stops short so the player still has to spot her.
  void revealHint() {
    final target = _target;
    if (target == null || target.isFound) {
      return;
    }
    audioManager.play(GameSound.hint);
    camera.viewfinder.add(
      MoveToEffect(
        Vector2(level.target.centerX, level.target.centerY),
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

  void _showFloatingScore(Vector2 position, int amount) {
    final positive = amount >= 0;
    final text = TextComponent(
      text: positive ? '+$amount' : '$amount',
      position: position.clone()..y -= 40,
      anchor: Anchor.center,
      priority: 100,
      textRenderer: TextPaint(
        style: TextStyle(
          fontFamily: 'Findo',
          fontSize: 60,
          fontWeight: FontWeight.w700,
          color: positive ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
          shadows: const [
            Shadow(color: Color(0xCC101828), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
      ),
    );
    text.add(
      MoveByEffect(
        Vector2(0, -90),
        EffectController(duration: 0.75, curve: Curves.easeOut),
      ),
    );
    text.add(OpacityEffect.fadeOut(EffectController(startDelay: 0.3, duration: 0.45)));
    text.add(RemoveEffect(delay: 0.8));
    world.add(text);
  }
}
