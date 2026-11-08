// level_01 in the v1 format. The migrated file is committed and reviewed, so
// any change to what migration produces is a visible diff, not a surprise.

import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_platformer_kit/just_platformer_kit.dart';

const _v0 = 'test/fixtures/level_01.scene.json';
const _v1 = 'test/fixtures/level_01.migrated.scene.json';

Map<String, dynamic> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  // What the game's boot gives its engine: the core and the kit.
  late EngineContext context;
  setUp(() => context = EngineContext(extensions: [PlatformerKit.extension]));
  tearDown(() => context.dispose());

  test('migrating the v0 level matches the committed golden', () {
    final migrated = jsonDecode(
      jsonEncode(SceneFormat.migrate(_read(_v0), hooks: context.migrations)),
    );
    final file = File(_v1);
    if (!file.existsSync()) {
      file.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(migrated),
      );
      fail('Seeded $_v1; review it, then rerun.');
    }
    expect(
      const DeepCollectionEquality().equals(migrated, _read(_v1)),
      isTrue,
      reason: 'migration output changed; diff against a fresh seed',
    );
  });

  test('v0 and v1 load into the same world through the loader', () {
    // The loader migrates v0 on the way in; both files must yield entities
    // whose components re-encode identically, field for field.
    List<Map<String, dynamic>> snapshot(Map<String, dynamic> scene) {
      final world = World(context: context)..initialize();
      addTearDown(world.dispose);
      return [
        for (final e in SceneLoader.load(world, scene))
          for (final c in e.components) ?context.definitions.encode(c),
      ];
    }

    final fromV0 = snapshot(_read(_v0));
    final fromV1 = snapshot(_read(_v1));
    // 126 authored; the camera migration retires the follow flag and adds
    // a three-component MainCamera, the kit's turns one zone into three,
    // and the 23 bodies each become a rigid body and a collider.
    expect(fromV0, hasLength(153));
    expect(fromV0, fromV1);
  });

  test('an unknown type after migration still stops the load by name', () {
    final json = SceneFormat.migrate(hooks: context.migrations, {
      'name': 'x',
      'entities': [
        {
          'name': 'E',
          'components': [
            {'type': 'NoSuchComponent', 'a': 1},
          ],
        },
      ],
    });
    final world = World(context: context)..initialize();
    addTearDown(world.dispose);
    expect(
      () => SceneLoader.load(world, json),
      throwsA(
        isA<UnknownComponentTypeException>().having(
          (e) => e.type,
          'type',
          'NoSuchComponent',
        ),
      ),
    );
  });
}
