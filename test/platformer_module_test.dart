// The module contract is only real if something outside the editor package
// can use it to build a whole genre. This is that proof: the kit registers
// through the public API alone, a real designer session opens, and every
// contribution has to be reachable where the editor looks for it.

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart' as jge;
import 'package:just_game_engine_editor/just_game_engine_editor.dart';
import 'package:just_platformer_kit/editor.dart';
import 'package:just_platformer_kit/just_platformer_kit.dart';

({LevelDesignerSession session, jge.World world}) _openDesigner() {
  final world = jge.World()..initialize();
  var counter = 0;
  final session = LevelDesignerSession(
    scope: EditorScope(
      builtIns: const [BuiltInEditorModule.new],
      world: world,
      modules: [PlatformerModule()],
    )..selectDesigner('platformer'),
    uniqueName: (prefix) => '${prefix}_${counter++}',
    onDuplicate: () {},
    onDelete: () {},
    onArray: (_, _) {},
  );
  return (session: session, world: world);
}

void main() {
  // The module installs the kit into the scope's context, as the game's
  // boot does; it contributes the design-time half on top.

  late LevelDesignerSession session;
  late jge.World world;

  setUp(() => (:session, :world) = _openDesigner());
  tearDown(() {
    session.dispose();
    session.scope.dispose();
    world.dispose();
  });

  test('platformer prefabs join the palette alongside the built-ins', () {
    final ids = session.scope.prefabs.all.map((p) => p.id).toSet();
    for (final prefab in PlatformerPrefabs.all) {
      expect(ids, contains(prefab.id));
    }
    // The generic palette is still there: a module adds, not replaces.
    expect(ids, contains(BuiltInPrefabs.rectangleId));
  });

  test('the path tool is registered with the session it belongs to', () {
    final tool = session.tools.byId(PlatformerModule.pathToolId);
    expect(tool, isA<PathTool>());
    // K: W, E and R are Move, Scale and Rotate.
    expect(session.tools.byShortcut('K'), same(tool));
    expect(session.tools.byShortcut('E'), isNull);

    // Built-in tools survive alongside it.
    expect(session.tools.byId(BuiltInTools.select), isNotNull);
  });

  test('the platformer overlays are drawable and individually toggleable', () {
    final ids = session.overlays.all.map((o) => o.id).toSet();
    expect(ids, containsAll(['platformer.bounds', 'platformer.paths']));

    session.controller.setOverlayVisible('platformer.paths', visible: false);
    expect(session.controller.isOverlayVisible('platformer.paths'), isFalse);
    expect(session.controller.isOverlayVisible('platformer.bounds'), isTrue);
  });

  test('every platformer component is inspectable through its definition', () {
    // No design-time descriptors any more: the runtime schema carries the
    // hints, and every field of it has an editor in the scope.
    for (final schema
        in PlatformerSchemas.all.whereType<jge.ComponentSchema>()) {
      expect(schema.hints.name, isNotNull, reason: schema.type);
      expect(schema.hints.group, isNotNull, reason: schema.type);
      for (final field in schema.fields) {
        expect(
          session.scope.fieldEditors.canEdit(field),
          isTrue,
          reason: '${schema.type}.${field.name} (${field.kind.id})',
        );
      }
    }
  });

  test('platformer component groups appear in the picker order', () {
    expect(
      session.scope.modules.componentGroups,
      containsAll([
        PlatformerModule.gameplayGroup,
        PlatformerModule.levelGroup,
      ]),
    );
  });

  test('a camera zone is a shot with a trigger, sized like any shape', () {
    final prefab = PlatformerPrefabs.all.firstWhere(
      (p) => p.id == 'platformer.camera_zone',
    );
    final components = prefab.build(const Offset(10, 20), const Size(640, 360));
    final vcam = components.whereType<jge.VirtualCameraComponent>().single;
    expect(vcam.enabled, isFalse, reason: 'live only while the player is in');
    expect(vcam.follow, const jge.EntityTarget.tag('player'));
    expect(components.whereType<jge.CameraFramingComponent>(), hasLength(1));

    // A zone has no rectangle or collider; the trigger's extent is what lets
    // it be marquee-selected, aligned and resized like everything else.
    final trigger = components.whereType<jge.CameraTriggerComponent>().single;
    final zone = world.createEntityWithComponents(components, name: 'Zone');
    expect(DesignerGeometry.componentSize(zone), const Size(640, 360));
    expect(GizmoPainter.sizeOf(trigger), DesignerGeometry.sizeOf(trigger));
    expect(ComponentResizer.scaleComponent(trigger, 2, 0.5), isTrue);
    expect((trigger.width, trigger.height), (1280, 180));
  });

  test('every platformer prefab survives the undo round trip intact', () {
    // A component with no descriptor encodes to null and is silently dropped
    // when the entity is re-created — how checkpoints lost their behaviour.
    for (final prefab in PlatformerPrefabs.all) {
      final components = prefab.build(
        const Offset(100, 200),
        prefab.defaultSize,
      );
      for (final component in components) {
        final json = session.scope.codec.encode(component);
        expect(
          json,
          isNotNull,
          reason:
              '${prefab.id} places a ${component.runtimeType} that is '
              'dropped on undo',
        );
        expect(
          session.scope.codec.decode(json!).runtimeType,
          component.runtimeType,
          reason: prefab.id,
        );
      }
    }
  });

  test('a moving platform is drawn as an entity, undoably', () {
    session
      ..setTool(BuiltInTools.draw)
      ..controller.activePrefabId.value = 'platformer.platform_moving'
      ..onPointerDown(const Offset(0, 0), 32)
      ..onPointerMove(const Offset(256, 32), 32)
      ..onPointerUp(const Offset(256, 32), 32);

    List<jge.Entity> platforms() =>
        world.query([PlatformComponent]).where((e) => e.isActive).toList();

    expect(platforms(), hasLength(1));
    session.history.undo();
    expect(platforms(), isEmpty);
    session.history.redo();
    expect(platforms(), hasLength(1));
  });

  test('a solid platform is drawn under the level map, on its layer, '
      'undoably', () {
    session
      ..setTool(BuiltInTools.draw)
      ..controller.activePrefabId.value = 'platformer.platform_solid'
      ..onPointerDown(const Offset(0, 0), 32)
      ..onPointerMove(const Offset(256, 32), 32)
      ..onPointerUp(const Offset(256, 32), 32);

    List<jge.Entity> platforms() =>
        world.query([PlatformComponent]).where((e) => e.isActive).toList();
    final platform = platforms().single;
    final map = jge.LevelMaps.primaryEntity(world)!;
    expect(jge.LevelMaps.ownerOf(world, platform), same(map));
    expect(jge.LevelMaps.memberLayer(world, platform)!.name, 'Ground');
    session.history.undo();
    expect(platforms(), isEmpty);
    expect(jge.LevelMaps.primaryEntity(world), isNull);
  });

  test('a Tiled map\'s objects become the kit prefabs by their class, '
      'each an entity on the layer its object layer became', () async {
    const tmx = """<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" orientation="orthogonal" renderorder="right-down" width="8" height="8" tilewidth="16" tileheight="16" infinite="0" nextlayerid="3" nextobjectid="6">
 <objectgroup id="2" name="Objects">
  <object id="1" name="Start" type="PlayerSpawn" x="8" y="8"><point/></object>
  <object id="2" name="Coin" type="coin" x="32" y="32" width="16" height="16"/>
  <object id="3" name="Ledge" type="OneWay" x="0" y="64" width="96" height="16"/>
  <object id="4" name="Pit" type="spikes" x="96" y="64" width="32" height="16"/>
  <object id="5" name="Lift" type="MovingPlatform" x="0" y="100" width="64" height="16"/>
 </objectgroup>
</map>
""";
    final scope = session.scope;
    final plan = await TiledImporter(
      TiledFiles(root: '.', read: (_) async => tmx),
    ).read('level.tmx');
    final layer = plan.map.layers.single;
    expect(layer.name, 'Objects');

    final specs = TiledImporter.entities(
      plan,
      origin: Offset.zero,
      codec: scope.codec,
      uniqueName: (prefix) => prefix,
      mappers: scope.tiledObjectMappers,
      prefabs: scope.prefabs,
      mapName: jge.LevelMaps.primaryName,
    );
    List<jge.Component> of(String name) =>
        specs.firstWhere((s) => s.name == name).decode();
    for (final spec in specs.skip(1)) {
      expect(spec.parentName, jge.LevelMaps.primaryName, reason: spec.name);
      expect(
        spec.decode().whereType<jge.LayerComponent>().single.mapLayer,
        layer.id,
        reason: spec.name,
      );
    }

    final coin = of('Coin');
    expect(coin.whereType<CollectibleComponent>(), hasLength(1));
    final at = coin.whereType<jge.TransformComponent>().single.position;
    expect((at.x, at.y), (40.0, 40.0));
    expect(of('Lift').whereType<MovingPlatformComponent>(), hasLength(1));
    expect(of('Pit').whereType<HazardComponent>(), hasLength(1));
    // Drawn as a box in Tiled, a platform keeps its size.
    final ledge = of('Ledge').whereType<jge.Collider2D>().single;
    expect(ledge.oneWay, isTrue);
  });

  test('the module makes the kit tile kinds known to the editor', () {
    final world = jge.World()..initialize();
    addTearDown(world.dispose);
    EditorScope(
      builtIns: const [BuiltInEditorModule.new],
      world: world,
      modules: [PlatformerModule()],
    ).dispose();
    final kinds = world.context.collisionKinds;
    expect(kinds.byId('hazard'), isNotNull);
    expect(kinds.byId('crumbling')!.merge, jge.TileMergeMode.none);
    expect(
      jge.MapCollisionKinds.builtIn.byId('hazard'),
      isNull,
      reason: "only the edited engine's",
    );
  });
}
