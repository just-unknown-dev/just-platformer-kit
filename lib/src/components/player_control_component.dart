library;

import 'package:just_game_engine/just_game_engine.dart';

/// Tuning and runtime state for a platformer character controller.
///
/// None of this is provided by the physics engine — a rigid body with gravity
/// and an impulse gives you a character that feels awful. Everything here is a
/// deliberate deviation from physical accuracy in service of how the character
/// reads to the player, which is what actually makes a platformer playable:
///
/// * **Coyote time** — you can still jump for a few frames after walking off a
///   ledge. Without it, players who press jump "at the edge" get nothing and
///   blame the game.
/// * **Jump buffering** — a jump pressed slightly before landing fires on
///   touchdown instead of being dropped.
/// * **Variable jump height** — releasing jump early cuts the arc short, so one
///   button covers a hop and a full leap.
/// * **Asymmetric gravity** — falling faster than rising removes the floaty
///   hang at the apex.
///
/// Read by `PlayerControlSystem`, which runs between input and physics so a
/// press reaches the same frame's simulation step.
class PlayerControlComponent extends Component {
  PlayerControlComponent({
    this.moveSpeed = 420.0,
    this.acceleration = 3600.0,
    this.airAcceleration = 2200.0,
    this.groundFriction = 4200.0,
    this.airFriction = 600.0,
    this.jumpSpeed = 900.0,
    this.maxFallSpeed = 1600.0,
    this.coyoteTime = 0.10,
    this.jumpBufferTime = 0.12,
    this.riseGravityScale = 1.0,
    this.fallGravityScale = 1.7,
    this.jumpCutGravityScale = 3.2,
    this.maxJumps = 1,
    this.stompBounceSpeed = 620.0,
  });

  // ── Horizontal movement ───────────────────────────────────────────────────

  /// Top running speed in world units per second.
  double moveSpeed;

  /// How fast [moveSpeed] is reached while grounded.
  double acceleration;

  /// How fast [moveSpeed] is reached while airborne. Lower than
  /// [acceleration] so a jump commits to its arc instead of being steerable
  /// like a hovercraft.
  double airAcceleration;

  /// Deceleration applied on the ground with no input. High enough to stop
  /// crisply rather than skate.
  double groundFriction;

  /// Deceleration applied in the air with no input.
  double airFriction;

  // ── Jumping ───────────────────────────────────────────────────────────────

  /// Upward speed applied at the moment of a jump.
  double jumpSpeed;

  /// Terminal velocity. Without a cap, a long fall builds enough speed to
  /// tunnel through thin platforms and makes landings unreadable.
  double maxFallSpeed;

  /// Grace period after leaving the ground during which a jump still works.
  double coyoteTime;

  /// How early a jump press is remembered and replayed on landing.
  double jumpBufferTime;

  /// Gravity multiplier while moving upward with jump held.
  double riseGravityScale;

  /// Gravity multiplier while falling.
  double fallGravityScale;

  /// Gravity multiplier while rising with jump *released* — this is what makes
  /// a tapped jump shorter than a held one.
  double jumpCutGravityScale;

  /// Total jumps before touching ground again. 2 gives a double jump.
  int maxJumps;

  /// Upward speed granted for stomping an enemy.
  double stompBounceSpeed;

  // ── Runtime state, owned by PlayerControlSystem ───────────────────────────

  /// Seconds of coyote time remaining.
  double coyoteTimer = 0.0;

  /// Seconds of buffered jump remaining.
  double jumpBufferTimer = 0.0;

  /// Jumps used since last touching the ground.
  int jumpsUsed = 0;

  /// Whether the jump button was held last frame, for edge detection.
  bool jumpHeldLastFrame = false;

  /// True between leaving the ground on a jump and starting to fall.
  bool isRising = false;

  /// Facing direction: +1 right, -1 left. Held across idle frames so the
  /// character keeps facing the way it last moved.
  int facing = 1;

  /// Seconds of damage invulnerability remaining.
  double invulnerabilityTimer = 0.0;

  /// True while the entity is standing on something.
  bool isGrounded = false;

  /// True on the frame the entity touched down, for landing effects.
  bool justLanded = false;
}
