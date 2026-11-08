# Changelog

## 0.2.0-beta.1

Requires just_game_engine ^2.0.0 and just_editor_core ^0.1.0. The Asset Store manifest asks for just_game_engine ^2.0.0 and just_game_engine_editor ^0.1.0.

### Breaking

- **Layout.** `lib/src/` is by feature, one barrel each: `level/` (tags, bounds, parallax, camera zones), `platforms/`, `player/`, `enemies/`, `rules/` (pickups, hazards, goals, the gameplay system, its events, the tile kinds), `kit/` (`PlatformerKit`, `PlatformerDefinitions`, `PlatformerMigrations`) and `editor/`. Only `just_platformer_kit.dart` and `editor.dart` are API; the old `src/components/platformer.dart` and `src/systems/platformer.dart` barrels are gone.
- **Slope settings are on the player.** `PlayerControlSystem({maxSlopeDegrees, slopeSnap})` → `PlayerControlComponent.maxSlopeDegrees` (saved, default 50) and the new `PlayerControlComponent.snapDistance` (saved, default 4), so each player is tuned in the inspector. `slopeSnap` is gone: a player on a slope is brought down onto it by the distance its ground probe measures, not pressed into it at a fixed speed. A level saved before has neither field and loads with the defaults.
- `MovingPlatformComponent` → `MovingPlatform2DComponent` (file `moving_platform_2d_component.dart`): the third-person kit has a 3-D one. Levels saved before are renamed as they load (`PlatformerMigrations.renamedTypes`), at any scene format.
- `MovingPlatformSystem` → `MovingPlatform2DSystem`, the twin of the third-person kit's `MovingPlatform3DSystem`.
- `PlatformerSchemas` → `PlatformerDefinitions`, and its components' definitions are `ComponentDefinition`s, now that the engine has folded `ComponentSchema` into it.
- `PlatformerMigrations` has its own file, `kit/platformer_migrations.dart` (it was in the camera's); its API is the same.
- A `PlatformLoopMode.once` platform that finished its path, started again (`isMoving = true`), goes back the way it came; it used to stop again at once.
- `PlatformComponent.collidesBeforeCollapse` is gone: a crumbled platform's body collides with nothing through the engine's run-time `RigidBody2DComponent.collidesWithNothing`, and its saved `collidesWith` is never changed, so there is nothing to give back.

### Added

- **A ground probe for a rigid-body player.** When the world has a `Physics2DSystem`, `PlayerControlSystem` casts two short rays down the player's sides each step and takes its ground from them: the ramp's own face (never the flat top of the solid box buried at a seam between two ramp tiles), and how far below the feet it is. A player that stood is followed down ground that drops away by up to `snapDistance` plus what running at its speed down its steepest slope drops it; a jump, a spring or a knock-back moving it away from the ground is in the air at once. Sensors, bodies it does not collide with (a crumbled platform), one-way platforms not solid from above and one it is partway through are passed over.
- `PlayerControlComponent.maxSlopeDegrees` and `.snapDistance`, in the inspector's new "Slopes" group.
- `PlatformerChecks.oneWayPlatforms`: the Problems dock flags a one-way platform whose collider is solid (a level saved before the one-way prefab built a one-way body), with a one-click fix (`PlatformerChecks.makeOneWay`, one undo step).
- Tests mirror `lib/src/`; `test/library_layout_test.dart` guards the layout, the layer order and the release split; `test/store_manifest_test.dart` checks `just_store.json` against the pubspec and the definitions.

### Changed

- Installing the kit installs the engine's built-in components (`BuiltInComponents.extension`) too: its levels use them.
- `LevelBoundsComponent.killPlaneY` is 400 below the bounds until it is set, wherever the bounds are; a level that saves its bounds but no kill plane gets one under its own bounds (it kept 1600, under the default bounds).
- Patrol enemies probe walls and ledges with one ray test each (`raycast`, looking through a sensor in the way and asking again) instead of every hit along the ray, collected and sorted; and no ledge probe while airborne.
- Patrols size their probes with just_physics_engine 2.0.0's `Shape2D.boundsAt` (was `getBounds`), through the engine.
- "Respawn at the checkpoint" names the fields it writes (`ComponentFieldCommand(field:)`, just_editor_core ^0.1.0).
- pubspec: `sdk: ^3.12.2` (as the other kits), `homepage: https://engine.justunknown.com/`, a description that says what the kit has.
- `dart format` clean.

### Fixed

- **A character player standing on a solid hazard was hurt for ever, anywhere.** A `CharacterBody2DComponent` touches static bodies through its mover, with no contact to end, so the hazard never let go: it kept hurting the player each time its invulnerability ran out, wherever it went. The rule now follows the character's ground: off the hazard, it is hurt no more. (A character touching a solid hazard from the side is not hurt by it: its mover reports only its ground. A sensor hazard hurts it from any side.)
- **The template's player lost the ground on tiled ramps, and caught on them.** A 32 × 48 rigid box running down a 45° ramp was airborne for up to 26 frames of 40 (no coyote time or jump buffer, the `grounded` and `falling` bindings flickering), and climbing caught at the seams between ramp tiles and stopped for good. The ground probe holds it to the ramp on both physics backends. Give the player's box rounded corners (`cornerRadius: 4`, as the template now does): on native Box2D a sharp corner can still stall for a few frames at a ramp's foot, on the way up.
- **Play wrote saved physics fields.** `PlayerControlSystem` wrote the jump's gravities (rise, jump-cut, fall, and 0 on a slope) into the player's saved `gravityScale` every step, rigid body or character, and `PlatformerGameplaySystem` a crumbling platform's collisions into its saved `collidesWith`: a level saved mid-jump or mid-collapse kept them. They go through the engine's run-time `gravityScaleOverride` and `collidesWithNothing` now (just_game_engine 2.0.0), never saved; the saved fields stay as authored, and the player jumps and the platform crumbles exactly as before.
- **A sharp-cornered player stood with its corner on a ramp's crest could not run down the ramp** (native Box2D, the corner 0–1 px past the crest): the slope snap closed the gap to the ramp along its normal, which leans back up the ramp, and pushed the player back onto the crest, step after step. Running down a slope, the gap is now closed straight down; every start from 16 px before the crest to 16 px past it runs down without a stalled frame, on both backends.
- **The game no longer writes a saved field to mend old one-way platforms.** `PlatformerGameplaySystem` set `Collider2DComponent.oneWay` on every one-way platform, every step; such a level is now fixed where it is authored, through the Problems dock (above).
- A player with no `HealthComponent` falling past the kill plane fires `FellOutOfWorldEvent` (once, until it is back above it); only entities with health were seen.
- A finished `once` platform could not be started again (above).
- The CHANGELOG said 0.1.0-beta.1's slope settings were the player's; they were `PlayerControlSystem`'s, and are the player's now.

### Removed

- `PlayerControlSystem`'s `maxSlopeDegrees` and `slopeSnap` (see Breaking).
- `test/library_boundary_test.dart`: the guard test checks the release split.

## 0.1.0-beta.1

First release: platformer gameplay for `just_game_engine` 2.0, and the Level Designer module that authors it.

### Runtime — `package:just_platformer_kit/just_platformer_kit.dart`

Safe in a release build on every platform: it imports nothing of the editor.

- **Set-up.** `PlatformerKit.extension` (give it to `EngineConfig(extensions: [...])`) teaches an engine the kit's components, its migrations, its animator bindings and its collision kinds; it is a `RefreshableExtension`, so a hot reload in the editor puts them in place again from the code as it now is. `PlatformerKit.registerSystems(world, physics:, camera:)` adds the systems; `PlatformerKit.systems(...)` returns them, for a game that picks or replaces some.
- **Player.** `PlayerControlComponent` and `PlayerControlSystem`: run speed with ground and air acceleration, coyote time, jump buffering, variable jump height, rise/fall/jump-cut gravity, a fall-speed cap, air jumps (`maxJumps`), slopes (`PlayerControlSystem`'s `maxSlopeDegrees` and `slopeSnap`). A player is a `RigidBody2D` with a `Collider2D` and a `VelocityComponent`, or a `CharacterBody2D`, with an `InputComponent` (`moveAction`, `jumpAction`) and the `player` tag; both feel the same. A rigid-body player runs relative to the moving platform it stands on and is carried by it.
- **Platforms.** `PlatformComponent`: solid, one-way (`Collider2D.oneWay`), crumbling (`crumbleDelay`, `respawnDelay`) and bouncy (`bounceImpulse`). `MovingPlatformComponent` and `MovingPlatformSystem`: a kinematic body with a `VelocityComponent` along waypoints, ping-pong, loop or once, with a pause at each waypoint; `autoStart: false` waits until game code sets `isMoving`.
- **Hazards and pickups.** `HazardComponent` (damage or instant kill, knockback, invulnerability; it keeps hurting a player who stays in it each time the invulnerability runs out; `respawnOnHit` asks the game to send the player back, through `EntityDamagedEvent.respawn`). `CollectibleComponent` (kind, value, counted once). `GoalComponent` (next scene, optionally gated on every collectible).
- **Enemies.** `PatrolEnemyComponent` and `PatrolEnemySystem`: patrol, chase the nearest player, or stand still; turn at walls and (with `turnAtLedge`) at ledges; stompable from above; a touch from the side hurts the player and gives them `invulnerabilitySeconds` to get clear, knocked away from the enemy.
- **Level.** `LevelBoundsComponent`: the playable area (a `CameraBoundsSource` for a camera's confiner), the kill plane (a fallen player is left to the game, anything else is removed) and the level's gravity (`gravityY`, applied when the level starts). `ParallaxRectComponent` and `ParallaxRectSystem`: rectangle parallax, per rendered frame. `PlatformerCamera.zone(...)`: a camera zone built from the engine's virtual camera and trigger.
- **Rules and events.** `PlatformerGameplaySystem` turns sensor and collision events into the rules above and fires `CollectiblePickedUpEvent`, `LevelCompletedEvent`, `EntityDamagedEvent`, `FellOutOfWorldEvent`, `EnemyDefeatedEvent` and `PlatformCrumbledEvent`.
- **Tiles.** `PlatformerCollisionKinds` — `hazard`, `bouncy`, `crumbling` — give painted Level Map tiles the same behaviour as the prefabs, tuned by each tile's properties.
- **Animator bindings.** `grounded`, `rising`, `falling`, `justLanded`, `invulnerable`.
- **Tags.** `PlatformerTags.player` (the engine's) and `PlatformerTags.enemy`.
- The kit's systems stand still while time does (a `deltaTime` of 0): an editor authoring a level runs them that way, and they leave the level as it is.
- Every component is 2-D only (`Dimensions.twoD`), and its schema carries its inspector hints.

### Design time — `package:just_platformer_kit/editor.dart`

- `PlatformerModule`, through the editor's public `EditorModule` contract: "Platformer" in the Level Designer's switch, with the kit's prefabs (platforms of every kind, moving platform, hazard, coin, patrol enemy, player spawn, checkpoint, goal, camera zone, decoration) placed on the Level Map's layers, their Tiled names (`aliases`), the moving-platform path tool (K), overlays for the level bounds and the platform paths, scene-tree icons, the kit's tags, start-card tips, and a Problems-dock check for a checkpoint moved away from its respawn point (`PlatformerChecks`), with a one-click fix.
