import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../../models/level_definition.dart';
import '../findo_game.dart';

/// One collectable on the map: it knows whether it has been found, plays the
/// celebration when it is, and can glow on demand for the hint system.
class ItemTargetComponent extends SpriteComponent
    with TapCallbacks, HasGameReference<FindoGame> {
  ItemTargetComponent({
    required this.item,
    required Sprite sprite,
  }) : super(
          sprite: sprite,
          size: Vector2.all(item.size),
          position: Vector2(item.x, item.y),
          angle: item.angle,
          anchor: Anchor.center,
          priority: 10,
        );

  final LevelItem item;

  bool _found = false;
  _HintHalo? _halo;

  bool get isFound => _found;

  @override
  void onTapDown(TapDownEvent event) {
    if (_found) {
      return;
    }
    if (game.registerFind(item)) {
      collect();
    }
  }

  /// Plays the found animation and then leaves the tree.
  void collect() {
    if (_found) {
      return;
    }
    _found = true;
    _clearHalo();
    add(
      ColorEffect(
        Colors.white,
        EffectController(duration: 0.12, reverseDuration: 0.12),
        opacityTo: 0.85,
      ),
    );
    add(
      ScaleEffect.to(
        Vector2.all(1.45),
        EffectController(duration: 0.22, reverseDuration: 0.18),
      ),
    );
    add(OpacityEffect.fadeOut(EffectController(startDelay: 0.32, duration: 0.22)));
    add(RemoveEffect(delay: 0.58));
  }

  /// Pulses a ring around the item so the player can spot it, used by hints.
  void highlight({double seconds = 3.0}) {
    if (_found) {
      return;
    }
    _clearHalo();
    final halo = _HintHalo(radius: size.x * 0.85, lifetime: seconds);
    _halo = halo;
    add(halo);
    add(
      ScaleEffect.to(
        Vector2.all(1.18),
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

/// The pulsing ring drawn behind a hinted item.
class _HintHalo extends PositionComponent {
  _HintHalo({required this.radius, required this.lifetime})
      : super(priority: -1);

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
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0 * fade + 1.5
        ..color = const Color(0xFFFFD34E).withValues(alpha: 0.75 * fade);
      canvas.drawCircle(center, radius * (0.55 + 0.55 * t), paint);
    }
  }
}
