import 'dart:math';

import 'package:flutter/material.dart';

/// Findo herself, standing at the foot of the title screen.
///
/// A hundred levels are spent looking for her, and until the title screen the
/// only place she could be seen whole was a panel inside a level. Here she is
/// animated: she breathes, blinks, glances round as if searching a crowd, and
/// waves. The clip is a transparent animated WebP that loops on its own, cut
/// from an image-to-video render on a green screen and played at twelve frames
/// a second -- a cartoon animated on twos.
///
/// She is scenery, not a control: a tap on her does nothing, and she lets
/// taps through to whatever is beneath her.
class TitleFindo extends StatelessWidget {
  const TitleFindo({
    super.key,
    required this.enter,
    required this.still,
  });

  static const _clip = 'assets/images/targets/findo_idle.webp';

  /// The clip's first frame, for players who have asked for less motion.
  static const _stillFrame = 'assets/images/targets/findo_idle_still.png';

  /// The title screen's opening; she rises in over its last stretch.
  final AnimationController enter;

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
        animation: arrival,
        builder: (context, child) => Opacity(
          opacity: arrival.value,
          child: Transform.translate(
            offset: Offset(0, (1 - arrival.value) * 60),
            child: child,
          ),
        ),
        child: SizedBox(
          height: height,
          child: Image.asset(
            still ? _stillFrame : _clip,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            // The clip rebuilds with the opening; without this it could blank
            // for a frame each time.
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }
}
