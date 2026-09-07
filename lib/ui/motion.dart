import 'package:flutter/material.dart';

/// Every transition in the game comes from here, so screens and panels move
/// the same way and the timing can be tuned in one place.
///
/// Two rules shape the numbers below. The game asks players to replay levels
/// to improve their stars, so anything they sit through more than once has to
/// stay under about a third of a second. And a player who has asked their
/// system to reduce motion gets the same screens with the movement taken out,
/// never a different layout.
class Motion {
  const Motion._();

  /// Pushing or popping a screen.
  static const route = Duration(milliseconds: 240);

  /// A modal panel arriving over the game.
  static const panelIn = Duration(milliseconds: 260);

  /// Leaving is quicker than arriving: the player has already decided.
  static const panelOut = Duration(milliseconds: 160);

  /// Between one star landing and the next on the win panel.
  static const starStagger = Duration(milliseconds: 200);

  static const enterCurve = Curves.easeOutCubic;
  static const exitCurve = Curves.easeInCubic;

  /// True when the player has asked the system to keep movement to a minimum.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static Duration scale(BuildContext context, Duration full) =>
      reduced(context) ? Duration.zero : full;
}

/// A screen transition: the incoming page fades up and lifts slightly, the
/// outgoing one fades back. Subtle enough to sit under a game rather than
/// announce itself.
Route<T> findoRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: Motion.route,
    reverseTransitionDuration: Motion.route,
    pageBuilder: (context, animation, secondary) => page,
    transitionsBuilder: (context, animation, secondary, child) {
      if (Motion.reduced(context)) {
        return child;
      }
      final entering = CurvedAnimation(parent: animation, curve: Motion.enterCurve);
      final leaving = CurvedAnimation(parent: secondary, curve: Motion.exitCurve);
      return FadeTransition(
        opacity: entering,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.035), end: Offset.zero)
              .animate(entering),
          child: FadeTransition(
            opacity: Tween(begin: 1.0, end: 0.0).animate(leaving),
            child: child,
          ),
        ),
      );
    },
  );
}

/// Wraps a panel shown over the Flame canvas so it animates both ways.
///
/// Flame removes an overlay the instant `overlays.remove` is called, so a
/// panel that closes itself would be cut off mid-fade. The builder therefore
/// hands out a [PanelCloser]: call it with what should happen next, and it
/// plays the exit first and runs the action when the panel has actually gone.
typedef PanelCloser = void Function(VoidCallback then);

class AnimatedPanel extends StatefulWidget {
  const AnimatedPanel({super.key, required this.builder});

  final Widget Function(BuildContext context, PanelCloser close) builder;

  @override
  State<AnimatedPanel> createState() => _AnimatedPanelState();
}

class _AnimatedPanelState extends State<AnimatedPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.panelIn,
    reverseDuration: Motion.panelOut,
  );

  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    // Started from the first frame, so the panel is never seen at rest in its
    // hidden state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close(VoidCallback then) {
    if (_leaving) {
      return;
    }
    _leaving = true;
    if (Motion.reduced(context)) {
      then();
      return;
    }
    _controller.reverse().whenComplete(then);
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.builder(context, _close);
    if (Motion.reduced(context)) {
      return child;
    }
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Motion.enterCurve,
      reverseCurve: Motion.exitCurve,
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, inner) {
        return Opacity(
          opacity: curved.value,
          child: Transform.scale(
            // From slightly under full size, so it reads as opening rather
            // than appearing.
            scale: 0.92 + 0.08 * curved.value,
            child: inner,
          ),
        );
      },
      child: child,
    );
  }
}

/// Counts up to [value] when it first appears, for the numbers on the win
/// panel. A score that lands already totalled has nothing to watch.
class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    required this.style,
    this.prefix = '',
    this.duration = const Duration(milliseconds: 650),
  });

  final int value;
  final TextStyle style;
  final String prefix;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) {
      return Text('$prefix$value', style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, shown, _) => Text(
        '$prefix${shown.round()}',
        style: style,
      ),
    );
  }
}
