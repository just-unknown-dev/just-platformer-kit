/// Migrations for levels an older kit saved.
library;

import 'package:flutter/painting.dart' show Size;
import 'package:just_game_engine/just_game_engine.dart';

import '../level/level.dart';

/// Scene migrations for levels saved with older versions of the kit.
///
/// Renaming a saved component: add `'OldName': 'NewName'` to
/// [renamedTypes] and keep every earlier entry. The scene format applies a
/// package's `renamedTypes` to a level of any format as it loads — format 11
/// included — and follows chains (`A → B`, `B → C` loads both `A` and `B`
/// as `C`), so no definition `aliases` are needed. A renamed saved field goes
/// in `context.migrations.renamedFields` the same way.
abstract final class PlatformerMigrations {
  /// Adds the kit's rules to [context]'s migrations
  /// (`context.migrations`), writing components with its definitions.
  /// Installing `PlatformerKit.extension` calls it, once per context.
  static void install(EngineContext context) {
    final definitions = context.definitions;
    context.migrations
        .perEntity(1)
        .add(
          (entity, scene) =>
              cameraZone(entity, scene, definitions: definitions),
        );
    context.migrations.renamedTypes.addAll(renamedTypes);
  }

  /// The kit's renamed components, old name → new, applied to a level of
  /// any format as it loads.
  ///
  /// The first came with scene format 11, when every component's name came
  /// to end in `Component`, tagged 2D when it also has a 3-D version (the
  /// third-person kit's moving platform).
  static const Map<String, String> renamedTypes = {
    'MovingPlatformComponent': 'MovingPlatform2DComponent',
  };

  /// v1 → v2: `CameraZoneComponent` becomes what [PlatformerCamera.zone]
  /// builds — a virtual camera, its framing and a trigger — written with
  /// [definitions] (the engine's own when null).
  static void cameraZone(
    Map<String, dynamic> entity,
    Map<String, dynamic> scene, {
    ComponentDefinitionRegistry? definitions,
  }) {
    final components = entity['components'];
    if (components is! List) return;
    final index = components.indexWhere(
      (c) => c is Map && c['type'] == 'CameraZoneComponent',
    );
    if (index < 0) return;
    final old = (components[index] as Map)['fields'];
    final f = old is Map ? old : const {};
    double n(String key, double fallback) =>
        (f[key] as num?)?.toDouble() ?? fallback;

    // Only the engine's own camera components are written here.
    final registry = definitions ?? BuiltInComponents.registry();
    components
      ..removeAt(index)
      ..insertAll(index, [
        for (final component in PlatformerCamera.zone(
          size: Size(n('width', 800), n('height', 600)),
          zoom: n('zoom', 1),
          priority: (f['priority'] as num?)?.toInt() ?? 0,
          lockX: f['lockX'] == true,
          lockY: f['lockY'] == true,
        ))
          ?registry.encode(component),
      ]);
  }
}
