// PlayerControlSystem: horizontal movement and the jump's feel.
//
// Driven through a bare World with only the systems under test registered, so
// these stay fast and do not need a full Engine (which would also pull in a
// native physics world per test).

import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_platformer_kit/just_platformer_kit.dart';

/// Builds a player entity with everything [PlayerControlSystem] requires.
Entity _player(World world, {double x = 0, double y = 0}) =>
    world.createEntityWithComponents([
      TransformComponent(position: Vector3(x, y, 0)),
      VelocityComponent(),
      RigidBody2DComponent(lockRotation: true),
      Collider2DComponent(size: Vector2(32, 48)),
      PlayerControlComponent(),
      InputComponent(),
      HealthComponent(maxHealth: 3),
      TagComponent('player'),
    ], name: 'Player');

void main() {
  group('PlayerControlSystem — horizontal movement', () {
    late World world;
    late Entity player;

    setUp(() {
      world = World()..initialize();
      world.addSystem(PlayerControlSystem());
      player = _player(world);
    });

    test('accelerates toward input rather than snapping to top speed', () {
      final input = player.getComponent<InputComponent>()!
        ..setVector('move', const Offset(1, 0));
      final control = player.getComponent<PlayerControlComponent>()!;
      final velocity = player.getComponent<VelocityComponent>()!;

      world.update(1 / 60);
      final afterOneFrame = velocity.velocity.x;

      expect(afterOneFrame, greaterThan(0));
      expect(
        afterOneFrame,
        lessThan(control.moveSpeed),
        reason: 'one frame should not reach top speed',
      );
      expect(input.vector('move').dx, 1);
    });

    test('reaches top speed and stops there', () {
      player.getComponent<InputComponent>()!.setVector(
        'move',
        const Offset(1, 0),
      );
      final control = player.getComponent<PlayerControlComponent>()!;

      for (var i = 0; i < 60; i++) {
        world.update(1 / 60);
      }

      expect(
        player.getComponent<VelocityComponent>()!.velocity.x,
        closeTo(control.moveSpeed, 0.01),
      );
    });

    test('decelerates to a full stop when input is released', () {
      final input = player.getComponent<InputComponent>()!
        ..setVector('move', const Offset(1, 0));
      final bodyComp = player.getComponent<RigidBody2DComponent>()!
        ..isGrounded = true;

      for (var i = 0; i < 30; i++) {
        world.update(1 / 60);
      }
      input.setVector('move', Offset.zero);
      for (var i = 0; i < 30; i++) {
        world.update(1 / 60);
      }

      expect(player.getComponent<VelocityComponent>()!.velocity.x, 0.0);
      expect(bodyComp.isGrounded, isTrue);
    });

    test('tracks facing across idle frames', () {
      final input = player.getComponent<InputComponent>()!
        ..setVector('move', const Offset(-1, 0));
      final control = player.getComponent<PlayerControlComponent>()!;

      world.update(1 / 60);
      expect(control.facing, -1);

      input.setVector('move', Offset.zero);
      world.update(1 / 60);
      expect(control.facing, -1, reason: 'facing persists while idle');
    });
  });

  group('PlayerControlSystem — jump feel', () {
    late World world;
    late Entity player;
    late InputComponent input;
    late PlayerControlComponent control;
    late RigidBody2DComponent bodyComp;
    late VelocityComponent velocity;

    setUp(() {
      world = World()..initialize();
      world.addSystem(PlayerControlSystem());
      player = _player(world);
      input = player.getComponent<InputComponent>()!;
      control = player.getComponent<PlayerControlComponent>()!;
      bodyComp = player.getComponent<RigidBody2DComponent>()!;
      velocity = player.getComponent<VelocityComponent>()!;
    });

    test('jumps when grounded', () {
      bodyComp.isGrounded = true;
      world.update(1 / 60); // settle grounded state

      input.setDown('jump', true);
      world.update(1 / 60);

      expect(velocity.velocity.y, closeTo(-control.jumpSpeed, 0.01));
      expect(control.jumpsUsed, 1);
    });

    test('coyote time lets a jump land just after leaving a ledge', () {
      bodyComp.isGrounded = true;
      world.update(1 / 60);

      // Walk off the edge.
      bodyComp.isGrounded = false;
      world.update(1 / 60);

      // Press jump a couple of frames late — still inside the window.
      input.setDown('jump', true);
      world.update(1 / 60);

      expect(
        velocity.velocity.y,
        closeTo(-control.jumpSpeed, 0.01),
        reason: 'jump pressed within coyoteTime should still fire',
      );
    });

    test('coyote time expires', () {
      bodyComp.isGrounded = true;
      world.update(1 / 60);
      bodyComp.isGrounded = false;

      // Well past coyoteTime (0.10s).
      for (var i = 0; i < 20; i++) {
        world.update(1 / 60);
      }
      velocity.setVelocityXY(0, 0);

      input.setDown('jump', true);
      world.update(1 / 60);

      expect(
        velocity.velocity.y,
        greaterThanOrEqualTo(0),
        reason: 'jump should not fire once the window has closed',
      );
    });

    test('a jump pressed just before landing is buffered and replayed', () {
      bodyComp.isGrounded = false;
      // Press while still airborne.
      input.setDown('jump', true);
      world.update(1 / 60);
      input.setDown('jump', false);
      world.update(1 / 60);

      expect(velocity.velocity.y, greaterThanOrEqualTo(0));

      // Touch down inside the buffer window.
      bodyComp.isGrounded = true;
      world.update(1 / 60);

      expect(
        velocity.velocity.y,
        closeTo(-control.jumpSpeed, 0.01),
        reason: 'buffered jump should fire on landing',
      );
    });

    test('releasing jump early raises gravity, cutting the arc short', () {
      bodyComp.isGrounded = true;
      world.update(1 / 60);

      input.setDown('jump', true);
      world.update(1 / 60);
      final heldScale = bodyComp.effectiveGravityScale;

      input.setDown('jump', false);
      world.update(1 / 60);
      final releasedScale = bodyComp.effectiveGravityScale;

      expect(heldScale, closeTo(control.riseGravityScale, 1e-9));
      expect(releasedScale, closeTo(control.jumpCutGravityScale, 1e-9));
      expect(releasedScale, greaterThan(heldScale));
      expect(bodyComp.gravityScale, 1, reason: 'through the override only');
    });

    test('falling uses a heavier gravity than rising', () {
      velocity.setVelocityXY(0, 100); // falling
      world.update(1 / 60);

      expect(
        bodyComp.gravityScaleOverride,
        closeTo(control.fallGravityScale, 1e-9),
      );
      expect(control.fallGravityScale, greaterThan(control.riseGravityScale));
      expect(bodyComp.gravityScale, 1, reason: 'through the override only');
    });

    test('fall speed is capped', () {
      velocity.setVelocityXY(0, control.maxFallSpeed * 4);
      world.update(1 / 60);

      expect(velocity.velocity.y, closeTo(control.maxFallSpeed, 0.01));
    });

    test('a single jump cannot be repeated in mid-air', () {
      bodyComp.isGrounded = true;
      world.update(1 / 60);
      input.setDown('jump', true);
      world.update(1 / 60);
      bodyComp.isGrounded = false;

      // Release and press again while airborne.
      input.setDown('jump', false);
      world.update(1 / 60);
      velocity.setVelocityXY(0, 200);
      input.setDown('jump', true);
      world.update(1 / 60);

      expect(control.jumpsUsed, 1);
      expect(velocity.velocity.y, greaterThan(0), reason: 'still falling');
    });

    test('maxJumps = 2 allows a double jump', () {
      control.maxJumps = 2;
      bodyComp.isGrounded = true;
      world.update(1 / 60);

      input.setDown('jump', true);
      world.update(1 / 60);
      bodyComp.isGrounded = false;
      input.setDown('jump', false);
      world.update(1 / 60);

      velocity.setVelocityXY(0, 200);
      input.setDown('jump', true);
      world.update(1 / 60);

      expect(control.jumpsUsed, 2);
      expect(velocity.velocity.y, closeTo(-control.jumpSpeed, 0.01));
    });
  });
}
