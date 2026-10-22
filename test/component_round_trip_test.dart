// Every placement in the Level Designer round-trips its components through
// JSON — CreateEntitiesCommand has to rebuild them from scratch after an undo
// has destroyed the originals.
//
// A field missing from a component's editor descriptor is silently dropped by
// that round trip and comes back as the constructor default. Nothing throws;
// the entity is simply not what was drawn. That is how camera zones ended up
// ignoring their drag and appearing at a fixed size and position.
//
// So: author each component with values that differ from every default, send
// it through the round trip, and check what comes back.

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_editor_core/just_editor_core.dart';
import 'package:just_platformer_kit/editor.dart';
import 'package:just_platformer_kit/just_platformer_kit.dart';

/// Sends [component] through the same encode/decode the designer uses.
final _scope = EditorScope(
  world: World()..initialize(),
  modules: [PlatformerModule()],
);

T roundTrip<T extends Component>(T component) {
  final json = _scope.codec.encode(component);
  expect(json, isNotNull, reason: '${component.runtimeType} did not encode');
  final restored = _scope.codec.decode(json!);
  expect(restored, isA<T>(), reason: '${component.runtimeType} did not decode');
  return restored! as T;
}

void main() {
  // The kit's definitions are what the round trip goes through: the module
  // installs the kit into the scope's context, as the game's boot does, and
  // adds the inspector's view of them.

  test('PlatformComponent keeps every authored field', () {
    final restored = roundTrip(
      PlatformComponent(
        kind: PlatformKind.crumbling,
        crumbleDelay: 0.77,
        respawnDelay: 3.25,
        bounceImpulse: 1750,
      ),
    );

    expect(restored.kind, PlatformKind.crumbling);
    expect(restored.crumbleDelay, closeTo(0.77, 1e-9));
    expect(restored.respawnDelay, closeTo(3.25, 1e-9));
    expect(restored.bounceImpulse, closeTo(1750, 1e-9));
  });

  test('MovingPlatformComponent keeps its path', () {
    final restored = roundTrip(
      MovingPlatformComponent(
        waypoints: const [Offset(10, 20), Offset(300, 40), Offset(-5, 900)],
        speed: 275,
        loopMode: PlatformLoopMode.loop,
        pauseSeconds: 1.5,
        autoStart: false,
      ),
    );

    expect(restored.waypoints, hasLength(3));
    expect(restored.waypoints.first, const Offset(10, 20));
    expect(restored.waypoints.last, const Offset(-5, 900));
    expect(restored.speed, closeTo(275, 1e-9));
    expect(restored.loopMode, PlatformLoopMode.loop);
    expect(restored.pauseSeconds, closeTo(1.5, 1e-9));
    expect(restored.autoStart, isFalse);
  });

  test('HazardComponent keeps every authored field', () {
    final restored = roundTrip(
      HazardComponent(
        damage: 2.5,
        instantKill: true,
        knockback: const Offset(120, -880),
        invulnerabilitySeconds: 2.25,
        respawnOnHit: true,
      ),
    );

    expect(restored.damage, closeTo(2.5, 1e-9));
    expect(restored.instantKill, isTrue);
    expect(restored.knockback, const Offset(120, -880));
    expect(restored.invulnerabilitySeconds, closeTo(2.25, 1e-9));
    expect(restored.respawnOnHit, isTrue);
  });

  test('CollectibleComponent keeps every authored field', () {
    final restored = roundTrip(
      CollectibleComponent(kind: 'gem', value: 25, destroyOnCollect: false),
    );

    expect(restored.kind, 'gem');
    expect(restored.value, 25);
    expect(restored.destroyOnCollect, isFalse);
  });

  test('GoalComponent keeps every authored field', () {
    final restored = roundTrip(
      GoalComponent(nextScene: 'level_07', requiresAllCollectibles: true),
    );

    expect(restored.nextScene, 'level_07');
    expect(restored.requiresAllCollectibles, isTrue);
  });

  test(
    'an empty next scene stays null rather than becoming a scene named ""',
    () {
      expect(roundTrip(GoalComponent()).nextScene, isNull);
    },
  );

  test('PatrolEnemyComponent keeps every authored field', () {
    final restored = roundTrip(
      PatrolEnemyComponent(
        behaviour: EnemyBehaviour.chase,
        speed: 155,
        patrolRange: 333,
        aggroRange: 777,
        turnAtLedge: false,
        contactDamage: 3,
        stompable: false,
      ),
    );

    expect(restored.behaviour, EnemyBehaviour.chase);
    expect(restored.speed, closeTo(155, 1e-9));
    expect(restored.patrolRange, closeTo(333, 1e-9));
    expect(restored.aggroRange, closeTo(777, 1e-9));
    expect(restored.turnAtLedge, isFalse);
    expect(restored.contactDamage, closeTo(3, 1e-9));
    expect(restored.stompable, isFalse);
  });

  test('LevelBoundsComponent keeps its bounds', () {
    final restored = roundTrip(
      LevelBoundsComponent(
        bounds: const Rect.fromLTWH(-200, -100, 5000, 2000),
        killPlaneY: 2600,
        gravityY: 1850,
      ),
    );

    expect(restored.bounds, const Rect.fromLTWH(-200, -100, 5000, 2000));
    expect(restored.killPlaneY, closeTo(2600, 1e-9));
    expect(restored.gravityY, closeTo(1850, 1e-9));
  });

  test('ParallaxRectComponent keeps its scroll factors', () {
    final restored = roundTrip(
      ParallaxRectComponent(scrollFactorX: 0.15, scrollFactorY: 0.85),
    );

    expect(restored.scrollFactorX, closeTo(0.15, 1e-9));
    expect(restored.scrollFactorY, closeTo(0.85, 1e-9));
  });

  test('PlayerControlComponent keeps its tuning', () {
    final restored = roundTrip(
      PlayerControlComponent(
        moveSpeed: 511,
        jumpSpeed: 1001,
        coyoteTime: 0.175,
        jumpBufferTime: 0.225,
        fallGravityScale: 2.35,
        jumpCutGravityScale: 4.1,
        maxJumps: 3,
        maxFallSpeed: 1900,
      ),
    );

    expect(restored.moveSpeed, closeTo(511, 1e-9));
    expect(restored.jumpSpeed, closeTo(1001, 1e-9));
    expect(restored.coyoteTime, closeTo(0.175, 1e-9));
    expect(restored.jumpBufferTime, closeTo(0.225, 1e-9));
    expect(restored.fallGravityScale, closeTo(2.35, 1e-9));
    expect(restored.jumpCutGravityScale, closeTo(4.1, 1e-9));
    expect(restored.maxJumps, 3);
    expect(restored.maxFallSpeed, closeTo(1900, 1e-9));
  });
}
