import 'dart:math';

import 'package:flutter/material.dart';

/// Findo herself, standing at the foot of the title screen.
///
/// A hundred levels are spent looking for her, and until the title screen the
/// only place she could be seen whole was a panel inside a level. Here she is
/// simply present: she arrives last and breathes. She is scenery, not a
/// control -- a tap on her does nothing, and she lets taps through to whatever
/// is beneath her.
class TitleFindo extends StatelessWidget {
  const TitleFindo({
    super.key,
    required this.enter,
    required this.idle,
    required this.still,
  });

  /// The title screen's opening; she rises in over its last stretch.
  final AnimationController enter;

  /// The screen's resting pulse, which her breathing follows.
  final AnimationController idle;

  /// Reduced motion: she stands still.
  final bool still;

  @override
  Widget build(BuildContext context) {
    final height = min(MediaQuery.sizeOf(context).height * 0.26, 235.0);
    final arrival = CurvedAnimation(
      parent: enter,
      curve: const Interval(0.55, 1.0, curve: Curves.easeOutCubic),
    );

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([arrival, idle]),
        builder: (context, child) {
          // Breathing: a couple of pixels, and a hair of stretch with it.
          final breath = still ? 0.0 : sin(idle.value * pi * 2 * 2);
          return Opacity(
            opacity: arrival.value,
            child: Transform.translate(
              offset: Offset(0, (1 - arrival.value) * 60 + breath * 2.5),
              child: Transform.scale(
                scaleY: 1 + breath * 0.008,
                scaleX: 1 - breath * 0.004,
                alignment: Alignment.bottomCenter,
                child: child,
              ),
            ),
          );
        },
        child: SizedBox(
          height: height,
          child: Image.asset(
            'assets/images/targets/findo.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}
