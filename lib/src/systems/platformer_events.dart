library;

import 'package:just_game_engine/just_game_engine.dart';

import '../components/platformer.dart';

/// Fired when the player reaches a [GoalComponent].
class LevelCompletedEvent extends GameEvent {
  LevelCompletedEvent({
    required this.goalEntity,
    required this.playerEntity,
    this.nextScene,
  });

  /// The goal that was reached.
  final Entity goalEntity;

  /// Who reached it.
  final Entity playerEntity;

  /// Scene to load next, or null if this was the last level.
  final String? nextScene;
}

/// Fired when a [CollectibleComponent] is picked up.
class CollectiblePickedUpEvent extends GameEvent {
  CollectiblePickedUpEvent({
    required this.collectibleEntity,
    required this.collectorEntity,
    required this.kind,
    required this.value,
  });

  /// The pickup. Already marked collected, and destroyed on the next command
  /// flush if it was configured to be — do not assume it is still alive.
  final Entity collectibleEntity;

  /// Who picked it up.
  final Entity collectorEntity;

  /// [CollectibleComponent.kind], so a listener can tell a coin from a key.
  final String kind;

  /// [CollectibleComponent.value].
  final int value;
}

/// Fired when an entity takes damage from a [HazardComponent] or an enemy.
///
/// Fired only when the damage actually lands — a hit absorbed by
/// invulnerability frames raises nothing.
class EntityDamagedEvent extends GameEvent {
  EntityDamagedEvent({
    required this.entity,
    required this.amount,
    this.sourceEntity,
    this.wasFatal = false,
  });

  /// Who was hurt.
  final Entity entity;

  /// How much health was removed.
  final double amount;

  /// What hurt them, if it came from an entity.
  final Entity? sourceEntity;

  /// Whether this hit took them to zero health.
  final bool wasFatal;
}

/// Fired when an entity falls below [LevelBoundsComponent.killPlaneY].
///
/// Separate from [EntityDamagedEvent] because falling out of the world is
/// always fatal regardless of health, and games usually want to treat it
/// differently (no hit animation, instant respawn).
class FellOutOfWorldEvent extends GameEvent {
  FellOutOfWorldEvent({required this.entity});

  /// Who fell.
  final Entity entity;
}

/// Fired when a [PatrolEnemyComponent] entity is stomped.
class EnemyDefeatedEvent extends GameEvent {
  EnemyDefeatedEvent({required this.enemyEntity, required this.byEntity});

  /// The defeated enemy. Destroyed on the next command flush.
  final Entity enemyEntity;

  /// Who stomped it.
  final Entity byEntity;
}

/// Fired when a [PlatformKind.crumbling] platform collapses.
class PlatformCrumbledEvent extends GameEvent {
  PlatformCrumbledEvent({required this.platformEntity});

  /// The platform that gave way.
  final Entity platformEntity;
}
