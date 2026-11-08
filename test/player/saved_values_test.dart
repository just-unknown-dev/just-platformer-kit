// Play never writes what a level saves. The jump's gravities go through the
// body's run-time gravity scale override, and a crumbled platform through
// its body's run-time collision switch: a level saved mid-jump or
// mid-collapse saves what was authored. (They used to be written into the
// saved `gravityScale` and `collidesWith`, which the editor then saved.)

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_platformer_kit/just_platformer_kit.dart';

/// The player's saved gravity scale: not one of the controller's own.
const _authored = 0.8;

void main() {
  for (final (backend, make) in [
    ('native Box2D', PhysicsEngineFactory.create2D),
    ('pure Dart', Physics2DEngine.pureDart),
  ]) {
    group('on $backend', () => _suite(make));
  }
}

void _suite(Physics2DEngine Function() make) {
  final definitions = BuiltInComponents.registry();
  late Physics2DEngine physics;
  late World world;

  setUp(() {
    physics = make()..initialize();
    physics.setGravity(0, 2200);
    world = World(context: EngineContext(extensions: [PlatformerKit.extension]))
      ..initialize();
    world
      ..addSystem(PlayerControlSystem())
      ..addSystem(Physics2DSystem(physics))
      ..addSystem(PlatformerGameplaySystem());
  });
  tearDown(() {
    world.dispose();
    physics.dispose();
  });

  String saved(Component c) => jsonEncode(definitions.encode(c));

  Entity solid(
    double x,
    double y,
    Collider2DComponent collider, [
    List<Component> more = const [],
    int? collidesWith,
  ]) => world.createEntityWithComponents([
    TransformComponent(position: Vector3(x, y, 0)),
    RigidBody2DComponent(
      bodyType: Body2DType.static,
      friction: 0.2,
      restitution: 0,
      collidesWith: collidesWith,
    ),
    collider,
    ...more,
  ]);

  /// Ground whose top is at y = 300, from x = -400 to 1200.
  void floor() => solid(400, 340, Collider2DComponent(size: Vector2(1600, 80)));

  /// The template's player, but for its saved gravity scale.
  Entity player({double x = 0, double y = 200}) =>
      world.createEntityWithComponents([
        TransformComponent(position: Vector3(x, y, 0)),
        VelocityComponent(),
        RigidBody2DComponent(
          mass: 1,
          lockRotation: true,
          friction: 0.2,
          restitution: 0,
          linearDamping: 0,
          angularDamping: 0,
          gravityScale: _authored,
        ),
        Collider2DComponent(size: Vector2(32, 48), cornerRadius: 4),
        PlayerControlComponent(),
        InputComponent(),
        TagComponent(PlatformerTags.player),
      ], name: 'Player');

  test('a jump, a fall and a slope never write the saved gravity scale; '
      'a save mid-jump writes the authored one', () {
    floor();
    // A ramp up from x = 200 to 400, 100 high, and the level beyond it.
    solid(
      300,
      250,
      Collider2DComponent(
        shape: Collider2DShape.polygon,
        points: const [Offset(-100, 50), Offset(100, -50), Offset(100, 50)],
      ),
    );
    solid(800, 250, Collider2DComponent(size: Vector2(800, 100)));
    final p = player();
    final rigid = p.getComponent<RigidBody2DComponent>()!;
    final control = p.getComponent<PlayerControlComponent>()!;
    final input = p.getComponent<InputComponent>()!;
    final before = saved(rigid);
    final seen = <double?>{};

    void step(int frames) {
      for (var i = 0; i < frames; i++) {
        world.update(1 / 60);
        seen.add(rigid.gravityScaleOverride);
        expect(rigid.gravityScale, _authored);
        expect(
          p.getComponent<Physics2DBodyRefComponent>()!.body.gravityScale,
          rigid.effectiveGravityScale,
          reason: 'the body falls by the override',
        );
      }
    }

    step(40);
    expect(control.isGrounded, isTrue);

    // Rising, the button held.
    input.setDown('jump', true);
    step(6);
    expect(control.isRising, isTrue);
    expect(rigid.gravityScaleOverride, control.riseGravityScale);
    expect(saved(rigid), before, reason: 'a save mid-jump');

    // Let go early: the jump is cut.
    input.setDown('jump', false);
    step(2);
    expect(rigid.gravityScaleOverride, control.jumpCutGravityScale);
    expect(saved(rigid), before);

    // Falling.
    step(10);
    expect(control.isRising, isFalse);
    expect(rigid.gravityScaleOverride, control.fallGravityScale);
    expect(saved(rigid), before, reason: 'a save mid-fall');
    step(40);
    expect(control.isGrounded, isTrue);

    // Up the ramp: held to it with no gravity at all.
    input.setVector('move', const Offset(1, 0));
    step(120);
    expect(seen, contains(0.0), reason: 'it ran on the slope');
    expect(
      p.getComponent<TransformComponent>()!.position.x,
      greaterThan(420),
      reason: 'up it, and over the top',
    );
    expect(saved(rigid), before);
  });

  test('a character player: a jump and a fall never write its saved gravity '
      'scale', () {
    floor();
    final p = world.createEntityWithComponents([
      TransformComponent(position: Vector3(0, 250, 0)),
      CharacterBody2DComponent(
        shape: CharacterBody2DShape.box,
        gravityScale: _authored,
      ),
      PlayerControlComponent(),
      InputComponent(),
      TagComponent(PlatformerTags.player),
    ], name: 'Player');
    final body = p.getComponent<CharacterBody2DComponent>()!;
    final control = p.getComponent<PlayerControlComponent>()!;
    final input = p.getComponent<InputComponent>()!;
    final before = saved(body);

    void step(int frames) {
      for (var i = 0; i < frames; i++) {
        world.update(1 / 60);
        expect(body.gravityScale, _authored);
      }
    }

    step(30);
    expect(control.isGrounded, isTrue);
    input.setDown('jump', true);
    step(4);
    expect(body.gravityScaleOverride, control.riseGravityScale);
    expect(saved(body), before, reason: 'a save mid-jump');
    input.setDown('jump', false);
    step(30);
    expect(body.gravityScaleOverride, control.fallGravityScale);
    expect(saved(body), before, reason: 'a save mid-fall');
    step(60);
    expect(control.isGrounded, isTrue);
    expect(saved(body), before);
  });

  test('a platform that crumbles under the player and comes back never '
      'writes its saved collision list', () {
    floor();
    // Its own list (layers 0 and 1), not the grid: what has to come back.
    final crumble = solid(0, 210, Collider2DComponent(size: Vector2(160, 20)), [
      PlatformComponent(
        kind: PlatformKind.crumbling,
        crumbleDelay: 0.2,
        respawnDelay: 0.5,
      ),
    ], 0x3);
    final rigid = crumble.getComponent<RigidBody2DComponent>()!;
    final platform = crumble.getComponent<PlatformComponent>()!;
    final before = saved(rigid);
    Physics2DBody body() =>
        crumble.getComponent<Physics2DBodyRefComponent>()!.body;
    final p = player(y: 150);
    double y() => p.getComponent<TransformComponent>()!.position.y;

    var frames = 0;
    while (!platform.isCollapsed && frames < 120) {
      world.update(1 / 60);
      frames++;
      expect(rigid.collidesWith, 0x3);
    }
    expect(platform.isCollapsed, isTrue);
    expect(rigid.collidesWithNothing, isTrue);
    expect(rigid.collidesWith, 0x3, reason: 'its saved list stays');
    expect(saved(rigid), before, reason: 'a save mid-collapse');
    world.update(1 / 60);
    expect(body().maskBits, 0, reason: 'the body collides with nothing');

    // The player falls through it, to the floor.
    for (var i = 0; i < 20; i++) {
      world.update(1 / 60);
    }
    expect(y(), greaterThan(250));

    // Back: as it was authored.
    for (var i = 0; i < 40; i++) {
      world.update(1 / 60);
    }
    expect(platform.isCollapsed, isFalse);
    expect(rigid.collidesWithNothing, isFalse);
    expect(body().maskBits, 0x3);
    expect(saved(rigid), before);

    // And it holds a player again.
    final second = player(x: 40, y: 150);
    for (var i = 0; i < 6; i++) {
      world.update(1 / 60);
    }
    expect(
      second.getComponent<TransformComponent>()!.position.y,
      lessThan(200),
      reason: 'standing on it',
    );
  });
}
