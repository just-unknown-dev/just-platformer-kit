// A patrolling enemy turns at a wall, not just at the end of its range; a
// chaser stops at the edge of what it walks on rather than following the
// player off it. Through real physics, as the probes are rays.

import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_platformer_kit/just_platformer_kit.dart';

void main() {
  for (final (name, make) in [
    ('native Box2D', () => PhysicsEngineFactory.create2D()..initialize()),
    ('pure Dart', () => Physics2DEngine.pureDart()..initialize()),
  ]) {
    group(name, () => _probes(make));
  }
}

void _probes(Physics2DEngine Function() make) {
  late Physics2DEngine physics;
  late World world;

  setUp(() {
    physics = make()..setGravity(0, 2200);
    world = World()..initialize();
    world
      ..addSystem(PatrolEnemySystem(physics: physics))
      ..addSystem(Physics2DSystem(physics));
  });
  tearDown(() {
    world.dispose();
    physics.dispose();
  });

  /// A static block centred on (x, y).
  Entity block(double x, double y, double w, double h) =>
      world.createEntityWithComponents([
        TransformComponent(position: Vector3(x, y, 0)),
        RigidBody2DComponent(bodyType: Body2DType.static, friction: 0.2),
        Collider2DComponent(size: Vector2(w, h)),
      ]);

  /// An enemy standing on ground whose top is at y = 100.
  Entity enemy(double x, PatrolEnemyComponent behaviour) =>
      world.createEntityWithComponents([
        TransformComponent(position: Vector3(x, 81, 0)),
        VelocityComponent(),
        RigidBody2DComponent(
          lockRotation: true,
          friction: 0.2,
          linearDamping: 0,
        ),
        Collider2DComponent(size: Vector2(36, 36)),
        behaviour,
      ], name: 'Enemy');

  double x(Entity e) => e.getComponent<TransformComponent>()!.position.x;

  void run(int frames) {
    for (var i = 0; i < frames; i++) {
      world.update(1 / 60);
    }
  }

  test('a patrol turns back at a wall well inside its range', () {
    block(0, 120, 2000, 40); // the floor, its top at y = 100
    block(300, 60, 40, 80); // a wall at x = 280..320
    final e = enemy(150, PatrolEnemyComponent(patrolRange: 1000));
    var turned = false;
    var furthest = x(e);
    for (var i = 0; i < 180; i++) {
      run(1);
      if (x(e) > furthest) furthest = x(e);
      if (e.getComponent<PatrolEnemyComponent>()!.facing == -1) turned = true;
    }
    // Walked there: on flat ground the ledge probe finds the ground it
    // stands in a hair deep (the solver's slop), so it does not turn early.
    expect(furthest, greaterThan(240));
    expect(turned, isTrue);
    expect(x(e), lessThan(200), reason: 'and walked back');
  });

  test('a coin ahead is walked through, not turned from', () {
    block(0, 120, 2000, 40);
    // A sensor stacked on a sensor, both right in the wall probe's way.
    for (final w in [24.0, 30.0]) {
      world.createEntityWithComponents([
        TransformComponent(position: Vector3(180, 81, 0)),
        RigidBody2DComponent(bodyType: Body2DType.static, isSensor: true),
        Collider2DComponent(size: Vector2(w, w)),
      ]);
    }
    final e = enemy(150, PatrolEnemyComponent(patrolRange: 1000));
    var turned = false;
    for (var i = 0; i < 30; i++) {
      run(1);
      if (e.getComponent<PatrolEnemyComponent>()!.facing == -1) turned = true;
    }
    expect(turned, isFalse);
    expect(x(e), greaterThan(180), reason: 'past the coins');
  });

  test('a player ahead is walked into, not turned from', () {
    block(0, 120, 2000, 40);
    world.createEntityWithComponents([
      TransformComponent(position: Vector3(200, 76, 0)),
      RigidBody2DComponent(lockRotation: true),
      Collider2DComponent(size: Vector2(32, 48)),
      TagComponent(PlatformerTags.player),
    ]);
    final e = enemy(150, PatrolEnemyComponent(patrolRange: 1000));
    run(20);
    expect(e.getComponent<PatrolEnemyComponent>()!.facing, 1);
  });

  test('a chaser stops at a ledge rather than following the player off it', () {
    block(0, 120, 600, 40); // ground from x = -300 to 300
    world.createEntityWithComponents([
      TransformComponent(position: Vector3(520, 300, 0)),
      TagComponent(PlatformerTags.player),
    ]);
    final e = enemy(
      100,
      PatrolEnemyComponent(behaviour: EnemyBehaviour.chase, aggroRange: 600),
    );
    run(240);
    expect(x(e), lessThan(300), reason: 'still on the ground');
    expect(e.getComponent<TransformComponent>()!.position.y, lessThan(100));
  });
}
