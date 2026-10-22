library;

import 'package:just_game_engine/just_game_engine.dart';

/// A pickup — coins, gems, keys.
///
/// Expects a sensor body ([RigidBody2D.isSensor]) and a [Collider2D].
class CollectibleComponent extends Component {
  CollectibleComponent({
    this.kind = 'coin',
    this.value = 1,
    this.destroyOnCollect = true,
  });

  /// Free-form category, so one component covers coins, gems and keys without
  /// a component per pickup type.
  String kind;

  /// How much this is worth, in whatever [kind] counts.
  int value;

  /// Remove the entity on pickup. Turn off for a pickup that should stay in
  /// the world and merely change appearance.
  bool destroyOnCollect;

  /// Set on pickup so it cannot be collected twice before removal lands.
  bool isCollected = false;
}
