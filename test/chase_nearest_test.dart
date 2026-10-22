// With two players, a chaser goes after the nearer one — not whichever
// happened to spawn first.

import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_platformer_kit/just_platformer_kit.dart';

void main() {
  late World world;
  late PhysicsEngine physics;

  setUp(() {
    world = World()..initialize();
    physics = PhysicsEngine()..initialize();
    world.addSystem(PatrolEnemySystem(physics: physics));
  });
  tearDown(() {
    world.dispose();
    physics.dispose();
  });

  Entity player(double x) => world.createEntityWithComponents([
    TransformComponent(position: Vector3(x, 0, 0)),
    TagComponent('player'),
  ]);

  Entity chaser() => world.createEntityWithComponents([
    TransformComponent(position: Vector3.zero()),
    VelocityComponent(),
    PatrolEnemyComponent(
      behaviour: EnemyBehaviour.chase,
      aggroRange: 400,
      turnAtLedge: false,
    ),
  ]);

  int facing(Entity e) => e.getComponent<PatrolEnemyComponent>()!.facing;

  test('it turns toward the nearer player', () {
    final first = player(300); // spawned first, and further away
    player(-100);
    final enemy = chaser();
    world.update(1 / 60);
    expect(facing(enemy), -1);

    first.getComponent<TransformComponent>()!.setPositionXY(50, 0);
    world.update(1 / 60);
    expect(facing(enemy), 1);
  });

  test('a player out of the world is not chased', () {
    player(300);
    final near = player(-50)..isActive = false;
    final enemy = chaser();
    world.update(1 / 60);
    expect(near.isActive, isFalse);
    expect(facing(enemy), 1);
  });
}
