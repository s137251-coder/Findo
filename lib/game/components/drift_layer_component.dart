import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../models/level_definition.dart';

/// What drifts over a scene. Chosen to belong to the place rather than to
/// decorate it -- snow over a ski base, bubbles in an aquarium -- because a
/// player who reads the motion as part of the world keeps searching, and one
/// who reads it as an effect starts ignoring it, which defeats the point.
/// Sizes and speeds below are in MAP units, and the map is 2048 across drawn
/// into a phone at roughly 0.45 zoom -- so a value here reads on screen at
/// under half its size. The first pass used numbers that looked sensible as
/// pixels and produced particles a pixel and a half wide: present in a frame
/// difference, invisible to a player.
enum DriftKind {
  snow(Color(0xFFFFFFFF), fallSpeed: 105, sway: 64, radius: 14, spin: 0),
  bubble(Color(0xFFBFE8FF), fallSpeed: -136, sway: 48, radius: 19, spin: 0),
  confetti(Color(0xFFFFC53D), fallSpeed: 176, sway: 104, radius: 16, spin: 5),
  leaf(Color(0xFFC8A45A), fallSpeed: 120, sway: 120, radius: 17, spin: 3),
  petal(Color(0xFFF2B8D8), fallSpeed: 88, sway: 96, radius: 15, spin: 2),
  ember(Color(0xFFFFB35C), fallSpeed: -72, sway: 56, radius: 12, spin: 0),
  dust(Color(0xFFFFF3D0), fallSpeed: 32, sway: 80, radius: 10, spin: 0),
  rain(Color(0xFFCFE3F5), fallSpeed: 600, sway: 16, radius: 7, spin: 0);

  const DriftKind(
    this.colour, {
    required this.fallSpeed,
    required this.sway,
    required this.radius,
    required this.spin,
  });

  /// Map units a second. Negative rises, which is what bubbles and embers do.
  final double fallSpeed;

  /// How far it wanders sideways, in map units.
  final double sway;

  final double radius;

  /// Radians a second. Zero keeps a shape upright.
  final double spin;

  final Color colour;

  /// The drift that belongs to a scene, by its translation key.
  ///
  /// Anything unlisted gets [dust]: a scene with no obvious weather still
  /// wants its share of difficulty, and motes in the light suit any room.
  static DriftKind forLevel(String nameKey) => switch (nameKey) {
        'level.snow' || 'level.skibase' => snow,
        'level.water' ||
        'level.aquarium' ||
        'level.waterpark' ||
        'level.port' =>
          bubble,
        'level.fair' ||
        'level.festival' ||
        'level.nightfest' ||
        'level.stadium' ||
        'level.marathon' ||
        'level.arcade' =>
          confetti,
        'level.farm' || 'level.farmers' || 'level.nursery' => leaf,
        'level.glasshouse' || 'level.castle' => petal,
        'level.rooftop' || 'level.busdepot' => ember,
        'level.docks' || 'level.beach' => rain,
        _ => dust,
      };
}

/// A drifting overlay that makes a still scene harder to search.
///
/// Drawn in one component rather than one per particle: at the top of the
/// curve there are over a hundred of them, and a hundred Flame components each
/// with their own transform costs far more than a hundred circles in a single
/// canvas pass.
///
/// It sits above the map and below Findo on purpose: a particle drawn over her
/// would make the level unfair rather than hard, and one drawn under the map is
/// not there at all.
class DriftLayerComponent extends PositionComponent {
  DriftLayerComponent({
    required this.kind,
    required this.intensity,
    required Vector2 mapSize,
    int? seed,
  })  : _random = Random(seed ?? 7),
        super(size: mapSize, position: Vector2.zero(), priority: _priority);

  /// Above the map, which sits at 0, and below Findo, who sits at 10. A
  /// negative priority reads as "behind" and is what the first attempt used --
  /// it put the whole layer behind the artwork, where it rendered perfectly
  /// and was never once visible.
  static const _priority = 5;

  /// Most particles a level can carry, at intensity 1.
  ///
  /// They are spread over the whole 2048 square map, not over the screen, so
  /// the count has to be generous before the field reads as weather: twenty
  /// of them across a map that size is a handful of specks.
  static const maxParticles = 260;

  final DriftKind kind;

  /// 0 to 1, straight from the level.
  final double intensity;

  final Random _random;
  final List<_Particle> _particles = [];
  final Paint _paint = Paint()..isAntiAlias = true;

  /// Particles carry a dark rim. Without it white snow over a white ski slope
  /// is invisible, which is the one scene where snow is the obvious choice --
  /// the drift has to read on whatever the artwork happens to be.
  final Paint _rim = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..color = const Color(0x40101820);

  @override
  Future<void> onLoad() async {
    final count = (maxParticles * intensity).round();
    for (var i = 0; i < count; i++) {
      _particles.add(_spawn(anywhere: true));
    }
  }

  _Particle _spawn({bool anywhere = false}) {
    // A new particle enters from the edge it drifts away from, so the layer
    // never visibly restarts; on the first fill they start scattered instead.
    final rising = kind.fallSpeed < 0;
    final y = anywhere
        ? _random.nextDouble() * size.y
        : (rising ? size.y + kind.radius * 4 : -kind.radius * 4);
    return _Particle(
      position: Vector2(_random.nextDouble() * size.x, y),
      phase: _random.nextDouble() * pi * 2,
      // Varying the speed stops the field moving as one sheet, which reads as
      // a filter over the picture rather than as things in it.
      speed: 0.65 + _random.nextDouble() * 0.7,
      scale: 0.7 + _random.nextDouble() * 0.6,
      angle: _random.nextDouble() * pi * 2,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    final rising = kind.fallSpeed < 0;
    for (var i = 0; i < _particles.length; i++) {
      final particle = _particles[i];
      particle.position.y += kind.fallSpeed * particle.speed * dt;
      particle.phase += dt * particle.speed;
      particle.angle += kind.spin * particle.speed * dt;
      final gone = rising
          ? particle.position.y < -kind.radius * 4
          : particle.position.y > size.y + kind.radius * 4;
      if (gone) {
        _particles[i] = _spawn();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    for (final particle in _particles) {
      final drift = sin(particle.phase) * kind.sway;
      final x = particle.position.x + drift;
      final radius = kind.radius * particle.scale;
      // Fading with the sway keeps the layer from reading as a flat stencil.
      _paint.color = kind.colour.withValues(
        alpha: 0.30 + 0.25 * (0.5 + 0.5 * sin(particle.phase * 0.7)),
      );
      _rim.strokeWidth = radius * 0.35;
      if (kind == DriftKind.rain) {
        final streak =
            Rect.fromLTWH(x, particle.position.y, radius * 0.6, radius * 7);
        canvas.drawRect(streak, _paint);
        canvas.drawRect(streak, _rim);
      } else if (kind.spin > 0) {
        canvas.save();
        canvas.translate(x, particle.position.y);
        canvas.rotate(particle.angle);
        final flake = Rect.fromCenter(
          center: Offset.zero,
          width: radius * 2,
          height: radius * 1.1,
        );
        canvas.drawRect(flake, _paint);
        canvas.drawRect(flake, _rim);
        canvas.restore();
      } else {
        final centre = Offset(x, particle.position.y);
        canvas.drawCircle(centre, radius, _paint);
        canvas.drawCircle(centre, radius, _rim);
      }
    }
  }
}

class _Particle {
  _Particle({
    required this.position,
    required this.phase,
    required this.speed,
    required this.scale,
    required this.angle,
  });

  final Vector2 position;
  double phase;
  final double speed;
  final double scale;
  double angle;
}

/// Builds the layer a level asks for, or nothing when it asks for none.
DriftLayerComponent? driftLayerFor(LevelDefinition level, Vector2 mapSize) {
  if (level.motion <= 0) {
    return null;
  }
  return DriftLayerComponent(
    kind: DriftKind.forLevel(level.nameKey),
    intensity: level.motion,
    mapSize: mapSize,
    seed: level.index,
  );
}
