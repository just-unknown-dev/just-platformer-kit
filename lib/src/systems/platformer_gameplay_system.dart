library;

import 'package:flutter/painting.dart' show Offset;

import 'package:just_game_engine/just_game_engine.dart';

import '../components/platformer.dart';
import '../platformer_tags.dart';
import 'platformer_events.dart';
import 'player_control_system.dart';

/// The rules of the level: pickups, hazards, goals, crumbling platforms,
/// bounce pads, and the kill plane.
///
/// Sensor overlaps are handled through [SensorEnter2DEvent] rather than by
/// polling distances, so a fast-moving player cannot skip a pickup between
/// frames. Solid contacts come from [CollisionEnter2DEvent], which carries the
/// contact normal — that normal is what distinguishes stomping an enemy from
/// walking into one.
///
/// A hazard keeps hurting a player who stays in it (or on it), once each
/// time their invulnerability runs out — a lava pool is not safe to stand in
/// after the first hit.
///
/// Runs at [SystemPriorities.genreRules] (59), just under gameplay, so
/// the health changes it causes are visible to [CheckpointSystem] in the same
/// frame. Stands still while time does (a `deltaTime` of 0: paused, or an
/// editor authoring the level), so it never edits the level being authored.
class PlatformerGameplaySystem extends System {
  PlatformerGameplaySystem({this.playerTag = PlatformerTags.player, this.physics});

  /// [TagComponent] value identifying the player.
  final String playerTag;

  /// Where a level's [LevelBoundsComponent.gravityY] is applied: the world's
  /// physics. Null applies none.
  final PhysicsEngine? physics;

  @override
  int get priority => SystemPriorities.genreRules;

  // Queried manually — this reacts to events and sweeps timers rather than
  // operating on one fixed archetype.
  @override
  List<Type> get requiredComponents => const [];

  final List<EventSubscription> _subscriptions = [];

  @override
  void onAddedToWorld() {
    _subscriptions
      ..add(world.events.on<SensorEnter2DEvent>(_onSensorEnter))
      ..add(world.events.on<SensorExit2DEvent>(_onSensorExit))
      ..add(world.events.on<CollisionEnter2DEvent>(_onCollision))
      ..add(world.events.on<CollisionExit2DEvent>(_onCollisionExit));
  }

  @override
  void onRemovedFromWorld() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _inHazard.clear();
    _groundOf.clear();
  }

  @override
  void update(double deltaTime) {
    if (deltaTime <= 0) return;
    _applyLevelGravity();
    _checkCharacterLandings();
    _hurtWhileInHazards();
    _tickCrumblingPlatforms(deltaTime);
    _checkKillPlane();
  }

  static const List<Type> _boundsQuery = [LevelBoundsComponent];
  static const List<Type> _charactersQuery = [CharacterBody2D];
  static const List<Type> _collectiblesQuery = [CollectibleComponent];
  static const List<Type> _platformsQuery = [PlatformComponent];
  static const List<Type> _mortalsQuery = [TransformComponent, HealthComponent];

  // ── Level gravity ─────────────────────────────────────────────────────────

  /// The bounds whose gravity is applied, and the gravity it had then.
  LevelBoundsComponent? _gravityOf;
  double? _gravityApplied;

  /// Puts the level's [LevelBoundsComponent.gravityY] on [physics] when a
  /// level with bounds starts, and again when it is changed. Gravity set by
  /// game code in between stays until then.
  void _applyLevelGravity() {
    final physics = this.physics;
    if (physics == null) return;
    final entities = world.query(_boundsQuery);
    if (entities.isEmpty) return;
    final bounds = entities.first.getComponent<LevelBoundsComponent>()!;
    if (identical(bounds, _gravityOf) && bounds.gravityY == _gravityApplied) {
      return;
    }
    _gravityOf = bounds;
    _gravityApplied = bounds.gravityY;
    physics.setGravity(physics.gravity.x, bounds.gravityY);
  }

  /// What each character player stood on last frame.
  final Map<Entity, Entity?> _groundOf = {};

  /// A character touches static and kinematic bodies through its mover,
  /// not through contacts (as in 3-D), so landing on a bounce pad or a
  /// crumbling platform is seen here, as its ground changing.
  void _checkCharacterLandings() {
    _groundOf.removeWhere((e, _) => !e.isAlive);
    for (final player in world.query(_charactersQuery)) {
      if (!player.isActive || !_isPlayer(player)) continue;
      final body = player.getComponent<CharacterBody2D>()!;
      final ground = body.isGrounded ? body.groundEntity : null;
      if (ground != null && !identical(ground, _groundOf[player]) && ground.isAlive) {
        _resolveContact(ground, player, -1);
      }
      _groundOf[player] = ground;
    }
  }

  // ── Sensor overlaps: pickups, hazard volumes, the goal ────────────────────

  void _onSensorEnter(SensorEnter2DEvent event) {
    final sensor = event.sensor;
    final visitor = event.other;
    if (!sensor.isAlive || !visitor.isAlive) return;

    final collectible = sensor.getComponent<CollectibleComponent>();
    if (collectible != null) {
      _collect(sensor, visitor, collectible);
      return;
    }

    final hazard = sensor.getComponent<HazardComponent>();
    if (hazard != null) {
      _enterHazard(sensor, visitor, hazard);
      return;
    }

    final goal = sensor.getComponent<GoalComponent>();
    if (goal != null) {
      _reachGoal(sensor, visitor, goal);
    }
  }

  void _onSensorExit(SensorExit2DEvent event) =>
      _inHazard.remove((event.sensor, event.other));

  void _onCollisionExit(CollisionExit2DEvent event) {
    _inHazard
      ..remove((event.entityA, event.entityB))
      ..remove((event.entityB, event.entityA));
  }

  // ── Staying in a hazard ───────────────────────────────────────────────────

  /// (hazard, player) pairs touching now: hurt again whenever the player's
  /// invulnerability runs out.
  final Set<(Entity, Entity)> _inHazard = {};

  /// A player touching [hazard]: hurt now, and kept track of until they part.
  void _enterHazard(Entity source, Entity victim, HazardComponent hazard) {
    if (!_isPlayer(victim)) return;
    // Hurt again while inside only when there are i-frames to wait out:
    // without them it would take health every step.
    if (victim.hasComponent<PlayerControlComponent>()) {
      _inHazard.add((source, victim));
    }
    _applyHazard(source, victim, hazard);
  }

  void _hurtWhileInHazards() {
    if (_inHazard.isEmpty) return;
    _inHazard.removeWhere((pair) => !pair.$1.isAlive || !pair.$2.isAlive);
    for (final (source, victim) in _inHazard.toList()) {
      final hazard = source.getComponent<HazardComponent>();
      final control = victim.getComponent<PlayerControlComponent>();
      if (hazard == null || control == null) {
        _inHazard.remove((source, victim));
        continue;
      }
      if (!source.isActive || !victim.isActive) continue;
      if (control.invulnerabilityTimer <= 0) _applyHazard(source, victim, hazard);
    }
  }

  void _collect(Entity pickup, Entity collector, CollectibleComponent c) {
    if (c.isCollected) return;
    if (!_isPlayer(collector)) return;

    // Marked before the event fires so a listener that inspects the component
    // sees a consistent state, and so a second overlap in the same frame
    // cannot double-count it.
    c.isCollected = true;

    world.events.fire(
      CollectiblePickedUpEvent(
        collectibleEntity: pickup,
        collectorEntity: collector,
        kind: c.kind,
        value: c.value,
      ),
    );

    // Deferred through the command buffer: destroying an entity while the
    // physics system is still iterating its contact events would invalidate
    // the iteration.
    if (c.destroyOnCollect) world.commands.destroy(pickup);
  }

  void _reachGoal(Entity goalEntity, Entity visitor, GoalComponent goal) {
    if (goal.isReached || !_isPlayer(visitor)) return;
    if (goal.requiresAllCollectibles && _remainingCollectibles() > 0) return;

    goal.isReached = true;
    world.events.fire(
      LevelCompletedEvent(
        goalEntity: goalEntity,
        playerEntity: visitor,
        nextScene: goal.nextScene,
      ),
    );
  }

  int _remainingCollectibles() => world
      .query(_collectiblesQuery)
      .where(
        (e) =>
            e.isActive && !e.getComponent<CollectibleComponent>()!.isCollected,
      )
      .length;

  // ── Solid contacts: stomping, side damage, bounce pads ───────────────────

  void _onCollision(CollisionEnter2DEvent event) {
    final a = event.entityA;
    final b = event.entityB;
    if (!a.isAlive || !b.isAlive) return;

    // The normal points from A to B. Screen space has +Y down, so a normal
    // with a strongly negative Y means B is above A.
    _resolveContact(a, b, event.normal.dy);
    _resolveContact(b, a, -event.normal.dy);
  }

  /// Handles [other] touching [subject], where [normalY] points from
  /// [subject] toward [other].
  void _resolveContact(Entity subject, Entity other, double normalY) {
    if (!_isPlayer(other)) return;

    // other is above subject when the normal from subject to other points up.
    final otherIsAbove = normalY < -0.5;

    final enemy = subject.getComponent<PatrolEnemyComponent>();
    if (enemy != null) {
      _resolveEnemyContact(subject, other, enemy, otherIsAbove);
      return;
    }

    final platform = subject.getComponent<PlatformComponent>();
    if (platform != null && otherIsAbove) {
      _resolvePlatformLanding(subject, other, platform);
    }

    // A solid (non-sensor) hazard, e.g. a spiked block you can also stand on.
    final hazard = subject.getComponent<HazardComponent>();
    if (hazard != null &&
        subject.getComponent<CollectibleComponent>() == null) {
      _enterHazard(subject, other, hazard);
    }
  }

  void _resolveEnemyContact(
    Entity enemyEntity,
    Entity player,
    PatrolEnemyComponent enemy,
    bool playerIsAbove,
  ) {
    if (enemy.isDefeated) return;

    if (enemy.stompable && playerIsAbove) {
      enemy.isDefeated = true;
      PlayerControlSystem.bounce(player);
      world.events.fire(
        EnemyDefeatedEvent(enemyEntity: enemyEntity, byEntity: player),
      );
      world.commands.destroy(enemyEntity);
      return;
    }

    // Touched from the side or below: the enemy wins this exchange. The
    // player is knocked away from it — whichever way it faces — and given
    // time to get clear before it can hurt again.
    final playerX = player.getComponent<TransformComponent>()?.position.x;
    final enemyX = enemyEntity.getComponent<TransformComponent>()?.position.x;
    final away = playerX == null || enemyX == null || playerX == enemyX
        ? enemy.facing
        : (playerX > enemyX ? 1 : -1);
    _damage(
      player,
      enemy.contactDamage,
      source: enemyEntity,
      knockbackX: away * 380.0,
      knockbackY: -420.0,
      invulnerabilitySeconds: enemy.invulnerabilitySeconds,
    );
  }

  void _resolvePlatformLanding(
    Entity platformEntity,
    Entity lander,
    PlatformComponent platform,
  ) {
    switch (platform.kind) {
      case PlatformKind.bouncy:
        PlayerControlSystem.bounce(lander, speed: platform.bounceImpulse);

      case PlatformKind.crumbling:
        // Start the countdown on first contact only; re-triggering on every
        // contact event would reset the timer and the platform would never
        // actually fall.
        if (platform.crumbleTimer < 0 && !platform.isCollapsed) {
          platform.crumbleTimer = platform.crumbleDelay;
        }

      case PlatformKind.solid:
      case PlatformKind.oneWay:
        break;
    }
  }

  // ── Damage ────────────────────────────────────────────────────────────────

  void _applyHazard(Entity source, Entity victim, HazardComponent hazard) {
    if (!_isPlayer(victim)) return;
    _damage(
      victim,
      hazard.instantKill ? double.infinity : hazard.damage,
      source: source,
      knockbackX: hazard.knockback.dx,
      knockbackY: hazard.knockback.dy,
      invulnerabilitySeconds: hazard.invulnerabilitySeconds,
      respawn: hazard.respawnOnHit,
    );
  }

  /// Applies damage, honouring invulnerability frames — the player's own
  /// timer, and [HealthComponent.isInvulnerable], which no hit gets past.
  ///
  /// Without an invulnerability window, standing in a hazard drains the whole
  /// health bar within a few frames — the player never sees what killed them.
  void _damage(
    Entity victim,
    double amount, {
    Entity? source,
    double knockbackX = 0,
    double knockbackY = 0,
    double? invulnerabilitySeconds,
    bool respawn = false,
  }) {
    final control = victim.getComponent<PlayerControlComponent>();
    if (control != null && control.invulnerabilityTimer > 0) return;

    final health = victim.getComponent<HealthComponent>();
    if (health != null && health.isInvulnerable) return;
    final fatal =
        amount.isInfinite || (health != null && health.health <= amount);

    if (health != null) {
      if (amount.isInfinite) {
        health.health = 0;
      } else {
        health.damage(amount);
      }
    }

    if (control != null) {
      control.invulnerabilityTimer =
          invulnerabilitySeconds ?? control.invulnerabilityTimer;
    }

    if (knockbackX != 0 || knockbackY != 0) {
      final character = victim.getComponent<CharacterBody2D>();
      if (character != null) {
        // Sideways through its run speed, which player control eases off;
        // up as a launch.
        character.moveVelocity = Offset(knockbackX, 0);
        if (knockbackY < 0) PlayerControlSystem.launch(character, -knockbackY);
      } else {
        victim.getComponent<VelocityComponent>()?.setVelocityXY(knockbackX, knockbackY);
      }
    }

    world.events.fire(
      EntityDamagedEvent(
        entity: victim,
        amount: amount.isInfinite ? (health?.maxHealth ?? 1.0) : amount,
        sourceEntity: source,
        wasFatal: fatal,
        respawn: respawn,
      ),
    );
  }

  // ── Timers and the kill plane ─────────────────────────────────────────────

  /// Advances crumble and respawn timers.
  ///
  /// Collapsing is done by disabling the collider and hiding the renderable
  /// rather than destroying the entity, so the platform can come back without
  /// the level having to remember how to rebuild it.
  void _tickCrumblingPlatforms(double deltaTime) {
    for (final entity in world.query(_platformsQuery)) {
      if (!entity.isActive) continue;
      final platform = entity.getComponent<PlatformComponent>()!;
      if (platform.kind == PlatformKind.oneWay) {
        // A one-way platform *is* a one-way body. Levels saved before the
        // prefab said so have a solid body under a one-way label, which
        // the player could not jump up through.
        final collider = entity.getComponent<Collider2D>();
        if (collider != null && !collider.oneWay) collider.oneWay = true;
        continue;
      }
      if (platform.kind != PlatformKind.crumbling) continue;

      final transform = entity.getComponent<TransformComponent>();
      platform.restingPosition ??= transform == null
          ? null
          : Offset(transform.position.x, transform.position.y);

      if (platform.crumbleTimer >= 0) {
        platform.crumbleTimer -= deltaTime;
        if (platform.crumbleTimer <= 0) {
          platform.crumbleTimer = -1.0;
          _setPlatformCollapsed(entity, platform, collapsed: true);
          platform.respawnTimer = platform.respawnDelay;
          world.events.fire(PlatformCrumbledEvent(platformEntity: entity));
        }
      } else if (platform.respawnTimer >= 0) {
        platform.respawnTimer -= deltaTime;
        if (platform.respawnTimer <= 0) {
          platform.respawnTimer = -1.0;
          _setPlatformCollapsed(entity, platform, collapsed: false);
        }
      }
    }
  }

  void _setPlatformCollapsed(
    Entity entity,
    PlatformComponent platform, {
    required bool collapsed,
  }) {
    platform.isCollapsed = collapsed;

    // Colliding with no layer, the body stops nothing — which, unlike making
    // it a sensor, keeps the body as it is on both physics backends.
    final bodyComp = entity.getComponent<RigidBody2D>();
    if (bodyComp != null) {
      if (collapsed) {
        platform.collidesBeforeCollapse = bodyComp.collidesWith;
        bodyComp.collidesWith = 0;
      } else {
        bodyComp.collidesWith = platform.collidesBeforeCollapse;
      }
    }

    final renderable = entity.getComponent<RenderableComponent>();
    renderable?.renderable.visible = !collapsed;

    // A crumbling tile or shape of the map: it goes with its body, and comes
    // back with it.
    final fromMap = entity.getComponent<MapBodyComponent>();
    if (fromMap != null) {
      LevelMaps.ofBody(world, fromMap)?.setBodyHidden(fromMap, collapsed);
    }

    final resting = platform.restingPosition;
    final transform = entity.getComponent<TransformComponent>();
    if (!collapsed && resting != null && transform != null) {
      transform.setPositionXY(resting.dx, resting.dy);
    }
  }

  /// Kills anything that has fallen past the level's kill plane.
  ///
  /// A player is left for the game to bring back; anything else — an enemy
  /// that walked off a ledge — is destroyed, rather than falling and being
  /// simulated forever below the level.
  ///
  /// This exists instead of [BoundarySystem], which requires only
  /// [TransformComponent] and therefore acts on every entity in the world,
  /// camera included.
  void _checkKillPlane() {
    final boundsEntities = world.query(_boundsQuery);
    if (boundsEntities.isEmpty) return;
    final bounds = boundsEntities.first.getComponent<LevelBoundsComponent>()!;

    for (final entity in world.query(_mortalsQuery)) {
      if (!entity.isActive) continue;
      final transform = entity.getComponent<TransformComponent>()!;
      if (transform.position.y < bounds.killPlaneY) continue;

      final health = entity.getComponent<HealthComponent>()!;
      if (health.health <= 0) continue; // already dead, awaiting respawn

      health.health = 0;
      world.events.fire(FellOutOfWorldEvent(entity: entity));
      // Deferred, like every destroy here: the query is being walked.
      if (!_isPlayer(entity)) world.commands.destroy(entity);
    }
  }

  bool _isPlayer(Entity entity) => entity.hasTag(playerTag);
}
