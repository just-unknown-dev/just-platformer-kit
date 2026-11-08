/// What stands under a rigid-body player's feet, found with short rays.
library;

import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart' show internal;
import 'package:just_game_engine/just_game_engine.dart';

/// What [PlayerGroundProbe.probe] found under a player's feet.
@internal
final class GroundHit {
  /// Ground [gap] from the feet, facing [normal], of [body].
  const GroundHit(this.gap, this.normal, this.body);

  /// How far the feet are from the ground, along [normal]: 0 touching,
  /// less than 0 sunk into it.
  final double gap;

  /// The surface's normal there, length 1, facing up (`dy < 0`).
  final Offset normal;

  /// The body it belongs to.
  final Physics2DBody body;
}

/// Two short rays straight down from a rigid-body player's feet — one under
/// each lower corner — that find the ground the way the player stands on
/// it.
///
/// Contacts alone are a poor guide on tiled ground: a contact ends for a
/// step whenever the body lifts a hair off a ramp it runs down, and where
/// two tiles of a ramp meet, the corner of the solid box under the next
/// tile gives a contact whose normal is flat. A ray finds the face of the
/// ramp itself — the seam's buried corner is never what a ray from above
/// meets first — and its plane gives how far the corner above it is from
/// the ground, so the player can be held to it.
///
/// A box's corners are its own (a rounded box's are the centres of its
/// rounded corners); a circle or a capsule is taken by its lower round, a
/// ray either side of its middle. Another polygon is taken as the box
/// round it.
///
/// A ray passes over a sensor, a body the player does not collide with
/// (its layers, or a crumbled platform's emptied mask), the player's own
/// body, a one-way platform that is not solid from above, and one the
/// player is partway through.
@internal
final class PlayerGroundProbe {
  /// How far above the feet each ray starts, in world units: above ground
  /// the body has sunk into, so the ray does not start inside it (a ray
  /// passes over a shape it starts inside).
  static const double lift = 6;

  /// How far a one-way platform may be above the feet and still count: a
  /// player partway through one is not standing on it.
  static const double oneWayTolerance = 1.5;

  final Set<Physics2DBody> _exclude = {};

  /// The ground nearest [body]'s feet within [reach] below them, or null:
  /// whichever ray's ground is nearer its corner.
  GroundHit? probe(Physics2DEngine physics, Physics2DBody body, double reach) {
    final position = Offset(body.position.x, body.position.y);
    final shape = body.shape;
    // The two lower corners — the centres of their rounding, and its
    // radius — and the bottom of the shape straight under each.
    final Offset left, right;
    final double radius;
    switch (shape) {
      case Circle2DShape():
        radius = shape.radius;
        left = right = shape.centerAt(position);
      case Capsule2DShape():
        radius = shape.radius;
        left = right =
            position +
            (shape.center1.dy > shape.center2.dy
                ? shape.center1
                : shape.center2);
      default:
        final bounds = body.boundsAt(position);
        radius = shape is RoundedPolygon2DShape
            ? math.min(shape.cornerRadius, bounds.width / 2)
            : 0;
        final inset = math.max(radius, 0.01);
        left = Offset(bounds.left + inset, bounds.bottom - radius);
        right = Offset(bounds.right - inset, bounds.bottom - radius);
    }
    // A box's rays go down its sides — a hair inside, so a ray never runs
    // down a wall the side is flush with — where its corners first meet a
    // ramp's foot or a ledge's lip; a round's either side of its middle.
    final round = shape is Circle2DShape || shape is Capsule2DShape;
    final dx = round ? radius / 2 : math.max(0.0, radius - 0.01);
    _exclude
      ..clear()
      ..add(body);
    final a = _cast(physics, body, left, -dx, radius, reach);
    final b = _cast(physics, body, right, dx, radius, reach);
    if (a == null) return b;
    if (b == null) return a;
    return a.gap <= b.gap ? a : b;
  }

  /// A ray down at [dx] across from [corner] — a round's centre of
  /// [radius] — and how far the round is from the plane it meets.
  GroundHit? _cast(
    Physics2DEngine physics,
    Physics2DBody self,
    Offset corner,
    double dx,
    double radius,
    double reach,
  ) {
    final x = corner.dx + dx;
    final foot =
        corner.dy + math.sqrt(math.max(0.0, radius * radius - dx * dx));
    final ray = Ray2D(
      origin: Offset(x, foot - lift),
      direction: const Offset(0, 1),
      maxDistance: lift + reach,
    );
    for (final hit in physics.raycastAll(ray, exclude: _exclude)) {
      final other = hit.body;
      if (other.isSensor || !_collides(self, other)) continue;
      final n = hit.normal;
      final length = n.distance;
      // Facing up: what a ray from above meets on ground it can stand on.
      if (length == 0 || n.dy >= 0) continue;
      final normal = n / length;
      // The round's nearest point to the plane is its centre less its
      // radius along the normal — when that is over what the ray met. Far
      // to the side of it, the plane is a slope's carried on past where the
      // slope ends (the top of a ramp, under a round's middle): not ground.
      final support = corner - normal * radius;
      if ((support.dx - x).abs() > radius + 0.5) return null;
      final gap =
          (support.dx - hit.point.dx) * normal.dx +
          (support.dy - hit.point.dy) * normal.dy;
      if (other.isOneWay &&
          (other.oneWayDirection != OneWayDirection.fromAbove ||
              gap < -oneWayTolerance)) {
        continue;
      }
      return GroundHit(gap, normal, other);
    }
    return null;
  }

  /// Whether [a] and [b] collide by their layers and groups.
  static bool _collides(Physics2DBody a, Physics2DBody b) {
    if (a.groupIndex != 0 && a.groupIndex == b.groupIndex) {
      return a.groupIndex > 0;
    }
    return (a.maskBits & b.categoryBits) != 0 &&
        (b.maskBits & a.categoryBits) != 0;
  }
}
