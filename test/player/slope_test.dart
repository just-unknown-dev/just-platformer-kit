// Slopes: a character stands still on one, runs up it at its usual speed,
// and runs down it without taking off — on tiles built by the engine, on
// each physics backend, with a small box and with the platformer template's
// player. Then the template's player over the ramps of the template's own
// levels, cell for cell: tiled ramps are where a player that goes by its
// contacts loses the ground running down, and catches on the seams
// climbing.

import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_platformer_kit/just_platformer_kit.dart';

const _t = 32.0;
const _solid = 0, _up = 1, _down = 2;

/// A player's collider, and half its height.
typedef _Shape = (Collider2DComponent Function(), double);

/// A small box.
final _Shape _small = (() => Collider2DComponent(size: Vector2(24, 40)), 20);

/// The platformer template's player: a 32 × 48 box with its corners rounded
/// (its `game_boot.dart`'s `spawnPlayer`).
final _Shape _templatePlayer = (
  () => Collider2DComponent(size: Vector2(32, 48), cornerRadius: 4),
  24,
);

void main() {
  for (final (backend, make) in [
    ('native Box2D', PhysicsEngineFactory.create2D),
    ('pure Dart', Physics2DEngine.pureDart),
  ]) {
    group('$backend, a small box', () => _ramp(make, _small));
    group('$backend, the template player', () => _ramp(make, _templatePlayer));
    group(
      "$backend, the template player on its levels' ramps",
      () => _levels(make),
    );
    group('$backend, a sharp box dropped on the crest', () => _crest(make));
  }
}

/// The ramp tiles: rising to the right, and falling.
TilesetData _tileset() {
  final ts = TilesetData(
    name: 's',
    tileWidth: 32,
    tileHeight: 32,
    columns: 3,
    tileCount: 3,
  );
  ts.tileOrNew(_solid).collision = TileCollision.full(32, 32);
  ts.tileOrNew(_up).collision = TileCollision(
    shapes: [
      const TilePolygonShape([Offset(0, 32), Offset(32, 0), Offset(32, 32)]),
    ],
  );
  ts.tileOrNew(_down).collision = TileCollision(
    shapes: [
      const TilePolygonShape([Offset(0, 0), Offset(32, 32), Offset(0, 32)]),
    ],
  );
  return ts;
}

/// A world on [physics] with player control and a collidable map of
/// [paint]'s cells.
World _world(
  Physics2DEngine physics,
  void Function(TileChunkStore cells) paint,
) {
  final world = World()..initialize();
  world.context.tiles.putTileset('s.tileset.json', _tileset());
  world
    ..addSystem(Physics2DSystem(physics))
    ..addSystem(PlayerControlSystem());
  registerLevelMapSystems(world);
  final data = LevelMapData(tileWidth: 32, tileHeight: 32)
    ..addTileset('s.tileset.json');
  paint((data.addLayer(name: 'Ground')..collides = true).cells);
  world.createEntityWithComponents([
    TransformComponent(),
    LevelMapComponent(inline: data),
  ]);
  return world;
}

Entity _spawn(World world, _Shape shape, double x, double y) =>
    world.createEntityWithComponents([
      TransformComponent(position: Vector3(x, y, 0)),
      VelocityComponent(),
      // As the template's player: the kit steers it by its velocity.
      RigidBody2DComponent(
        mass: 1,
        lockRotation: true,
        friction: 0.2,
        restitution: 0,
        linearDamping: 0,
        angularDamping: 0,
      ),
      shape.$1(),
      PlayerControlComponent(),
      InputComponent(),
    ]);

void _ramp(Physics2DEngine Function() make, _Shape shape) {
  late Physics2DEngine physics;
  late World world;
  late Entity player;
  final half = shape.$2;

  setUp(() {
    physics = make()..initialize();
    // Flat ground to x = 4, a ramp up across x = 5..9, flat again after.
    world = _world(physics, (cells) {
      for (var x = 0; x < 20; x++) {
        cells.setCell(x, 12, TileCell.make(0, _solid));
      }
      for (var i = 0; i < 5; i++) {
        final x = 5 + i;
        final top = 11 - i;
        cells.setCell(x, top, TileCell.make(0, _up));
        for (var y = top + 1; y < 12; y++) {
          cells.setCell(x, y, TileCell.make(0, _solid));
        }
      }
      for (var x = 10; x < 20; x++) {
        for (var y = 7; y < 12; y++) {
          cells.setCell(x, y, TileCell.make(0, _solid));
        }
      }
    });
  });

  tearDown(() {
    world.dispose();
    physics.dispose();
  });

  Entity spawn(double x, double y) => player = _spawn(world, shape, x, y);

  Offset at() {
    final p = player.getComponent<TransformComponent>()!.position;
    return Offset(p.x, p.y);
  }

  bool grounded() => player.getComponent<PlayerControlComponent>()!.isGrounded;
  void move(double x) =>
      player.getComponent<InputComponent>()!.setVector('move', Offset(x, 0));

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
      player.getComponent<RigidBody2DComponent>()!.groundNormal.dx,
      isNot(closeTo(0, 0.05)),
      reason: 'it is on the slope, not the flat',
    );
  });

  test('running up it, the character climbs', () {
    spawn(6 * _t + 16, 7 * _t);
    run(60);
    final start = at();
    move(1);
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
      greaterThan(7 * _t - half - 3),
      reason: 'no hop at the crest',
    );
  });

  test('running up it from the flat, the corner does not catch', () {
    spawn(2 * _t + 16, 10 * _t);
    run(60);
    move(1);
    var stalled = 0;
    var last = at().dx;
    run(40, () {
      if ((at().dx - last).abs() < 0.5) stalled++;
      last = at().dx;
    });
    expect(stalled, lessThanOrEqualTo(3), reason: 'not stuck at the foot');
    expect(at().dx, greaterThan(6 * _t), reason: 'onto the ramp');
    expect(at().dy, lessThan(12 * _t - half - 32), reason: 'and up it');
  });

  test('running down it, the character stays on the ground', () {
    spawn(9 * _t + 16, 3 * _t);
    run(60);
    expect(grounded(), isTrue);
    move(-1);
    var airborne = 0;
    run(40, () {
      if (!grounded()) airborne++;
    });
    expect(at().dx, lessThan(8 * _t), reason: 'it went down');
    expect(airborne, lessThanOrEqualTo(2), reason: 'not skipping down it');
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
    expect(grounded(), isFalse);
  });
}

/// A box with sharp corners dropped at rest with its lower corner on the
/// crest of a ramp — its last vertex, where the level ground begins — or a
/// pixel or two either side, then run down the ramp. Its corner's slope
/// snap used to push it back onto the crest, against its run, frame after
/// frame (on native Box2D, with the corner 0–1 px past the crest).
void _crest(Physics2DEngine Function() make) {
  final shapes = <String, (Collider2DComponent Function(), double)>{
    '32 × 48': (() => Collider2DComponent(size: Vector2(32, 48)), 16),
    '24 × 40': (() => Collider2DComponent(size: Vector2(24, 40)), 12),
  };
  for (final MapEntry(key: name, value: (collider, halfWidth))
      in shapes.entries) {
    for (final mirrored in [false, true]) {
      final way = mirrored ? 'right' : 'left';
      test('$name, running $way down the ramp: it never stalls', () {
        // Corner offsets past the crest, in pixels, onto the level side.
        for (final past in [-2.0, -1.0, 0.0, 1.0, 2.0]) {
          final physics = make()..initialize();
          addTearDown(physics.dispose);
          // The ramp of _ramp — up across x = 5..9 to the crest at
          // x = 10 tiles, level after — or its mirror image.
          final world = _world(physics, (cells) {
            void set(int x, int y, int tile) => cells.setCell(
              mirrored ? 19 - x : x,
              y,
              TileCell.make(0, mirrored && tile == _up ? _down : tile),
            );
            for (var x = 0; x < 20; x++) {
              set(x, 12, _solid);
            }
            for (var i = 0; i < 5; i++) {
              set(5 + i, 11 - i, _up);
              for (var y = 12 - i; y < 12; y++) {
                set(5 + i, y, _solid);
              }
            }
            for (var x = 10; x < 20; x++) {
              for (var y = 7; y < 12; y++) {
                set(x, y, _solid);
              }
            }
          });
          addTearDown(world.dispose);
          // Its corner `past` beyond the crest, at x = 10 tiles.
          final x = 10 * _t + past - halfWidth;
          final player = world.createEntityWithComponents([
            TransformComponent(
              position: Vector3(mirrored ? 20 * _t - x : x, 3 * _t, 0),
            ),
            VelocityComponent(),
            RigidBody2DComponent(
              mass: 1,
              lockRotation: true,
              friction: 0.2,
              restitution: 0,
              linearDamping: 0,
            ),
            collider(),
            PlayerControlComponent(),
            InputComponent(),
          ]);
          for (var i = 0; i < 60; i++) {
            world.update(1 / 60);
          }
          final control = player.getComponent<PlayerControlComponent>()!;
          final t = player.getComponent<TransformComponent>()!;
          expect(control.isGrounded, isTrue, reason: 'at $past px');
          player.getComponent<InputComponent>()!.setVector(
            'move',
            Offset(mirrored ? 1 : -1, 0),
          );
          var stalled = 0, airborne = 0;
          var last = t.position.x;
          for (var i = 0; i < 40; i++) {
            world.update(1 / 60);
            if (!control.isGrounded) airborne++;
            if ((t.position.x - last).abs() < 0.5) stalled++;
            last = t.position.x;
          }
          expect(stalled, 0, reason: 'stalled frames, corner at $past px');
          expect(airborne, 0, reason: 'airborne frames, corner at $past px');
          final travelled = (t.position.x - (mirrored ? 20 * _t - x : x)).abs();
          expect(travelled, greaterThan(100), reason: 'down the ramp');
        }
      });
    }
  }
}

/// The ramps of the platformer template's levels, cell for cell from their
/// Ground layers: (map, its first cell's column and row, its rows). `#` is
/// solid, `/` a ramp tile rising to the right, `\` one falling.
const _levelMaps = {
  'showcase_2d, columns 20-44': (
    20,
    8,
    [
      '.................####....',
      '.........................',
      '.........................',
      '.......................#.',
      r'............./###########',
      r'............/############',
      r'.........../#############',
      r'........../##############',
      '#########################',
      '#########################',
    ],
  ),
  'showcase_2d, columns 80-95': (
    80,
    8,
    [
      '................',
      '................',
      '................',
      '.............###',
      r'#######\........',
      r'.#######\.......',
      r'.########\......',
      '.###############',
      '.###############',
      '################',
    ],
  ),
  'showcase_2d_cave, columns 4-21': (
    4,
    6,
    [
      '..................',
      '..................',
      '..................',
      '..................',
      r'######\...........',
      r'#######\..........',
      r'########\.........',
      r'#########\........',
      r'##########\.......',
      '##################',
      '##################',
    ],
  ),
  'showcase_2d_cave, columns 76-91': (
    76,
    6,
    [
      '................',
      '..............##',
      '................',
      '................',
      r'........./######',
      r'......../#######',
      r'......./########',
      '################',
      '################',
    ],
  ),
};

/// Runs over [_levelMaps]: the map, which way, the cell it starts on (the
/// floor under its feet), and the column it must get past.
const _levelRuns = [
  ('showcase_2d, columns 20-44', 'up', 26, 16, 1.0, 36),
  ('showcase_2d, columns 20-44', 'down', 36, 12, -1.0, 27),
  ('showcase_2d, columns 80-95', 'down', 85, 12, 1.0, 92),
  ('showcase_2d, columns 80-95', 'up', 92, 15, -1.0, 85),
  ('showcase_2d_cave, columns 4-21', 'down', 7, 10, 1.0, 17),
  ('showcase_2d_cave, columns 4-21', 'up', 18, 15, -1.0, 8),
  ('showcase_2d_cave, columns 76-91', 'up', 80, 13, 1.0, 88),
  ('showcase_2d_cave, columns 76-91', 'down', 88, 10, -1.0, 80),
];

void _levels(Physics2DEngine Function() make) {
  for (final (map, way, startX, startY, dir, pastX) in _levelRuns) {
    test('$map, running $way the ramp: on the ground all the way', () {
      final (left, top, rows) = _levelMaps[map]!;
      final physics = make()
        ..initialize()
        // The template's levels' gravity (their LevelBoundsComponent).
        ..setGravity(0, 2200);
      final world = _world(physics, (cells) {
        for (var r = 0; r < rows.length; r++) {
          for (var c = 0; c < rows[r].length; c++) {
            final tile = switch (rows[r][c]) {
              '#' => _solid,
              '/' => _up,
              r'\' => _down,
              _ => null,
            };
            if (tile != null) {
              cells.setCell(left + c, top + r, TileCell.make(0, tile));
            }
          }
        }
      });
      addTearDown(() {
        world.dispose();
        physics.dispose();
      });
      final player = _spawn(
        world,
        _templatePlayer,
        startX * _t + 16,
        startY * _t - _templatePlayer.$2 - 2,
      );
      for (var i = 0; i < 60; i++) {
        world.update(1 / 60);
      }
      final control = player.getComponent<PlayerControlComponent>()!;
      final position = player.getComponent<TransformComponent>()!.position;
      expect(control.isGrounded, isTrue, reason: 'it starts on the ground');
      player.getComponent<InputComponent>()!.setVector('move', Offset(dir, 0));

      final goal = pastX * _t + 16;
      bool past() => dir > 0 ? position.x >= goal : position.x <= goal;
      var frames = 0, airborne = 0, stalled = 0;
      var last = position.x;
      while (!past() && frames < 150) {
        world.update(1 / 60);
        frames++;
        if (!control.isGrounded) airborne++;
        if ((position.x - last).abs() < 0.5) stalled++;
        last = position.x;
      }
      expect(past(), isTrue, reason: 'it got past the ramp ($frames frames)');
      expect(airborne, lessThanOrEqualTo(2), reason: 'frames off the ground');
      expect(stalled, lessThanOrEqualTo(5), reason: 'frames caught');
    });
  }
}
