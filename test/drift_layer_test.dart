import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:findo/game/components/drift_layer_component.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the drift layer costs per frame, and what it costs per level.
///
/// Both were reported from a real session: a tester deep in the game said
/// everything had gone slow, and that closing the game and opening it again
/// put it right -- the signature of something piling up level after level
/// rather than of one heavy level.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// A layer at the top of the difficulty curve, loaded.
  Future<DriftLayerComponent> load(WidgetTester tester, DriftKind kind) async {
    final layer = DriftLayerComponent(
      kind: kind,
      intensity: 1,
      mapSize: Vector2.all(2048),
      seed: 3,
    );
    await tester.runAsync(layer.onLoad);
    return layer;
  }

  testWidgets('the whole field is drawn in one call', (tester) async {
    final layer = await load(tester, DriftKind.snow);
    expect(layer.spriteReady, isTrue);
    expect(layer.particleCount, DriftLayerComponent.maxParticles);

    final canvas = _CountingCanvas(const Rect.fromLTWH(0, 0, 2048, 2048));
    layer.render(canvas);

    expect(canvas.atlasCalls, 1);
    expect(canvas.stamps, layer.particleCount,
        reason: 'every particle should be in that one call');
    expect(canvas.otherDraws, 0, reason: 'nothing should be drawn per particle');
  });

  testWidgets('a rain streak and a spinning flake draw the same way',
      (tester) async {
    for (final kind in [DriftKind.rain, DriftKind.confetti]) {
      final layer = await load(tester, kind);
      final canvas = _CountingCanvas(const Rect.fromLTWH(0, 0, 2048, 2048));
      layer.render(canvas);
      expect(canvas.atlasCalls, 1, reason: '$kind');
      expect(canvas.otherDraws, 0, reason: '$kind');
    }
  });

  testWidgets('particles off screen are left out', (tester) async {
    final layer = await load(tester, DriftKind.snow);
    final canvas = _CountingCanvas(const Rect.fromLTWH(0, 0, 200, 200));
    layer.render(canvas);
    expect(canvas.stamps, lessThan(layer.particleCount));
  });

  testWidgets('a frame builds nothing it could have kept', (tester) async {
    // Drawing used to gather the transforms and colours into fresh lists each
    // time: a few hundred short-lived objects, sixty times a second, and the
    // collecting that follows is work a phone pays for in warmth. The buffers
    // are filled in place now, so the same memory comes back frame after
    // frame.
    final layer = await load(tester, DriftKind.snow);
    final canvas = _CountingCanvas(const Rect.fromLTWH(0, 0, 2048, 2048));

    for (var frame = 0; frame < 3; frame++) {
      layer.update(0.016);
      layer.render(canvas);
      // Writing through what the canvas was handed lands in the layer's own
      // buffer: the numbers were written in place, not gathered into a new
      // list for this frame.
      canvas.transforms![0] = 1234.5;
      expect(layer.transformBuffer[0], 1234.5,
          reason: 'frame $frame built its transforms again');
    }
  });

  testWidgets('every level of a kind shares one stamp', (tester) async {
    // Flame does not run onRemove on the components of a game it replaces, so
    // a picture built per level would be a picture leaked per level -- which
    // is exactly the kind of drip that makes a long session slow.
    final first = await load(tester, DriftKind.petal);
    final second = await load(tester, DriftKind.petal);
    expect(first.spriteReady && second.spriteReady, isTrue);

    final canvasA = _CountingCanvas(const Rect.fromLTWH(0, 0, 2048, 2048));
    final canvasB = _CountingCanvas(const Rect.fromLTWH(0, 0, 2048, 2048));
    first.render(canvasA);
    second.render(canvasB);
    expect(identical(canvasA.atlas, canvasB.atlas), isTrue);
  });
}

/// A canvas that counts what was asked of it.
class _CountingCanvas implements Canvas {
  _CountingCanvas(this._clip);

  final Rect _clip;

  int atlasCalls = 0;
  int stamps = 0;
  int otherDraws = 0;
  ui.Image? atlas;
  Float32List? transforms;

  @override
  Rect getLocalClipBounds() => _clip;

  @override
  void drawRawAtlas(
    ui.Image atlas,
    Float32List rstTransforms,
    Float32List rects,
    Int32List? colors,
    BlendMode? blendMode,
    Rect? cullRect,
    Paint paint,
  ) {
    atlasCalls++;
    // Four numbers describe where each stamp goes.
    stamps += rstTransforms.length ~/ 4;
    this.atlas = atlas;
    transforms = rstTransforms;
  }

  @override
  void noSuchMethod(Invocation invocation) {
    if (invocation.isMethod &&
        invocation.memberName.toString().contains('draw')) {
      otherDraws++;
    }
  }
}
