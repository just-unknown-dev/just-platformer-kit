library;

import 'package:flutter/painting.dart' show Offset, Rect;

import 'package:just_game_engine/just_game_engine.dart';

/// The playable extent of a level, plus the height below which you die.
///
/// One per level, on its own entity. The camera clamps to [bounds] and
/// `PlatformerGameplaySystem` treats anything past [killPlaneY] as fallen out
/// of the world: anything with a `HealthComponent`, and any player.
///
/// This exists instead of `BoundarySystem`, which requires only
/// [TransformComponent] and therefore acts on *every* entity in the world —
/// including the camera.
class LevelBoundsComponent extends Component implements CameraBoundsSource {
  LevelBoundsComponent({
    this.bounds = const Rect.fromLTWH(0, 0, 4000, 1200),
    this._killPlaneY,
    this.gravityY = 2200.0,
  });

  /// World-space playable area. A `CameraConfinerComponent` that names this
  /// entity keeps its camera inside it.
  Rect bounds;

  /// Below this Y, an entity has fallen out of the level. Until it is set,
  /// a little under [bounds] — 400 below its bottom, wherever the bounds are
  /// — so a pit reads as a pit before it kills.
  double get killPlaneY => _killPlaneY ?? bounds.bottom + 400;
  set killPlaneY(double value) => _killPlaneY = value;
  double? _killPlaneY;

  /// World gravity for this level: `PlatformerGameplaySystem` (given the
  /// world's physics, as `PlatformerKit.systems` does) applies it when the
  /// level starts, and again whenever it changes.
  ///
  /// The physics package is calibrated at 1 unit = 1 cm, so its 981 default is
  /// real-world gravity and feels floaty for a platformer. Roughly 2200 gives
  /// the snappier arc the genre expects.
  double gravityY;

  /// The playable area is absolute, wherever this entity sits.
  @override
  Rect cameraBoundsAt(Offset entityPosition) => bounds;
}
