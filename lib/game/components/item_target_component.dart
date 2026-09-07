import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../../models/level_definition.dart';
import '../findo_game.dart';

/// Findo herself, standing wherever the level metadata says she is hiding.
///
/// There is exactly one of these per map. Hit testing samples the character's
/// own alpha channel rather than her bounding box, so tapping the gap between
/// an arm and the skirt counts as a miss the way a player would expect -- but
/// with a small tolerance, because a finger is not a mouse pointer.
class ItemTargetComponent extends SpriteComponent
    with TapCallbacks, HasGameReference<FindoGame> {
  ItemTargetComponent({
    required this.target,
    required Sprite sprite,
    required this.alpha,
  }) : super(
          sprite: sprite,
          size: Vector2(target.width, target.height),
          position: Vector2(target.x, target.y),
          anchor: Anchor.topLeft,
          priority: 10,
        ) {
    // The character is drawn far below her source resolution at low zoom and
    // far above it at high zoom; both want smoothing.
    paint
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true;
  }

  /// A tap this far outside an opaque pixel, as a fraction of the sprite's
  /// width, still counts. Roughly a finger's worth of slack.
  static const _touchSlack = 0.18;

  final LevelTarget target;
  /// Raw RGBA of the sprite, used for the hit test.
  final ByteData? alpha;

  bool _found = false;
  _FoundBurst? _burst;
  _HintHalo? _halo;

  bool get isFound => _found;

  @override
  bool containsLocalPoint(Vector2 point) {
    if (!super.containsLocalPoint(point)) {
      return false;
    }
    final pixels = alpha;
    final image = sprite?.image;
    if (pixels == null || image == null) {
      return true;
    }

    final u = point.x / size.x;
    final v = point.y / size.y;
    final slackX = math.max(1, (image.width * _touchSlack).round());
    final slackY = math.max(1, (image.height * _touchSlack).round());
    final cx = (u * image.width).round();
    final cy = (v * image.height).round();

    // Nine samples: the point itself plus a ring at the slack radius. Enough
    // to forgive a near miss without turning the test back into a rectangle.
    for (final dx in [0, -slackX, slackX]) {
      for (final dy in [0, -slackY, slackY]) {
        if (_isOpaque(image, pixels, cx + dx, cy + dy)) {
          return true;
        }
      }
    }
    return false;
  }

  bool _isOpaque(ui.Image image, ByteData pixels, int x, int y) {
    if (x < 0 || y < 0 || x >= image.width || y >= image.height) {
      return false;
    }
    final offset = (y * image.width + x) * 4 + 3;
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

  /// Rings Findo and gives her a little jump, so the moment of finding her
  /// reads clearly before the win panel appears.
  void celebrate() {
    if (_found) {
      return;
    }
    _found = true;
    _clearHalo();
    _burst = _FoundBurst(radius: math.max(size.x, size.y) * 1.1);
    add(_burst!);
    add(
      ColorEffect(
        Colors.white,
        EffectController(duration: 0.14, reverseDuration: 0.14),
        opacityTo: 0.75,
      ),
    );
    add(
      ScaleEffect.to(
        Vector2.all(1.22),
        EffectController(duration: 0.20, reverseDuration: 0.22, repeatCount: 2),
      ),
    );
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
    add(
      ScaleEffect.to(
        Vector2.all(1.15),
        EffectController(
          duration: 0.45,
          reverseDuration: 0.45,
          repeatCount: math.max(1, (seconds / 0.9).round()),
        ),
      ),
    );
  }

  void _clearHalo() {
    _halo?.removeFromParent();
    _halo = null;
  }
}

/// The expanding ring drawn the instant Findo is found.
class _FoundBurst extends PositionComponent {
  _FoundBurst({required this.radius}) : super(priority: -1);

  static const _duration = 0.75;

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
    final t = (_elapsed / _duration).clamp(0.0, 1.0);
    final fade = 1.0 - t;
    canvas.drawCircle(
      center,
      radius * (0.35 + 1.05 * t),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0 * fade + 1.5
        ..color = const Color(0xFF4ADE80).withValues(alpha: 0.85 * fade),
    );
  }
}

/// The pulsing ring drawn while a hint is active.
class _HintHalo extends PositionComponent {
  _HintHalo({required this.radius, required this.lifetime}) : super(priority: -1);

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
