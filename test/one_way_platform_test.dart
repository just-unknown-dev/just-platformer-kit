// A one-way platform is a one-way body.
//
// The prefab used to build an ordinary solid body under a
// `PlatformComponent(kind: oneWay)` label, so the player could not jump up
// through it — the kind promised something the collider never did.

import 'package:flutter/painting.dart' show Offset, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_platformer_kit/editor.dart';
import 'package:just_platformer_kit/just_platformer_kit.dart';

void main() {
  test('the one-way prefab builds a one-way body', () {
    final prefab = PlatformerPrefabs.all.firstWhere(
      (p) => p.id == 'platformer.platform_one_way',
    );
    final components = prefab.build(Offset.zero, const Size(128, 16));
    final body = components.whereType<Collider2DComponent>().single;

    expect(body.oneWay, isTrue);
  });

  test('the solid prefab stays solid', () {
    final prefab = PlatformerPrefabs.all.firstWhere(
      (p) => p.id == 'platformer.platform_solid',
    );
    final components = prefab.build(Offset.zero, const Size(128, 32));

    expect(components.whereType<Collider2DComponent>().single.oneWay, false);
  });

  test('a one-way platform saved with a solid body becomes one-way', () {
    final world = World()..initialize();
    addTearDown(world.dispose);
    world.addSystem(PlatformerGameplaySystem());
    final platform = world.createEntityWithComponents([
      TransformComponent(),
      RigidBody2DComponent(bodyType: Body2DType.static), Collider2DComponent(size: Vector2(128, 16)),
      PlatformComponent(kind: PlatformKind.oneWay),
    ]);

    world.update(1 / 60);

    expect(platform.getComponent<Collider2DComponent>()!.oneWay, isTrue);
  });
}
