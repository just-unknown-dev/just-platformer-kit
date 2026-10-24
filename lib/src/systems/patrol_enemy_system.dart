library;

import 'dart:math' as math;

import 'package:flutter/painting.dart' show Offset;

import 'package:just_game_engine/just_game_engine.dart';

import '../components/platformer.dart';
import '../platformer_tags.dart';

/// Walks simple enemies back and forth, or toward the nearest player.
///
/// A patrolling enemy turns at the end of its range and at a wall (anything
/// solid ahead that is not a player), and with
/// [PatrolEnemyComponent.turnAtLedge] at the edge of what it walks on. A
/// chaser stops at a wall, and with `turnAtLedge` at an edge, rather than
/// walking off it after the player.
///
/// Stands still while time does (a `deltaTime` of 0: paused, or an editor
/// authoring the level), so the level's saved velocities are left alone and
/// a patrol is measured from where the enemy stands when play starts.
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
  List<Type> get requiredComponents => const [
    TransformComponent,
    VelocityComponent,
    PatrolEnemyComponent,
  ];

  /// How far above an enemy's feet the ledge probe starts, world units.
  static const double _probeLift = 4;

  // Kept between steps so a step allocates no lists or sets of its own.
  final List<Offset> _playerPositions = [];
  final Set<PhysicsBody> _playerBodies = {};
  final Set<PhysicsBody> _exclude = {};
  bool _gathered = false;

  @override
  void update(double deltaTime) {
    if (deltaTime <= 0) return;
    // Players are gathered once a step, and only if something needs them.
    _gathered = false;

    forEach((entity) {
      if (!entity.isActive) return;

      final enemy = entity.getComponent<PatrolEnemyComponent>()!;
      if (enemy.isDefeated) return;

      final transform = entity.getComponent<TransformComponent>()!;
      final velocity = entity.getComponent<VelocityComponent>()!;
      enemy.originX ??= transform.position.x;

      final walks = switch (enemy.behaviour) {
        EnemyBehaviour.stationary => false,
        EnemyBehaviour.patrol => _patrol(entity, enemy, transform),
        EnemyBehaviour.chase => _chase(entity, enemy, transform),
      };
      velocity.velocity.x = walks ? enemy.facing * enemy.speed : 0;
    });
  }

  /// Turns at the end of the range, at a wall and (with
  /// [PatrolEnemyComponent.turnAtLedge]) at a ledge. It always walks on.
  bool _patrol(
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
    } else if (_wallAhead(entity, transform, enemy) ||
        enemy.turnAtLedge && _ledgeAhead(entity, transform, enemy)) {
      enemy.facing = -enemy.facing;
    }
    return true;
  }

  /// Faces the nearest player in range and walks at them, stopping at a wall
  /// or (with [PatrolEnemyComponent.turnAtLedge]) a ledge; out of range, or
  /// with no player, it patrols. Whether it walks.
  bool _chase(
    Entity entity,
    PatrolEnemyComponent enemy,
    TransformComponent transform,
  ) {
    _gather();
    // The nearest player — with two, a chaser does not ignore the one right
    // beside it for the one who happened to spawn first.
    final hereX = transform.position.x, hereY = transform.position.y;
    Offset? target;
    var best = double.infinity;
    for (final p in _playerPositions) {
      final dx = p.dx - hereX, dy = p.dy - hereY;
      final d = dx * dx + dy * dy;
      if (d < best) {
        best = d;
        target = p;
      }
    }
    if (target == null || math.sqrt(best) > enemy.aggroRange) {
      // Out of range: fall back to patrolling so it does not freeze.
      return _patrol(entity, enemy, transform);
    }
    enemy.facing = target.dx - hereX >= 0 ? 1 : -1;
    // Held at a wall or an edge rather than walking into it, or off it.
    return !_wallAhead(entity, transform, enemy) &&
        !(enemy.turnAtLedge && _ledgeAhead(entity, transform, enemy));
  }

  /// Whether the ground runs out just ahead of the enemy: a ray down from in
  /// front of its feet, as deep as it is tall, finds nothing solid.
  bool _ledgeAhead(
    Entity entity,
    TransformComponent transform,
    PatrolEnemyComponent enemy,
  ) {
    final body = entity.getComponent<PhysicsBodyRefComponent>()?.body;
    if (body == null) return false;

    // The collider as simulated: placed and scaled with the entity.
    final bounds = body.shape.getBounds(Offset.zero);
    final aheadX = transform.position.x + enemy.facing * (bounds.width / 2 + 4);
    final footY = transform.position.y + bounds.height / 2;
    // From a little above the feet: a body at rest sinks a hair into what
    // it stands on (the solver's slop), and a ray that starts inside the
    // ground passes over it — every step would read as a ledge.
    final ray = Ray(
      origin: Offset(aheadX, footY - _probeLift),
      direction: const Offset(0, 1),
      maxDistance: bounds.height + _probeLift,
    );
    return !_solidHit(ray, body, skipPlayers: false);
  }

  /// Whether something solid other than a player is just ahead of the
  /// enemy: a ray from its middle the way it faces, a little past its side.
  bool _wallAhead(
    Entity entity,
    TransformComponent transform,
    PatrolEnemyComponent enemy,
  ) {
    final body = entity.getComponent<PhysicsBodyRefComponent>()?.body;
    if (body == null) return false;

    final bounds = body.shape.getBounds(Offset.zero);
    final ray = Ray(
      origin: Offset(transform.position.x, transform.position.y),
      direction: Offset(enemy.facing.toDouble(), 0),
      maxDistance: bounds.width / 2 + 4,
    );
    // A player ahead is walked into, not turned from: that is the attack.
    return _solidHit(ray, body, skipPlayers: true);
  }

  /// Whether [ray] meets a body that is not a sensor (a coin, a trigger),
  /// [self] — or the probe would hit the enemy's own collider at once —
  /// or, with [skipPlayers], a player's.
  bool _solidHit(Ray ray, PhysicsBody self, {required bool skipPlayers}) {
    _exclude
      ..clear()
      ..add(self);
    if (skipPlayers) {
      _gather();
      _exclude.addAll(_playerBodies);
    }
    for (final hit in physics.castRayAll(ray, exclude: _exclude)) {
      if (!hit.body.isSensor) return true;
    }
    return false;
  }

  /// The players' positions and bodies, once a step.
  void _gather() {
    if (_gathered) return;
    _gathered = true;
    _playerPositions.clear();
    _playerBodies.clear();
    for (final entity in world.allTagged(playerTag)) {
      final transform = entity.getComponent<TransformComponent>();
      if (transform != null) {
        _playerPositions.add(
          Offset(transform.position.x, transform.position.y),
        );
      }
      final body = entity.getComponent<PhysicsBodyRefComponent>()?.body;
      if (body != null) _playerBodies.add(body);
    }
  }
}
