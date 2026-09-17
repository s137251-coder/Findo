import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

/// Findo's title-screen clip has to reach Flutter as an animation, not as a
/// picture. An animated WebP that the engine's decoder reads as a single frame
/// shows her standing still with nothing to say why, so the clip is decoded
/// here with the same codec the app uses.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the clip decodes as a looping animation', (tester) async {
    await tester.runAsync(() async {
      final bytes = File('assets/images/targets/findo_idle.webp').readAsBytesSync();
      final codec = await ui.instantiateImageCodec(bytes);
      expect(codec.frameCount, 120, reason: 'the decoder did not see every frame');
      // -1 is "repeat forever".
      expect(codec.repetitionCount, -1, reason: 'the clip would stop after one pass');

      final first = await codec.getNextFrame();
      final second = await codec.getNextFrame();
      expect(first.duration, greaterThan(Duration.zero));
      expect(second.duration, greaterThan(Duration.zero));
      expect(first.image.width, 336);
      expect(first.image.height, 640);
      first.image.dispose();
      second.image.dispose();
      codec.dispose();
    });
  });
}
