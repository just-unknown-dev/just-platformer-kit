library;

import 'package:flutter/painting.dart' show Offset;

import 'package:just_game_engine/just_game_engine.dart';

/// Marks an entity as damaging to touch — spikes, lava, a saw blade.
///
/// Pair with a sensor [RigidBody2D] for something the player passes
/// through (lava, a kill volume), or a solid one for something they also stand
/// on (a spiked block).
class HazardComponent extends Component {
  HazardComponent({
    this.damage = 1.0,
    this.instantKill = false,
    this.knockback = const Offset(0, -600),
    this.invulnerabilitySeconds = 1.0,
    this.respawnOnHit = false,
  });

  /// Health removed per hit. Ignored when [instantKill].
  double damage;

  /// Kills outright regardless of remaining health. Bottomless pits and
  /// crushers.
  bool instantKill;

  /// Impulse applied to the victim, giving the hit a readable reaction rather
  /// than silently decrementing a number.
  Offset knockback;

  /// How long the victim cannot be hurt again. A player who stays in (or on)
  /// the hazard is hurt again each time this runs out; without it, overlapping
  /// a hazard would drain the whole health bar in a handful of frames.
  double invulnerabilitySeconds;

  /// Send the victim back to their last checkpoint even if they survived: the
  /// hit's `EntityDamagedEvent.respawn` is true, and the game moves them.
  bool respawnOnHit;
}
