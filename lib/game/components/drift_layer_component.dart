import 'dart:math';
import 'dart:ui' as ui;

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
  final Paint _paint = Paint()
    ..isAntiAlias = true
    ..filterQuality = FilterQuality.medium;

  /// The one particle of this kind, drawn once and then stamped for every
  /// particle in the field in a single call.
  ///
  /// The first version drew each particle itself, with a fill and a rim: at the
  /// top of the difficulty curve that is over five hundred draw calls a frame,
  /// which is a large part of what made the late levels stutter on a phone.
  /// The shape never changes from one particle to the next -- only where it is,
  /// how big, how turned and what colour -- and that is exactly what a single
  /// `drawAtlas` call takes.
  ui.Image? _sprite;

  /// One stamp per kind for the whole session, because a level is thrown away
  /// and rebuilt every time the player moves on, and Flame does not run
  /// `onRemove` on the components of a game it replaces -- an image made per
  /// level would be an image leaked per level.
  static final Map<DriftKind, ui.Image> _sprites = {};

  /// The radius the stamp is drawn at, so a particle's own radius becomes a
  /// scale factor.
  static const _spriteRadius = 32.0;

  /// Particles carry a dark rim. Without it white snow over a white ski slope
  /// is invisible, which is the one scene where snow is the obvious choice --
  /// the drift has to read on whatever the artwork happens to be.
  static const _rimColour = Color(0x40101820);

  /// How many particles this layer carries.
  @visibleForTesting
  int get particleCount => _particles.length;

  /// Whether the stamp is ready; until it is, the layer draws nothing.
  @visibleForTesting
  bool get spriteReady => _sprite != null;

  @override
  Future<void> onLoad() async {
    final count = (maxParticles * intensity).round();
    for (var i = 0; i < count; i++) {
      _particles.add(_spawn(anywhere: true));
    }
    _sprite = _sprites[kind] ??= await _drawSprite();
  }

  /// Draws this kind's particle -- a circle, a flake or a streak -- in white
  /// with its rim, so that a per-particle colour can be multiplied over it at
  /// draw time and the rim stays dark.
  Future<ui.Image> _drawSprite() async {
    const r = _spriteRadius;
    final stroke = r * 0.35;
    final (double width, double height) = switch (kind) {
      DriftKind.rain => (r * 0.6 + stroke * 2, r * 7 + stroke * 2),
      _ when kind.spin > 0 => (r * 2 + stroke * 2, r * 1.1 + stroke * 2),
      _ => (r * 2 + stroke * 2, r * 2 + stroke * 2),
    };
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final fill = Paint()
      ..isAntiAlias = true
      ..color = const Color(0xFFFFFFFF);
    final rim = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = _rimColour;
    final centre = Offset(width / 2, height / 2);
    if (kind == DriftKind.rain || kind.spin > 0) {
      final shape = Rect.fromCenter(
        center: centre,
        width: width - stroke * 2,
        height: height - stroke * 2,
      );
      canvas
        ..drawRect(shape, fill)
        ..drawRect(shape, rim);
    } else {
      canvas
        ..drawCircle(centre, r, fill)
        ..drawCircle(centre, r, rim);
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(width.ceil(), height.ceil());
    picture.dispose();
    return image;
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
    final sprite = _sprite;
    if (sprite == null) {
      return;
    }
    // Only what the camera can see. The field is spread over the whole 2048
    // square, but a player pinched in is looking at a fraction of it, and
    // every particle outside that fraction still costs work every frame. The
    // clip Flame sets for the viewport says which fraction; a canvas without
    // one reports a huge rectangle, which culls nothing -- the right answer
    // when the whole map is on screen.
    final visible = canvas.getLocalClipBounds().inflate(kind.radius * 8);
    final src = Rect.fromLTWH(
      0,
      0,
      sprite.width.toDouble(),
      sprite.height.toDouble(),
    );
    final transforms = <RSTransform>[];
    final rects = <Rect>[];
    final colours = <Color>[];
    for (final particle in _particles) {
      final drift = sin(particle.phase) * kind.sway;
      final x = particle.position.x + drift;
      if (x < visible.left ||
          x > visible.right ||
          particle.position.y < visible.top ||
          particle.position.y > visible.bottom) {
        continue;
      }
      transforms.add(
        RSTransform.fromComponents(
          rotation: kind.spin > 0 ? particle.angle : 0,
          scale: kind.radius * particle.scale / _spriteRadius,
          anchorX: src.width / 2,
          anchorY: src.height / 2,
          translateX: x,
          translateY: particle.position.y,
        ),
      );
      rects.add(src);
      // Fading with the sway keeps the layer from reading as a flat stencil.
      colours.add(
        kind.colour.withValues(
          alpha: 0.30 + 0.25 * (0.5 + 0.5 * sin(particle.phase * 0.7)),
        ),
      );
    }
    if (transforms.isEmpty) {
      return;
    }
    // The whole field in one call. The stamp is white, so multiplying it by
    // each particle's colour gives that particle its colour back and leaves
    // the dark rim dark.
    canvas.drawAtlas(
      sprite,
      transforms,
      rects,
      colours,
      BlendMode.modulate,
      null,
      _paint,
    );
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
