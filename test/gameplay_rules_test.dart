// The level rules a player meets: an enemy's touch (its i-frames and which
// way it knocks you), standing in a hazard, a hazard that sends you back,
// god mode, level gravity, a stomp's refunded jump, the kill plane for what
// is not a player — and the kit's smaller promises: the falling binding of a
// character, level bounds' origin, fresh collision kinds.

import 'package:flutter/painting.dart' show Offset, Rect;
import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_platformer_kit/just_platformer_kit.dart';

const _dt = 1 / 60;

void main() {
  late World world;
  late Entity player;
  late List<EntityDamagedEvent> hits;

  Entity makePlayer({double x = 0}) => world.createEntityWithComponents([
    TransformComponent(position: Vector3(x, 0, 0)),
    VelocityComponent(),
    RigidBody2D(lockRotation: true),
    Collider2D(size: Vector2(32, 48)),
    PlayerControlComponent(),
    InputComponent(),
    HealthComponent(maxHealth: 3),
    TagComponent(PlatformerTags.player),
  ], name: 'Player');

  setUp(() {
    world = World()..initialize();
    world
      ..addSystem(PlayerControlSystem())
      ..addSystem(PlatformerGameplaySystem());
    player = makePlayer();
    hits = [];
    world.events.on<EntityDamagedEvent>(hits.add);
  });
  tearDown(() => world.dispose());

  void run(double seconds) {
    for (var t = 0.0; t < seconds - 1e-9; t += _dt) {
      world.update(_dt);
    }
  }

  double health() => player.getComponent<HealthComponent>()!.health;
  double vx() => player.getComponent<VelocityComponent>()!.velocity.x;

  group('an enemy', () {
    Entity enemy({double x = 0, int facing = 1}) =>
        world.createEntityWithComponents([
          TransformComponent(position: Vector3(x, 0, 0)),
          VelocityComponent(),
          PatrolEnemyComponent()..facing = facing,
        ], name: 'Enemy');

    void touch(Entity enemy) => world.events.fire(
      CollisionEnter2DEvent(
        point: Offset.zero,
        entityA: enemy,
        entityB: player,
        normal: const Offset(1, 0), // from the side
      ),
    );

    test('hurts once, then the player has time to get clear', () {
      final e = enemy();
      touch(e);
      run(0.3);
      touch(e);
      expect(health(), 2, reason: 'the second touch is inside the i-frames');
      run(1);
      touch(e);
      expect(health(), 1, reason: 'and after them it hurts again');
    });

    test('knocks the player away from it, whichever way it faces', () {
      // Walking right into a player on its right.
      player.getComponent<TransformComponent>()!.setPositionXY(40, 0);
      touch(enemy(facing: 1));
      expect(vx(), greaterThan(0));

      world.dispose();
      world = World()..initialize();
      world.addSystem(PlatformerGameplaySystem());
      player = makePlayer(x: -40);
      // Walking right, touched from behind by a player on its left.
      touch(enemy(facing: 1));
      expect(vx(), lessThan(0));
    });
  });

  group('a hazard', () {
    Entity spikes({bool respawnOnHit = false}) =>
        world.createEntityWithComponents([
          TransformComponent(),
          RigidBody2D(isSensor: true),
          Collider2D(size: Vector2(64, 16)),
          HazardComponent(respawnOnHit: respawnOnHit),
        ], name: 'Spikes');

    test('keeps hurting a player who stays in it, once per i-frames', () {
      final s = spikes();
      world.events.fire(SensorEnter2DEvent(sensor: s, other: player));
      run(2.1);
      expect(hits, hasLength(3));
      expect(health(), 0);
    });

    test('stops once the player is out of it', () {
      final s = spikes();
      world.events.fire(SensorEnter2DEvent(sensor: s, other: player));
      run(0.5);
      world.events.fire(SensorExit2DEvent(sensor: s, other: player));
      run(2);
      expect(hits, hasLength(1));
    });

    test('with respawnOnHit, asks for the player to be sent back', () {
      final s = spikes(respawnOnHit: true);
      world.events.fire(SensorEnter2DEvent(sensor: s, other: player));
      expect(hits.single.respawn, isTrue);
      expect(hits.single.wasFatal, isFalse);
    });

    test('hurts nothing that is invulnerable', () {
      player.getComponent<HealthComponent>()!
        ..health = 1
        ..isInvulnerable = true;
      world.events.fire(SensorEnter2DEvent(sensor: spikes(), other: player));
      expect(hits, isEmpty, reason: 'no hit, so no fatal hit to respawn after');
      expect(health(), 1);
    });
  });

  test("a stomp gives back the air jump it would take, and no more", () {
    final control = player.getComponent<PlayerControlComponent>()!;
    final body = player.getComponent<RigidBody2D>()!;
    final input = player.getComponent<InputComponent>()!;
    final velocity = player.getComponent<VelocityComponent>()!;

    void jumpFromGround() {
      body.isGrounded = true;
      world.update(_dt);
      input.setDown('jump', true);
      world.update(_dt);
      body.isGrounded = false;
      input.setDown('jump', false);
      run(0.3); // past coyote time
    }

    control.maxJumps = 2;
    jumpFromGround();
    PlayerControlSystem.bounce(player);
    velocity.setVelocityXY(0, 100);
    input.setDown('jump', true);
    world.update(_dt);
    expect(velocity.velocity.y, closeTo(-control.jumpSpeed, 0.01), reason: 'the double jump is still there');

    input.setDown('jump', false);
    control.maxJumps = 1;
    jumpFromGround();
    PlayerControlSystem.bounce(player);
    velocity.setVelocityXY(0, 100);
    input.setDown('jump', true);
    world.update(_dt);
    expect(velocity.velocity.y, greaterThan(0), reason: 'one jump, and it was used');
  });

  test('something that is not a player falling past the kill plane is removed', () {
    world.createEntityWithComponents([
      LevelBoundsComponent(bounds: const Rect.fromLTWH(0, 0, 1000, 400), killPlaneY: 600),
    ]);
    final enemy = world.createEntityWithComponents([
      TransformComponent(position: Vector3(0, 700, 0)),
      HealthComponent(maxHealth: 1),
    ]);
    final fell = <FellOutOfWorldEvent>[];
    world.events.on<FellOutOfWorldEvent>(fell.add);
    player.getComponent<TransformComponent>()!.setPositionXY(0, 700);
    world.update(_dt);
    expect(fell.map((e) => e.entity), containsAll([enemy, player]));
    expect(enemy.isAlive, isFalse);
    expect(player.isAlive, isTrue, reason: 'the game brings players back');
  });

  test("a level's gravity goes on the physics when it starts and when it changes", () {
    final physics = PhysicsEngine.pureDart()..initialize();
    addTearDown(physics.dispose);
    world.addSystem(PlatformerGameplaySystem(physics: physics));
    final bounds = LevelBoundsComponent(gravityY: 1000);
    world.createEntityWithComponents([bounds]);
    world.update(_dt);
    expect(physics.gravity.y, 1000);

    physics.setGravity(0, 800); // game code: a low-gravity zone
    world.update(_dt);
    expect(physics.gravity.y, 800, reason: 'left alone while the level does not change it');

    bounds.gravityY = 1500;
    world.update(_dt);
    expect(physics.gravity.y, 1500);
  });

  test('a character falls by its own velocity, for the falling binding', () {
    PlatformerKit.registerAnimatorBindings(world.context.animatorBindings);
    final body = CharacterBody2D()..velocity = const Offset(0, 300);
    final hero = world.createEntityWithComponents([
      TransformComponent(),
      body,
      PlayerControlComponent(),
    ]);
    final falling = world.context.animatorBindings.of('falling')!;
    expect(falling(hero), isTrue);
    body.velocity = const Offset(0, -300);
    expect(falling(hero), isFalse);
  });

  test("level bounds' origin moves them, keeping their size", () {
    final schema = PlatformerSchemas.levelBounds;
    final bounds = LevelBoundsComponent(bounds: const Rect.fromLTWH(0, 0, 4000, 1200));
    schema.field('boundsLeft')!.write!(bounds, 500.0);
    schema.field('boundsTop')!.write!(bounds, -100.0);
    expect(bounds.bounds, const Rect.fromLTWH(500, -100, 4000, 1200));

    final loaded = schema.decode({
      'type': 'LevelBoundsComponent',
      'fields': {'boundsLeft': 5000},
    });
    expect(loaded.bounds.width, 4000, reason: 'a size left out keeps its default');
  });

  test('the collision kinds are made afresh, so a hot reload reaches them', () {
    expect(identical(PlatformerCollisionKinds.hazard, PlatformerCollisionKinds.hazard), isFalse);
  });
}
