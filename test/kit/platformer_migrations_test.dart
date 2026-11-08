// Levels saved before every component's name ended in `Component` (scene
// format 10) load with the kit's components under their new names — and so
// does a level saved at the current format that still names an old one:
// the kit's renames apply at every format.
import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_platformer_kit/just_platformer_kit.dart';

void main() {
  test('a v10 moving platform loads as a MovingPlatform2DComponent', () {
    final context = EngineContext(extensions: [PlatformerKit.extension]);
    final scene = SceneFormat.migrate({
      'version': 10,
      'name': 's',
      'entities': [
        {
          'name': 'Lift',
          'components': [
            {'type': 'MovingPlatformComponent', 'fields': <String, dynamic>{}},
          ],
        },
      ],
    }, hooks: context.migrations);
    final component =
        ((scene['entities'] as List).single['components'] as List).single
            as Map;
    expect(component['type'], 'MovingPlatform2DComponent');
    for (final renamed in PlatformerMigrations.renamedTypes.values) {
      expect(context.definitions.definitionByType(renamed), isNotNull);
    }
  });

  test('a current-format level naming an old type loads it renamed', () {
    final context = EngineContext(extensions: [PlatformerKit.extension]);
    final scene = SceneFormat.migrate({
      'version': SceneFormat.current,
      'name': 's',
      'entities': [
        {
          'name': 'Lift',
          'components': [
            {
              'type': 'MovingPlatformComponent',
              'fields': <String, dynamic>{'speed': 75.0},
            },
          ],
        },
      ],
    }, hooks: context.migrations);
    final component =
        ((scene['entities'] as List).single['components'] as List).single
            as Map;
    expect(component['type'], 'MovingPlatform2DComponent');
    expect((component['fields'] as Map)['speed'], 75.0);
  });

  test('a current-format level naming only current types is itself', () {
    final context = EngineContext(extensions: [PlatformerKit.extension]);
    final level = {
      'version': SceneFormat.current,
      'name': 's',
      'entities': [
        {
          'name': 'Lift',
          'components': [
            {
              'type': 'MovingPlatform2DComponent',
              'fields': <String, dynamic>{},
            },
          ],
        },
      ],
    };
    expect(
      identical(SceneFormat.migrate(level, hooks: context.migrations), level),
      isTrue,
    );
  });
}
