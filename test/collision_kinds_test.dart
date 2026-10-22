// Painted platformer tiles behave like the placed ones: spikes hurt,
// springs launch, crumbling ground gives way — and takes its tile with it.
//
// On the engine's pure-Dart physics, with the tile systems building bodies
// from a tileset, as a level does.

import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_platformer_kit/just_platformer_kit.dart';

const _tile = 32.0;
const _solid = 0, _spike = 1, _spring = 2, _crumble = 3;

TilesetData _tileset() {
  final ts = TilesetData(
    name: 'kit',
    tileWidth: 32,
    tileHeight: 32,
    columns: 4,
    tileCount: 4,
  );
  ts.tileOrNew(_solid).collision = TileCollision.full(32, 32);
  ts.tileOrNew(_spike)
    ..collision = TileCollision.full(32, 32, kind: 'hazard')
    ..properties.set('damage', 2.0, TilePropertyType.float);
  ts.tileOrNew(_spring).collision = TileCollision.full(32, 32, kind: 'bouncy');
  ts.tileOrNew(_crumble)
    ..collision = TileCollision.full(32, 32, kind: 'crumbling')
    ..properties.set('crumbleDelay', 0.1, TilePropertyType.float)
    ..properties.set('respawnDelay', 0.5, TilePropertyType.float);
  return ts;
}

class _Level {
  _Level() {
    physics = PhysicsEngine.pureDart()..initialize();
    world = World()
      ..context.install(PlatformerKit.extension)
      ..initialize();
    world.context.tiles.putTileset('kit.tileset.json', _tileset());
    world
      ..addSystem(PhysicsSystem(physics))
      ..addSystem(PlayerControlSystem())
      ..addSystem(PlatformerGameplaySystem());
    registerLevelMapSystems(world);
    final data = LevelMapData(tileWidth: 32, tileHeight: 32)
      ..addTileset('kit.tileset.json');
    ground = data.addLayer(name: 'Ground')..collides = true;
    map = world.createEntityWithComponents([
      TransformComponent(),
      LevelMapComponent(inline: data),
    ], name: 'Map');
  }

  late final PhysicsEngine physics;
  late final World world;
  late final MapLayerData ground;
  late final Entity map;

  void row(int y, int x0, int x1, int tile) {
    for (var x = x0; x <= x1; x++) {
      ground.cells.setCell(x, y, TileCell.make(0, tile));
    }
  }

  Entity player(double x, double y) => world.createEntityWithComponents([
    TransformComponent(position: Vector3(x, y, 0)),
    VelocityComponent(),
    RigidBody2D(lockRotation: true, friction: 0.2, restitution: 0),
    Collider2D(size: Vector2(24, 40)),
    PlayerControlComponent(),
    InputComponent(),
    HealthComponent(maxHealth: 5),
    TagComponent('player'),
  ], name: 'Player');

  void run(int frames, [void Function()? each]) {
    for (var i = 0; i < frames; i++) {
      world.update(1 / 60);
      each?.call();
    }
  }

  void dispose() {
    world.dispose();
    physics.dispose();
  }
}

void main() {
  late _Level level;
  setUp(() => level = _Level());
  tearDown(() => level.dispose());

  test('the kit registers its kinds', () {
    expect([
      for (final k in PlatformerCollisionKinds.all)
        level.world.context.collisionKinds.byId(k.id),
    ], everyElement(isNotNull));
  });

  test('spikes hurt by their tile\'s damage, and are passed through', () {
    level.row(6, 0, 6, _spike);
    level.row(7, 0, 6, _solid);
    final hits = <double>[];
    level.world.events.on<EntityDamagedEvent>((e) => hits.add(e.amount));
    final player = level.player(3 * _tile + 16, 2 * _tile);
    level.run(90);

    expect(hits, isNotEmpty);
    expect(hits.first, 2);
    expect(player.getComponent<HealthComponent>()!.health, 3);
    final spikes = level.world
        .query([MapBodyComponent])
        .where((e) => e.hasComponent<HazardComponent>());
    expect(spikes, isNotEmpty);
    expect(spikes.first.getComponent<RigidBody2D>()!.isSensor, isTrue);
  });

  test('a spring launches what lands on it', () {
    level.row(6, 0, 6, _spring);
    final player = level.player(3 * _tile + 16, 2 * _tile);
    var launched = false;
    level.run(90, () {
      if (player.getComponent<VelocityComponent>()!.velocity.y < -1000) {
        launched = true;
      }
    });
    expect(launched, isTrue);
  });

  test('crumbling ground gives way under the player and comes back, tile '
      'and all', () {
    level.row(6, 0, 2, _crumble);
    level.run(1);
    expect(
      level.world.query([MapBodyComponent]).length,
      3,
      reason: 'one body a tile: each falls on its own',
    );

    final player = level.player(1 * _tile + 16, 4 * _tile);
    final handle = LevelMaps.of(level.world, level.map)!;
    var gone = false;
    level.run(40, () {
      if (handle.runtime.hiddenCells[level.ground.id]?.isNotEmpty ?? false) {
        gone = true;
      }
    });
    expect(gone, isTrue, reason: 'the tile it stood on went');
    final yAfter = player.getComponent<TransformComponent>()!.position.y;
    expect(yAfter, greaterThan(6 * _tile), reason: 'and so did the player');

    level.run(60);
    expect(
      handle.runtime.hiddenCells[level.ground.id],
      isEmpty,
      reason: 'back',
    );
  });
}
