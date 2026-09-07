import 'package:flutter/material.dart';

import '../../theme.dart';
import '../safe_area_wrapper.dart';

/// One to three stars, dimmed when not earned.
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.stars, this.size = 22, this.total = 3});

  final int stars;
  final int total;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (index) {
        final earned = index < stars;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: size * 0.06),
          child: Icon(
            earned ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: earned ? FindoColors.primary : FindoColors.locked,
          ),
        );
      }),
    );
  }
}

/// The rounded dark card every overlay is built from.
class FindoPanel extends StatelessWidget {
  const FindoPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: FindoColors.surface,
        borderRadius: BorderRadius.circular(FindoMetrics.radiusPanel),
        border: Border.all(color: FindoColors.surfaceRaised, width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 28, offset: Offset(0, 12)),
        ],
      ),
      child: child,
    );
  }
}

/// A labelled readout used by the HUD and the win summary.
class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.icon,
    required this.value,
    this.color = FindoColors.textPrimary,
  });

  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xCC1E2333),
        borderRadius: BorderRadius.circular(FindoMetrics.radiusControl),
        border: Border.all(color: FindoColors.surfaceRaised),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

/// Formats a countdown as m:ss.
String formatSeconds(double seconds) {
  final total = seconds.ceil().clamp(0, 359999);
  final minutes = total ~/ 60;
  final rest = total % 60;
  return '$minutes:${rest.toString().padLeft(2, '0')}';
}

/// Dims the game behind a panel and keeps the panel inside the safe area.
class ModalScrim extends StatelessWidget {
  const ModalScrim({super.key, required this.child, this.maxContentWidth = 420});

  final Widget child;
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xB3050710),
      child: SafeAreaWrapper(
        maxContentWidth: maxContentWidth,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(child: Center(child: child)),
      ),
    );
  }
}

/// Findo's portrait, drawn from the very same sprite the map hides, so the
/// player is looking for exactly what they were shown.
class FindoPortrait extends StatelessWidget {
  const FindoPortrait({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.10),
      decoration: BoxDecoration(
        color: FindoColors.surfaceRaised,
        borderRadius: BorderRadius.circular(size * 0.24),
        border: Border.all(color: FindoColors.primary, width: 2),
      ),
      child: Image.asset(
        'assets/images/targets/findo.png',
        filterQuality: FilterQuality.high,
        fit: BoxFit.contain,
      ),
    );
  }
}
