import 'dart:math';

import 'package:flutter/material.dart';

import '../managers/localization_manager.dart';
import '../models/level_definition.dart';
import '../models/rank.dart';
import '../theme.dart';
import 'widgets/common.dart';

/// The end of the hunt: what a player sees after clearing the hundredth level.
///
/// The whole game is one gesture -- find the girl in the crowd -- so the
/// ending is that gesture completed rather than a trophy handed over. The
/// crowd she was hiding in fades up, the glass crosses it one last time, and
/// she walks out of it: full size, in the middle of the screen, looking back
/// at the player for the first time.
///
/// Then it points somewhere. Finishing the levels is not finishing the game --
/// three stars on each is 300, and almost nobody arrives here holding them --
/// so the last thing on the screen is the level closest to its third star.
class FinaleScreen extends StatefulWidget {
  const FinaleScreen({
    super.key,
    required this.stars,
    required this.starsPossible,
    required this.rank,
    required this.mapAsset,
    required this.chaseLevel,
    required this.onChase,
    required this.onLevelList,
  });

  static const overlayId = 'finale';

  /// Stars banked across every level.
  final int stars;

  /// Three for every level in the catalogue.
  final int starsPossible;

  /// The last rank, earned by this clear.
  final Rank rank;

  /// The map of the level just finished, relative to `assets/images/`.
  final String mapAsset;

  /// The level nearest to a third star, or null when there is none left.
  final LevelDefinition? chaseLevel;

  final ValueChanged<LevelDefinition> onChase;
  final VoidCallback onLevelList;

  @override
  State<FinaleScreen> createState() => _FinaleScreenState();
}

class _FinaleScreenState extends State<FinaleScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4600),
  );

  /// The crowd she spent a hundred levels in.
  late final Animation<double> _crowd = _phase(0.0, 0.22);

  /// The glass, crossing it one last time.
  late final Animation<double> _sweep = _phase(0.10, 0.44, Curves.easeInOutCubic);

  /// Findo, stepping out of the lens and growing to full size.
  late final Animation<double> _emerge = _phase(0.42, 0.68);

  late final Animation<double> _title = _phase(0.58, 0.78);
  late final Animation<double> _stats = _phase(0.70, 0.88);
  late final Animation<double> _buttons = _phase(0.82, 1.0);

  Animation<double> _phase(double from, double to, [Curve curve = Curves.easeOut]) {
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(from, to, curve: curve),
    );
  }

  bool get _perfect => widget.stars >= widget.starsPossible;

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

  /// A player who has seen it once, or who would rather read than watch, gets
  /// the finished screen on a tap.
  void _skip() {
    if (_controller.isAnimating) {
      _controller.animateTo(1, duration: const Duration(milliseconds: 280));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    }
    final media = MediaQuery.of(context);
    final decodeWidth = (media.size.width * media.devicePixelRatio).round();

    return GestureDetector(
      onTap: _skip,
      child: Material(
        color: FindoColors.background,
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Emergence(
                      crowd: _crowd.value,
                      sweep: _sweep.value,
                      emerge: _emerge.value,
                      mapAsset: 'assets/images/${widget.mapAsset}',
                      decodeWidth: decodeWidth,
                      gold: _perfect,
                    ),
                    const SizedBox(height: 22),
                    Opacity(
                      opacity: _title.value,
                      child: Column(
                        children: [
                          Text(
                            l10n.t('finale.eyebrow'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: FindoColors.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.t(_perfect ? 'finale.perfectTitle' : 'finale.title'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            l10n.t(_perfect ? 'finale.perfectBody' : 'finale.body'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.55,
                              color: FindoColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Opacity(
                      opacity: _stats.value,
                      child: _Tally(
                        levels: widget.rank.lastLevel,
                        stars: widget.stars,
                        starsPossible: widget.starsPossible,
                        rankName: l10n.t(widget.rank.nameKey),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Opacity(
                      opacity: _buttons.value,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.chaseLevel != null) ...[
                            FilledButton.icon(
                              onPressed: () => widget.onChase(widget.chaseLevel!),
                              icon: const Icon(Icons.star_rounded, size: 22),
                              label: Text(
                                l10n.t('finale.chase', params: {
                                  'index': widget.chaseLevel!.index,
                                  'name': l10n.t(widget.chaseLevel!.nameKey),
                                }),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          TextButton(
                            onPressed: widget.onLevelList,
                            child: Text(l10n.t('finale.menu')),
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

/// The stage: the crowd, the glass crossing it, and Findo walking out.
class _Emergence extends StatelessWidget {
  const _Emergence({
    required this.crowd,
    required this.sweep,
    required this.emerge,
    required this.mapAsset,
    required this.decodeWidth,
    required this.gold,
  });

  final double crowd;
  final double sweep;
  final double emerge;
  final String mapAsset;
  final int decodeWidth;

  /// Set for a player arriving with every star: the light turns gold.
  final bool gold;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.08,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(FindoMetrics.radiusPanel),
        child: ColoredBox(
          color: FindoColors.surface,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final side = constraints.biggest;
              // The lens comes in from the edge and stops in the middle, where
              // she is. Right to left or left to right, following the language.
              final fromLeft = Directionality.of(context) == TextDirection.rtl;
              final lensX = ((fromLeft ? 1.0 : -1.0) * (1 - sweep)) * 0.62;
              final lensCentre = Alignment(lensX, 0.04);
              // She is inside the glass until it settles, then steps forward.
              final scale = 0.16 + 0.84 * Curves.easeOutBack.transform(emerge);
              return Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: crowd * (1 - 0.55 * emerge),
                    child: Transform.scale(
                      scale: 1.05 + 0.12 * emerge,
                      child: Image.asset(
                        mapAsset,
                        fit: BoxFit.cover,
                        cacheWidth: decodeWidth,
                      ),
                    ),
                  ),
                  // The light of the glass, and what it leaves behind.
                  CustomPaint(
                    painter: _LensPainter(
                      lens: lensCentre,
                      settled: sweep,
                      emerge: emerge,
                      gold: gold,
                    ),
                  ),
                  // Findo herself, from a speck in the lens to the size of a
                  // person standing in front of you.
                  Align(
                    alignment: Alignment(
                      lensCentre.x * (1 - emerge),
                      lensCentre.y * (1 - emerge) + 0.06 * emerge,
                    ),
                    child: Transform.scale(
                      scale: scale,
                      child: Opacity(
                        opacity: (crowd * 0.35 + 0.65 * emerge).clamp(0.0, 1.0),
                        child: SizedBox(
                          height: side.height * 0.74,
                          child: Image.asset(
                            'assets/images/targets/findo.png',
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LensPainter extends CustomPainter {
  _LensPainter({
    required this.lens,
    required this.settled,
    required this.emerge,
    required this.gold,
  });

  final Alignment lens;
  final double settled;
  final double emerge;
  final bool gold;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = lens.alongSize(size);
    final radius = size.shortestSide * 0.24;
    final light = gold ? FindoColors.primary : FindoColors.accent;

    // The glow inside the glass, strongest as she comes out of it.
    final glow = Paint()
      ..isAntiAlias = true
      ..shader = RadialGradient(
        colors: [
          light.withValues(alpha: 0.30 * settled + 0.28 * emerge),
          light.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: centre, radius: radius * (1 + 1.6 * emerge)),
      );
    canvas.drawCircle(centre, radius * (1 + 1.6 * emerge), glow);

    // The rim, which expands and thins out as she steps through it.
    if (emerge < 1) {
      final rim = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * (1 - emerge) + 0.5
        ..color = FindoColors.primary
            .withValues(alpha: (0.55 * settled) * (1 - emerge));
      canvas.drawCircle(centre, radius * (1 + 0.9 * emerge), rim);
    }

    // The burst: thrown outwards the moment she is clear of the glass.
    if (emerge > 0) {
      final ray = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      const spokes = 16;
      for (var i = 0; i < spokes; i++) {
        final angle = i / spokes * pi * 2 + 0.18;
        final fade = (1 - emerge).clamp(0.0, 1.0);
        final inner = radius * (0.9 + 1.4 * emerge);
        final outer = inner + radius * 0.42 * (0.4 + emerge);
        ray
          ..strokeWidth = 3.2 * fade + 0.6
          ..color = light.withValues(alpha: 0.5 * fade);
        canvas.drawLine(
          centre + Offset(cos(angle), sin(angle)) * inner,
          centre + Offset(cos(angle), sin(angle)) * outer,
          ray,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_LensPainter old) =>
      old.settled != settled || old.emerge != emerge || old.lens != lens;
}

/// What the run added up to: levels, stars, and the rank it earned.
class _Tally extends StatelessWidget {
  const _Tally({
    required this.levels,
    required this.stars,
    required this.starsPossible,
    required this.rankName,
  });

  final int levels;
  final int stars;
  final int starsPossible;
  final String rankName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FindoPanel(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Figure(value: '$levels', label: l10n.t('finale.levels')),
          _Divider(),
          _Figure(
            value: '$stars/$starsPossible',
            label: l10n.t('finale.stars'),
            highlight: stars >= starsPossible,
          ),
          _Divider(),
          _Figure(value: rankName, label: l10n.t('finale.rank')),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 34,
        color: FindoColors.surfaceRaised,
      );
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.value,
    required this.label,
    this.highlight = false,
  });

  final String value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: highlight ? FindoColors.primary : FindoColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: FindoColors.textMuted),
          ),
        ],
      ),
    );
  }
}
