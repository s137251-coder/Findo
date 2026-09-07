import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../findo_game.dart';

/// The level artwork, and the surface that turns a tap on nothing into a
/// misclick.
///
/// Flame delivers a tap only to the topmost component under the finger, so a
/// tap that lands on Findo never reaches this one -- the penalty here fires
/// exactly when the player guessed wrong.
class MapBackgroundComponent extends SpriteComponent
    with TapCallbacks, HasGameReference<FindoGame> {
  MapBackgroundComponent({required Sprite sprite, required Vector2 mapSize})
      : super(sprite: sprite, size: mapSize, position: Vector2.zero()) {
    // The map is drawn shrunk to fit the screen and then magnified several
    // times over as the player pinches in. High-quality filtering is what
    // keeps the crowd legible at both ends.
    paint
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true;
  }

  @override
  void onTapDown(TapDownEvent event) {
    game.registerMisclick(event.localPosition);
  }
}
