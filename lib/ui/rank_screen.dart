import 'dart:math';

import 'package:flutter/material.dart';

import '../managers/localization_manager.dart';
import '../models/rank.dart';
import '../theme.dart';

/// The promotion ceremony.
///
/// The game is about finding one thing in a crowd, and the magnifier is its
/// mark, so the rank is not handed over on a trophy -- it is *found*. A crowd
/// of silhouettes fills the panel, the glass sweeps across it, and the title
/// resolves under the lens as it passes. The player watches themselves being
/// spotted, which is the same verb the game is built on.
class RankScreen extends StatefulWidget {
  const RankScreen({super.key, required this.rank, required this.onDone});

  static const overlayId = 'rank';

  final Rank rank;
  final VoidCallback onDone;

  @override
  State<RankScreen> createState() => _RankScreenState();
}

class _RankScreenState extends State<RankScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  /// The glass crosses the panel, then settles in the middle.
  late final Animation<double> _sweep = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.05, 0.55, curve: Curves.easeInOutCubic),
  );

  /// The title fades up behind the glass once it has passed over it.
  late final Animation<double> _reveal = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.42, 0.68, curve: Curves.easeOut),
  );

  /// The burst fires at the moment the glass lands.
  late final Animation<double> _burst = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.5, 0.95, curve: Curves.easeOutCubic),
  );

  /// Everything below the badge arrives last, so the eye is not split.
  late final Animation<double> _tail = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.66, 1.0, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Reduced motion is an accessibility setting, not a difficulty one: the
    // ceremony is decoration, so it is shown already finished rather than
    // played out.
    final still = MediaQuery.disableAnimationsOf(context);
    if (still) {
      _controller.value = 1;
    }

    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: _tail.value,
                      child: Text(
                        l10n.t('rank.promoted').toUpperCase(),
                        // Tracked capitals are a Latin convention. Spaced out,
                        // Hebrew letters stop reading as words.
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: Directionality.of(context) ==
                                  TextDirection.rtl
                              ? 0
                              : 2.4,
                          fontWeight: FontWeight.w700,
                          color: FindoColors.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _Lens(
                      sweep: _sweep.value,
                      reveal: _reveal.value,
                      burst: _burst.value,
                      rank: widget.rank,
                      title: l10n.t(widget.rank.nameKey),
                    ),
                    const SizedBox(height: 18),
                    Opacity(
                      opacity: _tail.value,
                      child: Column(
                        children: [
                          Text(
                            l10n.t('rank.levels', params: {
                              'from': widget.rank.firstLevel,
                              'to': widget.rank.lastLevel,
                            }),
                            style: const TextStyle(
                              fontSize: 13,
                              color: FindoColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.t(widget.rank.blurbKey),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.55,
                              color: FindoColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: widget.onDone,
                              child: Text(l10n.t('rank.continue')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows the ceremony outside a level, for a rank earned earlier. The home
/// screen replays it on a tap: after the moment has passed, that is the only
/// place the rank's description can still be read.
Future<void> showRankCeremony(BuildContext context, Rank rank) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    // The ceremony's own scrim is tuned for a busy map behind it. Over the home
    // screen the yellow Play button showed through the blurb, and a darker
    // translucent barrier only faded it, so outside a level nothing shows.
    barrierColor: FindoColors.background,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogContext, animation, secondaryAnimation) => RankScreen(
      rank: rank,
      onDone: () => Navigator.of(dialogContext).pop(),
    ),
  );
}

/// The panel the ceremony happens in: a crowd, a glass that crosses it, and
/// the title coming into focus underneath.
class _Lens extends StatelessWidget {
  const _Lens({
    required this.sweep,
    required this.reveal,
    required this.burst,
    required this.rank,
    required this.title,
  });

  final double sweep;
  final double reveal;
  final double burst;
  final Rank rank;
  final String title;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.5,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(FindoMetrics.radiusPanel),
        child: ColoredBox(
          color: FindoColors.surface,
          child: CustomPaint(
            painter: _LensPainter(
              sweep: sweep,
              reveal: reveal,
              burst: burst,
              number: rank.number,
              title: title,
              direction: Directionality.of(context),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _LensPainter extends CustomPainter {
  _LensPainter({
    required this.sweep,
    required this.reveal,
    required this.burst,
    required this.number,
    required this.title,
    required this.direction,
  });

  final double sweep;
  final double reveal;
  final double burst;
  final int number;
  final String title;
  final TextDirection direction;

  /// Fixed seed: the crowd is scenery, and scenery that reshuffles on every
  /// rebuild reads as noise rather than as a place.
  static final _random = Random(31);
  static final List<Offset> _crowd = List.generate(
    95,
    (i) => Offset(_random.nextDouble(), _random.nextDouble()),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;

    // --- the crowd, drawn as figures too small to tell apart ---------------
    paint.color = FindoColors.surfaceRaised;
    for (final spot in _crowd) {
      final x = spot.dx * size.width;
      final y = 18 + spot.dy * (size.height - 36);
      // A head clear of a rounded body reads as a person. The first draft
      // fused the two into one thin stroke, and 150 of those read as rain.
      final h = size.height * 0.062;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - h * 0.26, y, h * 0.52, h * 0.78),
          Radius.circular(h * 0.26),
        ),
        paint,
      );
      canvas.drawCircle(Offset(x, y - h * 0.30), h * 0.21, paint);
    }

    // --- where the glass is -------------------------------------------------
    final radius = size.height * 0.30;
    final travel = size.width * 0.62;
    final centre = Offset(
      size.width / 2 + (direction == TextDirection.rtl ? 1 : -1) *
          travel * (1 - sweep) / 2 * 2,
      size.height / 2,
    );

    // --- the title, only where the lens has been ---------------------------
    // The title has to sit inside the glass, not collide with its rim. Names
    // run from three letters to two words, so the size is fitted rather than
    // fixed: start large and step down until it clears the ring.
    final fits = radius * 2 * 0.80;
    var fontSize = size.height * 0.20;
    late TextPainter painter;
    while (true) {
      painter = TextPainter(
        text: TextSpan(
          text: title,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            color: FindoColors.textPrimary.withValues(alpha: reveal),
          ),
        ),
        textDirection: direction,
        textAlign: TextAlign.center,
        maxLines: 1,
      )..layout();
      if (painter.width <= fits || fontSize <= 12) {
        break;
      }
      fontSize *= 0.92;
    }
    painter.paint(
      canvas,
      Offset(centre.dx - painter.width / 2, centre.dy - painter.height / 2),
    );

    // --- the burst, thrown from the lens -----------------------------------
    if (burst > 0) {
      final spokes = 14;
      for (var i = 0; i < spokes; i++) {
        final angle = i / spokes * pi * 2 + 0.2;
        final reach = radius * (1.05 + burst * 1.15);
        final fade = (1 - burst).clamp(0.0, 1.0);
        paint.color = FindoColors.primary.withValues(alpha: fade * 0.8);
        final dot = centre + Offset(cos(angle), sin(angle)) * reach;
        canvas.drawCircle(dot, 3.4 * fade + 1, paint);
      }
    }

    // --- the glass itself ---------------------------------------------------
    paint.color = const Color(0x24A8D6F0);
    canvas.drawCircle(centre, radius, paint);

    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.13
      ..color = FindoColors.primary;
    canvas.drawCircle(centre, radius, paint);

    paint
      ..strokeWidth = radius * 0.16
      ..strokeCap = StrokeCap.round
      ..color = FindoColors.primaryDeep;
    final grip = centre + Offset(radius * 0.72, radius * 0.72);
    canvas.drawLine(grip, grip + Offset(radius * 0.62, radius * 0.62), paint);

    paint
      ..strokeWidth = radius * 0.07
      ..color = Colors.white.withValues(alpha: 0.75);
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius * 0.63),
      pi * 1.12,
      pi * 0.45,
      false,
      paint,
    );
    paint.style = PaintingStyle.fill;

    // --- the rank number, riding on the rim --------------------------------
    final badge = TextPainter(
      text: TextSpan(
        text: '$number',
        style: TextStyle(
          fontSize: radius * 0.42,
          fontWeight: FontWeight.w900,
          color: FindoColors.background.withValues(alpha: reveal),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final badgeCentre = centre + Offset(0, -radius);
    paint.color = FindoColors.primary.withValues(alpha: reveal);
    canvas.drawCircle(badgeCentre, radius * 0.30, paint);
    badge.paint(canvas,
        badgeCentre - Offset(badge.width / 2, badge.height / 2));
  }

  @override
  bool shouldRepaint(_LensPainter old) =>
      old.sweep != sweep ||
      old.reveal != reveal ||
      old.burst != burst ||
      old.title != title;
}
