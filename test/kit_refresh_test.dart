// The kit after a hot reload, in an editor: its components put in place
// again as the code now makes them (EngineContext.refreshDefinitions), as
// often as the editor asks, with nothing it registered lost or doubled.

import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_platformer_kit/just_platformer_kit.dart';

void main() {
  test('the kit is refreshable', () {
    expect(PlatformerKit.extension, isA<RefreshableExtension>());
  });

  test('refreshing puts each component in place again, every time', () {
    final context = EngineContext(extensions: [PlatformerKit.extension]);
    final before = {
      for (final d in context.definitions.definitions) d.type: d,
    };

    context
      ..refreshDefinitions()
      ..refreshDefinitions();

    final after = {for (final d in context.definitions.definitions) d.type: d};
    expect(after.keys, unorderedEquals(before.keys));
    for (final type in ['PatrolEnemyComponent', 'PlatformComponent']) {
      expect(after[type], isNotNull, reason: type);
      expect(identical(after[type], before[type]), isFalse, reason: type);
      expect(
        after[type]!.fields.map((f) => f.name),
        before[type]!.fields.map((f) => f.name),
        reason: type,
      );
    }
  });

  test('a refreshed context still reads a platformer component', () {
    final context = EngineContext(extensions: [PlatformerKit.extension])
      ..refreshDefinitions();
    final enemy = PatrolEnemyComponent()..speed = 42;
    final json = context.definitions.encode(enemy)!;
    final back = context.definitions.decode(json)! as PatrolEnemyComponent;
    expect(back.speed, 42);
  });
}
