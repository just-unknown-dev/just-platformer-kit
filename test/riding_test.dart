// A rigid-body player — the template's — riding a moving platform, through
// real physics on both backends: carried along at the platform's speed, and
// kept on one that goes down rather than landing on it again and again.

import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_platformer_kit/just_platformer_kit.dart';

void main() {
  for (final (name, make) in [
    ('native Box2D', () => Physics2DEngine()..initialize()),
    ('pure Dart', () => Physics2DEngine.pureDart()..initialize()),
  ]) {
    group(name, () => _riding(make));
  }

  group('MovingPlatform2DSystem', () {
    late World world;
    setUp(() {
      world = World()..initialize();
      world.addSystem(MovingPlatform2DSystem());
    });
    tearDown(() => world.dispose());

    Entity platform({bool autoStart = true, double pause = 0}) =>
        world.createEntityWithComponents([
          TransformComponent(position: Vector3(0, 0, 0)),
          VelocityComponent(),
          MovingPlatform2DComponent(
            waypoints: const [Offset(0, 0), Offset(100, 0)],
            autoStart: autoStart,
            pauseSeconds: pause,
          ),
        ]);

    test('one that does not start by itself waits until it is started', () {
      final p = platform(autoStart: false);
      final component = p.getComponent<MovingPlatform2DComponent>()!;
      final velocity = p.getComponent<VelocityComponent>()!;
      expect(component.isMoving, isFalse);
      for (var i = 0; i < 60; i++) {
        world.update(1 / 60);
      }
      expect(velocity.velocity.x, 0);

      component.isMoving = true;
      world.update(1 / 60);
      expect(velocity.velocity.x, closeTo(120, 1e-6));
    });

    test('with no pause, it goes straight on at a waypoint', () {
      final p = platform();
      p.getComponent<TransformComponent>()!.setPositionXY(100, 0);
      world.update(1 / 60);
      final component = p.getComponent<MovingPlatform2DComponent>()!;
      expect(component.targetIndex, 0);
      expect(p.getComponent<VelocityComponent>()!.velocity.x, closeTo(-120, 1e-6));
      expect(component.currentVelocity.dx, closeTo(-120, 1e-6), reason: 'units a second');
    });

    test('with a pause, it waits there', () {
      final p = platform(pause: 0.5);
      p.getComponent<TransformComponent>()!.setPositionXY(100, 0);
      world.update(1 / 60);
      expect(p.getComponent<VelocityComponent>()!.velocity.x, 0);
      expect(p.getComponent<MovingPlatform2DComponent>()!.currentVelocity, Offset.zero);
    });

    test('a platform with no velocity component is not driven', () {
      final p = world.createEntityWithComponents([
        TransformComponent(),
        MovingPlatform2DComponent(waypoints: const [Offset(0, 0), Offset(100, 0)]),
      ]);
      world.update(1 / 60);
      expect(p.getComponent<MovingPlatform2DComponent>()!.currentVelocity, Offset.zero);
    });
  });
}

void _riding(Physics2DEngine Function() make) {
  late Physics2DEngine physics;
  late World world;

  setUp(() {
    physics = make()..setGravity(0, 2200);
    world = World()..initialize();
    world
      ..addSystem(PlayerControlSystem())
      ..addSystem(MovingPlatform2DSystem())
      ..addSystem(Physics2DSystem(physics));
  });
  tearDown(() {
    world.dispose();
    physics.dispose();
  });

  Entity lift(List<Offset> path) => world.createEntityWithComponents([
    TransformComponent(position: Vector3(path.first.dx, path.first.dy, 0)),
    RigidBody2DComponent(bodyType: Body2DType.kinematic, lockRotation: true, friction: 0.2),
    Collider2DComponent(size: Vector2(300, 20)),
    VelocityComponent(),
    MovingPlatform2DComponent(waypoints: path, speed: 120),
  ], name: 'Lift');

  /// The template's player, standing on a lift whose top is at y = 190.
  Entity player() => world.createEntityWithComponents([
    TransformComponent(position: Vector3(0, 165, 0)),
    VelocityComponent(),
    RigidBody2DComponent(
      mass: 1,
      friction: 0.2,
      restitution: 0,
      linearDamping: 0,
      angularDamping: 0,
      lockRotation: true,
    ),
    Collider2DComponent(size: Vector2(32, 48)),
    PlayerControlComponent(),
    InputComponent(),
    TagComponent(PlatformerTags.player),
  ], name: 'Player');

  double x(Entity e) => e.getComponent<TransformComponent>()!.position.x;
  double y(Entity e) => e.getComponent<TransformComponent>()!.position.y;

  void run(int frames, [void Function()? each]) {
    for (var i = 0; i < frames; i++) {
      world.update(1 / 60);
      each?.call();
    }
  }

  test('standing still on a moving platform, it is carried along', () {
    final platform = lift(const [Offset(0, 200), Offset(2000, 200)]);
    final hero = player();
    run(30);
    final offset = x(hero) - x(platform);
    final startX = x(platform);
    run(120);
    expect(x(platform) - startX, greaterThan(200), reason: 'the lift moved');
    expect(x(hero) - x(platform), closeTo(offset, 8), reason: 'and took the player along');
  });

  test('on a platform going down, it stays on it: no landing after landing', () {
    final platform = lift(const [Offset(0, 200), Offset(0, 1200)]);
    final hero = player();
    run(30);
    final control = hero.getComponent<PlayerControlComponent>()!;
    final gap = y(platform) - y(hero);
    var landings = 0;
    run(120, () {
      if (control.justLanded) landings++;
    });
    expect(y(platform), greaterThan(400), reason: 'the lift went down');
    expect(y(platform) - y(hero), closeTo(gap, 4));
    expect(landings, 0);
  });
}
