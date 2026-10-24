# Changelog

## 0.1.0-beta.1

First release: platformer gameplay for `just_game_engine` 2.0, and the Level Designer module that authors it.

### Runtime — `package:just_platformer_kit/just_platformer_kit.dart`

Safe in a release build on every platform: it imports nothing of the editor.

- **Set-up.** `PlatformerKit.extension` (give it to `EngineConfig(extensions: [...])`) teaches an engine the kit's components, its migrations, its animator bindings and its collision kinds; it is a `RefreshableExtension`, so a hot reload in the editor puts them in place again from the code as it now is. `PlatformerKit.registerSystems(world, physics:, camera:)` adds the systems; `PlatformerKit.systems(...)` returns them, for a game that picks or replaces some.
- **Player.** `PlayerControlComponent` and `PlayerControlSystem`: run speed with ground and air acceleration, coyote time, jump buffering, variable jump height, rise/fall/jump-cut gravity, a fall-speed cap, air jumps (`maxJumps`), slopes (`maxSlopeDegrees`, `slopeSnap`). A player is a `RigidBody2D` with a `Collider2D` and a `VelocityComponent`, or a `CharacterBody2D`, with an `InputComponent` (`moveAction`, `jumpAction`) and the `player` tag; both feel the same. A rigid-body player runs relative to the moving platform it stands on and is carried by it.
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
