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
/// The clip plays even when the device asks for reduced motion. Battery saver
/// turns animations off on many phones, and a still Findo on a frozen title
/// screen read as broken to the players who saw it; a character gently moving
/// in place, with no flashing and nothing sweeping the screen, is the one
/// piece of motion kept. The rest of the title screen still holds still.
///
/// She is scenery, not a control: a tap on her does nothing, and she lets
/// taps through to whatever is beneath her.
class TitleFindo extends StatelessWidget {
  const TitleFindo({super.key, required this.enter});

  static const _clip = 'assets/images/targets/findo_idle.webp';

  /// The title screen's opening; she rises in over its last stretch.
  final AnimationController enter;

  @override
  Widget build(BuildContext context) {
    final height = min(MediaQuery.sizeOf(context).height * 0.24, 220.0);
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
        // Flutter's Image pauses any animated image on its first frame when
        // the device asks for reduced motion, so leaving out a still fallback
        // was not enough: she stood still anyway. The request is lifted for
        // this image alone; everything else on the screen still honours it.
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: false),
          child: SizedBox(
            height: height,
            child: Image.asset(
              _clip,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              // The clip rebuilds with the opening; without this it could
              // blank for a frame each time.
              gaplessPlayback: true,
            ),
          ),
        ),
      ),
    );
  }
}
