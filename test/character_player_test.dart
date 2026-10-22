// A player that is a CharacterBody2D instead of a rigid body: the same feel
// from PlayerControlSystem, and the same level rules from
// PlatformerGameplaySystem — bounce pads, crumbling platforms, stomps,
// pickups, knockback — through real physics.

import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_platformer_kit/just_platformer_kit.dart';

void main() {
  // The same player on each backend.
  for (final (name, make) in [
    ('native Box2D', () => PhysicsEngine()..initialize()),
    ('pure Dart', () => PhysicsEngine.pureDart()..initialize()),
  ]) {
    group(name, () => _suite(make));
  }
}

void _suite(PhysicsEngine Function() make) {
  late PhysicsEngine physics;
  late World world;

  setUp(() {
    physics = make();
    physics.setGravity(0, 2000);
    world = World(context: EngineContext(extensions: [PlatformerKit.extension]))
      ..initialize();
    world
      ..addSystem(PlayerControlSystem())
      ..addSystem(PhysicsSystem(physics))
      ..addSystem(PlatformerGameplaySystem());
  });
  tearDown(() {
    world.dispose();
    physics.dispose();
  });

  void run([int frames = 60]) {
    for (var i = 0; i < frames; i++) {
      world.update(1 / 60);
    }
  }

  Entity block(
    double x,
    double y,
    double w,
    double h, [
    List<Component> more = const [],
  ]) => world.createEntityWithComponents([
    TransformComponent(position: Vector3(x, y, 0)),
    RigidBody2D(bodyType: BodyType.static),
    Collider2D(size: Vector2(w, h)),
    ...more,
  ]);

  /// The floor's top is at y = 100.
  void floor() => block(0, 120, 4000, 40);

  Entity hero({double x = 0, double y = 60}) =>
      world.createEntityWithComponents([
        TransformComponent(position: Vector3(x, y, 0)),
        CharacterBody2D(shape: CharacterShape2D.box),
        PlayerControlComponent(),
        InputComponent(),
        HealthComponent(maxHealth: 3),
        TagComponent(PlatformerTags.player),
      ], name: 'Player');

  CharacterBody2D bodyOf(Entity e) => e.getComponent<CharacterBody2D>()!;
  InputComponent inputOf(Entity e) => e.getComponent<InputComponent>()!;
  PlayerControlComponent controlOf(Entity e) =>
      e.getComponent<PlayerControlComponent>()!;
  Offset at(Entity e) {
    final p = e.getComponent<TransformComponent>()!.position;
    return Offset(p.x, p.y);
  }

  test('it runs at the move speed, and slows to a stop on release', () {
    floor();
    final p = hero();
    run(20);
    inputOf(p).setVector('move', const Offset(1, 0));
    run(60);
    expect(bodyOf(p).moveVelocity.dx, closeTo(controlOf(p).moveSpeed, 0.01));
    expect(bodyOf(p).velocity.dx, closeTo(controlOf(p).moveSpeed, 1));
    inputOf(p).setVector('move', Offset.zero);
    run(60);
    expect(bodyOf(p).velocity.dx, 0);
    expect(controlOf(p).isGrounded, isTrue);
  });

  test('it jumps, rises under rise gravity while held, and lands', () {
    floor();
    final p = hero();
    run(20);
    final y0 = at(p).dy;
    inputOf(p).setDown('jump', true);
    run(2);
    expect(controlOf(p).isGrounded, isFalse);
    expect(bodyOf(p).gravityScale, controlOf(p).riseGravityScale);
    expect(at(p).dy, lessThan(y0));
    inputOf(p).setDown('jump', false);
    run(120);
    expect(controlOf(p).isGrounded, isTrue);
    expect(at(p).dy, closeTo(y0, 1));
  });

  test('coyote time: a jump just after walking off a ledge still jumps', () {
    block(-200, 120, 400, 40); // a ledge ending at x = 0
    final p = hero(x: -40);
    run(20);
    inputOf(p).setVector('move', const Offset(1, 0));
    var airborne = 0;
    while (controlOf(p).isGrounded && airborne < 120) {
      run(1);
      airborne++;
    }
    expect(controlOf(p).isGrounded, isFalse, reason: 'walked off');
    final y = at(p).dy;
    inputOf(p).setDown('jump', true);
    run(6);
    expect(at(p).dy, lessThan(y), reason: 'it jumped from the air');
  });

  test('a bounce pad bounces it', () {
    floor();
    block(0, 90, 120, 20, [
      PlatformComponent(kind: PlatformKind.bouncy, bounceImpulse: 1400),
    ]);
    final p = hero(y: -100);
    var up = 0.0;
    for (var i = 0; i < 90; i++) {
      run(1);
      if (bodyOf(p).velocity.dy < up) up = bodyOf(p).velocity.dy;
    }
    expect(up, lessThan(-1000), reason: 'sent up at the pad\'s speed');
  });

  test('a crumbling platform it lands on collapses under it', () {
    floor();
    final crumble = block(0, 20, 120, 20, [
      PlatformComponent(
        kind: PlatformKind.crumbling,
        crumbleDelay: 0.2,
        respawnDelay: 5,
      ),
    ]);
    final p = hero(y: -60);
    run(10);
    expect(bodyOf(p).groundEntity, same(crumble));
    final platform = crumble.getComponent<PlatformComponent>()!;
    expect(platform.crumbleTimer, greaterThan(0));
    run(60);
    expect(platform.isCollapsed, isTrue);
    expect(at(p).dy, greaterThan(60), reason: 'fell through to the floor');
  });

  test('it stomps an enemy from above and bounces off', () {
    floor();
    final enemy = world.createEntityWithComponents([
      TransformComponent(position: Vector3(0, 84, 0)),
      RigidBody2D(lockRotation: true),
      Collider2D(size: Vector2(32, 32)),
      PatrolEnemyComponent(),
      HealthComponent(maxHealth: 1),
    ], name: 'Enemy');
    final p = hero(y: -100);
    var up = 0.0;
    for (var i = 0; i < 60; i++) {
      run(1);
      if (bodyOf(p).velocity.dy < up) up = bodyOf(p).velocity.dy;
    }
    expect(
      enemy.getComponent<PatrolEnemyComponent>()?.isDefeated ?? true,
      isTrue,
    );
    expect(up, lessThan(-300), reason: 'the stomp bounce');
    expect(p.getComponent<HealthComponent>()!.health, 3);
  });

  test('it picks up a coin, and a hazard knocks it back', () {
    floor();
    world.createEntityWithComponents([
      TransformComponent(position: Vector3(80, 76, 0)),
      RigidBody2D(bodyType: BodyType.static, isSensor: true),
      Collider2D(size: Vector2(16, 16)),
      CollectibleComponent(),
    ]);
    world.createEntityWithComponents([
      TransformComponent(position: Vector3(200, 76, 0)),
      RigidBody2D(bodyType: BodyType.static, isSensor: true),
      Collider2D(size: Vector2(16, 40)),
      HazardComponent(knockback: const Offset(-300, -400)),
    ]);
    final picked = <Entity>[];
    world.events.on<CollectiblePickedUpEvent>(
      (e) => picked.add(e.collectorEntity),
    );
    final p = hero();
    run(20);
    inputOf(p).setVector('move', const Offset(1, 0));
    var knocked = false;
    for (var i = 0; i < 90 && !knocked; i++) {
      run(1);
      knocked = p.getComponent<HealthComponent>()!.health < 3;
    }
    expect(picked, [p]);
    expect(knocked, isTrue);
    run(1);
    expect(bodyOf(p).velocity.dx, lessThan(0), reason: 'thrown back');
    expect(bodyOf(p).velocity.dy, lessThan(0), reason: 'and up');
  });
}
