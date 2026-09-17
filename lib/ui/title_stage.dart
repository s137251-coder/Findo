import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// The moving backdrop behind the title: a crowd too dim to search, a lens
/// wandering over it, and dust hanging in the light.
///
/// It is one of the game's own maps rather than an abstract pattern, because
/// the first thing a title screen has to say is what the game is -- a picture
/// packed with people, and something to find in it. The map is drawn twice,
/// dim and bright, from a single decode: the bright copy is masked to a circle
/// that drifts, which is the magnifier passing over the crowd.
class TitleStage extends StatefulWidget {
  const TitleStage({super.key, required this.child});

  /// The title, the buttons -- everything that sits over the backdrop.
  final Widget child;

  /// The map the title screen searches. A daylight crowd with colour in it,
  /// so the lens has something to find as it goes by.
  static const backdrop = 'assets/images/maps/level_43.webp';

  @override
  State<TitleStage> createState() => _TitleStageState();
}

class _TitleStageState extends State<TitleStage>
    with SingleTickerProviderStateMixin {
  /// One slow cycle drives everything: the drift of the map, the path of the
  /// lens and the dust. Long enough that nothing on screen visibly repeats
  /// while a player is deciding whether to press Play.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 48),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reduced motion is an accessibility setting: the backdrop holds still,
    // parked at a point in the cycle where the lens is off centre and the
    // composition still reads.
    final still = MediaQuery.disableAnimationsOf(context);
    if (still && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0.18;
    }

    final media = MediaQuery.of(context);
    // Decoded at the width it is drawn, not at the map's own 1254 to 2048px.
    final decodeWidth = (media.size.width * media.devicePixelRatio).round();
    final map = Image.asset(
      TitleStage.backdrop,
      fit: BoxFit.cover,
      cacheWidth: decodeWidth,
      // A title screen that flashes its own background in is worse than one
      // that simply has it.
      gaplessPlayback: true,
    );

    return ColoredBox(
      color: FindoColors.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => _Backdrop(t: _controller.value, map: map),
          ),
          widget.child,
        ],
      ),
    );
  }
}

/// Everything that moves, rebuilt each frame; the title above it is not.
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.t, required this.map});

  /// 0 to 1, one pass of the cycle.
  final double t;
  final Widget map;

  /// How far the lens wanders from the middle, as a fraction of the screen.
  static const _lensTravelX = 0.30;
  static const _lensTravelY = 0.22;

  @override
  Widget build(BuildContext context) {
    final angle = t * pi * 2;
    // A drift with two periods that do not divide into each other, so the map
    // never appears to return to where it started.
    final driftX = sin(angle) * 0.035 + sin(angle * 0.37) * 0.02;
    final driftY = cos(angle * 0.61) * 0.03;
    // The lens travels a Lissajous path: it crosses the crowd, turns, and
    // comes back across a different part of it.
    final lens = Alignment(
      sin(angle * 0.83) * _lensTravelX * 2,
      sin(angle * 1.27 + 1.1) * _lensTravelY * 2,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // --- the crowd, dim ---------------------------------------------
        Transform.scale(
          scale: 1.22,
          child: Transform.translate(
            offset: Offset(driftX * 120, driftY * 120),
            child: Opacity(opacity: 0.62, child: map),
          ),
        ),
        // --- the same crowd, lit, only where the lens is ------------------
        ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => RadialGradient(
            center: lens,
            radius: 0.30,
            colors: const [
              Colors.white,
              Color(0x66FFFFFF),
              Colors.transparent,
            ],
            stops: const [0.0, 0.72, 1.0],
          ).createShader(rect),
          child: Transform.scale(
            scale: 1.22,
            child: Transform.translate(
              offset: Offset(driftX * 120, driftY * 120),
              child: Opacity(opacity: 0.92, child: map),
            ),
          ),
        ),
        // --- the rim of the glass, and the dust in its light --------------
        CustomPaint(painter: _LensAndDust(t: t, lens: lens)),
        // --- the scrim the title reads against ----------------------------
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                // Dark enough at the top and bottom for the name and the
                // buttons to read, and thin in the middle so the crowd shows.
                Color(0xB3141824),
                Color(0x59141824),
                Color(0xCC141824),
              ],
              stops: [0.0, 0.42, 1.0],
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 0.95,
              colors: [Colors.transparent, Color(0x80080A12)],
              stops: [0.55, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

/// The ring of the magnifier, and slow motes lit by it.
class _LensAndDust extends CustomPainter {
  _LensAndDust({required this.t, required this.lens});

  final double t;
  final Alignment lens;

  /// Fixed seed: dust is scenery, and scenery that reshuffles reads as noise.
  static final _random = Random(19);
  static final List<Offset> _motes =
      List.generate(22, (_) => Offset(_random.nextDouble(), _random.nextDouble()));
  static final List<double> _speeds =
      List.generate(22, (_) => 0.35 + _random.nextDouble() * 0.9);

  @override
  void paint(Canvas canvas, Size size) {
    final centre = lens.alongSize(size);
    final radius = size.shortestSide * 0.30;

    // The rim: two hairlines, so the glass has an edge without a hard cut.
    final rim = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = FindoColors.primary.withValues(alpha: 0.28);
    canvas.drawCircle(centre, radius, rim);
    rim
      ..strokeWidth = 5
      ..color = FindoColors.primary.withValues(alpha: 0.07);
    canvas.drawCircle(centre, radius + 3, rim);

    // Dust, brighter the closer it drifts to the light.
    final speck = Paint()..isAntiAlias = true;
    for (var i = 0; i < _motes.length; i++) {
      final mote = _motes[i];
      final y = (mote.dy - t * _speeds[i]) % 1.0;
      final point = Offset(
        (mote.dx + sin((t * _speeds[i] + mote.dx) * pi * 2) * 0.02) * size.width,
        y * size.height,
      );
      final lit = 1 - ((point - centre).distance / (radius * 2.2)).clamp(0.0, 1.0);
      speck.color = FindoColors.primary
          .withValues(alpha: 0.05 + 0.30 * lit * lit);
      canvas.drawCircle(point, 1.4 + 2.2 * lit, speck);
    }
  }

  @override
  bool shouldRepaint(_LensAndDust old) => old.t != t;
}
