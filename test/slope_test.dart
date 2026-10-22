// Slopes: a character stands still on one, runs up it at its usual speed,
// and runs down it without taking off — on tiles built by the engine, over
// its pure-Dart physics.

import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_platformer_kit/just_platformer_kit.dart';

const _t = 32.0;
const _solid = 0, _up = 1;

void main() {
  late PhysicsEngine physics;
  late World world;
  late Entity player;

  setUp(() {
    final ts = TilesetData(
      name: 's',
      tileWidth: 32,
      tileHeight: 32,
      columns: 2,
      tileCount: 2,
    );
    ts.tileOrNew(_solid).collision = TileCollision.full(32, 32);
    // Rising to the right.
    ts.tileOrNew(_up).collision = TileCollision(
      shapes: [
        const TilePolygonShape([Offset(0, 32), Offset(32, 0), Offset(32, 32)]),
      ],
    );
    physics = PhysicsEngine.pureDart()..initialize();
    world = World()..initialize();
    world.context.tiles.putTileset('s.tileset.json', ts);
    world
      ..addSystem(PhysicsSystem(physics))
      ..addSystem(PlayerControlSystem());
    registerLevelMapSystems(world);
    final data = LevelMapData(tileWidth: 32, tileHeight: 32)
      ..addTileset('s.tileset.json');
    final ground = data.addLayer(name: 'Ground')..collides = true;
    // Flat ground to x = 4, a ramp up across x = 5..9, flat again after.
    for (var x = 0; x < 20; x++) {
      ground.cells.setCell(x, 12, TileCell.make(0, _solid));
    }
    for (var i = 0; i < 5; i++) {
      final x = 5 + i;
      final top = 11 - i;
      ground.cells.setCell(x, top, TileCell.make(0, _up));
      for (var y = top + 1; y < 12; y++) {
        ground.cells.setCell(x, y, TileCell.make(0, _solid));
      }
    }
    for (var x = 10; x < 20; x++) {
      for (var y = 7; y < 12; y++) {
        ground.cells.setCell(x, y, TileCell.make(0, _solid));
      }
    }
    world.createEntityWithComponents([
      TransformComponent(),
      LevelMapComponent(inline: data),
    ]);
  });

  tearDown(() {
    world.dispose();
    physics.dispose();
  });

  Entity spawn(double x, double y) =>
      player = world.createEntityWithComponents([
        TransformComponent(position: Vector3(x, y, 0)),
        VelocityComponent(),
        // As the template's player: the kit steers it by its velocity.
        RigidBody2D(
          lockRotation: true,
          friction: 0.2,
          restitution: 0,
          linearDamping: 0,
        ),
        Collider2D(size: Vector2(24, 40)),
        PlayerControlComponent(),
        InputComponent(),
      ]);

  Offset at() {
    final p = player.getComponent<TransformComponent>()!.position;
    return Offset(p.x, p.y);
  }

  bool grounded() => player.getComponent<PlayerControlComponent>()!.isGrounded;

  void run(int frames, [void Function()? each]) {
    for (var i = 0; i < frames; i++) {
      world.update(1 / 60);
      each?.call();
    }
  }

  test('standing on a slope, the character stays put', () {
    spawn(7 * _t + 16, 6 * _t);
    run(90);
    expect(grounded(), isTrue);
    final before = at();
    run(120);
    expect((at() - before).distance, lessThan(2), reason: 'no sliding down');
    expect(
      player.getComponent<RigidBody2D>()!.groundNormal.dx,
      isNot(closeTo(0, 0.05)),
      reason: 'it is on the slope, not the flat',
    );
  });

  test('running up it, the character climbs', () {
    spawn(6 * _t + 16, 7 * _t);
    run(60);
    final start = at();
    player.getComponent<InputComponent>()!.setVector(
      'move',
      const Offset(1, 0),
    );
    run(30);
    final end = at();
    expect(end.dx, greaterThan(start.dx + 20));
    expect(end.dy, lessThan(start.dy - 20), reason: 'up the slope');

    // And over the top without taking off.
    var highest = double.infinity;
    run(40, () {
      if (at().dx > 10 * _t + 12 && at().dy < highest) highest = at().dy;
    });
    expect(at().dx, greaterThan(10 * _t + 12), reason: 'it got over');
    expect(
      highest,
      greaterThan(7 * _t - 20 - 3),
      reason: 'no hop at the crest',
    );
  });

  test('running down it, the character stays on the ground', () {
    spawn(9 * _t + 16, 3 * _t);
    run(60);
    expect(grounded(), isTrue);
    player.getComponent<InputComponent>()!.setVector(
      'move',
      const Offset(-1, 0),
    );
    var airborne = 0;
    var frames = 0;
    run(40, () {
      frames++;
      if (!grounded()) airborne++;
    });
    expect(at().dx, lessThan(8 * _t), reason: 'it went down');
    expect(airborne / frames, lessThan(0.2), reason: 'not skipping down it');
  });

  test('a jump from a slope still leaves it', () {
    spawn(7 * _t + 16, 6 * _t);
    run(60);
    final y = at().dy;
    final input = player.getComponent<InputComponent>()!;
    // A press: held one frame, then let go.
    input.setDown('jump', true);
    run(1);
    input.setDown('jump', false);
    var highest = y;
    run(30, () {
      if (at().dy < highest) highest = at().dy;
    });
    expect(highest, lessThan(y - 30));
  });
}
