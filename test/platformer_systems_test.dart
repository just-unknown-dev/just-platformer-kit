// Behaviour of the platformer layer: the character controller's feel
// features, moving platforms, and the level rules.
//
// Driven through a bare World with only the systems under test registered, so
// these stay fast and do not need a full Engine (which would also pull in a
// native physics world per test).

import 'package:flutter/painting.dart' show Offset, Rect, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_platformer_kit/just_platformer_kit.dart';

/// Builds a player entity with everything [PlayerControlSystem] requires.
Entity _player(World world, {double x = 0, double y = 0}) =>
    world.createEntityWithComponents([
      TransformComponent(position: Vector3(x, y, 0)),
      VelocityComponent(),
      RigidBody2D(lockRotation: true), Collider2D(size: Vector2(32, 48)),
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
      final bodyComp = player.getComponent<RigidBody2D>()!
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
    late RigidBody2D bodyComp;
    late VelocityComponent velocity;

    setUp(() {
      world = World()..initialize();
      world.addSystem(PlayerControlSystem());
      player = _player(world);
      input = player.getComponent<InputComponent>()!;
      control = player.getComponent<PlayerControlComponent>()!;
      bodyComp = player.getComponent<RigidBody2D>()!;
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
      final heldScale = bodyComp.gravityScale;

      input.setDown('jump', false);
      world.update(1 / 60);
      final releasedScale = bodyComp.gravityScale;

      expect(heldScale, closeTo(control.riseGravityScale, 1e-9));
      expect(releasedScale, closeTo(control.jumpCutGravityScale, 1e-9));
      expect(releasedScale, greaterThan(heldScale));
    });

    test('falling uses a heavier gravity than rising', () {
      velocity.setVelocityXY(0, 100); // falling
      world.update(1 / 60);

      expect(bodyComp.gravityScale, closeTo(control.fallGravityScale, 1e-9));
      expect(control.fallGravityScale, greaterThan(control.riseGravityScale));
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

  group('MovingPlatformSystem', () {
    late World world;

    setUp(() {
      world = World()..initialize();
      world.addSystem(MovingPlatformSystem());
    });

    Entity platform({
      required List<Offset> waypoints,
      PlatformLoopMode loop = PlatformLoopMode.pingPong,
      double speed = 120,
    }) => world.createEntityWithComponents([
      TransformComponent(
        position: Vector3(waypoints.first.dx, waypoints.first.dy, 0),
      ),
      VelocityComponent(),
      MovingPlatformComponent(
        waypoints: waypoints,
        speed: speed,
        loopMode: loop,
      ),
    ], name: 'Platform');

    test('drives velocity toward the next waypoint', () {
      final entity = platform(waypoints: const [Offset(0, 0), Offset(240, 0)]);

      world.update(1 / 60);

      final velocity = entity.getComponent<VelocityComponent>()!;
      expect(velocity.velocity.x, closeTo(120, 0.01));
      expect(velocity.velocity.y, closeTo(0, 0.01));
    });

    test('moves by velocity, not by teleporting the transform', () {
      final entity = platform(waypoints: const [Offset(0, 0), Offset(240, 0)]);
      final transform = entity.getComponent<TransformComponent>()!;

      world.update(1 / 60);

      expect(
        transform.position.x,
        0,
        reason: 'the system sets velocity; physics does the moving',
      );
    });

    test('ping-pong reverses at the end of the path', () {
      final entity = platform(waypoints: const [Offset(0, 0), Offset(100, 0)]);
      final component = entity.getComponent<MovingPlatformComponent>()!;
      final transform = entity.getComponent<TransformComponent>()!;

      expect(component.targetIndex, 1);

      // Arrive at the far waypoint.
      transform.setPositionXY(100, 0);
      world.update(1 / 60);

      expect(component.targetIndex, 0, reason: 'now heading back');
      expect(component.direction, -1);
    });

    test('loop mode wraps to the first waypoint', () {
      final entity = platform(
        waypoints: const [Offset(0, 0), Offset(100, 0), Offset(200, 0)],
        loop: PlatformLoopMode.loop,
      );
      final component = entity.getComponent<MovingPlatformComponent>()!;
      final transform = entity.getComponent<TransformComponent>()!;

      transform.setPositionXY(200, 0);
      component.targetIndex = 2;
      world.update(1 / 60);

      expect(component.targetIndex, 0);
    });

    test('once mode stops at the end', () {
      final entity = platform(
        waypoints: const [Offset(0, 0), Offset(100, 0)],
        loop: PlatformLoopMode.once,
      );
      final component = entity.getComponent<MovingPlatformComponent>()!;
      final transform = entity.getComponent<TransformComponent>()!;

      transform.setPositionXY(100, 0);
      world.update(1 / 60);

      expect(component.isMoving, isFalse);
      expect(entity.getComponent<VelocityComponent>()!.velocity.x, 0);
    });

    test('a single waypoint is stationary', () {
      final entity = platform(waypoints: const [Offset(50, 50)]);

      world.update(1 / 60);

      expect(entity.getComponent<VelocityComponent>()!.velocity.x, 0);
      expect(entity.getComponent<VelocityComponent>()!.velocity.y, 0);
    });
  });

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
          RigidBody2D(isSensor: true), Collider2D(size: Vector2(32, 32)),
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
      RigidBody2D(isSensor: true), Collider2D(size: Vector2(32, 32)),
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
        RigidBody2D(bodyType: BodyType.static), Collider2D(size: Vector2(100, 20)),
        PlatformComponent(
          kind: PlatformKind.crumbling,
          crumbleDelay: 0.1,
          respawnDelay: 0.2,
        ),
      ], name: 'Crumble');
      final component = platform.getComponent<PlatformComponent>()!;
      final bodyComp = platform.getComponent<RigidBody2D>()!;

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
      expect(bodyComp.collidesWith, 0, reason: 'collider disabled');

      for (var i = 0; i < 15; i++) {
        world.update(1 / 60);
      }
      expect(component.isCollapsed, isFalse);
      expect(bodyComp.collidesWith, isNull, reason: 'collider restored');
    });
  });

  group('camera zones', () {
    // A zone is the engine's camera parts arranged by the kit: a shot that a
    // trigger enables while the player is inside. These cover the platformer
    // promises — the zoom applies inside, the zone is where its entity is,
    // overlapping zones are settled by priority, a locked axis does not scroll.
    late World world;
    late CameraSystem cameras;
    late Entity player;

    setUp(() {
      world = World()..initialize();
      cameras = CameraSystem()..initialize();
      cameras.mainCamera.viewportSize = const Size(800, 600);
      cameras.brain.defaultBlend = CameraBlend.cut;
      registerCameraSystems(world, cameras);

      world.createEntityWithComponents([
        TransformComponent(position: Vector3.zero()),
        VirtualCameraComponent(
          priority: 10,
          follow: const EntityTarget.tag('player'),
        ),
        CameraFramingComponent(
          deadZoneWidth: 0,
          deadZoneHeight: 0,
          dampingX: 0,
          dampingY: 0,
        ),
      ], name: 'MainCamera');

      player = world.createEntityWithComponents([
        TransformComponent(position: Vector3.zero()),
        TagComponent('player'),
      ], name: 'Player');
    });
    tearDown(() => world.dispose());

    /// A zone centred on [at], sized [size], that zooms to [zoom].
    Entity zone(
      Offset at, {
      String name = 'Zone',
      Size size = const Size(400, 400),
      double zoom = 2,
      int priority = 0,
      bool lockX = false,
    }) => world.createEntityWithComponents([
      TransformComponent(position: Vector3(at.dx, at.dy, 0)),
      ...PlatformerCamera.zone(
        size: size,
        zoom: zoom,
        priority: priority,
        lockX: lockX,
      ),
    ], name: name);

    void movePlayerTo(Offset at) =>
        player.getComponent<TransformComponent>()!.setPositionXY(at.dx, at.dy);

    double cameraZoom() => cameras.mainCamera.zoom;

    test('a player inside the zone takes its zoom', () {
      zone(const Offset(500, 500));
      movePlayerTo(const Offset(500, 500));
      world.update(1 / 60);
      expect(cameraZoom(), 2);
      expect(cameras.brain.liveCamera?.name, 'Zone');
    });

    test('a player outside every zone returns to the main camera', () {
      zone(const Offset(500, 500));
      movePlayerTo(const Offset(500, 500));
      world.update(1 / 60);
      expect(cameraZoom(), 2);

      movePlayerTo(const Offset(5000, 5000));
      world.update(1 / 60);
      expect(cameraZoom(), 1);
      expect(cameras.brain.liveCamera?.name, 'MainCamera');
    });

    test('the change of zoom is a blend, not a pop', () {
      cameras.brain.defaultBlend = const CameraBlend(duration: 1);
      zone(const Offset(500, 500));
      world.update(1 / 60);
      movePlayerTo(const Offset(500, 500));
      world.update(1 / 60);
      expect(cameraZoom(), inExclusiveRange(1, 2));
    });

    test('the zone follows its transform when moved', () {
      // The regression this covers: a zone that stores its own world-space
      // rect stays behind when its entity is dragged in the editor — the
      // marker and the behaviour drift apart with nothing on screen to
      // explain it.
      final moved = zone(const Offset(500, 500));
      movePlayerTo(const Offset(3000, 3000));
      world.update(1 / 60);
      expect(cameraZoom(), 1, reason: 'player starts outside');

      moved.getComponent<TransformComponent>()!.setPositionXY(3000, 3000);
      world.update(1 / 60);
      expect(cameraZoom(), 2, reason: 'the zone is where its entity is');
    });

    test('the higher-priority zone wins where two overlap', () {
      zone(Offset.zero, size: const Size(1000, 1000), zoom: 2);
      zone(
        Offset.zero,
        name: 'ZoneHigh',
        size: const Size(400, 400),
        zoom: 0.5,
        priority: 5,
      );
      movePlayerTo(Offset.zero);
      world.update(1 / 60);
      expect(cameraZoom(), 0.5);
      expect(cameras.brain.liveCamera?.name, 'ZoneHigh');
    });

    test('lockX pins the camera to the zone centre', () {
      zone(const Offset(800, 400), size: const Size(600, 600), lockX: true);
      movePlayerTo(const Offset(1000, 500));
      world.update(1 / 60);
      expect(cameras.mainCamera.position.dx, 800, reason: 'x does not scroll');
      expect(cameras.mainCamera.position.dy, closeTo(500, 1e-6));
    });

    test('an old level\'s CameraZoneComponent loads as a zone', () {
      final world = World()..context.install(PlatformerKit.extension);
      addTearDown(world.dispose);
      final loaded = SceneLoader.load(world, {
        'version': 1,
        'name': 's',
        'entities': [
          {
            'name': 'Cave',
            'components': [
              {
                'type': 'TransformComponent',
                'fields': {
                  'position': {'x': 10.0, 'y': 20.0},
                },
              },
              {
                'type': 'CameraZoneComponent',
                'fields': {
                  'width': 640.0,
                  'height': 360.0,
                  'zoom': 0.65,
                  'priority': 3,
                  'lockX': true,
                  'lockY': false,
                },
              },
            ],
          },
        ],
      }).single;
      final vcam = loaded.getComponent<VirtualCameraComponent>()!;
      expect(vcam.priority, PlatformerCamera.zonePriority + 3);
      expect(vcam.enabled, isFalse);
      expect(vcam.zoom, 0.65);
      final framing = loaded.getComponent<CameraFramingComponent>()!;
      expect((framing.followX, framing.followY), (false, true));
      final trigger = loaded.getComponent<CameraTriggerComponent>()!;
      expect((trigger.width, trigger.height), (640, 360));
    });
  });
}
