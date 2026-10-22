// The level must load in a shipped game, where the editor does not exist.
//
// This file deliberately imports nothing from just_game_engine_editor. If a
// component the level uses could only be decoded by editor code, this fails —
// which is exactly the defect the runtime loader exists to remove.

import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_platformer_kit/just_platformer_kit.dart';

Map<String, dynamic> _level() =>
    jsonDecode(File('test/fixtures/level_01.scene.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  // What the game's boot gives its engine: the core and the kit.
  late EngineContext context;
  setUp(() => context = EngineContext(extensions: [PlatformerKit.extension]));
  tearDown(() => context.dispose());

  test(
    'every component of the real level round-trips in the current format',
    () {
      // The fixture is v0. Migrated to the current format, every component
      // decodes through its definition and encodes back with every migrated
      // value intact.
      var checked = 0;
      final scene = SceneFormat.migrate(_level(), hooks: context.migrations);
      for (final entity
          in (scene['entities'] as List).cast<Map<String, dynamic>>()) {
        for (final migrated
            in (entity['components'] as List).cast<Map<String, dynamic>>()) {
          final where = '${entity['name']}.${migrated['type']}';
          final decoded = context.definitions.decode(migrated);
          expect(decoded, isNotNull, reason: where);
          Map<String, dynamic> encode(Component c) =>
              jsonDecode(jsonEncode(context.definitions.encode(c)))
                  as Map<String, dynamic>;
          final encoded = encode(decoded!);
          // Every authored value comes back; the definition may add fields
          // the old file never had (they encode at their defaults).
          expect(encoded['type'], migrated['type'], reason: where);
          for (final f
              in (migrated['fields'] as Map<String, dynamic>).entries) {
            expect(
              encoded['fields'],
              containsPair(f.key, f.value),
              reason: where,
            );
          }
          // And in the current format the round trip is exact.
          final again = encode(context.definitions.decode(encoded)!);
          expect(again, encoded, reason: where);
          checked++;
        }
      }
      // 126 authored; the camera migration retires the follow flag and adds
      // a three-component MainCamera, the kit's turns one zone into three,
      // and the 23 bodies each become a rigid body and a collider.
      expect(checked, 153);
    },
  );

  test('the level loads into a bare world with every entity intact', () {
    final world = World(context: context)..initialize();
    addTearDown(world.dispose);

    final entities = SceneLoader.load(world, _level());
    // 25 authored, plus the MainCamera the camera migration adds for the
    // player the old follow flag sat on.
    expect(entities, hasLength(26));

    int count<T extends Component>() =>
        world.query([T]).where((e) => e.isActive).length;
    expect(count<TransformComponent>(), 26);
    expect(count<VirtualCameraComponent>(), 2);
    expect(count<LayerComponent>(), 25);
    expect(count<PlatformComponent>(), 22);
    expect(count<Collider2D>(), 23);
    expect(count<RigidBody2D>(), 23);
    expect(count<PlayerControlComponent>(), 1);
    // The old camera zone is now a shot with a trigger around it.
    expect(count<CameraTriggerComponent>(), 1);
    expect(count<SpawnComponent>(), 1);
  });

  test('authored values survive the load, not just the component types', () {
    final world = World(context: context)..initialize();
    addTearDown(world.dispose);
    final loaded = SceneLoader.load(world, _level());
    final source =
        (SceneFormat.migrate(_level(), hooks: context.migrations)['entities']
                as List)
            .cast<Map<String, dynamic>>();

    // Paired by position, not name: the real level has two entities both
    // called Platform_20, so a name lookup would compare the wrong ones.
    expect(loaded, hasLength(source.length));
    for (var i = 0; i < loaded.length; i++) {
      final entity = loaded[i];
      final json = source[i];
      expect(entity.name, json['name']);
      Map<String, dynamic>? raw(String type) =>
          (json['components'] as List)
                  .cast<Map<String, dynamic>>()
                  .where((c) => c['type'] == type)
                  .firstOrNull?['fields']
              as Map<String, dynamic>?;

      // Compare against the source, so a codec that decodes to defaults
      // cannot pass by producing the right *types*.
      final p = raw('TransformComponent')!['position'] as Map<String, dynamic>;
      final transform = entity.getComponent<TransformComponent>()!;
      expect(
        transform.position.x,
        (p['x'] as num).toDouble(),
        reason: entity.name,
      );
      expect(
        transform.position.y,
        (p['y'] as num).toDouble(),
        reason: entity.name,
      );

      final plat = raw('PlatformComponent');
      if (plat != null) {
        expect(
          entity.getComponent<PlatformComponent>()!.kind.name,
          plat['kind'],
          reason: entity.name,
        );
      }
      final rect = raw('RectangleComponent');
      if (rect != null) {
        // Shapes are stored under RenderableComponent, so read the list
        // rather than getComponent<RectangleComponent>.
        final r = entity.components.whereType<RectangleComponent>().single;
        expect(r.width, (rect['width'] as num).toDouble(), reason: entity.name);
        expect(
          r.height,
          (rect['height'] as num).toDouble(),
          reason: entity.name,
        );
      }
    }
  });

  test('an unregistered component type stops the load and names itself', () {
    // A bare world: the engine's own components, the kit's deliberately
    // missing.
    final world = World()..initialize();
    addTearDown(world.dispose);

    expect(
      () => SceneLoader.load(world, _level()),
      throwsA(
        isA<UnknownComponentTypeException>().having(
          (e) => e.type,
          'type',
          anyOf('PlatformComponent', 'PlayerControlComponent'),
        ),
      ),
    );
    // Nothing half-loaded: a failed load leaves the world as it was.
    expect(world.query([TransformComponent]), isEmpty);
  });
}
