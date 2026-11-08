// A character player (CharacterBody2DComponent) on a solid hazard — a
// spiked block it can stand on. Its mover touches static bodies without
// contacts, so no contact ever ends to say it has left one: the rule
// follows its ground instead. On each backend.

import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_platformer_kit/just_platformer_kit.dart';

void main() {
  for (final (name, make) in [
    ('native Box2D', PhysicsEngineFactory.create2D),
    ('pure Dart', Physics2DEngine.pureDart),
  ]) {
    group(name, () => _suite(make));
  }
}

void _suite(Physics2DEngine Function() make) {
  late Physics2DEngine physics;
  late World world;
  late Entity hero;

  HealthComponent health() => hero.getComponent<HealthComponent>()!;
  void run(int frames) {
    for (var i = 0; i < frames; i++) {
      world.update(1 / 60);
    }
  }

  void move(double x) =>
      hero.getComponent<InputComponent>()!.setVector('move', Offset(x, 0));

  setUp(() {
    physics = make()
      ..initialize()
      ..setGravity(0, 2000);
    world = World(context: EngineContext(extensions: [PlatformerKit.extension]))
      ..initialize();
    world
      ..addSystem(PlayerControlSystem())
      ..addSystem(Physics2DSystem(physics))
      ..addSystem(PlatformerGameplaySystem());
    // Floor, top at y = 100, from x = -2000 to 2000.
    world.createEntityWithComponents([
      TransformComponent(position: Vector3(0, 120, 0)),
      RigidBody2DComponent(bodyType: Body2DType.static),
      Collider2DComponent(size: Vector2(4000, 40)),
    ]);
    // A spiked block standing on it, top at y = 60.
    world.createEntityWithComponents([
      TransformComponent(position: Vector3(0, 80, 0)),
      RigidBody2DComponent(bodyType: Body2DType.static),
      Collider2DComponent(size: Vector2(64, 40)),
      HazardComponent(knockback: Offset.zero, invulnerabilitySeconds: 0.5),
    ]);
    hero = world.createEntityWithComponents([
      TransformComponent(position: Vector3(0, 0, 0)),
      CharacterBody2DComponent(shape: CharacterBody2DShape.box),
      PlayerControlComponent(),
      InputComponent(),
      HealthComponent(maxHealth: 100),
      TagComponent(PlatformerTags.player),
    ], name: 'Player');
  });

  tearDown(() {
    world.dispose();
    physics.dispose();
  });

  test('standing on it, it is hurt again whenever its i-frames run out', () {
    run(30);
    expect(health().health, 99, reason: 'hurt landing on it');
    run(60);
    expect(health().health, lessThan(99), reason: 'still on it: hurt again');
  });

  test('once it walks off, it is hurt no more', () {
    run(30);
    expect(health().health, 99);
    move(1);
    run(60);
    move(0);
    final x = hero.getComponent<TransformComponent>()!.position.x;
    expect(x, greaterThan(200), reason: 'well off the block');
    final before = health().health;
    run(180);
    expect(health().health, before, reason: 'on plain floor, for 3 s');
  });

  test('once it jumps off, it is hurt no more', () {
    run(30);
    expect(health().health, 99);
    // Up and away to the right, then left standing on the floor.
    final input = hero.getComponent<InputComponent>()!..setDown('jump', true);
    move(1);
    run(2);
    input.setDown('jump', false);
    run(58);
    move(0);
    run(30);
    final x = hero.getComponent<TransformComponent>()!.position.x;
    expect(x, greaterThan(64), reason: 'past the block');
    final before = health().health;
    run(180);
    expect(health().health, before);
  });
}
