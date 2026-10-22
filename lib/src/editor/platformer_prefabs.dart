import 'package:flutter/material.dart';
import 'package:just_game_engine/just_game_engine.dart' as jge;
import 'package:just_editor_core/just_editor_core.dart';

import '../../just_platformer_kit.dart' as kit;

/// The platformer palette, contributed through [PlatformerModule].
///
/// Rectangles throughout, deliberately: this is a template, and a flat colour
/// block makes the *structure* of a level legible in a way art would obscure.
/// Swapping a rectangle for a sprite later is a one-component change.
///
/// Every prefab is a plain composition of `just_game_engine` and kit
/// components, so a level built from them has no dependency on the editor at
/// runtime. Ids are prefixed `platformer.` so they cannot collide with the
/// editor's own `builtin.` palette.
abstract final class PlatformerPrefabs {
  /// Level geometry.
  static const Color solidColor = Color(0xFF546E7A);

  /// Jump-through platforms, lighter so they read as "not fully solid".
  static const Color oneWayColor = Color(0xFF8D9EA8);

  /// Anything that moves under its own power.
  static const Color movingColor = Color(0xFF4FC3F7);

  /// Anything that will kill you.
  static const Color hazardColor = Color(0xFFE53935);

  /// Pickups.
  static const Color collectibleColor = Color(0xFFFFD54F);

  /// Enemies.
  static const Color enemyColor = Color(0xFFAB47BC);

  /// Checkpoints and the goal.
  static const Color progressColor = Color(0xFF66BB6A);

  /// Non-interactive scenery.
  static const Color decorColor = Color(0xFF37474F);

  /// Every platformer prefab, in palette order.
  static List<PrefabDefinition> get all => [
    _solidPlatform,
    _oneWayPlatform,
    _movingPlatform,
    _crumblingPlatform,
    _bouncyPad,
    _hazard,
    _collectible,
    _patrolEnemy,
    _playerSpawn,
    _checkpoint,
    _goal,
    _cameraZone,
    _decoration,
  ];

  /// Rectangle visual plus a matching collider, the common core of every piece
  /// of level geometry.
  static List<jge.Component> _body(
    Offset position,
    Size size, {
    required Color color,
    bool isStatic = true,
    bool isSensor = false,
    bool isOneWay = false,
    jge.BodyType bodyType = jge.BodyType.dynamic,
    int layer = jge.LevelLayers.main,
    double strokeOpacity = 0.35,
  }) {
    return [
      jge.TransformComponent(
        position: jge.Vector3(position.dx, position.dy, 0),
      ),
      jge.RectangleComponent(
        width: size.width,
        height: size.height,
        fillStyle: jge.ShapePaintStyle(color: color),
        strokeStyle: jge.ShapePaintStyle(
          color: Color.lerp(color, Colors.white, strokeOpacity)!,
        ),
        strokeWidth: 2,
      ),
      jge.RigidBody2D(
        bodyType: isStatic ? jge.BodyType.static : bodyType,
        isSensor: isSensor,
        lockRotation: true,
        // What the kit's movement is tuned on, and what pieces placed before
        // the split kept: new ones feel the same as old ones in a level.
        mass: 1,
        friction: 0.2,
        restitution: 0,
        linearDamping: 0,
        angularDamping: 0,
      ),
      // The rectangle drawn, followed as it is resized.
      jge.Collider2D(shape: jge.ColliderShape2D.matchShape, oneWay: isOneWay),
      jge.LayerComponent(layer: layer),
    ];
  }

  static PrefabDefinition get _solidPlatform => PrefabDefinition(
    id: 'platformer.platform_solid',
    name: 'Platform',
    aliases: ['Solid'],
    category: 'Geometry',
    icon: Icons.crop_16_9,
    color: solidColor,
    description: 'Solid ground. The default building block.',
    namePrefix: 'Platform',
    build: (position, size) => [
      ..._body(position, size, color: solidColor),
      kit.PlatformComponent(),
    ],
  );

  static PrefabDefinition get _oneWayPlatform => PrefabDefinition(
    id: 'platformer.platform_one_way',
    name: 'One-way platform',
    aliases: ['OneWay', 'one_way'],
    category: 'Geometry',
    icon: Icons.vertical_align_top,
    color: oneWayColor,
    defaultSize: const Size(128, 16),
    description: 'Land on it from above, jump up through it from below.',
    namePrefix: 'OneWay',
    build: (position, size) => [
      ..._body(position, size, color: oneWayColor, isOneWay: true),
      kit.PlatformComponent(kind: kit.PlatformKind.oneWay),
    ],
  );

  static PrefabDefinition get _movingPlatform => PrefabDefinition(
    id: 'platformer.platform_moving',
    name: 'Moving platform',
    aliases: ['MovingPlatform', 'moving_platform'],
    category: 'Geometry',
    icon: Icons.swap_horiz,
    color: movingColor,
    description: 'Travels a waypoint path. Edit the path with the Path tool.',
    namePrefix: 'MovingPlatform',
    build: (position, size) => [
      // Kinematic, not static: it has to move, but must not be pushed by
      // whatever is standing on it.
      ..._body(
        position,
        size,
        color: movingColor,
        isStatic: false,
        bodyType: jge.BodyType.kinematic,
      ),
      jge.VelocityComponent(),
      kit.PlatformComponent(),
      kit.MovingPlatformComponent(
        waypoints: [position, position + const Offset(240, 0)],
      ),
    ],
  );

  static PrefabDefinition get _crumblingPlatform => PrefabDefinition(
    id: 'platformer.platform_crumbling',
    name: 'Crumbling platform',
    aliases: ['Crumbling'],
    category: 'Geometry',
    icon: Icons.grid_off,
    color: Color(0xFF8D6E63),
    description: 'Collapses shortly after being stepped on, then returns.',
    namePrefix: 'Crumble',
    build: (position, size) => [
      ..._body(position, size, color: const Color(0xFF8D6E63)),
      kit.PlatformComponent(kind: kit.PlatformKind.crumbling),
    ],
  );

  static PrefabDefinition get _bouncyPad => PrefabDefinition(
    id: 'platformer.platform_bouncy',
    name: 'Bounce pad',
    aliases: ['Bouncy', 'Spring'],
    category: 'Geometry',
    icon: Icons.arrow_upward,
    color: Color(0xFF26A69A),
    defaultSize: const Size(96, 24),
    description: 'Launches whatever lands on it.',
    namePrefix: 'Bouncer',
    build: (position, size) => [
      ..._body(position, size, color: const Color(0xFF26A69A)),
      kit.PlatformComponent(kind: kit.PlatformKind.bouncy),
    ],
  );

  static PrefabDefinition get _hazard => PrefabDefinition(
    id: 'platformer.hazard_spikes',
    name: 'Hazard',
    aliases: ['Spikes'],
    category: 'Hazards',
    icon: Icons.warning_amber_rounded,
    color: hazardColor,
    defaultSize: const Size(96, 24),
    description: 'Damages on contact. A sensor, so you pass through it.',
    namePrefix: 'Hazard',
    build: (position, size) => [
      ..._body(position, size, color: hazardColor, isSensor: true),
      kit.HazardComponent(),
    ],
  );

  static PrefabDefinition get _collectible => PrefabDefinition(
    id: 'platformer.collectible_coin',
    name: 'Collectible',
    aliases: ['Coin', 'Pickup'],
    category: 'Pickups',
    icon: Icons.stars_rounded,
    color: collectibleColor,
    placement: PrefabPlacement.point,
    defaultSize: const Size(24, 24),
    description: 'A pickup. Counts toward level completion.',
    namePrefix: 'Coin',
    build: (position, size) => [
      ..._body(position, size, color: collectibleColor, isSensor: true),
      kit.CollectibleComponent(),
    ],
  );

  static PrefabDefinition get _patrolEnemy => PrefabDefinition(
    id: 'platformer.enemy_patrol',
    name: 'Patrol enemy',
    aliases: ['Enemy', 'Patrol'],
    category: 'Actors',
    icon: Icons.bug_report,
    color: enemyColor,
    placement: PrefabPlacement.point,
    defaultSize: const Size(36, 36),
    description: 'Walks back and forth. Stompable from above.',
    namePrefix: 'Enemy',
    build: (position, size) => [
      // Dynamic so it falls onto the ground and collides properly, with
      // rotation locked so a scrape against scenery does not set it spinning.
      ..._body(position, size, color: enemyColor, isStatic: false),
      jge.VelocityComponent(),
      kit.PatrolEnemyComponent(),
      jge.HealthComponent(maxHealth: 1),
      jge.TagComponent(kit.PlatformerTags.enemy),
    ],
  );

  static PrefabDefinition get _playerSpawn => PrefabDefinition(
    id: 'platformer.player_spawn',
    name: 'Player spawn',
    aliases: ['PlayerSpawn', 'player_spawn', 'Spawn', 'Player', 'Start'],
    category: 'Progress',
    icon: Icons.person_pin_circle,
    color: progressColor,
    placement: PrefabPlacement.point,
    defaultSize: const Size(32, 48),
    description: 'Where the player appears. One per level.',
    namePrefix: 'PlayerSpawn',
    build: (position, size) => [
      jge.TransformComponent(
        position: jge.Vector3(position.dx, position.dy, 0),
      ),
      // No collider and no visual body: the spawn point is authoring metadata,
      // consumed at play time to place the real player entity. The editor
      // draws its own marker for it.
      jge.SpawnComponent(),
      jge.LayerComponent(layer: jge.LevelLayers.main),
    ],
  );

  static PrefabDefinition get _checkpoint => PrefabDefinition(
    id: 'platformer.checkpoint',
    name: 'Checkpoint',
    category: 'Progress',
    icon: Icons.flag_outlined,
    color: progressColor,
    placement: PrefabPlacement.point,
    defaultSize: const Size(32, 64),
    description: 'Respawn point once touched.',
    namePrefix: 'Checkpoint',
    build: (position, size) => [
      ..._body(position, size, color: progressColor, isSensor: true),
      jge.CheckpointComponent(
        respawnPosition: jge.Vector3(position.dx, position.dy, 0),
      ),
    ],
  );

  static PrefabDefinition get _goal => PrefabDefinition(
    id: 'platformer.goal',
    name: 'Goal',
    aliases: ['Exit', 'Finish'],
    category: 'Progress',
    icon: Icons.sports_score,
    color: Color(0xFF00E676),
    placement: PrefabPlacement.point,
    defaultSize: const Size(48, 80),
    description: 'The level exit.',
    namePrefix: 'Goal',
    build: (position, size) => [
      ..._body(position, size, color: const Color(0xFF00E676), isSensor: true),
      kit.GoalComponent(),
    ],
  );

  static PrefabDefinition get _cameraZone => PrefabDefinition(
    id: 'platformer.camera_zone',
    name: 'Camera zone',
    aliases: ['CameraZone'],
    category: 'Camera',
    icon: Icons.crop_free,
    color: Color(0xFF7E57C2),
    defaultSize: const Size(640, 360),
    description:
        'A shot of its own while the player is inside: set its zoom and '
        'framing in the inspector.',
    namePrefix: 'CameraZone',
    build: (position, size) => [
      jge.TransformComponent(
        position: jge.Vector3(position.dx, position.dy, 0),
      ),
      // No renderable and no collider: a zone is a virtual camera with a
      // trigger around it. The editor draws both; nothing shows at play time.
      ...kit.PlatformerCamera.zone(size: size),
      jge.LayerComponent(layer: jge.LevelLayers.main),
    ],
  );

  static PrefabDefinition get _decoration => PrefabDefinition(
    id: 'platformer.decoration',
    name: 'Decoration',
    category: 'Background',
    icon: Icons.wallpaper,
    color: decorColor,
    defaultSize: const Size(256, 128),
    description: 'Background scenery. No collider, scrolls with parallax.',
    namePrefix: 'Decor',
    build: (position, size) => [
      jge.TransformComponent(
        position: jge.Vector3(position.dx, position.dy, 0),
      ),
      jge.RectangleComponent(
        width: size.width,
        height: size.height,
        fillStyle: const jge.ShapePaintStyle(color: decorColor),
        strokeWidth: 0,
        filled: true,
      ),
      // Purely visual, so no physics body — ParallaxRectSystem rewrites the
      // transform every frame and would fight a physics sync.
      kit.ParallaxRectComponent(),
      jge.LayerComponent(
        layerId: 'background',
        layer: jge.LevelLayers.background,
      ),
    ],
    // Scenery: on a background layer of the map. Its own
    // ParallaxRectComponent scrolls it; the layer gives it only its depth,
    // draw order and visibility.
    depth: 'background',
  );
}
