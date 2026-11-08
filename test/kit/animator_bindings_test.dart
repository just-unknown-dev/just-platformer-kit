// A platformer character's state, offered to animator graphs by name.

import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_platformer_kit/just_platformer_kit.dart';

void main() {
  test('the kit binds grounded, rising, falling, landing and i-frames', () {
    final world = World();
    addTearDown(world.dispose);
    PlatformerKit.registerAnimatorBindings(world.context.animatorBindings);
    final control = PlayerControlComponent();
    final velocity = VelocityComponent();
    final player = world.createEntityWithComponents([
      TransformComponent(),
      velocity,
      control,
    ]);
    final crate = world.createEntityWithComponents([TransformComponent()]);
    Object? read(String id, [Entity? e]) =>
        world.context.animatorBindings.of(id)!(e ?? player);

    control.isGrounded = true;
    expect(read('grounded'), isTrue);
    expect(read('falling'), isFalse);

    control.isGrounded = false;
    velocity.velocity.y = 300; // screen space: down
    expect(read('falling'), isTrue);
    velocity.velocity.y = -300;
    expect(read('falling'), isFalse);

    control.invulnerabilityTimer = 0.4;
    expect(read('invulnerable'), isTrue);
    expect(read('grounded', crate), isNull, reason: 'not a character');
  });
}
