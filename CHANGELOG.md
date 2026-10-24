# Changelog

## 0.1.0

Initial release. The platformer that briefly lived inside `just_game_engine` and `just_game_engine_editor`, as its own package, so the engine and editor carry no genre.

- **Runtime** (`just_platformer_kit.dart`): platforms (solid, one-way, crumbling, bouncy), moving platforms, hazards, collectibles, goals, patrol enemies, level bounds, camera zones, rectangle parallax, and a player controller with coyote time, jump buffering and variable jump height. `PlatformerKit.registerSystems` and `PlatformerKit.registerCodecs`.
- **Design time** (`editor.dart`): `PlatformerModule`, with the kit's prefabs, a moving-platform path tool, and overlays for level bounds and platform paths.

- The level bounds and platform paths are gizmos: drawn as the editor's Gizmos button and menu say in each mode, for what is off the Level Map too.
- **Builds on `just_editor_core`**, the editor's module contract, instead of depending on `just_game_engine_editor`: the module's code needs nothing else of the editor. The tests that drive a real editor take `just_game_engine_editor` as a dev dependency.

- **The engine's one physics model.** The kit's systems read a body's `RigidBody2D` (ground contact, collision filter) and its `Collider2D` (`oneWay`), and listen for `CollisionEnter2DEvent` and `SensorEnter2DEvent`. Its prefabs are a static `RigidBody2D` with a `Collider2D` that matches the drawn rectangle, so resizing a platform resizes what it collides as. They keep the friction the kit's movement is tuned on (0.2), as pieces placed before do. A patrolling enemy turns at ledges by its collider as simulated.

- **A player can be a `CharacterBody2D`.** `PlayerControlSystem` drives one when the player has it — run speed into `moveVelocity`, jumps (coyote time and air jumps included), the rise, jump-cut and fall gravity, the fall-speed cap — and a rigid body as before otherwise. The character mover takes slopes, steps and moving platforms itself. Bounce pads, crumbling platforms and solid hazards notice a character landing on them by its ground, stomps and knockback work on both, and `PlayerControlSystem.launch` sends a character up from the ground or the air alike.

- **Hot reload reaches the kit.** `PlatformerKit.extension` is a `RefreshableExtension`: after a hot reload the editor puts the kit's component definitions, animator bindings and collision kinds in place again from the code as it now is, so a field added to a component shows in the inspector without a restart. The migrations, which append, are left as installed. `PlatformerSchemas` and the editor's `PlatformerPrefabs` are getters now rather than `static final`s, which a reload never rebuilds.

- **Collision layers.** A crumbling platform stops colliding by setting its body's `collidesWith` to 0, and gives back what it had when it returns (`PlatformComponent.collidesBeforeCollapse`), where it used to set every bit of a mask back. The prefabs make static bodies with `bodyType: BodyType.static`.

- **Tags the kit relies on, declared.** `PlatformerTags.player` (the engine's `EngineTags.player`) and `PlatformerTags.enemy`, with `PlatformerTags.declared` for an editor's tag list. `PlatformerModule.tags` offers them, so the editor lists them as built in. The systems default to them and find players through the world's tag index (`world.allTagged`, `entity.hasTag`) instead of comparing strings.
- **Camera zones take targets.** `PlatformerCamera.zone(follow:, target:)` take an `EntityTarget`, defaulting to the player tag. `followName` and `targetName` still work, and are deprecated.

- **Tips on the editor's start card** (`gettingStartedTips`): where the Player spawn goes, what the palette holds, and K for a moving platform's path.

- **Ready for the 3-D engine** (just_game_engine 2.0). Every platformer component is marked 2-D-only (`Dimensions.twoD`), so an editor does not offer them in a 3-D scene; the kit's prefabs, path tool and overlays are 2-D by default. No scene rules were needed for format 6.

- **Several players.** `PlayerControlSystem` reads the new `InputComponent` (`vector(moveAction)`, `isDown(jumpAction)` — `moveAction` is finally used). Chasers go after the nearest player, not the first one spawned. `PlatformerCamera.zone` takes `followName`/`targetName`, so a zone can follow the players' camera group.

- **The Path tool's key is K.** W, E and R are the editor's Move, Scale and Rotate. The level-bounds and platform-path overlays skip what the viewport hides (`OverlayPaintContext.isShown`).
- **Placed on the Level Map.** Every kit prefab is an entity, built by its `build`. Drawn or painted in the Level Designer, platforms, one-way, crumbling and bouncy platforms, hazards, decorations and the rest become children of the scene's Level Map, each on one of the map's layers. Decoration has `depth: 'background'`, so it always goes on a Background layer.

- **Tile kinds**: `PlatformerCollisionKinds` (was `PlatformerTileKinds`, now in `src/map/`) — `hazard`, `bouncy`, `crumbling` — registered by `registerCodecs`, so painted spikes, springs and crumbling ground behave as the prefabs do, tuned by each tile's properties (`damage`, `instantKill`, `respawnOnHit`, `bounce`, `crumbleDelay`, `respawnDelay`). A crumbling tile hides while it is down (`LevelMapHandle.setBodyHidden`, which hides the body's cells).

- **Slopes**: `PlayerControlSystem` follows the ground's normal — no sliding when standing still, full speed along the slope, no launching off it going down or over its top. `maxSlopeDegrees` and `slopeSnap` tune it.

- **Tiled objects**: the kit's prefabs carry the names Tiled maps commonly give them (`PrefabDefinition.aliases`: `Spikes`, `OneWay`, `Spring`, `Coin`, `PlayerSpawn`, `MovingPlatform`, …), so an imported object becomes the prefab its class names: an entity on the Level Map layer its object group became.

- Scene-tree icons for the things a platformer is made of — player, coin, hazard, goal, patrolling enemy, moving platform, platform, level bounds, parallax — through `EditorModule.entityIcons`. The editor draws a generic box for anything no module claims; what a coin looks like is the kit's business, not the editor's.

- Animator bindings for a platformer character: `grounded`, `rising`, `falling`, `justLanded`, `invulnerable` (`PlatformerKit.registerAnimatorBindings`, called by `registerCodecs`).

- Level bounds shows `Origin X/Y` and `Size W/H`, and Parallax `Factor X/Y`, each on one inspector row (`ComponentHints.fieldRows`).

- **Camera zones are the engine's virtual cameras now.** `CameraZoneComponent`, `CameraZoneSystem`, `CameraZoneOverlay` and the zone's extent are gone; a zone is what `PlatformerCamera.zone(...)` builds — a virtual camera that a `CameraTriggerComponent` enables while the player is inside, with its own framing (`lockX` / `lockY` became `followX` / `followY: false`). The change of zoom is a real blend, overlapping zones are settled by priority, and the editor draws them with its camera overlay. `PlatformerMigrations` (registered by `PlatformerKit.registerCodecs`) brings old levels forward.
- `LevelBoundsComponent` is a `CameraBoundsSource`: name its entity in a camera's Confiner to keep the view inside the level.
- The game registers the camera with `registerCameraSystems(...)`; the player no longer carries `CameraFollowComponent` — the level's `MainCamera` follows the `player` tag.
- **`PlatformerModule`** replaces `PlatformerEditorExtension`, for the editor's `EditorModule` contract: `modules: [PlatformerModule()]` instead of `registerExtension(...)`.
- The platformer designer is chosen in the Level Designer's header switch (the editor opens as its built-in designer); the choice is saved with the level.
- Camera zones are sized by a `ComponentExtent` on the `CameraZoneComponent` schema, so the editor measures and resizes them with no design-time code.
- `PlatformerKit.registerCodecs()` is still what a game calls at boot; the module only contributes the design-time half.
- Levels save in scene format v1; the v0 fixture is kept as the migration sample.
- The inspector descriptors are gone: every `PlatformerSchemas` schema carries its `ComponentHints` (labels, scrub feel, conditional fields such as a crumbling platform's delays). Enum fields use `EnumFieldType` (`platformer.platformKind`, `platformer.platformLoopMode`, `platformer.enemyBehaviour`).
