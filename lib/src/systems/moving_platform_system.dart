library;

import 'dart:math' as math;

import 'package:flutter/painting.dart' show Offset;

import 'package:just_game_engine/just_game_engine.dart';

import '../components/platformer.dart';

/// Steers kinematic platforms along their waypoint paths.
///
/// Sets velocity rather than writing the transform. A transform write is a
/// teleport: it would move the platform out from under anything standing on
/// it without imparting any motion, so riders would be left hanging in the air
/// and the platform would shove them out of the way on the next step. Velocity
/// keeps the contact physically meaningful, and [PlayerControlSystem] carries
/// a player standing on it at its [MovingPlatformComponent.currentVelocity].
///
/// Runs at [SystemPriorities.movingPlatform] (92), above physics, so this
/// frame's velocity is in place before the step that acts on it. Stands
/// still while time does (a `deltaTime` of 0: paused, or an editor
/// authoring the level), so the level's saved velocities are left alone.
class MovingPlatformSystem extends System {
  @override
  int get priority => SystemPriorities.movingPlatform;

  @override
  List<Type> get requiredComponents => const [
    TransformComponent,
    VelocityComponent,
    MovingPlatformComponent,
  ];

  @override
  void update(double deltaTime) {
    if (deltaTime <= 0) return;
    forEach((entity) {
      if (!entity.isActive) return;

      final platform = entity.getComponent<MovingPlatformComponent>()!;
      final transform = entity.getComponent<TransformComponent>()!;
      final velocity = entity.getComponent<VelocityComponent>()!;

      if (platform.waypoints.length < 2 || !platform.isMoving) {
        _halt(platform, velocity);
        return;
      }

      if (platform.pauseTimer > 0) {
        platform.pauseTimer -= deltaTime;
        _halt(platform, velocity);
        return;
      }

      _steer(platform, transform, velocity, deltaTime);
    });
  }

  void _halt(MovingPlatformComponent platform, VelocityComponent velocity) {
    platform.currentVelocity = Offset.zero;
    velocity.setVelocityXY(0, 0);
  }

  void _steer(
    MovingPlatformComponent platform,
    TransformComponent transform,
    VelocityComponent velocity,
    double deltaTime,
  ) {
    // Close enough that one more step would overshoot: snap the waypoint and
    // pick the next one. Without the step-size term a fast platform oscillates
    // around its target forever.
    final stepSize = platform.speed * deltaTime;
    var (dx, dy) = _toTarget(platform, transform);
    var distance = math.sqrt(dx * dx + dy * dy);
    if (distance <= math.max(stepSize, 1.0)) {
      _advanceWaypoint(platform);
      // Waiting there, or at the end of a one-way trip.
      if (platform.pauseTimer > 0 || !platform.isMoving) {
        _halt(platform, velocity);
        return;
      }
      // No wait: straight on toward the next one, without a stopped step
      // that would jolt whoever rides it.
      (dx, dy) = _toTarget(platform, transform);
      distance = math.sqrt(dx * dx + dy * dy);
      if (distance < 1e-9) {
        _halt(platform, velocity);
        return;
      }
    }

    final inv = 1.0 / distance;
    final vx = dx * inv * platform.speed;
    final vy = dy * inv * platform.speed;

    platform.currentVelocity = Offset(vx, vy);
    velocity.setVelocityXY(vx, vy);
  }

  /// From [transform] to the waypoint [platform] is heading for.
  (double, double) _toTarget(
    MovingPlatformComponent platform,
    TransformComponent transform,
  ) {
    final target =
        platform.waypoints[platform.targetIndex.clamp(
          0,
          platform.waypoints.length - 1,
        )];
    return (target.dx - transform.position.x, target.dy - transform.position.y);
  }

  /// Picks the next waypoint according to the loop mode.
  void _advanceWaypoint(MovingPlatformComponent platform) {
    platform.pauseTimer = platform.pauseSeconds;
    final last = platform.waypoints.length - 1;

    switch (platform.loopMode) {
      case PlatformLoopMode.pingPong:
        if (platform.targetIndex >= last) {
          platform.direction = -1;
        } else if (platform.targetIndex <= 0) {
          platform.direction = 1;
        }
        platform.targetIndex = (platform.targetIndex + platform.direction)
            .clamp(0, last);

      case PlatformLoopMode.loop:
        platform.targetIndex = platform.targetIndex >= last
            ? 0
            : platform.targetIndex + 1;

      case PlatformLoopMode.once:
        if (platform.targetIndex >= last) {
          platform.isMoving = false;
        } else {
          platform.targetIndex++;
        }
    }
  }
}
