# Just Platformer Kit

Platformer gameplay for `just_game_engine`, and the Level Designer module that lets you author it.

The kit is also the worked example of how to give the editor a genre. It uses only the public `EditorModule` contract, with no private access, so anything it does, your own game's module can do.

## Two libraries

| Import | Contains | Safe in a release build |
|---|---|---|
| `package:just_platformer_kit/just_platformer_kit.dart` | Components, systems, save/load schemas | Yes |
| `package:just_platformer_kit/editor.dart` | Prefabs, the path tool, overlays, the module — pick "Platformer" in the Level Designer's header switch | No: import it only from your editor entry point |

The runtime library never imports the editor, so a game built from `lib/main.dart` contains no editor code.

## Using it

```dart
// Game boot — both entry points.
final engine = Engine(
  config: const EngineConfig(
    extensions: [PlatformerKit.extension], // components, migrations, kinds
    defaultSystems: DefaultSystems.all,
  ),
);
await engine.initialize();
PlatformerKit.registerSystems(
  engine.world,
  physics: engine.physics,
  camera: engine.cameraSystem.mainCamera,
);
await SceneLoader.loadAsset(engine.world, SceneAssets.pathFor('level_01'));
```

```dart
// lib/main_editor.dart only.
final plugin = await JustGameEditorPlugin.register(
  engine: engine,
  modules: [PlatformerModule()],
);
```

A player is a `RigidBody2D` with a `Collider2D` and a `VelocityComponent` (the template's), or a `CharacterBody2D`: `PlayerControlSystem` gives both the same feel, and the level rules work on both. It also needs a `PlayerControlComponent`, an `InputComponent` (whose `move` and `jump` actions it reads) and the `player` tag (`PlatformerTags.player`), and a `HealthComponent` to be hurt. The kit steers a rigid body by its velocity, so give it `linearDamping: 0` (the engine's default of 0.05 slows it between steps: it skips running down a slope) and the kit's `friction: 0.2`, as the template's player has. A rigid-body player runs relative to the moving platform it stands on, so it rides one standing still.

What the game decides, the kit reports as events: `EntityDamagedEvent` (with `wasFatal`, and `respawn` for a hazard with `respawnOnHit`), `FellOutOfWorldEvent`, `CollectiblePickedUpEvent`, `LevelCompletedEvent`. The template's `GameSession` shows one way to answer them.

The kit's systems stand still while time does (a `deltaTime` of 0). An editor authoring a level runs the world that way, so they never move, capture or write anything in the level being edited.

## Tiles and the Level Map

A level's ground lives in its **Level Map** (the engine's `LevelMapComponent`, one per scene) as painted tiles. The kit adds three collision kinds, `PlatformerCollisionKinds`, registered by installing `PlatformerKit.extension`. They give a tile the same behaviour as the kit's prefabs:

| kind | behaves like | properties |
|---|---|---|
| `hazard` | the Hazard prefab: a sensor that hurts, again each time the player's invulnerability runs out while they stay in it | `damage`, `instantKill`, `respawnOnHit` (the hit's `EntityDamagedEvent.respawn`) |
| `bouncy` | the bouncy platform | `bounce` (launch speed) |
| `crumbling` | the crumbling platform: one body per tile, hidden while it is down (`LevelMapHandle.setBodyHidden`) | `crumbleDelay`, `respawnDelay` |

A tile gets its kind and properties in the editor's Tileset Editor.

Every kit prefab is an entity, built by its `build`. Drawn or painted in the Level Designer, it becomes a child of the Level Map on one of its layers, like everything else placed there: platforms, one-way, crumbling and bouncy platforms, hazards, moving platforms, collectibles, enemies, the player spawn, checkpoints, the goal and camera zones. Decoration has `depth: 'background'`, so it always goes on a Background layer of the map; its own `ParallaxRectComponent` scrolls it. A checkpoint's respawn point is saved in world space: move a checkpoint and the Problems dock says its respawn point stayed behind, with a fix that puts it back on the checkpoint.

`PlayerControlSystem` walks slopes: standing still on one stays put, running up keeps its speed, running down stays on the ground (`maxSlopeDegrees`, `slopeSnap`). Importing a Tiled map, each object group becomes a layer of the Level Map, and an object whose class names a kit prefab — by its id, its name or one of its `aliases` (`PlayerSpawn`, `Coin`, `Enemy`, `Spikes`, `OneWay`, `Spring`, `MovingPlatform`, …) — becomes that prefab, an entity on the layer its object group became. Other objects become plain entities there.

## Writing your own genre module

Say you're making a top-down game with doors that need keys. Mirror the kit's layout, putting the runtime half in your game's `lib/` and the design-time half in a file only `main_editor.dart` imports.

**1. Describe the component once, where it lives (runtime).** A `ComponentSchema` is what saves it, loads it in the shipped game, and — through its `hints` — what the inspector shows. It ships with the game; the hints are a few constants the editor reads and the game ignores.

```dart
final doorSchema = ComponentSchema<DoorComponent>(
  type: 'DoorComponent',
  id: 'door',                         // never change: saved levels use it
  create: DoorComponent.new,
  fields: [
    SchemaField(
      name: 'keyId',
      kind: FieldTypes.text,
      read: (c) => (c as DoorComponent).keyId,
      write: (c, v) => (c as DoorComponent).keyId = v as String,
    ),
  ],
  hints: const ComponentHints(
    name: 'Door',
    group: 'Dungeon',
    icon: Icons.door_front_door,
    fields: {'keyId': FieldHint(label: 'Key')},
  ),
);

// At boot, before loading a level:
ComponentDefinitionRegistry.instance.register(doorSchema);
```

Skip the registration and the level does not save the door: the editor leaves it out and says so in its log, because the shipped game could not have loaded it. There is no second, design-time description to keep in step.

**2. Write the module.** Every member has a default, so override only what you need.

```dart
class DungeonModule extends EditorModule {
  @override String get id => 'dungeon';
  @override String get name => 'Dungeon';

  @override
  List<String> get componentGroups => const ['Dungeon'];

  @override
  List<PrefabDefinition> get prefabs => [
    PrefabDefinition(
      id: 'dungeon.door',             // namespace your ids
      name: 'Door',
      category: 'Dungeon',
      icon: Icons.door_front_door,
      color: const Color(0xFF8D6E63),
      build: (position, size) => [
        TransformComponent(position: Vector3(position.dx, position.dy, 0)),
        RectangleComponent(width: size.width, height: size.height),
        // A static body the size of the rectangle, resized with it.
        Collider2D(shape: ColliderShape2D.matchShape),
        LayerComponent(),
        DoorComponent(),
      ],
    ),
  ];
}
```

Then pass it in `main_editor.dart`: `modules: [DungeonModule()]`. Every registry is rebuilt from the modules on hot reload, so an edited module takes effect without restarting. A module added to the list joins on the next hot reload too, when the app hands its list over again in `onReassemble` (`plugin.syncModules`; the template does, in `lib/editor/editor_wiring.dart`). The kit's components are refreshed the same way (`PlatformerKit.extension` is a `RefreshableExtension`), so a field added to one shows in the inspector after a hot reload.

**3. Go further when you need to.**

- `createTools(DesignerToolContext)`: viewport tools. Each is built per designer session and receives that session's selection and undo history. The kit's moving-platform path tool is the editor's generic `PathTool` with a `PathBinding`, which works for any component holding a list of points. `toolGroups` adds a captioned group to the tool strip for them.
- A prefab's `depth`: the depth it is always placed at, whatever depth is active in the designer (the kit's Decoration uses `'background'`). What Draw and Paint make goes under the Level Map, on the map's layer at that depth.
- A prefab's `aliases`: what Tiled maps commonly call it, so an imported object whose class is one of them becomes this prefab.
- `commands` and `keyBindings`: a `DesignerCommand` with a `KeyBinding`; bind a built-in's chord to take it over.
- `createSnapProviders`: a `SnapProvider` that snaps to your own things (tile seams, say), placed by priority against entities and the grid.
- `createSessionState` and `context.stateOf<T>()`: state a tool keeps for one designer session, kept across hot reloads.
- `saveEditorData` / `restoreEditorData`: what you keep in the scene file's `editor` section, under your module's id.
- `statusControls` and `designerPanels`: your own status-bar controls and side-panel sections.
- `docks`, `toolbarButtons`, `sceneTreeActions`, `rowDecorations`, `protectionRule`, `inspectorSections`: what you add to the base editor's chrome, beside the built-ins.
- `settingsSections` and `SettingPref`: your own settings, on the dialog's Modules tab, stored with the editor's.
- `themePresets`: palettes offered in the settings; read colours in your own widgets with `EditorTheme.of(context)`.
- `gridTopology`: the shape of the cells. `HexGridModule` is the editor's own example; add it to `modules:` for a hex game.
- `overlays`: things drawn over the level (patrol routes, trigger radii, spawn zones), each with its own visibility toggle.
- An `extent` on a component's definition, for one that implies a size in its own way (the engine's camera trigger is an example). It makes the entity selectable, alignable and resizable with the handles.
- `layers`: named draw-order layers your genre expects.

## Rules worth keeping

- **Never change a schema's `id`, `type` or field names** once levels use them. Add fields freely: a missing field loads as the constructor default.
- **Namespace ids** (`dungeon.door`, not `door`). A reused id replaces the earlier registration, which is how you override a built-in on purpose.
- **Keep the runtime half free of editor imports.** The kit's two-library split is what keeps the editor out of release builds.
- **Test the round trip.** See `test/component_round_trip_test.dart` (every field survives save and load) and `test/platformer_module_test.dart` (everything the module contributes is reachable from outside the editor package).

## License

BSD-3-Clause. See [LICENSE](LICENSE).
