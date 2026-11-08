// PlatformerGameplaySystem: pickups and the goal, hazards and enemies.
//
// Driven through a bare World with only the systems under test registered, so
// these stay fast and do not need a full Engine (which would also pull in a
// native physics world per test).

import 'package:flutter/painting.dart' show Offset, Rect;
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
  group('PlatformerGameplaySystem — pickups and goal', () {
    late World world;
    late Entity player;

    setUp(() {
      world = World()..initialize();
      world.addSystem(PlatformerGameplaySystem());
      player = _player(world);
    });

    Entity sensor(List<Component> extra, {double x = 0, double y = 0}) =>
        world.createEntityWithComponents([
          TransformComponent(position: Vector3(x, y, 0)),
          RigidBody2DComponent(isSensor: true),
          Collider2DComponent(size: Vector2(32, 32)),
          ...extra,
        ]);

    test('picking up a collectible fires an event and marks it collected', () {
      final coin = sensor([CollectibleComponent(kind: 'coin', value: 5)]);
      CollectiblePickedUpEvent? seen;
      world.events.on<CollectiblePickedUpEvent>((e) => seen = e);

      world.events.fire(SensorEnter2DEvent(sensor: coin, other: player));

      expect(seen, isNotNull);
      expect(seen!.kind, 'coin');
      expect(seen!.value, 5);
      expect(coin.getComponent<CollectibleComponent>()!.isCollected, isTrue);
    });

    test('a collectible cannot be picked up twice', () {
      final coin = sensor([CollectibleComponent()]);
      var count = 0;
      world.events.on<CollectiblePickedUpEvent>((_) => count++);

      world.events
        ..fire(SensorEnter2DEvent(sensor: coin, other: player))
        ..fire(SensorEnter2DEvent(sensor: coin, other: player));

      expect(count, 1);
    });

    test('a non-player visitor does not collect', () {
      final coin = sensor([CollectibleComponent()]);
      final crate = world.createEntityWithComponents([
        TransformComponent(position: Vector3.zero()),
      ]);
      var count = 0;
      world.events.on<CollectiblePickedUpEvent>((_) => count++);

      world.events.fire(SensorEnter2DEvent(sensor: coin, other: crate));

      expect(count, 0);
    });

    test('reaching the goal completes the level', () {
      final goal = sensor([GoalComponent(nextScene: 'level_02')]);
      LevelCompletedEvent? seen;
      world.events.on<LevelCompletedEvent>((e) => seen = e);

      world.events.fire(SensorEnter2DEvent(sensor: goal, other: player));

      expect(seen, isNotNull);
      expect(seen!.nextScene, 'level_02');
      expect(goal.getComponent<GoalComponent>()!.isReached, isTrue);
    });

    test('a gated goal stays shut while collectibles remain', () {
      sensor([CollectibleComponent()], x: 100);
      final goal = sensor([GoalComponent(requiresAllCollectibles: true)]);
      var completed = 0;
      world.events.on<LevelCompletedEvent>((_) => completed++);

      world.events.fire(SensorEnter2DEvent(sensor: goal, other: player));

      expect(completed, 0, reason: 'a collectible is still outstanding');
    });
  });

  group('PlatformerGameplaySystem — hazards and enemies', () {
    late World world;
    late Entity player;

    setUp(() {
      world = World()..initialize();
      world.addSystem(PlatformerGameplaySystem());
      player = _player(world);
    });

    Entity hazard(HazardComponent h) => world.createEntityWithComponents([
      TransformComponent(position: Vector3.zero()),
      RigidBody2DComponent(isSensor: true),
      Collider2DComponent(size: Vector2(32, 32)),
      h,
    ]);

    Entity enemy({double damage = 1}) => world.createEntityWithComponents([
      TransformComponent(position: Vector3(0, 100, 0)),
      VelocityComponent(),
      PatrolEnemyComponent(contactDamage: damage),
    ], name: 'Enemy');

    test('a hazard damages the player and knocks them back', () {
      final spikes = hazard(HazardComponent(damage: 1));
      final health = player.getComponent<HealthComponent>()!;
      EntityDamagedEvent? seen;
      world.events.on<EntityDamagedEvent>((e) => seen = e);

      world.events.fire(SensorEnter2DEvent(sensor: spikes, other: player));

      expect(health.health, 2);
      expect(seen?.wasFatal, isFalse);
      expect(
        player.getComponent<VelocityComponent>()!.velocity.y,
        lessThan(0),
        reason: 'knockback should push the player upward',
      );
    });

    test('i-frames stop a hazard draining all health at once', () {
      final spikes = hazard(HazardComponent(damage: 1));
      final health = player.getComponent<HealthComponent>()!;

      for (var i = 0; i < 5; i++) {
        world.events.fire(SensorEnter2DEvent(sensor: spikes, other: player));
      }

      expect(
        health.health,
        2,
        reason: 'only the first hit lands inside the invulnerability window',
      );
    });

    test('an instant-kill hazard is fatal regardless of health', () {
      final pit = hazard(HazardComponent(instantKill: true));
      EntityDamagedEvent? seen;
      world.events.on<EntityDamagedEvent>((e) => seen = e);

      world.events.fire(SensorEnter2DEvent(sensor: pit, other: player));

      expect(player.getComponent<HealthComponent>()!.health, 0);
      expect(seen?.wasFatal, isTrue);
    });

    test('falling past the kill plane is fatal', () {
      world.createEntityWithComponents([
        LevelBoundsComponent(
          bounds: const Rect.fromLTWH(0, 0, 1000, 600),
          killPlaneY: 800,
        ),
      ], name: 'LevelBounds');
      FellOutOfWorldEvent? seen;
      world.events.on<FellOutOfWorldEvent>((e) => seen = e);

      player.getComponent<TransformComponent>()!.setPositionXY(0, 900);
      world.update(1 / 60);

      expect(seen, isNotNull);
      expect(player.getComponent<HealthComponent>()!.health, 0);
    });

    test('stomping an enemy defeats it and bounces the player', () {
      final target = enemy();
      EnemyDefeatedEvent? seen;
      world.events.on<EnemyDefeatedEvent>((e) => seen = e);

      world.events.fire(
        CollisionEnter2DEvent(
          point: Offset.zero,
          entityA: target,
          entityB: player,
          normal: const Offset(0, -1), // player above the enemy
        ),
      );

      expect(seen, isNotNull);
      expect(target.getComponent<PatrolEnemyComponent>()!.isDefeated, isTrue);
      expect(
        player.getComponent<VelocityComponent>()!.velocity.y,
        lessThan(0),
        reason: 'a stomp should bounce the player upward',
      );
    });

    test('walking into an enemy from the side hurts the player', () {
      final target = enemy();

      world.events.fire(
        CollisionEnter2DEvent(
          point: Offset.zero,
          entityA: target,
          entityB: player,
          normal: const Offset(1, 0), // side contact
        ),
      );

      expect(player.getComponent<HealthComponent>()!.health, 2);
      expect(target.getComponent<PatrolEnemyComponent>()!.isDefeated, isFalse);
    });

    test('a crumbling platform collapses then comes back', () {
      final platform = world.createEntityWithComponents([
        TransformComponent(position: Vector3(0, 100, 0)),
        RigidBody2DComponent(bodyType: Body2DType.static),
        Collider2DComponent(size: Vector2(100, 20)),
        PlatformComponent(
          kind: PlatformKind.crumbling,
          crumbleDelay: 0.1,
          respawnDelay: 0.2,
        ),
      ], name: 'Crumble');
      final component = platform.getComponent<PlatformComponent>()!;
      final bodyComp = platform.getComponent<RigidBody2DComponent>()!;

      world.events.fire(
        CollisionEnter2DEvent(
          point: Offset.zero,
          entityA: platform,
          entityB: player,
          normal: const Offset(0, -1),
        ),
      );
      expect(component.crumbleTimer, greaterThan(0));

      for (var i = 0; i < 10; i++) {
        world.update(1 / 60);
      }
      expect(component.isCollapsed, isTrue);
      expect(bodyComp.collidesWithNothing, isTrue, reason: 'collider disabled');
      expect(bodyComp.collidesWith, isNull, reason: 'its saved list stays');

      for (var i = 0; i < 15; i++) {
        world.update(1 / 60);
      }
      expect(component.isCollapsed, isFalse);
      expect(
        bodyComp.collidesWithNothing,
        isFalse,
        reason: 'collider restored',
      );
      expect(bodyComp.collidesWith, isNull);
    });
  });
}
