library;

import 'package:flutter/painting.dart' show Offset;

import 'package:just_game_engine/just_game_engine.dart';

/// What a moving platform does when it reaches the last waypoint.
enum PlatformLoopMode {
  /// Walk the path forwards, then backwards, forever.
  pingPong,

  /// Jump back to the first waypoint and repeat.
  loop,

  /// Stop at the last waypoint.
  once,
}

/// Drives an entity along a path of world-space waypoints.
///
/// Requires the entity's [RigidBody2D] to be kinematic — a dynamic
/// body would be shoved off its path by whatever is standing on it, and a
/// static body cannot move at all. `MovingPlatformSystem` steers by setting
/// velocity rather than teleporting, so riders inherit the motion through
/// normal contact instead of being left behind.
class MovingPlatformComponent extends Component {
  MovingPlatformComponent({
    List<Offset>? waypoints,
    this.speed = 120.0,
    this.loopMode = PlatformLoopMode.pingPong,
    this.pauseSeconds = 0.0,
    this.autoStart = true,
  }) : waypoints = waypoints ?? <Offset>[];

  /// Path in world space. Fewer than two points means the platform is
  /// stationary. Editable on canvas with the level designer's path tool, and
  /// in the inspector as an offset list.
  List<Offset> waypoints;

  /// Travel speed in world units per second.
  double speed;

  /// What happens at the end of the path.
  PlatformLoopMode loopMode;

  /// How long to wait at each waypoint before moving on.
  double pauseSeconds;

  /// Whether the platform starts moving without being triggered.
  bool autoStart;

  // ── Runtime state, owned by MovingPlatformSystem ──────────────────────────

  /// Index of the waypoint currently being travelled toward.
  int targetIndex = 1;

  /// Direction of travel along the path: +1 forwards, -1 backwards. Only
  /// meaningful for [PlatformLoopMode.pingPong].
  int direction = 1;

  /// Counts down while paused at a waypoint.
  double pauseTimer = 0.0;

  /// Whether the platform is currently moving.
  bool isMoving = true;

  /// Velocity applied this frame, so riders can inherit it.
  Offset currentVelocity = Offset.zero;
}
