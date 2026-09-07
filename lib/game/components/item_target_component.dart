import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../../models/level_definition.dart';
import '../findo_game.dart';

/// Findo, drawn onto the map at the spot chosen for this attempt.
///
/// The map itself ships without her. Compositing her here rather than baking
/// her into the artwork is what lets a level hide her somewhere else on a
/// replay, which matters because the star rating is earned by playing a level
/// again and beating your time.
///
/// Hit testing samples her alpha channel rather than her bounding box, so
/// tapping the gap between an arm and the skirt counts as a miss the way a
/// player would expect -- with a finger's worth of tolerance, because a finger
/// is not a mouse pointer.
class ItemTargetComponent extends SpriteComponent
    with TapCallbacks, HasGameReference<FindoGame> {
  ItemTargetComponent({
    required this.target,
    required Sprite sprite,
    required this.alpha,
    Color? tint,
  })  : silhouette = sprite.image,
        super(
          sprite: sprite,
          size: Vector2(target.width, target.height),
          position: Vector2(target.x, target.y),
          anchor: Anchor.topLeft,
          priority: 10,
        ) {
    // She is drawn far below her source resolution at low zoom and far above
    // it at full magnification; both want smoothing.
    paint
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true;
    if (tint != null) {
      // Multiplied, so a dusk map dims her instead of recolouring her: a
      // daylit figure in a night scene is the brightest thing on the map and
      // gives itself away.
      paint.colorFilter = ColorFilter.mode(tint, BlendMode.modulate);
    }
  }

  /// A tap this far outside an opaque pixel, as a fraction of the character
  /// sheet's size, still counts. Roughly a finger's worth of slack.
  static const _touchSlack = 0.18;

  final LevelTarget target;

  /// Her source image, used for the shape of the hit test.
  final ui.Image silhouette;

  /// Raw RGBA of [silhouette]. Null falls back to the whole box being tappable.
  final ByteData? alpha;

  bool _found = false;
  _HintHalo? _halo;

  bool get isFound => _found;

  @override
  bool containsLocalPoint(Vector2 point) {
    if (!super.containsLocalPoint(point)) {
      return false;
    }
    final pixels = alpha;
    if (pixels == null) {
      return true;
    }

    final slackX = math.max(1, (silhouette.width * _touchSlack).round());
    final slackY = math.max(1, (silhouette.height * _touchSlack).round());
    final cx = (point.x / size.x * silhouette.width).round();
    final cy = (point.y / size.y * silhouette.height).round();

    // Nine samples: the point itself plus a ring at the slack radius. Enough
    // to forgive a near miss without turning the test back into a rectangle.
    for (final dx in [0, -slackX, slackX]) {
      for (final dy in [0, -slackY, slackY]) {
        if (_isOpaque(pixels, cx + dx, cy + dy)) {
          return true;
        }
      }
    }
    return false;
  }

  bool _isOpaque(ByteData pixels, int x, int y) {
    if (x < 0 || y < 0 || x >= silhouette.width || y >= silhouette.height) {
      return false;
    }
    final offset = (y * silhouette.width + x) * 4 + 3;
    if (offset >= pixels.lengthInBytes) {
      return false;
    }
    return pixels.getUint8(offset) > 32;
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (_found) {
      return;
    }
    if (game.registerFind()) {
      celebrate();
    }
  }

  /// Rings Findo where she stands, so the moment of finding her reads clearly
  /// before the win panel appears.
  void celebrate() {
    if (_found) {
      return;
    }
    _found = true;
    _clearHalo();
    add(_FoundBurst(radius: math.max(size.x, size.y) * 1.1));
  }

  /// Pulses a ring around Findo, used by the hint system.
  void highlight({double seconds = 3.0}) {
    if (_found) {
      return;
    }
    _clearHalo();
    final halo = _HintHalo(
      radius: math.max(size.x, size.y) * 0.85,
      lifetime: seconds,
    );
    _halo = halo;
    add(halo);
  }

  void _clearHalo() {
    _halo?.removeFromParent();
    _halo = null;
  }
}

/// The expanding ring drawn the instant Findo is found.
class _FoundBurst extends PositionComponent {
  _FoundBurst({required this.radius});

  static const _duration = 0.9;

  final double radius;
  double _elapsed = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= _duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final parentSize = (parent as PositionComponent).size;
    final center = Offset(parentSize.x / 2, parentSize.y / 2);
    // Two rings chasing each other outwards, so the eye is pulled to the spot.
    for (final phase in const [0.0, 0.28]) {
      final t = ((_elapsed / _duration) - phase).clamp(0.0, 1.0);
      if (t <= 0) {
        continue;
      }
      final fade = 1.0 - t;
      canvas.drawCircle(
        center,
        radius * (0.30 + 1.15 * t),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7.0 * fade + 1.5
          ..color = const Color(0xFF4ADE80).withValues(alpha: 0.9 * fade),
      );
    }
  }
}

/// The pulsing ring drawn while a hint is active.
class _HintHalo extends PositionComponent {
  _HintHalo({required this.radius, required this.lifetime});

  final double radius;
  final double lifetime;

  double _elapsed = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= lifetime) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final parentSize = (parent as PositionComponent).size;
    final center = Offset(parentSize.x / 2, parentSize.y / 2);
    // Two rings a half-cycle apart read as an outward pulse.
    for (final phase in const [0.0, 0.5]) {
      final t = ((_elapsed / 0.9) + phase) % 1.0;
      final fade = (1.0 - t).clamp(0.0, 1.0);
      canvas.drawCircle(
        center,
        radius * (0.55 + 0.55 * t),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.0 * fade + 1.5
          ..color = const Color(0xFFFFD34E).withValues(alpha: 0.75 * fade),
      );
    }
  }
}
