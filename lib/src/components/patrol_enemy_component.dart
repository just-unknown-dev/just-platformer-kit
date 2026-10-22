library;

import 'package:just_game_engine/just_game_engine.dart';

/// How a simple enemy decides where to go.
enum EnemyBehaviour {
  /// Walks back and forth over a fixed span.
  patrol,

  /// Walks toward the player once they are within [PatrolEnemyComponent.aggroRange].
  chase,

  /// Never moves.
  stationary,
}

/// A basic walking enemy.
///
/// Deliberately small: a template needs one enemy that reads clearly, not an
/// AI framework. Anything more belongs in game code.
class PatrolEnemyComponent extends Component {
  PatrolEnemyComponent({
    this.behaviour = EnemyBehaviour.patrol,
    this.speed = 90.0,
    this.patrolRange = 160.0,
    this.aggroRange = 400.0,
    this.turnAtLedge = true,
    this.contactDamage = 1.0,
    this.stompable = true,
  });

  /// What this enemy does.
  EnemyBehaviour behaviour;

  /// Walking speed in world units per second.
  double speed;

  /// How far either side of its spawn point it patrols.
  double patrolRange;

  /// Distance at which [EnemyBehaviour.chase] starts following the player.
  double aggroRange;

  /// Turn around at the edge of a platform instead of walking off it. Needs a
  /// downward raycast ahead of the enemy, so it costs one cast per enemy per
  /// frame — turn it off for enemies on continuous ground.
  bool turnAtLedge;

  /// Damage dealt to the player on side contact.
  double contactDamage;

  /// Whether landing on this enemy from above kills it. The defining
  /// interaction of the genre.
  bool stompable;

  // ── Runtime state, owned by PatrolEnemySystem ─────────────────────────────

  /// Current facing: +1 right, -1 left.
  int facing = 1;

  /// Spawn position, captured on first update; patrol is measured from here.
  double? originX;

  /// Set when stomped, so the death is processed once.
  bool isDefeated = false;
}
