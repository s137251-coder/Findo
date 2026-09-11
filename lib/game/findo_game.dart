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
    required this.target,
    required this.scoreManager,
    required this.levelManager,
    required this.audioManager,
    required this.onLevelCleared,
    required this.onTimeUp,
  });

  /// The character sheet, relative to Flame's image prefix. Drawn on the map,
  /// used for the shape of her hit area, and shown by the HUD as her portrait.
  static const targetSprite = 'targets/findo.png';

  /// How far past the fit-to-screen zoom the player may pinch in. The maps are
  /// authored at 2048px square so this much magnification stays sharp.
  static const maxZoomFactor = 3.2;

  /// Seconds a hinted target keeps glowing.
  static const hintDurationSeconds = 3.0;

  final LevelDefinition level;

  /// Where she is hiding this time round, chosen by [LevelManager] when the
  /// level was opened.
  final LevelTarget target;

  final ScoreManager scoreManager;
  final LevelManager levelManager;
  final AudioManager audioManager;
  final VoidCallback onLevelCleared;
  final VoidCallback onTimeUp;

  ItemTargetComponent? _target;

  /// How far a finger may travel and still count as a tap rather than a drag,
  /// in screen pixels. Below this a tap on nothing is a miss; above it the
  /// player was moving the map and owes nothing.
  static const tapSlop = 14.0;

  double _minZoom = 1.0;
  double _zoomAtScaleStart = 1.0;
  double _hudBottomInset = 0;
  bool _viewportDirty = true;
  bool _accepting = true;
  bool _finished = false;

  /// Distance the current gesture has covered, reset when it starts.
  double _gestureTravel = 0;

  /// True once the gesture has clearly become a drag or a pinch.
  bool get gestureWasDrag => _gestureTravel > tapSlop;

  /// Starts measuring a fresh gesture. Called from the touch handlers as well
  /// as [onScaleStart], because a tap that never moves may not open a scale
  /// gesture at all -- and then the previous drag's distance would still be
  /// sitting here and would swallow the tap.
  void beginGesture() {
    _gestureTravel = 0;
  }

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

    // The map ships without her. She is drawn here, at the spot chosen for
    // this attempt, which is what lets a replay be a fresh search.
    final findoImage = await images.load(targetSprite);
    final placed = ItemTargetComponent(
      target: target,
      sprite: Sprite(findoImage),
      alpha: await findoImage.toByteData(format: ui.ImageByteFormat.rawRgba),
      tint: level.tint,
    );
    _target = placed;
    world.add(placed);

    _applyViewport();
    _viewportDirty = false;
    camera.viewfinder.zoom = _minZoom;
    camera.viewfinder.position = mapSize / 2;
    // Bounds last: they are derived from the zoom, and the two lines above are
    // what set it.
    _applyCameraBounds();
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
    // canvasSize, not size: on a FlameGame `size` is the camera viewport's
    // size, so once a FixedSizeViewport is installed, measuring from `size`
    // would shrink it against itself on every call. Worse, a FixedSizeViewport
    // does not follow a resize, so after a rotation the stale portrait-shaped
    // viewport stayed on a landscape screen and the map filled less than half
    // of it.
    final canvas = canvasSize;
    // Never give away more than a third of the screen, however tall the HUD
    // reports itself to be.
    final height = math.max(canvas.y - _hudBottomInset, canvas.y * 0.66);
    final viewport = camera.viewport;
    if (viewport is FixedSizeViewport) {
      viewport.size = Vector2(canvas.x, height);
    } else {
      camera.viewport = FixedSizeViewport(canvas.x, height)
        ..position = Vector2.zero()
        ..anchor = Anchor.topLeft;
    }
    _applyZoomLimits();
    // Clamp the zoom before the bounds, which are computed from it.
    camera.viewfinder.zoom = camera.viewfinder.zoom.clamp(_minZoom, _maxZoom);
    _applyCameraBounds();
  }

  /// Restricts the camera so the map always fills the view.
  ///
  /// The bounds are worked out here rather than by handing Flame the map
  /// rectangle with `considerViewport: true`. That option shrinks the
  /// rectangle by half the visible world, but it measured that world at a zoom
  /// of 1 while the game runs nearer 0.45 -- an area two and a half times too
  /// small, so the camera was allowed roughly 500 world units below the map
  /// and the player dragged straight off the bottom of the artwork into the
  /// background. Doing the arithmetic here ties the bounds to the zoom
  /// actually in force, and it has to run again whenever that zoom changes.
  void _applyCameraBounds() {
    final zoom = camera.viewfinder.zoom;
    if (zoom <= 0) {
      return;
    }
    // Half the world the viewport covers: the closest the camera's centre may
    // sit to an edge before empty space appears beyond it.
    final half = camera.viewport.size / (2 * zoom);
    final centre = mapSize / 2;
    // math.min/max keep the rectangle valid when the view is larger than the
    // map on an axis; the range then collapses to the centre, which is the
    // right answer -- there is nowhere to pan to.
    camera.setBounds(
      Rectangle.fromLTRB(
        math.min(half.x, centre.x),
        math.min(half.y, centre.y),
        math.max(mapSize.x - half.x, centre.x),
        math.max(mapSize.y - half.y, centre.y),
      ),
      considerViewport: false,
    );
  }

  /// The map must always cover the viewport, otherwise the clamped bounds
  /// would fight the camera and the artwork would jitter at the edges.
  ///
  /// The ratio alone makes the map cover the viewport *exactly*, and that
  /// equality is the bug: the visible world then measures a hair over 2048 on
  /// the tight axis, the allowed range for the camera centre inverts, and the
  /// clamp stops holding -- the player drags past the bottom edge of the
  /// artwork and sees the empty background behind it. [_coverMargin] keeps the
  /// map strictly larger than the view so the range always has room in it.
  static const _coverMargin = 1.003;

  void _applyZoomLimits() {
    final viewportSize = camera.viewport.size;
    if (viewportSize.x <= 0 || viewportSize.y <= 0) {
      return;
    }
    _minZoom =
        math.max(viewportSize.x / mapSize.x, viewportSize.y / mapSize.y) *
            _coverMargin;
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
    beginGesture();
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    final delta = info.raw.focalPointDelta;
    _gestureTravel += delta.distance;

    final pointers = info.raw.pointerCount;
    if (pointers >= 2) {
      // A second finger is never a tap, whatever the fingers then do.
      _gestureTravel = double.infinity;
      camera.viewfinder.zoom =
          (_zoomAtScaleStart * info.raw.scale).clamp(_minZoom, _maxZoom);
      // The allowed area is derived from the zoom, so it moves with it.
      _applyCameraBounds();
      return;
    }
    // One finger drags the map: screen delta divided by zoom is world delta.
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
    _showFloatingScore(Vector2(target.centerX, target.y), awarded);

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
    final hidden = _target;
    if (hidden == null || hidden.isFound) {
      return;
    }
    audioManager.play(GameSound.hint);
    camera.viewfinder.add(
      MoveToEffect(
        _insideBounds(Vector2(target.centerX, target.centerY)),
        EffectController(duration: 0.45, curve: Curves.easeOutCubic),
      ),
    );
    hidden.highlight(seconds: hintDurationSeconds);
  }

  /// The nearest camera centre to [point] that still keeps the map covering
  /// the whole viewport.
  ///
  /// `setBounds` already clamps dragging, but it does that through a behaviour
  /// on the viewfinder, and a MoveToEffect on the same viewfinder writes the
  /// position straight afterwards -- so a hint aimed near an edge dragged the
  /// camera off the map and left black bands down the side and along the
  /// bottom. Clamping the destination before asking for it does not depend on
  /// which of the two runs last.
  Vector2 _insideBounds(Vector2 point) {
    final visible = camera.viewport.size / camera.viewfinder.zoom;
    double axis(double value, double half, double extent) {
      // When the map is narrower than the view there is only one legal centre.
      if (half * 2 >= extent) {
        return extent / 2;
      }
      return value.clamp(half, extent - half);
    }

    return Vector2(
      axis(point.x, visible.x / 2, mapSize.x),
      axis(point.y, visible.y / 2, mapSize.y),
    );
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
