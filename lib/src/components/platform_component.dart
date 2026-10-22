library;

import 'package:flutter/painting.dart' show Offset;

import 'package:just_game_engine/just_game_engine.dart';

/// How a platform behaves when something lands on it.
enum PlatformKind {
  /// Ordinary solid ground.
  solid,

  /// Jump-through: solid only from the direction the collider was configured
  /// for. Backed by [Collider2D.oneWay].
  oneWay,

  /// Collapses a short time after being stepped on, then respawns.
  crumbling,

  /// Launches whatever lands on it.
  bouncy,
}

/// Marks an entity as level geometry and says how it behaves underfoot.
///
/// This is deliberately separate from [RigidBody2D]: the body says
/// *how it collides*, this says *what it means in the game*. The level editor
/// keys its prefab palette and layer tinting off this, and
/// `PlatformerGameplaySystem` reads it to drive crumble and bounce.
class PlatformComponent extends Component {
  PlatformComponent({
    this.kind = PlatformKind.solid,
    this.crumbleDelay = 0.35,
    this.respawnDelay = 2.0,
    this.bounceImpulse = 1400.0,
  });

  /// What this platform does when landed on.
  PlatformKind kind;

  /// Seconds between first contact and collapse, for [PlatformKind.crumbling].
  /// The delay is the whole mechanic — an instant drop is unreadable.
  double crumbleDelay;

  /// Seconds before a collapsed platform comes back.
  double respawnDelay;

  /// Upward impulse applied by a [PlatformKind.bouncy] platform.
  double bounceImpulse;

  // ── Runtime state, owned by PlatformerGameplaySystem ──────────────────────

  /// Counts down once a crumbling platform has been triggered; negative means
  /// "not triggered".
  double crumbleTimer = -1.0;

  /// Counts down while a crumbled platform is waiting to come back.
  double respawnTimer = -1.0;

  /// Whether the platform is currently collapsed (no collider, not drawn).
  bool isCollapsed = false;

  /// What its body collided with before it collapsed, given back when it
  /// returns (`RigidBody2D.collidesWith`; null, the project's
  /// grid).
  int? collidesBeforeCollapse;

  /// Where the platform sits when intact, captured on first update so a
  /// respawn can put it back exactly.
  Offset? restingPosition;
}
