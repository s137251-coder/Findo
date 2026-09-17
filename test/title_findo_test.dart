import 'package:findo/ui/title_findo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Findo's clip on the title screen plays even when the device asks for
/// reduced motion -- battery saver asks on many phones.
///
/// Flutter's Image widget pauses animated images on their first frame under
/// that request. The title screen lifts it for her image alone, so this checks
/// what that image sees, and that the rest of the screen still sees the
/// device's real request.
void main() {
  testWidgets('her clip is not paused by a reduced-motion request', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              const _Probe(),
              const Align(alignment: Alignment.topCenter, child: TitleFindo(height: 150)),
            ],
          ),
        ),
      ),
    );

    final image = tester.element(find.byType(Image));
    expect(MediaQuery.disableAnimationsOf(image), isFalse,
        reason: 'Flutter would hold the clip on its first frame');

    final elsewhere = tester.element(find.byType(_Probe));
    expect(MediaQuery.disableAnimationsOf(elsewhere), isTrue,
        reason: 'the override leaked past her image');

    // Let the image finish loading so no timer outlives the test.
    await tester.pump(const Duration(milliseconds: 100));
  });
}

/// Stands in for the rest of the title screen.
class _Probe extends StatelessWidget {
  const _Probe();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
