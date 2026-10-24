library;

import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:just_game_engine/just_game_engine.dart';

import '../components/platformer.dart';

/// Turns input into character motion, with the feel adjustments a platformer
/// needs.
///
/// Runs at [SystemPriorities.playerControl] (95) — after input (100), before
/// physics (90) — so a button pressed this frame reaches this frame's
/// simulation step. Moving it after physics would make every input land a
/// frame late, which players read as sluggishness without being able to say
/// why.
///
/// A player is either body:
///
/// * a [RigidBody2D] (with a [VelocityComponent]): it writes the velocity
///   and [RigidBody2D.gravityScale] and lets the physics step integrate
///   them, rather than moving the transform itself — a transform write
///   registers as a teleport and breaks collision resolution;
/// * a [CharacterBody2D]: it sets [CharacterBody2D.moveVelocity], jumps and
///   [CharacterBody2D.gravityScale], and leaves slopes, steps and moving
///   platforms to the character mover.
///
/// The feel is the same either way. See [PlayerControlComponent] for what
/// each tuning value buys.
class PlayerControlSystem extends System {
  PlayerControlSystem({
    this.moveAction = 'move',
    this.jumpAction = 'jump',
    this.maxSlopeDegrees = 50,
    this.slopeSnap = 120,
  });

  /// Name of the vector2 action supplying horizontal movement.
  final String moveAction;

  /// Name of the button action for jumping.
  final String jumpAction;

  /// The steepest ground a character stands and runs on, in degrees from
  /// level. Steeper than this, it slides.
  final double maxSlopeDegrees;

  /// How hard a character on a slope is held to it, in pixels a second into
  /// the ground: what keeps it running down a slope rather than launching
  /// off it.
  final double slopeSnap;

  @override
  int get priority => SystemPriorities.playerControl;

  @override
  List<Type> get requiredComponents => const [
    TransformComponent,
    PlayerControlComponent,
    InputComponent,
  ];

  @override
  void update(double deltaTime) {
    // Time standing still — paused, or an editor authoring the level: the
    // player's saved values (its body's gravity scale, its velocity) are
    // left as they are.
    if (deltaTime <= 0) return;
    forEach((entity) {
      if (!entity.isActive) return;

      final control = entity.getComponent<PlayerControlComponent>()!;
      final input = entity.getComponent<InputComponent>()!;
      final character = entity.getComponent<CharacterBody2D>();
      if (character != null) {
        _updateCharacter(control, character, input, deltaTime);
        return;
      }
      final velocity = entity.getComponent<VelocityComponent>();
      final bodyComp = entity.getComponent<RigidBody2D>();
      if (velocity == null || bodyComp == null) return;

      final wasGrounded = control.isGrounded;
      control.isGrounded = bodyComp.isGrounded;
      control.justLanded = control.isGrounded && !wasGrounded;

      if (control.invulnerabilityTimer > 0) {
        control.invulnerabilityTimer -= deltaTime;
      }

      _tickJumpTimers(control, input, deltaTime);
      // What it stands on moves it too: its own speed is what is left.
      final ground = control.isGrounded ? groundVelocityOf(bodyComp) : Offset.zero;
      // On a slope, run as on the flat, along the ground.
      final slope = _slopeUnder(control, bodyComp);
      if (slope != null) velocity.velocity.x = _speedAlong(slope, velocity);
      velocity.velocity.x =
          ground.dx + _horizontal(control, input, velocity.velocity.x - ground.dx, deltaTime);
      final jumped = _applyJump(control, velocity, input);
      if (slope != null && !jumped) {
        _followSlope(slope, control, bodyComp, velocity);
      } else {
        // Over the top of a slope: what carried the character up it would
        // carry it into the air. Only running speed — a spring or a stomp
        // launches much faster, and still does.
        final up = -velocity.velocity.y;
        if (_wasOnSlope[entity] == true &&
            !jumped &&
            up > 0 &&
            up <= control.moveSpeed + slopeSnap) {
          velocity.velocity.y = 0;
        }
        _applyGravityFeel(control, bodyComp, velocity, input, ground.dy);
        _clampFallSpeed(control, velocity);
      }
      _wasOnSlope[entity] = slope != null && !jumped;
      if (!jumped) _followGroundDown(velocity, ground);
    });
  }

  /// The same feel for a [CharacterBody2D]: its run speed lives in
  /// [CharacterBody2D.moveVelocity], and the mover takes slopes, steps and
  /// moving platforms as they come.
  void _updateCharacter(
    PlayerControlComponent control,
    CharacterBody2D body,
    InputComponent input,
    double deltaTime,
  ) {
    final wasGrounded = control.isGrounded;
    control.isGrounded = body.isGrounded;
    control.justLanded = control.isGrounded && !wasGrounded;
    if (control.invulnerabilityTimer > 0) {
      control.invulnerabilityTimer -= deltaTime;
    }

    _tickJumpTimers(control, input, deltaTime);
    body.moveVelocity = Offset(
      _horizontal(control, input, body.moveVelocity.dx, deltaTime),
      0,
    );

    final hasJump =
        control.jumpsUsed < control.maxJumps &&
        (control.coyoteTimer > 0 || control.jumpsUsed > 0);
    if (control.jumpBufferTimer > 0 && hasJump) {
      launch(body, control.jumpSpeed);
      control
        ..jumpsUsed += 1
        ..jumpBufferTimer = 0.0
        ..coyoteTimer = 0.0;
    }
    control.jumpHeldLastFrame = input.isDown(jumpAction);

    if (body.velocity.dy < 0 || body.pendingJump != null) {
      control.isRising = true;
      body.gravityScale = input.isDown(jumpAction)
          ? control.riseGravityScale
          : control.jumpCutGravityScale;
    } else {
      control.isRising = false;
      body.gravityScale = control.fallGravityScale;
    }
    if (body.velocity.dy > control.maxFallSpeed) {
      body.velocity = Offset(body.velocity.dx, control.maxFallSpeed);
    }
  }

  /// Sends a character up at [speed]: from the ground as a jump, and in the
  /// air (coyote time, a second jump, a stomp) as its speed itself — the
  /// mover takes a jump only from the ground.
  static void launch(CharacterBody2D body, double speed) {
    body
      ..jump(speed)
      ..velocity = Offset(body.velocity.dx, -speed); // up is -Y
  }

  // ── Slopes ───────────────────────────────────────────────────────────────

  /// Whether each character was on a slope last frame.
  final Expando<bool> _wasOnSlope = Expando('wasOnSlope');

  /// The ground's normal when the character stands on a slope it can walk,
  /// scaled to length 1; null on level ground, in the air, or on ground too
  /// steep to stand on.
  Offset? _slopeUnder(
    PlayerControlComponent control,
    RigidBody2D body,
  ) {
    if (!control.isGrounded) return null;
    final n = body.groundNormal;
    final length = n.distance;
    if (length == 0) return null;
    final unit = n / length;
    // Level ground: gravity holds the character down, as it always has.
    if (unit.dx.abs() < 0.02 || unit.dy >= 0) return null;
    // Too steep: it slides.
    if (-unit.dy < math.cos(maxSlopeDegrees * math.pi / 180)) return null;
    return unit;
  }

  /// How fast the character moves along the ground with normal [n],
  /// rightwards positive — what running on the flat would call its speed.
  static double _speedAlong(Offset n, VelocityComponent velocity) =>
      velocity.velocity.x * -n.dy + velocity.velocity.y * n.dx;

  /// Moves the character along the slope at the speed [_applyHorizontal]
  /// chose, pressed gently into it, with gravity off: standing still stays
  /// still, running uphill keeps its speed, running downhill stays on the
  /// ground.
  void _followSlope(
    Offset n,
    PlayerControlComponent control,
    RigidBody2D body,
    VelocityComponent velocity,
  ) {
    final speed = velocity.velocity.x;
    // Along the ground, rightwards: the normal turned a quarter clockwise.
    final tx = -n.dy;
    final ty = n.dx;
    // Held to the slope unless climbing it: going up, the ground holds the
    // character; pressed into it as well, its corner would catch where the
    // next tile begins.
    final climbing = ty * speed < 0;
    final snap = climbing ? 0.0 : slopeSnap;
    velocity.velocity.x = tx * speed - n.dx * snap;
    velocity.velocity.y = ty * speed - n.dy * snap;
    body.gravityScale = 0;
    control.isRising = false;
  }

  /// Maintains coyote time and the jump buffer.
  ///
  /// Both are forgiveness windows: coyote time covers pressing jump just after
  /// walking off a ledge, the buffer covers pressing it just before landing.
  /// Between them, almost every "I definitely pressed jump" complaint goes
  /// away.
  void _tickJumpTimers(
    PlayerControlComponent control,
    InputComponent input,
    double deltaTime,
  ) {
    if (control.isGrounded) {
      control.coyoteTimer = control.coyoteTime;
      control.jumpsUsed = 0;
      control.isRising = false;
    } else if (control.coyoteTimer > 0) {
      control.coyoteTimer -= deltaTime;
    }

    final jumpHeld = input.isDown(jumpAction);
    final pressedThisFrame = jumpHeld && !control.jumpHeldLastFrame;

    if (pressedThisFrame) {
      control.jumpBufferTimer = control.jumpBufferTime;
    } else if (control.jumpBufferTimer > 0) {
      control.jumpBufferTimer -= deltaTime;
    }
  }

  /// The horizontal speed after [deltaTime], from [currentX]: towards the
  /// input direction, or slowing to a stop.
  ///
  /// Acceleration rather than a direct velocity write, and a lower rate in the
  /// air than on the ground, so a jump commits to its arc instead of being
  /// freely steerable mid-flight.
  double _horizontal(
    PlayerControlComponent control,
    InputComponent input,
    double currentX,
    double deltaTime,
  ) {
    final moveX = input.vector(moveAction).dx;
    if (moveX.abs() > 0.01) {
      control.facing = moveX > 0 ? 1 : -1;
      final target = moveX * control.moveSpeed;
      final rate = control.isGrounded
          ? control.acceleration
          : control.airAcceleration;
      final delta = rate * deltaTime;
      return (target - currentX).abs() <= delta
          ? target
          : currentX + delta * (target > currentX ? 1 : -1);
    }
    final friction = control.isGrounded
        ? control.groundFriction
        : control.airFriction;
    final drop = friction * deltaTime;
    return currentX.abs() <= drop
        ? 0.0
        : currentX - drop * (currentX > 0 ? 1 : -1);
  }

  /// Consumes a buffered jump if one is available. Returns whether it
  /// jumped.
  bool _applyJump(
    PlayerControlComponent control,
    VelocityComponent velocity,
    InputComponent input,
  ) {
    final hasJump =
        control.jumpsUsed < control.maxJumps &&
        (control.coyoteTimer > 0 || control.jumpsUsed > 0);

    var jumped = false;
    if (control.jumpBufferTimer > 0 && hasJump) {
      velocity.velocity.y = -control.jumpSpeed; // screen space: up is -Y
      control.jumpsUsed++;
      control.jumpBufferTimer = 0.0;
      control.coyoteTimer = 0.0;
      control.isRising = true;
      jumped = true;
    }

    control.jumpHeldLastFrame = input.isDown(jumpAction);
    return jumped;
  }

  /// Swaps gravity between three regimes so the jump arc reads well.
  ///
  /// Real gravity gives a symmetric parabola, which feels floaty at the apex
  /// and unresponsive on release. Falling harder than rising, and harder still
  /// when jump is let go early, is what turns one button into both a hop and a
  /// full leap.
  ///
  /// [groundDy] is the vertical speed of what it stands on: riding a rising
  /// platform is not rising.
  void _applyGravityFeel(
    PlayerControlComponent control,
    RigidBody2D bodyComp,
    VelocityComponent velocity,
    InputComponent input,
    double groundDy,
  ) {
    if (velocity.velocity.y - groundDy < 0) {
      control.isRising = true;
      bodyComp.gravityScale = input.isDown(jumpAction)
          ? control.riseGravityScale
          : control.jumpCutGravityScale;
    } else {
      control.isRising = false;
      bodyComp.gravityScale = control.fallGravityScale;
    }
  }

  /// Caps downward speed.
  ///
  /// Uncapped, a long fall builds enough speed to tunnel through thin
  /// platforms between steps, and the landing becomes impossible to read.
  void _clampFallSpeed(
    PlayerControlComponent control,
    VelocityComponent velocity,
  ) {
    if (velocity.velocity.y > control.maxFallSpeed) {
      velocity.velocity.y = control.maxFallSpeed;
    }
  }

  /// The velocity of what [body] stands on, in world units a second: a
  /// moving platform's ([MovingPlatformComponent.currentVelocity]), or any
  /// other kinematic body's; zero for ground that does not move.
  ///
  /// Contact friction alone does not carry a character on a moving platform —
  /// they visibly slide toward its trailing edge. Running relative to the
  /// ground is what makes standing still on a moving platform actually mean
  /// standing still: the run speed is worked out from the velocity less
  /// this, and this is added back.
  static Offset groundVelocityOf(RigidBody2D body) {
    final ground = body.groundEntity;
    if (ground == null || !ground.isAlive) return Offset.zero;
    final platform = ground.getComponent<MovingPlatformComponent>();
    if (platform != null) {
      return platform.isMoving ? platform.currentVelocity : Offset.zero;
    }
    final rigid = ground.getComponent<RigidBody2D>();
    return rigid != null && rigid.bodyType == BodyType.kinematic
        ? rigid.linearVelocity
        : Offset.zero;
  }

  /// Keeps a rider on ground that moves down: at least as fast down as it.
  ///
  /// Gravity alone lets a platform going down drop away under the rider, who
  /// lands again a moment later — grounded, airborne, grounded, a landing each
  /// time. Only downward motion: what moves up pushes the rider up itself.
  static void _followGroundDown(VelocityComponent velocity, Offset ground) {
    if (ground.dy > 0 && velocity.velocity.y < ground.dy) {
      velocity.velocity.y = ground.dy;
    }
  }

  /// Applies a stomp bounce, e.g. after defeating an enemy from above.
  static void bounce(Entity entity, {double? speed}) {
    final control = entity.getComponent<PlayerControlComponent>();
    if (control == null) return;
    final character = entity.getComponent<CharacterBody2D>();
    final velocity = entity.getComponent<VelocityComponent>();
    if (character != null) {
      launch(character, speed ?? control.stompBounceSpeed);
    } else if (velocity != null) {
      velocity.velocity.y = -(speed ?? control.stompBounceSpeed);
    } else {
      return;
    }
    // Refund one air jump so stomp chains stay possible — and stay in a
    // jump: at 0, past coyote time, no jump at all would be left.
    control.jumpsUsed = math.max(1, control.jumpsUsed - 1);
    control.isRising = true;
  }
}
