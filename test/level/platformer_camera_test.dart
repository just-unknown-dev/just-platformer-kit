// PlatformerCamera: camera zones built from the engine's camera parts.
//
// Driven through a bare World with only the systems under test registered, so
// these stay fast and do not need a full Engine (which would also pull in a
// native physics world per test).

import 'package:flutter/painting.dart' show Offset, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_platformer_kit/just_platformer_kit.dart';

void main() {
  group('camera zones', () {
    // A zone is the engine's camera parts arranged by the kit: a shot that a
    // trigger enables while the player is inside. These cover the platformer
    // promises — the zoom applies inside, the zone is where its entity is,
    // overlapping zones are settled by priority, a locked axis does not scroll.
    late World world;
    late CameraEngine cameras;
    late Entity player;

    setUp(() {
      world = World()..initialize();
      cameras = CameraEngine()..initialize();
      cameras.mainCamera.viewportSize = const Size(800, 600);
      cameras.brain.defaultBlend = CameraBlend.cut;
      registerCameraSystems(world, cameras);

      world.createEntityWithComponents([
        TransformComponent(position: Vector3.zero()),
        VirtualCameraComponent(
          priority: 10,
          follow: const EntityTarget.tag('player'),
        ),
        CameraFramingComponent(
          deadZoneWidth: 0,
          deadZoneHeight: 0,
          dampingX: 0,
          dampingY: 0,
        ),
      ], name: 'MainCamera');

      player = world.createEntityWithComponents([
        TransformComponent(position: Vector3.zero()),
        TagComponent('player'),
      ], name: 'Player');
    });
    tearDown(() => world.dispose());

    /// A zone centred on [at], sized [size], that zooms to [zoom].
    Entity zone(
      Offset at, {
      String name = 'Zone',
      Size size = const Size(400, 400),
      double zoom = 2,
      int priority = 0,
      bool lockX = false,
    }) => world.createEntityWithComponents([
      TransformComponent(position: Vector3(at.dx, at.dy, 0)),
      ...PlatformerCamera.zone(
        size: size,
        zoom: zoom,
        priority: priority,
        lockX: lockX,
      ),
    ], name: name);

    void movePlayerTo(Offset at) =>
        player.getComponent<TransformComponent>()!.setPositionXY(at.dx, at.dy);

    double cameraZoom() => cameras.mainCamera.zoom;

    test('a player inside the zone takes its zoom', () {
      zone(const Offset(500, 500));
      movePlayerTo(const Offset(500, 500));
      world.update(1 / 60);
      expect(cameraZoom(), 2);
      expect(cameras.brain.liveCamera?.name, 'Zone');
    });

    test('a player outside every zone returns to the main camera', () {
      zone(const Offset(500, 500));
      movePlayerTo(const Offset(500, 500));
      world.update(1 / 60);
      expect(cameraZoom(), 2);

      movePlayerTo(const Offset(5000, 5000));
      world.update(1 / 60);
      expect(cameraZoom(), 1);
      expect(cameras.brain.liveCamera?.name, 'MainCamera');
    });

    test('the change of zoom is a blend, not a pop', () {
      cameras.brain.defaultBlend = const CameraBlend(duration: 1);
      zone(const Offset(500, 500));
      world.update(1 / 60);
      movePlayerTo(const Offset(500, 500));
      world.update(1 / 60);
      expect(cameraZoom(), inExclusiveRange(1, 2));
    });

    test('the zone follows its transform when moved', () {
      // The regression this covers: a zone that stores its own world-space
      // rect stays behind when its entity is dragged in the editor — the
      // marker and the behaviour drift apart with nothing on screen to
      // explain it.
      final moved = zone(const Offset(500, 500));
      movePlayerTo(const Offset(3000, 3000));
      world.update(1 / 60);
      expect(cameraZoom(), 1, reason: 'player starts outside');

      moved.getComponent<TransformComponent>()!.setPositionXY(3000, 3000);
      world.update(1 / 60);
      expect(cameraZoom(), 2, reason: 'the zone is where its entity is');
    });

    test('the higher-priority zone wins where two overlap', () {
      zone(Offset.zero, size: const Size(1000, 1000), zoom: 2);
      zone(
        Offset.zero,
        name: 'ZoneHigh',
        size: const Size(400, 400),
        zoom: 0.5,
        priority: 5,
      );
      movePlayerTo(Offset.zero);
      world.update(1 / 60);
      expect(cameraZoom(), 0.5);
      expect(cameras.brain.liveCamera?.name, 'ZoneHigh');
    });

    test('lockX pins the camera to the zone centre', () {
      zone(const Offset(800, 400), size: const Size(600, 600), lockX: true);
      movePlayerTo(const Offset(1000, 500));
      world.update(1 / 60);
      expect(cameras.mainCamera.position.dx, 800, reason: 'x does not scroll');
      expect(cameras.mainCamera.position.dy, closeTo(500, 1e-6));
    });

    test('an old level\'s CameraZoneComponent loads as a zone', () {
      final world = World()..context.install(PlatformerKit.extension);
      addTearDown(world.dispose);
      final loaded = SceneLoader.load(world, {
        'version': 1,
        'name': 's',
        'entities': [
          {
            'name': 'Cave',
            'components': [
              {
                'type': 'TransformComponent',
                'fields': {
                  'position': {'x': 10.0, 'y': 20.0},
                },
              },
              {
                'type': 'CameraZoneComponent',
                'fields': {
                  'width': 640.0,
                  'height': 360.0,
                  'zoom': 0.65,
                  'priority': 3,
                  'lockX': true,
                  'lockY': false,
                },
              },
            ],
          },
        ],
      }).single;
      final vcam = loaded.getComponent<VirtualCameraComponent>()!;
      expect(vcam.priority, PlatformerCamera.zonePriority + 3);
      expect(vcam.enabled, isFalse);
      expect(vcam.zoom, 0.65);
      final framing = loaded.getComponent<CameraFramingComponent>()!;
      expect((framing.followX, framing.followY), (false, true));
      final trigger = loaded.getComponent<CameraTriggerComponent>()!;
      expect((trigger.width, trigger.height), (640, 360));
    });
  });
}
