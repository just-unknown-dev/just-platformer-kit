library;

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/painting.dart';
import 'package:just_game_engine/just_game_engine.dart';

import '../components/platformer.dart';

/// Saves and loads the platformer components.
///
/// These are the single description of each component's persisted fields.
/// The kit's editor descriptors are built from them with
/// its `hints`, which add only labels and scrub feel — so the
/// inspector cannot show a field that is not saved, and the shipped game
/// reads exactly what the editor wrote.
///
/// Ids match the ones the editor has always written, so existing levels load.
///
/// Every platformer component is for 2-D scenes (`Dimensions.twoD`): an
/// editor does not offer them in a 3-D one.
abstract final class PlatformerSchemas {
  static ComponentSchema<PatrolEnemyComponent> get patrolEnemy =>
      ComponentSchema<PatrolEnemyComponent>(
        type: 'PatrolEnemyComponent',
        hints: ComponentHints(
          dimensions: Dimensions.twoD,
          name: 'Patrol enemy',
          group: 'Platformer',
          description: 'Walks a route, or chases the player.',
          icon: Icons.bug_report,
          accentColor: const Color(0xFFAB47BC),
          fields: {
            'behaviour': const FieldHint(label: 'Behaviour'),
            'speed': const FieldHint(
              label: 'Speed',
              scrub: ScrubHint(step: 5, fractionDigits: 1),
            ),
            'patrolRange': FieldHint(
              label: 'Range',
              scrub: const ScrubHint(step: 10, fractionDigits: 0),
              visibleWhen: (c) =>
                  (c as PatrolEnemyComponent).behaviour ==
                  EnemyBehaviour.patrol,
            ),
            'aggroRange': FieldHint(
              label: 'Aggro',
              scrub: const ScrubHint(step: 10, fractionDigits: 0),
              visibleWhen: (c) =>
                  (c as PatrolEnemyComponent).behaviour == EnemyBehaviour.chase,
            ),
            'turnAtLedge': const FieldHint(label: 'Turn at ledge'),
            'contactDamage': const FieldHint(
              label: 'Damage',
              scrub: ScrubHint(step: 0.5, fractionDigits: 1),
            ),
            'invulnerabilitySeconds': const FieldHint(
              label: 'I-frames',
              scrub: ScrubHint(step: 0.1, fractionDigits: 2),
            ),
            'stompable': const FieldHint(label: 'Stompable'),
          },
        ),
        id: 'patrol_enemy_a10f3d62',
        create: PatrolEnemyComponent.new,
        fields: [
          SchemaField(
            name: 'behaviour',
            kind: const EnumFieldType(
              EnemyBehaviour.values,
              fallback: EnemyBehaviour.patrol,
              id: 'platformer.enemyBehaviour',
            ),
            read: (c) => (c as PatrolEnemyComponent).behaviour,
            write: (c, v) =>
                (c as PatrolEnemyComponent).behaviour = v as EnemyBehaviour,
          ),
          _decimal(
            'speed',
            (c) => (c as PatrolEnemyComponent).speed,
            (c, v) => (c as PatrolEnemyComponent).speed = v,
          ),
          SchemaField(
            name: 'patrolRange',
            kind: FieldTypes.decimal,
            read: (c) => (c as PatrolEnemyComponent).patrolRange,
            write: (c, v) =>
                (c as PatrolEnemyComponent).patrolRange = (v as num).toDouble(),
            min: 0,
          ),
          SchemaField(
            name: 'aggroRange',
            kind: FieldTypes.decimal,
            read: (c) => (c as PatrolEnemyComponent).aggroRange,
            write: (c, v) =>
                (c as PatrolEnemyComponent).aggroRange = (v as num).toDouble(),
            min: 0,
          ),
          SchemaField(
            name: 'turnAtLedge',
            kind: FieldTypes.boolean,
            read: (c) => (c as PatrolEnemyComponent).turnAtLedge,
            write: (c, v) =>
                (c as PatrolEnemyComponent).turnAtLedge = v as bool,
          ),
          _decimal(
            'contactDamage',
            (c) => (c as PatrolEnemyComponent).contactDamage,
            (c, v) => (c as PatrolEnemyComponent).contactDamage = v,
          ),
          _decimal(
            'invulnerabilitySeconds',
            (c) => (c as PatrolEnemyComponent).invulnerabilitySeconds,
            (c, v) => (c as PatrolEnemyComponent).invulnerabilitySeconds = v,
          ),
          SchemaField(
            name: 'stompable',
            kind: FieldTypes.boolean,
            read: (c) => (c as PatrolEnemyComponent).stompable,
            write: (c, v) => (c as PatrolEnemyComponent).stompable = v as bool,
          ),
        ],
      );

  static ComponentSchema<HazardComponent> get hazard =>
      ComponentSchema<HazardComponent>(
        type: 'HazardComponent',
        hints: ComponentHints(
          dimensions: Dimensions.twoD,
          name: 'Hazard',
          group: 'Platformer',
          description: 'Damages whatever touches it.',
          icon: Icons.warning_amber_rounded,
          accentColor: const Color(0xFFE53935),
          fields: {
            'damage': FieldHint(
              label: 'Damage',
              scrub: const ScrubHint(step: 0.5, fractionDigits: 1),
              visibleWhen: (c) => !(c as HazardComponent).instantKill,
            ),
            'instantKill': const FieldHint(label: 'Instant kill'),
            'knockback': const FieldHint(label: 'Knockback'),
            'invulnerabilitySeconds': const FieldHint(
              label: 'I-frames',
              scrub: ScrubHint(step: 0.1, fractionDigits: 2),
            ),
            'respawnOnHit': const FieldHint(label: 'Respawn on hit'),
          },
        ),
        id: 'hazard_5c1ab773',
        create: HazardComponent.new,
        fields: [
          SchemaField(
            name: 'damage',
            kind: FieldTypes.decimal,
            read: (c) => (c as HazardComponent).damage,
            write: (c, v) =>
                (c as HazardComponent).damage = (v as num).toDouble(),
            min: 0,
          ),
          SchemaField(
            name: 'instantKill',
            kind: FieldTypes.boolean,
            read: (c) => (c as HazardComponent).instantKill,
            write: (c, v) => (c as HazardComponent).instantKill = v as bool,
          ),
          SchemaField(
            name: 'knockback',
            kind: FieldTypes.offset,
            read: (c) => (c as HazardComponent).knockback,
            write: (c, v) => (c as HazardComponent).knockback =
                (v as Offset?) ?? Offset.zero,
          ),
          SchemaField(
            name: 'invulnerabilitySeconds',
            kind: FieldTypes.decimal,
            read: (c) => (c as HazardComponent).invulnerabilitySeconds,
            write: (c, v) => (c as HazardComponent).invulnerabilitySeconds =
                (v as num).toDouble(),
            min: 0,
          ),
          SchemaField(
            name: 'respawnOnHit',
            kind: FieldTypes.boolean,
            read: (c) => (c as HazardComponent).respawnOnHit,
            write: (c, v) => (c as HazardComponent).respawnOnHit = v as bool,
          ),
        ],
      );

  static ComponentSchema<CollectibleComponent> get collectible =>
      ComponentSchema<CollectibleComponent>(
        type: 'CollectibleComponent',
        hints: const ComponentHints(
          dimensions: Dimensions.twoD,
          name: 'Collectible',
          group: 'Platformer',
          description: 'A pickup. Counts toward level completion.',
          icon: Icons.stars_rounded,
          accentColor: Color(0xFFFFD54F),
          fields: {
            'kind': FieldHint(label: 'Kind'),
            'value': FieldHint(label: 'Value', scrub: ScrubHint(integer: true)),
            'destroyOnCollect': FieldHint(label: 'Destroy on pickup'),
          },
        ),
        id: 'collectible_9d20fe45',
        create: CollectibleComponent.new,
        fields: [
          SchemaField(
            name: 'kind',
            kind: FieldTypes.text,
            read: (c) => (c as CollectibleComponent).kind,
            write: (c, v) =>
                (c as CollectibleComponent).kind = (v as String?) ?? 'coin',
          ),
          SchemaField(
            name: 'value',
            kind: FieldTypes.integer,
            read: (c) => (c as CollectibleComponent).value,
            write: (c, v) =>
                (c as CollectibleComponent).value = (v as num).toInt(),
          ),
          SchemaField(
            name: 'destroyOnCollect',
            kind: FieldTypes.boolean,
            read: (c) => (c as CollectibleComponent).destroyOnCollect,
            write: (c, v) =>
                (c as CollectibleComponent).destroyOnCollect = v as bool,
          ),
        ],
      );

  static ComponentSchema<GoalComponent> get goal =>
      ComponentSchema<GoalComponent>(
        type: 'GoalComponent',
        hints: const ComponentHints(
          dimensions: Dimensions.twoD,
          name: 'Goal',
          group: 'Platformer',
          description: 'The level exit.',
          icon: Icons.sports_score,
          accentColor: Color(0xFF00E676),
          fields: {
            'nextScene': FieldHint(label: 'Next scene'),
            'requiresAllCollectibles': FieldHint(label: 'Needs all pickups'),
          },
        ),
        id: 'goal_4e7cb018',
        create: GoalComponent.new,
        fields: [
          SchemaField(
            name: 'nextScene',
            kind: FieldTypes.text,
            read: (c) => (c as GoalComponent).nextScene ?? '',
            write: (c, v) {
              // Empty means "this is the last level", which is meaningfully
              // different from an empty scene name.
              final name = ((v as String?) ?? '').trim();
              (c as GoalComponent).nextScene = name.isEmpty ? null : name;
            },
          ),
          SchemaField(
            name: 'requiresAllCollectibles',
            kind: FieldTypes.boolean,
            read: (c) => (c as GoalComponent).requiresAllCollectibles,
            write: (c, v) =>
                (c as GoalComponent).requiresAllCollectibles = v as bool,
          ),
        ],
      );

  static ComponentSchema<LevelBoundsComponent> get levelBounds =>
      ComponentSchema<LevelBoundsComponent>(
        type: 'LevelBoundsComponent',
        hints: const ComponentHints(
          dimensions: Dimensions.twoD,
          name: 'Level bounds',
          group: 'Level',
          description: 'Playable area, kill plane and level gravity.',
          icon: Icons.crop_free,
          accentColor: Color(0xFFFFB300),
          fieldRows: [
            FieldRowHint('Origin', {'boundsLeft': 'X', 'boundsTop': 'Y'}),
            FieldRowHint('Size', {'boundsWidth': 'W', 'boundsHeight': 'H'}),
          ],
          fields: {
            'boundsLeft': FieldHint(
              label: 'Left',
              scrub: ScrubHint(step: 32, fractionDigits: 0),
            ),
            'boundsTop': FieldHint(
              label: 'Top',
              scrub: ScrubHint(step: 32, fractionDigits: 0),
            ),
            'boundsWidth': FieldHint(
              label: 'Width',
              scrub: ScrubHint(step: 32, fractionDigits: 0),
            ),
            'boundsHeight': FieldHint(
              label: 'Height',
              scrub: ScrubHint(step: 32, fractionDigits: 0),
            ),
            'killPlaneY': FieldHint(
              label: 'Kill plane',
              scrub: ScrubHint(step: 32, fractionDigits: 0),
            ),
            'gravityY': FieldHint(
              label: 'Gravity',
              scrub: ScrubHint(step: 50, fractionDigits: 0),
            ),
          },
        ),
        id: 'level_bounds_c407ab29',
        create: LevelBoundsComponent.new,
        fields: [
          _decimal(
            'boundsLeft',
            (c) => (c as LevelBoundsComponent).bounds.left,
            _setLeft,
            min: double.negativeInfinity,
          ),
          _decimal(
            'boundsTop',
            (c) => (c as LevelBoundsComponent).bounds.top,
            _setTop,
            min: double.negativeInfinity,
          ),
          _decimal(
            'boundsWidth',
            (c) => (c as LevelBoundsComponent).bounds.width,
            _setWidth,
          ),
          _decimal(
            'boundsHeight',
            (c) => (c as LevelBoundsComponent).bounds.height,
            _setHeight,
          ),
          _decimal(
            'killPlaneY',
            (c) => (c as LevelBoundsComponent).killPlaneY,
            (c, v) => (c as LevelBoundsComponent).killPlaneY = v,
            min: double.negativeInfinity,
          ),
          _decimal(
            'gravityY',
            (c) => (c as LevelBoundsComponent).gravityY,
            (c, v) => (c as LevelBoundsComponent).gravityY = v,
          ),
        ],
      );

  static ComponentSchema<ParallaxRectComponent> get parallaxRect =>
      ComponentSchema<ParallaxRectComponent>(
        type: 'ParallaxRectComponent',
        hints: const ComponentHints(
          dimensions: Dimensions.twoD,
          name: 'Parallax',
          group: 'Level',
          description: 'Scrolls slower than the camera, for background depth.',
          icon: Icons.wallpaper,
          accentColor: Color(0xFF37474F),
          fieldRows: [
            FieldRowHint('Factor', {
              'scrollFactorX': 'X',
              'scrollFactorY': 'Y',
            }),
          ],
          fields: {
            'scrollFactorX': FieldHint(
              label: 'Factor X',
              scrub: ScrubHint(step: 0.05, fractionDigits: 2),
            ),
            'scrollFactorY': FieldHint(
              label: 'Factor Y',
              scrub: ScrubHint(step: 0.05, fractionDigits: 2),
            ),
          },
        ),
        id: 'parallax_rect_de92c144',
        create: ParallaxRectComponent.new,
        fields: [
          _decimal(
            'scrollFactorX',
            (c) => (c as ParallaxRectComponent).scrollFactorX,
            (c, v) => (c as ParallaxRectComponent).scrollFactorX = v,
          ),
          _decimal(
            'scrollFactorY',
            (c) => (c as ParallaxRectComponent).scrollFactorY,
            (c, v) => (c as ParallaxRectComponent).scrollFactorY = v,
          ),
        ],
      );

  static ComponentSchema<PlatformComponent> get platform =>
      ComponentSchema<PlatformComponent>(
        type: 'PlatformComponent',
        hints: ComponentHints(
          dimensions: Dimensions.twoD,
          name: 'Platform',
          group: 'Platformer',
          description: 'Marks level geometry and how it behaves underfoot.',
          icon: Icons.crop_16_9,
          accentColor: const Color(0xFF546E7A),
          fields: {
            'kind': const FieldHint(label: 'Kind'),
            // Only meaningful for a crumbling platform; showing it otherwise
            // implies it does something.
            'crumbleDelay': FieldHint(
              label: 'Crumble',
              scrub: const ScrubHint(step: 0.05, fractionDigits: 2),
              visibleWhen: (c) =>
                  (c as PlatformComponent).kind == PlatformKind.crumbling,
            ),
            'respawnDelay': FieldHint(
              label: 'Respawn',
              scrub: const ScrubHint(step: 0.1, fractionDigits: 2),
              visibleWhen: (c) =>
                  (c as PlatformComponent).kind == PlatformKind.crumbling,
            ),
            'bounceImpulse': FieldHint(
              label: 'Bounce',
              scrub: const ScrubHint(step: 25, fractionDigits: 0),
              visibleWhen: (c) =>
                  (c as PlatformComponent).kind == PlatformKind.bouncy,
            ),
          },
        ),
        id: 'platform_7f31c0a2',
        create: PlatformComponent.new,
        fields: [
          SchemaField(
            name: 'kind',
            kind: const EnumFieldType(
              PlatformKind.values,
              fallback: PlatformKind.solid,
              id: 'platformer.platformKind',
            ),
            read: (c) => (c as PlatformComponent).kind,
            write: (c, v) => (c as PlatformComponent).kind = v as PlatformKind,
          ),
          SchemaField(
            name: 'crumbleDelay',
            kind: FieldTypes.decimal,
            read: (c) => (c as PlatformComponent).crumbleDelay,
            write: (c, v) =>
                (c as PlatformComponent).crumbleDelay = (v as num).toDouble(),
            min: 0,
          ),
          SchemaField(
            name: 'respawnDelay',
            kind: FieldTypes.decimal,
            read: (c) => (c as PlatformComponent).respawnDelay,
            write: (c, v) =>
                (c as PlatformComponent).respawnDelay = (v as num).toDouble(),
            min: 0,
          ),
          SchemaField(
            name: 'bounceImpulse',
            kind: FieldTypes.decimal,
            read: (c) => (c as PlatformComponent).bounceImpulse,
            write: (c, v) =>
                (c as PlatformComponent).bounceImpulse = (v as num).toDouble(),
            min: 0,
          ),
        ],
      );

  static ComponentSchema<MovingPlatformComponent> get movingPlatform =>
      ComponentSchema<MovingPlatformComponent>(
        type: 'MovingPlatformComponent',
        hints: const ComponentHints(
          dimensions: Dimensions.twoD,
          name: 'Moving platform',
          group: 'Platformer',
          description: 'Drives a kinematic platform along a waypoint path.',
          icon: Icons.swap_horiz,
          accentColor: Color(0xFF4FC3F7),
          fields: {
            'waypoints': FieldHint(label: 'Path'),
            'speed': FieldHint(
              label: 'Speed',
              scrub: ScrubHint(step: 5, fractionDigits: 1),
            ),
            'loopMode': FieldHint(label: 'Loop'),
            'pauseSeconds': FieldHint(
              label: 'Pause',
              scrub: ScrubHint(step: 0.1, fractionDigits: 2),
            ),
            'autoStart': FieldHint(label: 'Auto start'),
          },
        ),
        id: 'moving_platform_2b84de10',
        create: MovingPlatformComponent.new,
        fields: [
          SchemaField(
            name: 'waypoints',
            kind: FieldTypes.offsetList,
            read: (c) => (c as MovingPlatformComponent).waypoints,
            write: (c, v) => (c as MovingPlatformComponent).waypoints
              ..clear()
              ..addAll((v as List?)?.cast<Offset>() ?? const []),
          ),
          SchemaField(
            name: 'speed',
            kind: FieldTypes.decimal,
            read: (c) => (c as MovingPlatformComponent).speed,
            write: (c, v) =>
                (c as MovingPlatformComponent).speed = (v as num).toDouble(),
            min: 0,
          ),
          SchemaField(
            name: 'loopMode',
            kind: const EnumFieldType(
              PlatformLoopMode.values,
              fallback: PlatformLoopMode.pingPong,
              id: 'platformer.platformLoopMode',
            ),
            read: (c) => (c as MovingPlatformComponent).loopMode,
            write: (c, v) =>
                (c as MovingPlatformComponent).loopMode = v as PlatformLoopMode,
          ),
          SchemaField(
            name: 'pauseSeconds',
            kind: FieldTypes.decimal,
            read: (c) => (c as MovingPlatformComponent).pauseSeconds,
            write: (c, v) => (c as MovingPlatformComponent).pauseSeconds =
                (v as num).toDouble(),
            min: 0,
          ),
          SchemaField(
            name: 'autoStart',
            kind: FieldTypes.boolean,
            read: (c) => (c as MovingPlatformComponent).autoStart,
            write: (c, v) =>
                (c as MovingPlatformComponent).autoStart = v as bool,
          ),
        ],
      );

  static ComponentSchema<PlayerControlComponent> get playerControl =>
      ComponentSchema<PlayerControlComponent>(
        type: 'PlayerControlComponent',
        hints: const ComponentHints(
          dimensions: Dimensions.twoD,
          name: 'Player control',
          group: 'Platformer',
          description: 'Character controller tuning: movement and jump feel.',
          icon: Icons.sports_esports,
          accentColor: Color(0xFF42A5F5),
          fieldGroups: {
            'Movement': [
              'moveSpeed',
              'acceleration',
              'airAcceleration',
              'groundFriction',
              'airFriction',
            ],
            'Jump': [
              'jumpSpeed',
              'maxFallSpeed',
              'maxJumps',
              'stompBounceSpeed',
            ],
            'Feel': [
              'coyoteTime',
              'jumpBufferTime',
              'riseGravityScale',
              'fallGravityScale',
              'jumpCutGravityScale',
            ],
          },
          fields: {
            'moveSpeed': FieldHint(
              label: 'Speed',
              scrub: ScrubHint(step: 10, fractionDigits: 1),
            ),
            'acceleration': FieldHint(
              label: 'Accel',
              scrub: ScrubHint(step: 100, fractionDigits: 1),
            ),
            'airAcceleration': FieldHint(
              label: 'Air accel',
              scrub: ScrubHint(step: 100, fractionDigits: 1),
            ),
            'groundFriction': FieldHint(
              label: 'Ground drag',
              scrub: ScrubHint(step: 100, fractionDigits: 1),
            ),
            'airFriction': FieldHint(
              label: 'Air drag',
              scrub: ScrubHint(step: 50, fractionDigits: 1),
            ),
            'jumpSpeed': FieldHint(
              label: 'Jump',
              scrub: ScrubHint(step: 25, fractionDigits: 1),
            ),
            'maxFallSpeed': FieldHint(
              label: 'Max fall',
              scrub: ScrubHint(step: 50, fractionDigits: 1),
            ),
            'maxJumps': FieldHint(
              label: 'Jumps',
              scrub: ScrubHint(integer: true),
            ),
            'stompBounceSpeed': FieldHint(
              label: 'Stomp bounce',
              scrub: ScrubHint(step: 25, fractionDigits: 1),
            ),
            'coyoteTime': FieldHint(
              label: 'Coyote',
              scrub: ScrubHint(step: 0.01, fractionDigits: 3),
            ),
            'jumpBufferTime': FieldHint(
              label: 'Buffer',
              scrub: ScrubHint(step: 0.01, fractionDigits: 3),
            ),
            'riseGravityScale': FieldHint(
              label: 'Rise G',
              scrub: ScrubHint(step: 0.05, fractionDigits: 2),
            ),
            'fallGravityScale': FieldHint(
              label: 'Fall G',
              scrub: ScrubHint(step: 0.05, fractionDigits: 2),
            ),
            'jumpCutGravityScale': FieldHint(
              label: 'Cut G',
              scrub: ScrubHint(step: 0.05, fractionDigits: 2),
            ),
          },
        ),
        id: 'player_control_6fd9ba31',
        create: PlayerControlComponent.new,
        fields: [
          _decimal(
            'moveSpeed',
            (c) => (c as PlayerControlComponent).moveSpeed,
            (c, v) => (c as PlayerControlComponent).moveSpeed = v,
          ),
          _decimal(
            'acceleration',
            (c) => (c as PlayerControlComponent).acceleration,
            (c, v) => (c as PlayerControlComponent).acceleration = v,
          ),
          _decimal(
            'airAcceleration',
            (c) => (c as PlayerControlComponent).airAcceleration,
            (c, v) => (c as PlayerControlComponent).airAcceleration = v,
          ),
          _decimal(
            'groundFriction',
            (c) => (c as PlayerControlComponent).groundFriction,
            (c, v) => (c as PlayerControlComponent).groundFriction = v,
          ),
          _decimal(
            'airFriction',
            (c) => (c as PlayerControlComponent).airFriction,
            (c, v) => (c as PlayerControlComponent).airFriction = v,
          ),
          _decimal(
            'jumpSpeed',
            (c) => (c as PlayerControlComponent).jumpSpeed,
            (c, v) => (c as PlayerControlComponent).jumpSpeed = v,
          ),
          _decimal(
            'maxFallSpeed',
            (c) => (c as PlayerControlComponent).maxFallSpeed,
            (c, v) => (c as PlayerControlComponent).maxFallSpeed = v,
          ),
          SchemaField(
            name: 'maxJumps',
            kind: FieldTypes.integer,
            read: (c) => (c as PlayerControlComponent).maxJumps,
            write: (c, v) =>
                (c as PlayerControlComponent).maxJumps = (v as num).toInt(),
            min: 1,
            max: 4,
          ),
          _decimal(
            'stompBounceSpeed',
            (c) => (c as PlayerControlComponent).stompBounceSpeed,
            (c, v) => (c as PlayerControlComponent).stompBounceSpeed = v,
          ),
          _decimal(
            'coyoteTime',
            (c) => (c as PlayerControlComponent).coyoteTime,
            (c, v) => (c as PlayerControlComponent).coyoteTime = v,
          ),
          _decimal(
            'jumpBufferTime',
            (c) => (c as PlayerControlComponent).jumpBufferTime,
            (c, v) => (c as PlayerControlComponent).jumpBufferTime = v,
          ),
          _decimal(
            'riseGravityScale',
            (c) => (c as PlayerControlComponent).riseGravityScale,
            (c, v) => (c as PlayerControlComponent).riseGravityScale = v,
          ),
          _decimal(
            'fallGravityScale',
            (c) => (c as PlayerControlComponent).fallGravityScale,
            (c, v) => (c as PlayerControlComponent).fallGravityScale = v,
          ),
          _decimal(
            'jumpCutGravityScale',
            (c) => (c as PlayerControlComponent).jumpCutGravityScale,
            (c, v) => (c as PlayerControlComponent).jumpCutGravityScale = v,
          ),
        ],
      );

  /// Every schema above.
  static List<ComponentCodec> get all => [
    patrolEnemy,
    hazard,
    collectible,
    goal,
    levelBounds,
    parallaxRect,
    platform,
    movingPlatform,
    playerControl,
  ];
}

/// A non-negative decimal, the most common field in the kit.
SchemaField _decimal(
  String name,
  Object? Function(Component component) read,
  void Function(Component component, double value) write, {
  double min = 0,
}) => SchemaField(
  name: name,
  kind: FieldTypes.decimal,
  read: read,
  write: (c, v) => write(c, (v as num).toDouble()),
  min: min,
);

// Level bounds are one Rect stored as four fields: an origin and a size. The
// origin moves the rect and keeps its size, as the inspector's "Origin" row
// says, and a field left out of a file keeps its default.

void _setLeft(Component c, double v) {
  final comp = c as LevelBoundsComponent;
  comp.bounds = Rect.fromLTWH(
    v,
    comp.bounds.top,
    comp.bounds.width,
    comp.bounds.height,
  );
}

void _setTop(Component c, double v) {
  final comp = c as LevelBoundsComponent;
  comp.bounds = Rect.fromLTWH(
    comp.bounds.left,
    v,
    comp.bounds.width,
    comp.bounds.height,
  );
}

void _setWidth(Component c, double v) {
  final comp = c as LevelBoundsComponent;
  comp.bounds = Rect.fromLTWH(
    comp.bounds.left,
    comp.bounds.top,
    v,
    comp.bounds.height,
  );
}

void _setHeight(Component c, double v) {
  final comp = c as LevelBoundsComponent;
  comp.bounds = Rect.fromLTWH(
    comp.bounds.left,
    comp.bounds.top,
    comp.bounds.width,
    v,
  );
}
