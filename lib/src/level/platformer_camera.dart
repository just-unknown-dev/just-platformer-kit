/// The platformer's camera vocabulary, in the engine's terms.
library;

import 'package:flutter/painting.dart' show Size;
import 'package:just_game_engine/just_game_engine.dart';

import 'platformer_tags.dart';

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
