import 'package:flutter/material.dart';
import 'package:just_game_engine/just_game_engine.dart' as jge;
import 'package:just_editor_core/just_editor_core.dart';

import '../../just_platformer_kit.dart';
import 'platformer_overlays.dart';
import 'platformer_prefabs.dart';

/// Teaches the Level Designer to author a platformer.
///
/// Everything here goes through the same public [EditorModule] contract a
/// project would use for its own genre — the kit has no privileged access to
/// the editor. That is the point: if a platformer can be expressed this way,
/// so can a top-down shooter, a puzzle game or anything else.
///
/// ```dart
/// EditorScope(engine: engine, modules: [PlatformerModule()]);
/// ```
class PlatformerModule extends EditorModule {
  /// Id of the moving-platform path tool.
  static const String pathToolId = 'platformer.path';

  /// Add-Component picker group for platformer gameplay components.
  static const String gameplayGroup = 'Platformer';

  /// Add-Component picker group for level-wide components.
  static const String levelGroup = 'Level';

  @override
  String get id => 'platformer';

  @override
  String get name => 'Platformer';

  @override
  IconData get icon => Icons.directions_run;

  @override
  List<String> get componentGroups => const [gameplayGroup, levelGroup];

  @override
  List<PrefabDefinition> get prefabs => PlatformerPrefabs.all;

  /// The kit's own tags, which its code looks for by name.
  @override
  List<jge.TagDefinition> get tags => PlatformerTags.declared;

  /// What the things a platformer is made of look like in the scene tree.
  ///
  /// The editor draws a generic box for anything it does not know; a coin
  /// is a coin because this says so, not because the editor has heard of
  /// coins.
  @override
  List<EntityIcon> get entityIcons => [
    EntityIcon(id: 'platformer.icons', of: _iconOf),
  ];

  static IconData? _iconOf(jge.Entity entity) {
    if (entity.getComponent<PlayerControlComponent>() != null) {
      return Icons.directions_run;
    }
    if (entity.getComponent<CollectibleComponent>() != null) {
      return Icons.monetization_on_outlined;
    }
    if (entity.getComponent<HazardComponent>() != null) {
      return Icons.warning_amber_rounded;
    }
    if (entity.getComponent<GoalComponent>() != null) return Icons.flag_rounded;
    if (entity.getComponent<PatrolEnemyComponent>() != null) {
      return Icons.pest_control_rodent_outlined;
    }
    if (entity.getComponent<MovingPlatformComponent>() != null) {
      return Icons.swap_horiz_rounded;
    }
    if (entity.getComponent<PlatformComponent>() != null) {
      return Icons.horizontal_rule_rounded;
    }
    if (entity.getComponent<LevelBoundsComponent>() != null) {
      return Icons.crop_free_rounded;
    }
    if (entity.getComponent<ParallaxRectComponent>() != null) {
      return Icons.layers_outlined;
    }
    final tags = entity.tags;
    if (tags.contains(PlatformerTags.player)) return Icons.directions_run;
    if (tags.contains(PlatformerTags.enemy)) {
      return Icons.pest_control_rodent_outlined;
    }
    return null;
  }

  @override
  List<LevelToolHandler> createTools(DesignerToolContext context) => [
    PathTool(
      sceneState: context.sceneState,
      history: context.history,
      id: pathToolId,
      label: 'Path',
      icon: Icons.route,
      // 'P' is Paint; W, E and R are Move, Scale and Rotate.
      shortcut: 'K',
      description:
          'Edit a moving platform\'s route: click to add a waypoint, drag one '
          'to move it, Alt+click to remove it',
      order: 40,
      binding: PathBinding(
        resolve: (entity) => entity.getComponent<MovingPlatformComponent>(),
        read: (component) =>
            List.of((component as MovingPlatformComponent).waypoints),
        write: (component, points) =>
            (component as MovingPlatformComponent).waypoints = points,
        isClosed: (component) =>
            (component as MovingPlatformComponent).loopMode ==
            PlatformLoopMode.loop,
        emptyMessage: 'Select a moving platform to edit its path',
      ),
    ),
  ];

  /// What the editor's start card says about building a platformer level.
  @override
  List<GettingStartedTip> get gettingStartedTips => const [
    GettingStartedTip(
      id: 'platformer.spawn',
      icon: Icons.directions_run,
      text:
          'Place a Player spawn where the level begins: Play brings the '
          'player in there.',
    ),
    GettingStartedTip(
      id: 'platformer.palette',
      icon: Icons.category_outlined,
      text:
          "Platforms, spikes, coins, enemies, checkpoints and the Goal are "
          "in the Level Designer's palette.",
    ),
    GettingStartedTip(
      id: 'platformer.path',
      icon: Icons.route,
      text:
          'Select a moving platform and press K in the Level Designer to '
          'draw the route it travels.',
    ),
  ];

  @override
  List<DesignerOverlay> get overlays => [
    LevelBoundsOverlay(),
    PlatformPathOverlay(pathToolId: pathToolId),
  ];

  @override
  void onRegister(EditorModuleContext context) {
    super.onRegister(context);
    // The kit's components, migrations, bindings and collision kinds, in the
    // edited engine's context — the game installs the same at boot, and an
    // install is once per context. The Tileset Editor offers the kinds.
    context.scope.context.install(PlatformerKit.extension);
  }
}
