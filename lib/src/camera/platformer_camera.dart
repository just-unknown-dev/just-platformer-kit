/// The platformer's camera vocabulary, in the engine's terms.
library;

import 'package:flutter/painting.dart' show Size;
import 'package:just_game_engine/just_game_engine.dart';

import '../platformer_tags.dart';

/// Camera set-ups a platformer reaches for, built from the engine's virtual
/// camera components. The kit has no camera components or systems of its
/// own: a camera zone is a shot with a trigger around it.
abstract final class PlatformerCamera {
  /// Priority a zone's shot starts from — above a level's main camera (10),
  /// so an entered zone wins without anyone tuning numbers.
  static const int zonePriority = 20;

  /// The components of a camera zone of [size]: a shot that is live only
  /// while a player — any entity tagged [playerTag] — is inside, at [zoom].
  ///
  /// [lockX] / [lockY] hold that axis at the zone's centre instead of
  /// following the player — a vertical shaft that does not scroll sideways.
  /// Where zones overlap, the higher [priority] wins.
  ///
  /// With several players, point the zone at their group: [follow] and
  /// [target] set to the target group's entity
  /// (`EntityTarget.name('Players')`) make the zone switch on where the
  /// group is and frame all of them. Both default to [playerTag].
  static List<Component> zone({
    required Size size,
    double zoom = 1.0,
    int priority = 0,
    bool lockX = false,
    bool lockY = false,
    String playerTag = PlatformerTags.player,
    EntityTarget? follow,
    EntityTarget? target,
  }) {
    // A blank tag is no target, not the entities tagged ''.
    final players = playerTag.trim().isEmpty
        ? EntityTarget.none
        : EntityTarget.tag(playerTag.trim());
    return [
      VirtualCameraComponent(
        priority: zonePriority + priority,
        // The trigger enables it; off, it is not even a candidate.
        enabled: false,
        follow: follow ?? players,
        zoom: zoom,
      ),
      CameraFramingComponent(followX: !lockX, followY: !lockY),
      CameraTriggerComponent(
        width: size.width,
        height: size.height,
        target: target ?? players,
      ),
    ];
  }
}

/// Scene migrations for levels saved with older versions of the kit.
abstract final class PlatformerMigrations {
  /// Adds the kit's rules to [context]'s migrations
  /// (`context.migrations`), writing components with its definitions.
  /// Installing [PlatformerKit.extension] calls it, once per context.
  static void install(EngineContext context) {
    final definitions = context.definitions;
    context.migrations
        .perEntity(1)
        .add(
          (entity, scene) =>
              cameraZone(entity, scene, definitions: definitions),
        );
  }

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
    final registry = definitions ?? ComponentDefinitionRegistry.core();
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
