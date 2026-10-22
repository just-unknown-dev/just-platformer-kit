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
/// keeps the contact physically meaningful, so Box2D carries the rider and
/// [PlayerControlSystem] can top it up with the platform's own speed.
///
/// Runs at [SystemPriorities.movingPlatform] (92), above physics, so this
/// frame's velocity is in place before the step that acts on it.
class MovingPlatformSystem extends System {
  @override
  int get priority => SystemPriorities.movingPlatform;

  @override
  List<Type> get requiredComponents => [
    TransformComponent,
    MovingPlatformComponent,
  ];

  @override
  void update(double deltaTime) {
    forEach((entity) {
      if (!entity.isActive) return;

      final platform = entity.getComponent<MovingPlatformComponent>()!;
      final transform = entity.getComponent<TransformComponent>()!;
      final velocity = entity.getComponent<VelocityComponent>();

      if (platform.waypoints.length < 2 ||
          !platform.autoStart && !platform.isMoving) {
        _halt(platform, velocity);
        return;
      }

      if (platform.pauseTimer > 0) {
        platform.pauseTimer -= deltaTime;
        _halt(platform, velocity);
        return;
      }

      platform.isMoving = true;
      _steer(entity, platform, transform, velocity, deltaTime);
    });
  }

  void _halt(MovingPlatformComponent platform, VelocityComponent? velocity) {
    platform.currentVelocity = Offset.zero;
    velocity?.setVelocityXY(0, 0);
  }

  void _steer(
    Entity entity,
    MovingPlatformComponent platform,
    TransformComponent transform,
    VelocityComponent? velocity,
    double deltaTime,
  ) {
    final target =
        platform.waypoints[platform.targetIndex.clamp(
          0,
          platform.waypoints.length - 1,
        )];
    final dx = target.dx - transform.position.x;
    final dy = target.dy - transform.position.y;
    final distance = math.sqrt(dx * dx + dy * dy);

    // Close enough that one more step would overshoot: snap the waypoint and
    // pick the next one. Without the step-size term a fast platform oscillates
    // around its target forever.
    final stepSize = platform.speed * deltaTime;
    if (distance <= math.max(stepSize, 1.0)) {
      _advanceWaypoint(platform);
      _halt(platform, velocity);
      return;
    }

    final inv = 1.0 / distance;
    final vx = dx * inv * platform.speed;
    final vy = dy * inv * platform.speed;

    platform.currentVelocity = Offset(vx * deltaTime, vy * deltaTime);
    velocity?.setVelocityXY(vx, vy);
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
