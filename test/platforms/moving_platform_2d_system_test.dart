// MovingPlatform2DSystem: waypoints, loop modes, pauses and starting.
//
// Driven through a bare World with only the systems under test registered, so
// these stay fast and do not need a full Engine (which would also pull in a
// native physics world per test).

import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_platformer_kit/just_platformer_kit.dart';

void main() {
  group('MovingPlatform2DSystem', () {
    late World world;

    setUp(() {
      world = World()..initialize();
      world.addSystem(MovingPlatform2DSystem());
    });

    Entity platform({
      required List<Offset> waypoints,
      PlatformLoopMode loop = PlatformLoopMode.pingPong,
      double speed = 120,
    }) => world.createEntityWithComponents([
      TransformComponent(
        position: Vector3(waypoints.first.dx, waypoints.first.dy, 0),
      ),
      VelocityComponent(),
      MovingPlatform2DComponent(
        waypoints: waypoints,
        speed: speed,
        loopMode: loop,
      ),
    ], name: 'Platform');

    test('drives velocity toward the next waypoint', () {
      final entity = platform(waypoints: const [Offset(0, 0), Offset(240, 0)]);

      world.update(1 / 60);

      final velocity = entity.getComponent<VelocityComponent>()!;
      expect(velocity.velocity.x, closeTo(120, 0.01));
      expect(velocity.velocity.y, closeTo(0, 0.01));
    });

    test('moves by velocity, not by teleporting the transform', () {
      final entity = platform(waypoints: const [Offset(0, 0), Offset(240, 0)]);
      final transform = entity.getComponent<TransformComponent>()!;

      world.update(1 / 60);

      expect(
        transform.position.x,
        0,
        reason: 'the system sets velocity; physics does the moving',
      );
    });

    test('ping-pong reverses at the end of the path', () {
      final entity = platform(waypoints: const [Offset(0, 0), Offset(100, 0)]);
      final component = entity.getComponent<MovingPlatform2DComponent>()!;
      final transform = entity.getComponent<TransformComponent>()!;

      expect(component.targetIndex, 1);

      // Arrive at the far waypoint.
      transform.setPositionXY(100, 0);
      world.update(1 / 60);

      expect(component.targetIndex, 0, reason: 'now heading back');
      expect(component.direction, -1);
    });

    test('loop mode wraps to the first waypoint', () {
      final entity = platform(
        waypoints: const [Offset(0, 0), Offset(100, 0), Offset(200, 0)],
        loop: PlatformLoopMode.loop,
      );
      final component = entity.getComponent<MovingPlatform2DComponent>()!;
      final transform = entity.getComponent<TransformComponent>()!;

      transform.setPositionXY(200, 0);
      component.targetIndex = 2;
      world.update(1 / 60);

      expect(component.targetIndex, 0);
    });

    test('once mode stops at the end', () {
      final entity = platform(
        waypoints: const [Offset(0, 0), Offset(100, 0)],
        loop: PlatformLoopMode.once,
      );
      final component = entity.getComponent<MovingPlatform2DComponent>()!;
      final transform = entity.getComponent<TransformComponent>()!;

      transform.setPositionXY(100, 0);
      world.update(1 / 60);

      expect(component.isMoving, isFalse);
      expect(entity.getComponent<VelocityComponent>()!.velocity.x, 0);
    });

    test('once mode, started again at the end, goes back the way it came', () {
      final entity = platform(
        waypoints: const [Offset(0, 0), Offset(100, 0)],
        loop: PlatformLoopMode.once,
      );
      final component = entity.getComponent<MovingPlatform2DComponent>()!;
      final transform = entity.getComponent<TransformComponent>()!;
      final velocity = entity.getComponent<VelocityComponent>()!;

      transform.setPositionXY(100, 0);
      world.update(1 / 60);
      expect(component.isMoving, isFalse, reason: 'stopped at the end');

      component.isMoving = true;
      world.update(1 / 60);
      expect(component.isMoving, isTrue, reason: 'started again');
      expect(velocity.velocity.x, closeTo(-120, 0.01), reason: 'heading back');

      // Back at the first waypoint: it stops there, and next time goes out.
      transform.setPositionXY(0, 0);
      world.update(1 / 60);
      expect(component.isMoving, isFalse);
      component.isMoving = true;
      world.update(1 / 60);
      expect(velocity.velocity.x, closeTo(120, 0.01));
    });

    test('a single waypoint is stationary', () {
      final entity = platform(waypoints: const [Offset(50, 50)]);

      world.update(1 / 60);

      expect(entity.getComponent<VelocityComponent>()!.velocity.x, 0);
      expect(entity.getComponent<VelocityComponent>()!.velocity.y, 0);
    });
  });
}
