library;

import 'dart:math' as math;

import 'package:flutter/painting.dart' show Offset;

import 'package:just_game_engine/just_game_engine.dart';

import '../components/platformer.dart';
import '../platformer_tags.dart';

/// Walks simple enemies back and forth, or toward the nearest player.
///
/// Deliberately minimal — a template needs one enemy that reads clearly, not
/// an AI framework. Anything cleverer belongs in game code.
class PatrolEnemySystem extends System {
  PatrolEnemySystem({
    required this.physics,
    this.playerTag = PlatformerTags.player,
  });

  /// Used for the ledge probe. Pass `engine.physics`.
  final PhysicsEngine physics;

  /// [TagComponent] value identifying the players a chaser goes after.
  final String playerTag;

  @override
  int get priority => SystemPriorities.playerControl - 1;

  @override
  List<Type> get requiredComponents => [
    TransformComponent,
    VelocityComponent,
    PatrolEnemyComponent,
  ];

  @override
  void update(double deltaTime) {
    // Gathered once a step, and only if something chases.
    List<Offset>? players;

    forEach((entity) {
      if (!entity.isActive) return;

      final enemy = entity.getComponent<PatrolEnemyComponent>()!;
      if (enemy.isDefeated) return;

      final transform = entity.getComponent<TransformComponent>()!;
      final velocity = entity.getComponent<VelocityComponent>()!;
      enemy.originX ??= transform.position.x;

      switch (enemy.behaviour) {
        case EnemyBehaviour.stationary:
          velocity.velocity.x = 0;
          return;

        case EnemyBehaviour.patrol:
          _patrol(entity, enemy, transform);

        case EnemyBehaviour.chase:
          players ??= _players();
          _chase(entity, enemy, transform, players!);
      }

      velocity.velocity.x = enemy.facing * enemy.speed;
    });
  }

  void _patrol(
    Entity entity,
    PatrolEnemyComponent enemy,
    TransformComponent transform,
  ) {
    final travelled = transform.position.x - enemy.originX!;
    if (travelled.abs() >= enemy.patrolRange) {
      // Turn around, and face back toward the origin rather than simply
      // flipping — otherwise an enemy nudged past its range by a collision
      // oscillates on the boundary instead of walking back.
      enemy.facing = travelled > 0 ? -1 : 1;
    } else if (enemy.turnAtLedge && _atLedgeOrWall(entity, transform, enemy)) {
      enemy.facing = -enemy.facing;
    }
  }

  void _chase(
    Entity entity,
    PatrolEnemyComponent enemy,
    TransformComponent transform,
    List<Offset> players,
  ) {
    // The nearest player — with two, a chaser does not ignore the one right
    // beside it for the one who happened to spawn first.
    final here = Offset(transform.position.x, transform.position.y);
    Offset? target;
    var best = double.infinity;
    for (final p in players) {
      final d = (p - here).distanceSquared;
      if (d < best) {
        best = d;
        target = p;
      }
    }
    if (target == null) return;

    final dx = target.dx - here.dx;
    if (math.sqrt(best) > enemy.aggroRange) {
      // Out of range: fall back to patrolling so it does not freeze.
      _patrol(entity, enemy, transform);
      return;
    }
    enemy.facing = dx >= 0 ? 1 : -1;
  }

  /// Probes just ahead of and below the enemy for missing ground.
  ///
  /// Costs one ray per enemy per frame, which is why
  /// [PatrolEnemyComponent.turnAtLedge] is opt-out: enemies on continuous
  /// ground never need it.
  bool _atLedgeOrWall(
    Entity entity,
    TransformComponent transform,
    PatrolEnemyComponent enemy,
  ) {
    final bodyRef = entity.getComponent<PhysicsBodyRefComponent>();
    if (bodyRef == null) return false;

    // The collider as simulated: placed and scaled with the entity.
    final bounds = bodyRef.body.shape.getBounds(Offset.zero);
    final aheadX = transform.position.x + enemy.facing * (bounds.width / 2 + 4);
    final footY = transform.position.y + bounds.height / 2;

    final hit = physics.castRay(
      Ray(
        origin: Offset(aheadX, footY),
        direction: const Offset(0, 1),
        maxDistance: bounds.height,
      ),
      // Exclude self, or the probe immediately hits the enemy's own collider.
      exclude: {bodyRef.body},
    );

    return hit == null;
  }

  List<Offset> _players() => [
    for (final entity in world.allTagged(playerTag))
      ?entity.getComponent<TransformComponent>()?.position.toOffset(),
  ];
}
