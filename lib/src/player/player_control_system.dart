library;

import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:just_game_engine/just_game_engine.dart';

import '../platforms/platforms.dart';
import 'player_control_component.dart';
import 'player_ground_probe.dart';

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
/// * a [RigidBody2DComponent] (with a [VelocityComponent]): it writes the velocity
///   and [RigidBody2DComponent.gravityScaleOverride] and lets the physics step
///   integrate them, rather than moving the transform itself — a transform
///   write registers as a teleport and breaks collision resolution;
/// * a [CharacterBody2DComponent]: it sets [CharacterBody2DComponent.moveVelocity], jumps and
///   [CharacterBody2DComponent.gravityScaleOverride], and leaves slopes, steps
///   and moving platforms to the character mover.
///
/// The feel is the same either way. See [PlayerControlComponent] for what
/// each tuning value buys. Its gravities go through the body's run-time
/// override, never its saved `gravityScale`: a level saved mid-jump keeps
/// the gravity scale it was authored with.
///
/// A rigid-body player finds its ground with two short rays down from its
/// feet (when the world has a [Physics2DSystem]), not by its contacts alone:
/// a contact ends for a step whenever the body lifts a hair off a ramp it
/// runs down, and where two tiles of a ramp meet, the corner of the solid
/// box under the next tile gives a contact with a flat normal. The rays find
/// the ramp's own face and how far below the feet it is; a grounded player
/// is brought down onto it — up to [PlayerControlComponent.snapDistance]
/// beyond what its speed drops it — rather than leaving it.
class PlayerControlSystem extends System {
  PlayerControlSystem({this.moveAction = 'move', this.jumpAction = 'jump'});

  /// Name of the vector2 action supplying horizontal movement.
  final String moveAction;

  /// Name of the button action for jumping.
  final String jumpAction;

  /// How far below the feet ground counts as touched, in world units: what
  /// a body at rest floats or sinks by.
  static const double _touching = 1.0;

  /// How fast a player moves away from the ground it stood on, in world
  /// units a step, when it is leaving it: a jump, a spring, a knock-back.
  /// Well above what holding it to a slope moves it by, and the kick a
  /// tile's buried corner can give it.
  static const double _leaving = 4;

  /// The steepest slope whose drop is followed, whatever a player's
  /// [PlayerControlComponent.maxSlopeDegrees]: past it the drop per step
  /// grows without bound.
  static const double _steepestFollowed = 80 * math.pi / 180;

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
    // player (its velocity, its body's gravity) is left as it is.
    if (deltaTime <= 0) return;
    _physics = world.getSystem<Physics2DSystem>();
    forEach((entity) {
      if (!entity.isActive) return;

      final control = entity.getComponent<PlayerControlComponent>()!;
      final input = entity.getComponent<InputComponent>()!;
      final character = entity.getComponent<CharacterBody2DComponent>();
      if (character != null) {
        _updateCharacter(control, character, input, deltaTime);
        return;
      }
      final velocity = entity.getComponent<VelocityComponent>();
      final bodyComp = entity.getComponent<RigidBody2DComponent>();
      if (velocity == null || bodyComp == null) return;

      final wasGrounded = control.isGrounded;
      final footing = _footing(entity, control, bodyComp, velocity, deltaTime);
      control.isGrounded = footing != null;
      control.justLanded = control.isGrounded && !wasGrounded;
      // What leaving is measured from next step: ground it can stand on.
      final normal = footing?.normal;
      _groundNormal[entity] = normal != null && _standable(control, normal)
          ? normal
          : null;

      if (control.invulnerabilityTimer > 0) {
        control.invulnerabilityTimer -= deltaTime;
      }

      _tickJumpTimers(control, input, deltaTime);
      // What it stands on moves it too: its own speed is what is left.
      final ground = footing == null
          ? Offset.zero
          : _velocityOfGround(footing.entity);
      // On a slope, run as on the flat, along the ground.
      final slope = footing == null ? null : _walkable(control, footing.normal);
      if (slope != null) velocity.velocity.x = _speedAlong(slope, velocity);
      velocity.velocity.x =
          ground.dx +
          _horizontal(
            control,
            input,
            velocity.velocity.x - ground.dx,
            deltaTime,
          );
      final jumped = _applyJump(control, velocity, input);
      if (slope != null && !jumped) {
        _followSlope(
          slope,
          footing!.gap,
          control,
          bodyComp,
          velocity,
          deltaTime,
        );
      } else {
        // Over the top of a slope: what carried the character up it would
        // carry it into the air. Only running speed — a spring or a stomp
        // launches much faster, and still does.
        final up = -velocity.velocity.y;
        if (_wasOnSlope[entity] == true &&
            !jumped &&
            up > 0 &&
            up <= control.moveSpeed) {
          velocity.velocity.y = 0;
        }
        _applyGravityFeel(control, bodyComp, velocity, input, ground.dy);
        _clampFallSpeed(control, velocity);
      }
      _wasOnSlope[entity] = slope != null && !jumped;
      if (!jumped) _followGroundDown(velocity, ground);
    });
  }

  // ── Ground ───────────────────────────────────────────────────────────────

  /// The world's 2-D physics, found each step: what the ground probe asks.
  Physics2DSystem? _physics;

  final PlayerGroundProbe _probe = PlayerGroundProbe();

  /// Each rigid-body player's ground normal last step; null in the air.
  final Expando<Offset> _groundNormal = Expando('groundNormal');

  /// What a rigid-body player stands on this step, or null in the air: the
  /// ground the probe finds under its feet, or — without a physics system,
  /// or past the probe's reach — what its contacts say.
  ///
  /// Ground counts when it touches the feet, or when the player stood last
  /// step and the ground has dropped away by no more than its
  /// [PlayerControlComponent.snapDistance] plus what running at its speed
  /// down its steepest slope drops it. Not while it leaves the ground — a
  /// jump, a spring, a knock-back moving it away from the surface it stood
  /// on faster than four units a step.
  ({Offset normal, Entity? entity, double gap})? _footing(
    Entity entity,
    PlayerControlComponent control,
    RigidBody2DComponent bodyComp,
    VelocityComponent velocity,
    double deltaTime,
  ) {
    final contact = bodyComp.isGrounded
        ? (
            normal: bodyComp.groundNormal,
            entity: bodyComp.groundEntity,
            // Its distance unknown: held where it is, not drawn down.
            gap: 0.0,
          )
        : null;
    final physics = _physics;
    final body = entity.getComponent<Physics2DBodyRefComponent>()?.body;
    if (physics == null || body == null) return contact;

    final slope = math.min(
      control.maxSlopeDegrees * math.pi / 180,
      _steepestFollowed,
    );
    final reach =
        math.max(0.0, control.snapDistance) +
        velocity.velocity.x.abs() * deltaTime * math.tan(math.max(0.0, slope));
    final found = _probe.probe(physics.physics, body, reach);
    // Too steep to stand on: it slides, as its contacts have it.
    final hit = found != null && -found.normal.dy >= math.cos(slope) - 1e-9
        ? found
        : null;

    final ground = hit == null ? null : physics.entityOf(hit.body);
    final moving = _velocityOfGround(ground);
    final reference = _groundNormal[entity] ?? hit?.normal;
    if (reference != null) {
      final away =
          (velocity.velocity.x - moving.dx) * reference.dx +
          (velocity.velocity.y - moving.dy) * reference.dy;
      // Leaving it — though a contact may last a step longer: in the air.
      if (away * deltaTime > _leaving) return null;
    }
    if (hit == null) return contact;

    // The top of a slope it was climbing: level ground ahead, above its
    // feet. Up the slope until its feet are at that level — taken flat
    // sooner, the corner would strike the lip and toss it up.
    final previous = _groundNormal[entity];
    if (hit.gap < -_touching &&
        previous != null &&
        _walkable(control, previous) != null &&
        _walkable(control, hit.normal) == null) {
      return (normal: previous, entity: ground, gap: 0.0);
    }

    // Ground that dropped away under feet that stood on it is followed;
    // ground below feet in the air is not stood on yet.
    if (hit.gap > _touching && !(control.isGrounded && hit.gap <= reach)) {
      return contact;
    }
    // A slope below, but something level the rays pass beside — an edge
    // under the middle of its feet — still holds it up: along the slope,
    // not drawn down onto it, or pressing on that edge it would stick there.
    if (hit.gap > _touching &&
        contact != null &&
        _walkable(control, contact.normal) == null) {
      return (normal: hit.normal, entity: ground, gap: 0.0);
    }
    // Level under the feet, but a corner already leans on a slope it can
    // walk — the foot of a ramp, or the lip of one it runs off — before a
    // ray has reached it: along that slope, as its contact has it, and over.
    // Not off the top of the slope it climbed: that is level ground now.
    if (contact != null &&
        _walkable(control, hit.normal) == null &&
        _walkable(control, contact.normal) != null &&
        (previous == null || _walkable(control, previous) == null)) {
      return contact;
    }
    return (normal: hit.normal, entity: ground, gap: hit.gap);
  }

  /// The same feel for a [CharacterBody2DComponent]: its run speed lives in
  /// [CharacterBody2DComponent.moveVelocity], and the mover takes slopes, steps and
  /// moving platforms as they come.
  void _updateCharacter(
    PlayerControlComponent control,
    CharacterBody2DComponent body,
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
      body.gravityScaleOverride = input.isDown(jumpAction)
          ? control.riseGravityScale
          : control.jumpCutGravityScale;
    } else {
      control.isRising = false;
      body.gravityScaleOverride = control.fallGravityScale;
    }
    if (body.velocity.dy > control.maxFallSpeed) {
      body.velocity = Offset(body.velocity.dx, control.maxFallSpeed);
    }
  }

  /// Sends a character up at [speed]: from the ground as a jump, and in the
  /// air (coyote time, a second jump, a stomp) as its speed itself — the
  /// mover takes a jump only from the ground.
  static void launch(CharacterBody2DComponent body, double speed) {
    body
      ..jump(speed)
      ..velocity = Offset(body.velocity.dx, -speed); // up is -Y
  }

  // ── Slopes ───────────────────────────────────────────────────────────────

  /// Whether each character was on a slope last frame.
  final Expando<bool> _wasOnSlope = Expando('wasOnSlope');

  /// Whether ground with normal [n] is level or a slope [control] can walk.
  static bool _standable(PlayerControlComponent control, Offset n) {
    final length = n.distance;
    return length > 0 &&
        -n.dy / length >= math.cos(control.maxSlopeDegrees * math.pi / 180);
  }

  /// Ground with normal [n] when it is a slope [control] can walk, its
  /// normal scaled to length 1; null on level ground, or on ground too
  /// steep to stand on.
  static Offset? _walkable(PlayerControlComponent control, Offset n) {
    final length = n.distance;
    if (length == 0) return null;
    final unit = n / length;
    // Level ground: gravity holds the character down, as it always has.
    if (unit.dx.abs() < 0.02 || unit.dy >= 0) return null;
    // Too steep: it slides.
    if (-unit.dy < math.cos(control.maxSlopeDegrees * math.pi / 180)) {
      return null;
    }
    return unit;
  }

  /// How fast the character moves along the ground with normal [n],
  /// rightwards positive — what running on the flat would call its speed.
  static double _speedAlong(Offset n, VelocityComponent velocity) =>
      velocity.velocity.x * -n.dy + velocity.velocity.y * n.dx;

  /// Moves the character along the slope at the speed [_horizontal] chose,
  /// with gravity off, brought down onto it across the [gap] between its
  /// feet and the slope: standing still stays still, running uphill keeps
  /// its speed, running downhill stays on the ground.
  ///
  /// Brought onto it, not pressed into it: a corner pressed into a ramp
  /// catches where the next tile begins, and at its top.
  ///
  /// Never brought back against its run: running down a slope, its normal
  /// leans back up it, and closing the gap along the normal pushed the
  /// character back the way it came. A box stood with its corner on a
  /// ramp's crest, held up there by the level ground beside it, was pushed
  /// back onto the crest step after step and never got going (on native
  /// Box2D). Running down, the gap is closed straight down instead: the
  /// same slope, reached in the same step.
  void _followSlope(
    Offset n,
    double gap,
    PlayerControlComponent control,
    RigidBody2DComponent body,
    VelocityComponent velocity,
    double deltaTime,
  ) {
    final speed = velocity.velocity.x;
    // Along the ground, rightwards: the normal turned a quarter clockwise.
    final tx = -n.dy;
    final ty = n.dx;
    final snap = math.max(0.0, gap) / deltaTime;
    if (snap > 0 && speed * n.dx > 0) {
      // Running down it: straight down by as much as the normal's gap is
      // high there.
      velocity.velocity.x = tx * speed;
      velocity.velocity.y = ty * speed + snap / -n.dy;
    } else {
      velocity.velocity.x = tx * speed - n.dx * snap;
      velocity.velocity.y = ty * speed - n.dy * snap;
    }
    body.gravityScaleOverride = 0;
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
    RigidBody2DComponent bodyComp,
    VelocityComponent velocity,
    InputComponent input,
    double groundDy,
  ) {
    if (velocity.velocity.y - groundDy < 0) {
      control.isRising = true;
      bodyComp.gravityScaleOverride = input.isDown(jumpAction)
          ? control.riseGravityScale
          : control.jumpCutGravityScale;
    } else {
      control.isRising = false;
      bodyComp.gravityScaleOverride = control.fallGravityScale;
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
  /// moving platform's ([MovingPlatform2DComponent.currentVelocity]), or any
  /// other kinematic body's; zero for ground that does not move.
  ///
  /// Contact friction alone does not carry a character on a moving platform —
  /// they visibly slide toward its trailing edge. Running relative to the
  /// ground is what makes standing still on a moving platform actually mean
  /// standing still: the run speed is worked out from the velocity less
  /// this, and this is added back.
  static Offset groundVelocityOf(RigidBody2DComponent body) =>
      _velocityOfGround(body.groundEntity);

  /// The velocity of [ground]: see [groundVelocityOf].
  static Offset _velocityOfGround(Entity? ground) {
    if (ground == null || !ground.isAlive) return Offset.zero;
    final platform = ground.getComponent<MovingPlatform2DComponent>();
    if (platform != null) {
      return platform.isMoving ? platform.currentVelocity : Offset.zero;
    }
    final rigid = ground.getComponent<RigidBody2DComponent>();
    return rigid != null && rigid.bodyType == Body2DType.kinematic
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
    final character = entity.getComponent<CharacterBody2DComponent>();
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
