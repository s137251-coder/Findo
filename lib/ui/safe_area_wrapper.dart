import 'package:flutter/material.dart';

/// Keeps content clear of the notch, the Dynamic Island, the Android status
/// bar and the gesture pill, and additionally caps the width on tablets so a
/// panel does not stretch across a 4:3 iPad screen.
class SafeAreaWrapper extends StatelessWidget {
  const SafeAreaWrapper({
    super.key,
    required this.child,
    this.maxContentWidth = 560,
    this.padding = EdgeInsets.zero,
    this.top = true,
    this.bottom = true,
  });

  final Widget child;
  final double maxContentWidth;
  final EdgeInsets padding;
  final bool top;
  final bool bottom;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: top,
      bottom: bottom,
      child: Padding(
        padding: padding,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Safe-area insets without the width clamp, for full-bleed layers such as the
/// in-game HUD that must span the whole screen.
class SafeAreaEdges extends StatelessWidget {
  const SafeAreaEdges({super.key, required this.child, this.minimum = EdgeInsets.zero});

  final Widget child;
  final EdgeInsets minimum;

  @override
  Widget build(BuildContext context) {
    return SafeArea(minimum: minimum, child: child);
  }
}
