import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/findo_game.dart';
import '../managers/localization_manager.dart';
import '../theme.dart';
import 'motion.dart';

/// The steps of the guided first hunt, in the order they are taught.
enum TutorialStep { meet, drag, zoom, hint, find, done }

/// Where the guided first hunt has got to.
///
/// Each step but the first waits for the player to actually do the thing --
/// drag, pinch, ask for a hint, tap her -- and moves on by itself when they
/// have. A step the player already did out of turn (pinching while they were
/// asked to drag) is not taught again: it is passed over when its turn comes.
class TutorialController extends ChangeNotifier {
  TutorialStep _step = TutorialStep.meet;
  final Set<TutorialStep> _done = {};

  TutorialStep get step => _step;

  bool get active => _step != TutorialStep.done;

  /// The step's place, from 1, for the "2 / 5" on the card.
  int get number => _step.index + 1;

  static final int count = TutorialStep.done.index;

  /// Records that the player did [what], and moves on when it was the step
  /// being taught.
  void did(TutorialStep what) {
    if (!active) {
      return;
    }
    _done.add(what);
    if (what != _step) {
      return;
    }
    var next = TutorialStep.values[_step.index + 1];
    while (next != TutorialStep.done && _done.contains(next) && _skippable(next)) {
      next = TutorialStep.values[next.index + 1];
    }
    _step = next;
    notifyListeners();
  }

  /// Steps that are only practice can be passed over when already done. The
  /// hint and the find cannot: the find is the point, and the hint is what
  /// shows the player where she is.
  static bool _skippable(TutorialStep step) =>
      step == TutorialStep.drag || step == TutorialStep.zoom;

  void skip() {
    if (!active) {
      return;
    }
    _step = TutorialStep.done;
    notifyListeners();
  }
}

/// The coach that walks a new player through their first hunt.
///
/// It is drawn over a live game: everything but the card itself lets touches
/// through, so the player drags and pinches the real map while the card tells
/// them how. A moving hand shows the gesture; reduced motion keeps the hand
/// and drops the movement.
class TutorialOverlay extends StatelessWidget {
  const TutorialOverlay({
    super.key,
    required this.game,
    required this.controller,
  });

  static const overlayId = 'tutorial';

  final FindoGame game;
  final TutorialController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final step = controller.step;
        if (step == TutorialStep.done) {
          return const SizedBox.shrink();
        }
        final padding = MediaQuery.paddingOf(context);
        // Above the objective bar, which is where the portrait and the hint
        // button the card points at live.
        final aboveBar = math.max(game.hudBottomInset, 96.0) + 10;
        final atBottom = step == TutorialStep.meet || step == TutorialStep.hint;

        return Stack(
          children: [
            if (step == TutorialStep.drag || step == TutorialStep.zoom)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(child: _GestureHint(step: step)),
                ),
              ),
            Positioned(
              left: 12,
              right: 12,
              top: atBottom ? null : padding.top + 72,
              bottom: atBottom ? aboveBar : null,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: _CoachCard(
                    controller: controller,
                    pointsAt: switch (step) {
                      TutorialStep.meet => AlignmentDirectional.bottomStart,
                      TutorialStep.hint => AlignmentDirectional.bottomEnd,
                      _ => null,
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({required this.controller, required this.pointsAt});

  final TutorialController controller;

  /// The corner of the bar the card is about, or null when it is about the
  /// map.
  final AlignmentDirectional? pointsAt;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final step = controller.step;
    final key = 'tutorial.${step.name}';
    final card = Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: FindoColors.surface,
        borderRadius: BorderRadius.circular(FindoMetrics.radiusPanel),
        border: Border.all(color: FindoColors.primary, width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x99000000), blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(_iconFor(step), color: FindoColors.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.t('$key.title'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                l10n.t('tutorial.progress', params: {
                  'step': controller.number,
                  'count': TutorialController.count,
                }),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: FindoColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.t('$key.body'),
            style: const TextStyle(fontSize: 15, height: 1.4, color: FindoColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              // Flexible, so a long translation or a large system font
              // shrinks the skip link rather than pushing the button off.
              Flexible(
                child: TextButton(
                  onPressed: controller.skip,
                  style: TextButton.styleFrom(foregroundColor: FindoColors.textMuted),
                  child: Text(
                    l10n.t('tutorial.skip'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const Spacer(),
              // Only the introduction has a button. Every other step moves on
              // when the player does what it asks.
              if (step == TutorialStep.meet)
                FilledButton(
                  onPressed: () => controller.did(TutorialStep.meet),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                  child: Text(l10n.t('tutorial.next')),
                ),
            ],
          ),
        ],
      ),
    );

    final corner = pointsAt;
    if (corner == null) {
      return Semantics(liveRegion: true, child: card);
    }
    return Semantics(
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          card,
          Align(
            alignment: corner,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: _Bounce(
                child: const Icon(
                  Icons.arrow_downward_rounded,
                  size: 34,
                  color: FindoColors.primary,
                  shadows: [Shadow(color: Color(0xCC000000), blurRadius: 8)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(TutorialStep step) => switch (step) {
        TutorialStep.meet => Icons.face_retouching_natural_rounded,
        TutorialStep.drag => Icons.pan_tool_alt_rounded,
        TutorialStep.zoom => Icons.pinch_rounded,
        TutorialStep.hint => Icons.lightbulb_rounded,
        TutorialStep.find => Icons.touch_app_rounded,
        TutorialStep.done => Icons.check_rounded,
      };
}

/// A hand in the middle of the map, acting out the gesture being taught.
class _GestureHint extends StatefulWidget {
  const _GestureHint({required this.step});

  final TutorialStep step;

  @override
  State<_GestureHint> createState() => _GestureHintState();
}

class _GestureHintState extends State<_GestureHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _loop.stop();
      _loop.value = 0.5;
    } else if (!_loop.isAnimating) {
      unawaited(_loop.repeat());
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const shadow = [Shadow(color: Color(0xCC000000), blurRadius: 12)];
    return AnimatedBuilder(
      animation: _loop,
      builder: (context, _) {
        // There and back, eased, so the hand looks like it is being moved.
        final t = Curves.easeInOut.transform(
          _loop.value < 0.5 ? _loop.value * 2 : (1 - _loop.value) * 2,
        );
        if (widget.step == TutorialStep.drag) {
          return Transform.translate(
            offset: Offset(-70 + 140 * t, 0),
            child: const Icon(Icons.pan_tool_alt_rounded,
                size: 64, color: Colors.white, shadows: shadow),
          );
        }
        // Two fingertips moving apart.
        final gap = 18 + 46 * t;
        return SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.translate(
                offset: Offset(-gap, gap),
                child: const _Fingertip(),
              ),
              Transform.translate(
                offset: Offset(gap, -gap),
                child: const _Fingertip(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Fingertip extends StatelessWidget {
  const _Fingertip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.85),
        border: Border.all(color: FindoColors.primary, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 10)],
      ),
    );
  }
}

/// A gentle up-and-down, for the arrow under the card.
class _Bounce extends StatefulWidget {
  const _Bounce({required this.child});

  final Widget child;

  @override
  State<_Bounce> createState() => _BounceState();
}

class _BounceState extends State<_Bounce> with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _loop.stop();
    } else if (!_loop.isAnimating) {
      unawaited(_loop.repeat(reverse: true));
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _loop,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, 6 * Curves.easeInOut.transform(_loop.value)),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// A one-off tip that slides in at the top of a hunt, says one thing, and
/// goes away on its own. Tapping it sends it away sooner.
///
/// These are how the game teaches what the first hunt did not: each appears
/// the first time it becomes useful -- a wrong tap, a level where time starts
/// to matter -- rather than all at once before the player has played.
class TipBanner extends StatefulWidget {
  const TipBanner({super.key, required this.tipKey, required this.onDone});

  static const overlayId = 'tip';

  /// How long a tip stays up.
  static const showFor = Duration(seconds: 6);

  final String tipKey;
  final VoidCallback onDone;

  @override
  State<TipBanner> createState() => _TipBannerState();
}

class _TipBannerState extends State<TipBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(TipBanner.showFor, widget.onDone);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final top = MediaQuery.paddingOf(context).top + 66;
    return Stack(
      children: [
        Positioned(
          left: 12,
          right: 12,
          top: top,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Semantics(
                liveRegion: true,
                child: Material(
                  color: const Color(0xF21E2333),
                  borderRadius: BorderRadius.circular(FindoMetrics.radiusControl),
                  child: InkWell(
                    onTap: widget.onDone,
                    borderRadius: BorderRadius.circular(FindoMetrics.radiusControl),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(FindoMetrics.radiusControl),
                        border: Border.all(color: FindoColors.accent, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.tips_and_updates_rounded,
                              color: FindoColors.accent, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.t(widget.tipKey),
                              style: const TextStyle(fontSize: 14, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
