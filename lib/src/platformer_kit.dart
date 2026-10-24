library;

import 'package:just_game_engine/just_game_engine.dart';

import 'camera/platformer_camera.dart';
import 'components/player_control_component.dart';
import 'codecs/platformer_schemas.dart';
import 'systems/platformer.dart';
import 'map/platformer_collision_kinds.dart';

/// One-call setup for the platformer runtime.
///
/// The systems order themselves by [System.priority], so the order they are
/// added in does not matter — but adding them as a set does, because they
/// depend on each other: [PlatformerGameplaySystem] reads the grounded state
/// [PlayerControlSystem] writes, and both consume the collision events the
/// engine's `PhysicsSystem` publishes. Leaving one out breaks the others
/// quietly rather than loudly.
abstract final class PlatformerKit {
  /// What the kit teaches an engine: how to save and load every platformer
  /// component, the migrations for levels an older kit saved, the animator
  /// bindings and the collision kinds.
  ///
  /// Give it to the engine before loading a level that uses them —
  /// `EngineConfig(extensions: [PlatformerKit.extension])`, or
  /// `context.install(PlatformerKit.extension)` for a world of your own;
  /// without it the loader stops with an error naming the first platformer
  /// component it meets, rather than loading platforms that are not
  /// platforms. Installed once per context.
  static const ContextExtension extension = _PlatformerKitExtension();

  /// Installs the kit into [context]; what [extension] does.
  static void install(EngineContext context) {
    context.definitions.registerAll(PlatformerSchemas.all, ifAbsent: true);
    // Levels saved by an older kit are brought forward as they load.
    PlatformerMigrations.install(context);
    registerAnimatorBindings(context.animatorBindings);
    // Painted spikes, springs and crumbling ground.
    PlatformerCollisionKinds.register(context.collisionKinds);
  }

  /// What an animator graph can bind a parameter to on a platformer
  /// character, beyond the engine's velocity and health: whether it stands
  /// on something, is going up, is coming down, just touched down, or is
  /// flashing after a hit — into [bindings], an engine's
  /// (`context.animatorBindings`). Safe to call more than once.
  static void registerAnimatorBindings(AnimatorBindings bindings) {
    PlayerControlComponent? of(Entity e) =>
        e.getComponent<PlayerControlComponent>();
    bindings.register('grounded', (e) => of(e)?.isGrounded);
    bindings.register('rising', (e) => of(e)?.isRising);
    bindings.register('falling', (e) {
      final control = of(e);
      if (control == null) return null;
      // A character's own velocity; a rigid body's, through its velocity
      // component.
      final vy =
          e.getComponent<CharacterBody2D>()?.velocity.dy ??
          e.getComponent<VelocityComponent>()?.velocity.y ??
          0;
      return !control.isGrounded && vy > 0;
    });
    bindings.register('justLanded', (e) => of(e)?.justLanded);
    bindings.register('invulnerable', (e) {
      final control = of(e);
      return control == null ? null : control.invulnerabilityTimer > 0;
    });
  }

  /// Adds every platformer system to [world].
  ///
  /// Add the engine's own systems (input, physics, camera, rendering) as
  /// well; this only adds the genre layer on top. Call once per world —
  /// twice would run every rule twice a frame.
  static void registerSystems(
    World world, {
    required PhysicsEngine physics,
    required GameCamera camera,
    String moveAction = 'move',
    String jumpAction = 'jump',
  }) {
    for (final system in systems(
      physics: physics,
      camera: camera,
      moveAction: moveAction,
      jumpAction: jumpAction,
    )) {
      world.addSystem(system);
    }
  }

  /// The platformer systems, for a game that wants to add them selectively or
  /// swap in its own replacement for one of them.
  ///
  /// [physics] is what the enemies probe and what a level's
  /// [LevelBoundsComponent.gravityY] is applied to; [camera] is what
  /// parallax is measured against; [moveAction] and [jumpAction] name the
  /// input actions the player controller reads.
  static List<System> systems({
    required PhysicsEngine physics,
    required GameCamera camera,
    String moveAction = 'move',
    String jumpAction = 'jump',
  }) => [
    PlayerControlSystem(moveAction: moveAction, jumpAction: jumpAction),
    PlatformerGameplaySystem(physics: physics),
    MovingPlatformSystem(),
    PatrolEnemySystem(physics: physics),
    ParallaxRectSystem(camera: camera),
  ];
}

final class _PlatformerKitExtension implements RefreshableExtension {
  const _PlatformerKitExtension();

  @override
  String get id => 'just_platformer_kit';

  @override
  void install(EngineContext context) => PlatformerKit.install(context);

  /// After a hot reload, in an editor: the components, bindings and
  /// collision kinds as the code now makes them. Each replaces by key; the
  /// migrations, which append, are left as installed.
  @override
  void refresh(EngineContext context) {
    context.definitions.refresh(PlatformerSchemas.all);
    PlatformerKit.registerAnimatorBindings(context.animatorBindings);
    PlatformerCollisionKinds.register(context.collisionKinds);
  }
}
