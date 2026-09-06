import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../findo_game.dart';

/// The level artwork, and the surface that turns a tap on nothing into a
/// misclick.
///
/// Flame delivers a tap only to the topmost component under the finger, so a
/// tap that lands on an [ItemTargetComponent] never reaches this one -- the
/// penalty here fires exactly when the player guessed wrong.
class MapBackgroundComponent extends SpriteComponent
    with TapCallbacks, HasGameReference<FindoGame> {
  MapBackgroundComponent({required Sprite sprite, required Vector2 worldSize})
      : super(sprite: sprite, size: worldSize, position: Vector2.zero());

  @override
  void onTapDown(TapDownEvent event) {
    game.registerMisclick(event.localPosition);
  }
}
