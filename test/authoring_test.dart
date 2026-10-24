// While an editor authors a level it holds the game's time at 0, but the
// systems still run — every step, with a deltaTime of 0. The kit's systems
// must leave the level alone then: what they wrote was saved with it
// (decorations moved with the editor's view, enemies' velocities, a zeroed
// health), and what they captured (a patrol's origin, a crumbling
// platform's resting place) went stale when the designer moved things.

import 'dart:convert';

import 'package:flutter/painting.dart' show Offset, Rect;
import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_platformer_kit/editor.dart';
import 'package:just_platformer_kit/just_platformer_kit.dart';

void main() {
  late World world;
  late PhysicsEngine physics;
  late Camera camera;

  setUp(() {
    physics = PhysicsEngine.pureDart()..initialize();
    physics.setGravity(0, 2200);
    world = World(context: EngineContext(extensions: [PlatformerKit.extension]))
      ..initialize();
    camera = Camera(position: Offset.zero, zoom: 1);
    world.addSystem(PhysicsSystem(physics));
    PlatformerKit.registerSystems(world, physics: physics, camera: camera);
  });
  tearDown(() {
    world.dispose();
    physics.dispose();
  });

  /// Every prefab of the kit, side by side, plus a player and level bounds
  /// whose kill plane is above one of the enemies.
  void buildLevel() {
    var x = 0.0;
    for (final prefab in PlatformerPrefabs.all) {
      world.createEntityWithComponents(
        prefab.build(Offset(x, 100), prefab.defaultSize),
        name: prefab.namePrefix,
      );
      x += 300;
    }
    world.createEntityWithComponents([
      TransformComponent(position: Vector3(0, 0, 0)),
      VelocityComponent(),
      RigidBody2D(lockRotation: true, friction: 0.2, linearDamping: 0),
      Collider2D(size: Vector2(32, 48)),
      PlayerControlComponent(),
      InputComponent(),
      HealthComponent(maxHealth: 3),
      TagComponent(PlatformerTags.player),
    ], name: 'Player');
    world.createEntityWithComponents([
      LevelBoundsComponent(
        bounds: const Rect.fromLTWH(0, 0, 4000, 400),
        killPlaneY: 500,
      ),
    ], name: 'LevelBounds');
    world.createEntityWithComponents([
      TransformComponent(position: Vector3(100, 900, 0)),
      VelocityComponent(),
      PatrolEnemyComponent(),
      HealthComponent(maxHealth: 1),
    ], name: 'Below');
  }

  /// The level as a save would write it.
  String saved() => jsonEncode([
    for (final e in world.entities)
      if (e.isAlive)
        {
          'name': e.name,
          'components': [
            for (final c in e.components) ?world.context.definitions.encode(c),
          ],
        },
  ]);

  test('authoring (deltaTime 0) leaves the saved level as it was', () {
    buildLevel();
    world.update(0); // bodies made, nothing moved
    final before = saved();

    for (var i = 0; i < 10; i++) {
      // The editor pans its view: the game's main camera.
      camera.position = Offset(2000.0 + i * 100, 600);
      world.update(0);
      world.frame(0, 1);
    }

    expect(saved(), before);
  });

  test('what a system captures is captured when play starts, not before', () {
    buildLevel();
    for (var i = 0; i < 5; i++) {
      world.update(0);
    }
    final enemy = world.entities.firstWhere(
      (e) => e.hasComponent<PatrolEnemyComponent>(),
    );
    final decor = world.entities.firstWhere(
      (e) => e.hasComponent<ParallaxRectComponent>(),
    );
    final crumble = world.entities.firstWhere(
      (e) =>
          e.getComponent<PlatformComponent>()?.kind == PlatformKind.crumbling,
    );
    expect(enemy.getComponent<PatrolEnemyComponent>()!.originX, isNull);
    expect(decor.getComponent<ParallaxRectComponent>()!.baseX, isNull);
    expect(crumble.getComponent<PlatformComponent>()!.restingPosition, isNull);

    // The designer drags them, then presses Play.
    enemy.getComponent<TransformComponent>()!.setPositionXY(1500, 100);
    decor.getComponent<TransformComponent>()!.setPositionXY(2600, 50);
    crumble.getComponent<TransformComponent>()!.setPositionXY(1800, 100);
    world.update(1 / 60);

    expect(enemy.getComponent<PatrolEnemyComponent>()!.originX, 1500);
    expect(decor.getComponent<ParallaxRectComponent>()!.baseX, 2600);
    expect(
      crumble.getComponent<PlatformComponent>()!.restingPosition!.dx,
      closeTo(1800, 1),
    );
  });
}
