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
    // times over as the player pinches in, so it wants smoothing at both ends.
    //
    // Medium, not high: at the fit-to-screen zoom a 2048px map is resampled
    // down to about a third of its size on every frame, and high does that
    // with a cubic filter each time, which is what made the later levels
    // crawl on mid-range phones. Medium uses mipmaps -- built once, sampled
    // cheaply -- and on a crowd scene the difference is not visible at either
    // end of the zoom.
    paint
      ..filterQuality = FilterQuality.medium
      ..isAntiAlias = true;
  }

  @override
  void onTapDown(TapDownEvent event) {
    // Nothing is charged on the way down: a miss costs 15 points and 3
    // seconds, and the finger that just landed may be about to drag the map.
    game.beginGesture();
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (game.gestureWasDrag) {
      return;
    }
    game.registerMisclick(event.localPosition);
  }
}
