library;

import 'package:just_game_engine/just_game_engine.dart';

/// The level exit. Reaching it completes the level.
///
/// Expects a sensor [RigidBody2D]; `PlatformerGameplaySystem` fires
/// [LevelCompletedEvent] on overlap.
class GoalComponent extends Component {
  GoalComponent({this.nextScene, this.requiresAllCollectibles = false});

  /// Scene to load next. Null means "this is the last level".
  String? nextScene;

  /// Gate the exit on having picked up every collectible in the level.
  bool requiresAllCollectibles;

  /// Set once the goal has fired, so it cannot re-trigger while the player is
  /// still standing in it.
  bool isReached = false;
}
