# Contributing to Just Platformer Kit

Thank you for your interest in contributing to **Just Platformer Kit**. Bug fixes, features, tests and documentation are all welcome.

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Reporting Bugs and Suggesting Features](#reporting-bugs-and-suggesting-features)
- [Development Setup](#development-setup)
- [Working Against Unpublished Dependencies](#working-against-unpublished-dependencies)
- [How the Package Fits Together](#how-the-package-fits-together)
- [Running the Tests](#running-the-tests)
- [Coding Guidelines](#coding-guidelines)
- [Submitting a Pull Request](#submitting-a-pull-request)
- [Commit Message Convention](#commit-message-convention)
- [License](#license)

---

## Code of Conduct

This project follows our [Code of Conduct](CODE_OF_CONDUCT.md). By taking part you agree to its terms. Please report unacceptable behaviour to the maintainers.

---

## Reporting Bugs and Suggesting Features

Before opening an issue, search the [existing issues](https://github.com/just-unknown-dev/just-platformer-kit/issues) and check that the problem happens on the latest version.

A bug report should have:

- a clear title;
- steps to reproduce, and what you expected instead of what happened;
- the output of `flutter --version`, and the platform (Android, iOS, Linux, macOS, Windows, web);
- the level's `.scene.json`, or the smallest part of it that shows the problem: the entities involved, with their components and field values;
- for a movement bug, whether the player is a `RigidBody2D` or a `CharacterBody2D`, its `PlayerControlComponent` settings, and whether the game runs on the native Box2D physics or on `PhysicsEngine.pureDart()`;
- for a painted tile that misbehaves, its collision kind (`hazard`, `bouncy` or `crumbling`) and the tile's properties from the tileset;
- for a Level Designer bug, the prefab or tool involved (the moving-platform Path tool is K) and what you did in the editor.

Bugs often belong somewhere else:

- A collision or character bug you can show without any kit component belongs in [just_physics_engine](https://github.com/just-unknown-dev/just-physics-engine/issues) (bodies, the character mover) or in [just_game_engine](https://github.com/just-unknown-dev/just-game-engine/issues) (components, scene loading, the Level Map, cameras).
- A Level Designer bug you can show without `PlatformerModule` belongs in `just_game_engine_editor`. So does importing a Tiled map; the editor reads the file with [just_tiled](https://github.com/just-unknown-dev/just-tiled/issues). Which kit prefab an imported object becomes is decided here, by the prefabs' `aliases`.

For a feature, open an issue labelled **`enhancement`** that describes the problem it solves and how it should behave. The package's scope is a platformer's gameplay: its components and systems, its tile kinds, camera zones, the migrations for levels an older kit saved, and the Level Designer module that authors them. The engine and the editor carry no genre: platformer rules belong here, generic ones there. A change to how a component is saved affects every level a game has saved, so open the issue first and agree the approach before you write it.

---

## Development Setup

| Tool | Minimum version |
|------|-----------------|
| Dart | 3.11.0 |
| Flutter | 3.44.0. The package's own pubspec accepts Flutter 1.17.0, but `just_game_engine` 2.0.0 needs 3.44.0 |
| C/C++ toolchain | For the native Box2D library that `just_physics_engine`'s build hook compiles when the tests run. Windows: Visual Studio with the "Desktop development with C++" workload. Linux: clang or gcc. macOS: Xcode |

There is no app to run here: you work on the package and its tests. To try a change in a real game, take a game made from the platformer template (`just_platformer_template`) and override `just_platformer_kit` in its `pubspec_overrides.yaml` with `path: ../just_platformer_kit`. The game's `lib/main_editor.dart` opens the editor, where `PlatformerModule` adds the Level Designer side.

The kit is not published to pub.dev (`publish_to: none`). Games get it as an Asset Store item, described by `just_store.json`.

```bash
git clone https://github.com/just-unknown-dev/just-platformer-kit.git just_platformer_kit
cd just_platformer_kit
flutter pub get
flutter test
```

If you're working from the Just engine monorepo, run every command from `packages/just_platformer_kit`.

---

## Working Against Unpublished Dependencies

The package depends on four just_* packages: `just_game_engine`, `just_physics_engine`, `just_game_engine_editor` and `just_game_engine_formats`. When a change needs an unreleased version of one of them, check it out next to this repository and point this package at it with a `pubspec_overrides.yaml` in the repository root:

```yaml
# pubspec_overrides.yaml: local only, never commit it.
dependency_overrides:
  just_game_engine:
    path: ../just_game_engine
  just_physics_engine:
    path: ../just_physics_engine
  just_game_engine_editor:
    path: ../just_game_engine_editor
  just_game_engine_formats:
    path: ../just_game_engine_formats
```

List only the ones you need. If an overridden package needs an unreleased version of a package it depends on in turn (`just_inputs`, `just_tiled`, `just_jolt`, …), add that one too. In the monorepo the file overrides all thirteen just_* packages the kit reaches.

Then run `flutter pub get`. Delete the file (or the entry) and run `flutter pub get` again to go back to the published versions.

Do not change `pubspec.yaml` to a path dependency. If your pull request needs a version of a just_* package that is not published yet, say so in the pull request: this package can only be released after it.

The platformer template depends on this package. Its game boot adds `PlatformerKit.systems`, and the lists the Asset Store generates for it register `PlatformerKit.extension` and `PlatformerModule`. If you change the public API, a saved field or `just_store.json`, say in the pull request what the template will need.

---

## How the Package Fits Together

| Path | Contents |
|------|----------|
| `lib/just_platformer_kit.dart` | The runtime library, safe in a release build |
| `lib/src/components/` | `PlatformComponent`, `MovingPlatformComponent`, `HazardComponent`, `CollectibleComponent`, `GoalComponent`, `PatrolEnemyComponent`, `PlayerControlComponent`, `LevelBoundsComponent`, `ParallaxRectComponent` |
| `lib/src/systems/` | `PlayerControlSystem`, `PlatformerGameplaySystem`, `MovingPlatformSystem`, `PatrolEnemySystem`, `ParallaxRectSystem`; the events in `platformer_events.dart` |
| `lib/src/codecs/` | `PlatformerSchemas`: how each component is saved, loaded and shown in the inspector |
| `lib/src/camera/` | `PlatformerCamera.zone`, a camera zone built from the engine's virtual camera components; `PlatformerMigrations` |
| `lib/src/map/` | `PlatformerCollisionKinds`: the `hazard`, `bouncy` and `crumbling` tile kinds |
| `lib/src/platformer_kit.dart` | `PlatformerKit`: the extension, the animator bindings and the systems |
| `lib/src/platformer_tags.dart` | `PlatformerTags`: the tags the kit's code looks for |
| `lib/editor.dart`, `lib/src/editor/` | Design time only: `PlatformerModule`, `PlatformerPrefabs`, `LevelBoundsOverlay`, `PlatformPathOverlay` |
| `just_store.json` | The Asset Store manifest: the extension and module a game registers, the component types the kit adds, the setup code shown after installing it, and the editor-only libraries. The `just` CLI's release check reads that last list |
| `test/fixtures/` | `level_01.scene.json`, a level saved in the oldest scene format, and the two goldens made from it |

A few rules hold the package together. Keep them:

- **The runtime never imports the editor.** Nothing that `lib/just_platformer_kit.dart` reaches imports `just_game_engine_editor` or a file under `lib/src/editor/`. That is what keeps the editor out of release builds. `just_store.json` lists `editor.dart` and `src/editor/` as editor-only; keep it in step.
- **The module uses the public contract only.** `PlatformerModule` is the worked example of an `EditorModule`, so the editor half imports `package:just_game_engine_editor/just_game_engine_editor.dart` and never a file under its `src/`.
- **Every saved component has a `ComponentSchema`** in `PlatformerSchemas.all`, in the runtime library, and its type is listed under `runtime.componentTypes` in `just_store.json`. Without one, the loader stops with an error naming the component, and the editor leaves the component out of the level. The schema's `hints` are the inspector's only description of a component, so the inspector cannot show a field that is not saved.
- **Saved levels must keep loading.** Never change a schema's `type` or `id`, or a field's name. Never rename an enum value either: `EnumFieldType` saves the value's name, and an unknown name loads as the fallback. A new field needs nothing more, because a level saved without it loads the constructor's default. To replace or remove a component, add a rule to `PlatformerMigrations`, as `cameraZone` does for the old `CameraZoneComponent`.
- **Schemas and prefabs are getters.** A hot reload never rebuilds a `static final`. `PlatformerKit.extension` is a `RefreshableExtension`, and its `refresh` puts the schemas back as the code now makes them. Write new ones as getters too.
- **Steer bodies, don't move them.** `PlayerControlSystem` writes a rigid body's velocity and gravity scale and lets the physics step integrate them. A write to the transform counts as a teleport and breaks collision resolution.
- **A player is a `RigidBody2D` or a `CharacterBody2D`.** `PlayerControlSystem` and `PlatformerGameplaySystem` support both, so a change to the feel or to a level rule must work, and be tested, on both.
- **The systems are a set.** They order themselves by `System.priority` (`SystemPriorities`) and depend on each other: `PlatformerGameplaySystem` reads the ground state `PlayerControlSystem` writes. `PlayerControlSystem` runs after input and before physics, so a press reaches the same frame's step. The systems find players by tag (`PlatformerTags.player`, through `world.allTagged` and `entity.hasTag`), never by name.
- **Time comes from `deltaTime`.** Timers count down the `deltaTime` a system is given. Nothing under `lib/` reads the wall clock or a random generator.
- **Every component is 2-D only** (`Dimensions.twoD` in its hints), so an editor does not offer it in a 3-D scene.

---

## Running the Tests

Run every command from the repository root. The tests read `test/fixtures/` by a relative path and expect that working directory.

```bash
# The whole suite.
flutter test

# One file.
flutter test test/platformer_systems_test.dart
```

**Saved levels.** Three tests use `test/fixtures/level_01.scene.json`. `test/runtime_scene_load_test.dart` loads it with the runtime library alone: it imports nothing from `just_game_engine_editor`, and must stay that way. `test/scene_format_golden_test.dart` compares what migration makes of it with `level_01.migrated.scene.json`. `test/level_values_golden_test.dart` compares the component values it loads to with `level_01.expected.json`. When your change is meant to alter a golden, delete that file and run its test: it writes a new one and fails. Review the diff, then run the test again.

**Round trips.** `test/component_round_trip_test.dart` sets every component to values that differ from its defaults and sends it through the editor's encode and decode. A field you add goes in there.

**The module.** `test/platformer_module_test.dart` opens a real `LevelDesignerSession` with `PlatformerModule` and checks that everything the module adds is reachable. `test/kit_refresh_test.dart` checks what the extension does after a hot reload.

**Physics.** `test/character_player_test.dart` runs each case on the native Box2D physics and on `PhysicsEngine.pureDart()`. The tile tests (`test/collision_kinds_test.dart`, `test/slope_test.dart`) build a tileset in code and run on the pure-Dart physics.

**Writing tests.** There is no shared helper library. Build a bare `World` with only the systems under test, as `test/platformer_systems_test.dart` does, and step it with `world.update(1 / 60)`. Drive a player through its `InputComponent` (`setVector('move', …)`, `setDown('jump', true)`). Give a context the kit the way a game does, with `EngineContext(extensions: [PlatformerKit.extension])`.

---

## Coding Guidelines

- **Formatting.** Format the files you change with `dart format <files>`. Not every file in the package is formatted yet, so do not reformat files your change does not touch.
- **Analysis.** `flutter analyze` must report no issues at all: no errors, warnings or infos. The rules are in `analysis_options.yaml`: `flutter_lints`, with `build/` excluded.
- **Web.** Nothing under `lib/` imports `dart:io` or `dart:html`. Keep it that way: the platformer template also builds for the web.
- **Documentation.** Give every public API you add a `///` doc comment. Describe user-visible changes in [CHANGELOG.md](CHANGELOG.md), and update [README.md](README.md) if the public API changes.
- **Tests.** Add or update tests for any behaviour you change. A bug fix comes with a test that fails without it.
- **Dependencies.** Do not add a dependency without discussing it in an issue first.
- **Structure.** Match the existing folders under `lib/src/`. A new component is exported from `lib/src/components/platformer.dart`, a new system from `lib/src/systems/platformer.dart`. Runtime API reaches users through `lib/just_platformer_kit.dart`, design-time API through `lib/editor.dart`. Prefab ids start with `platformer.`.

---

## Submitting a Pull Request

1. Create a topic branch from `main`:
   ```bash
   git checkout -b fix/crumbling-platform-respawn
   ```
2. Make your change, following the [Coding Guidelines](#coding-guidelines).
3. Check that everything passes:
   ```bash
   dart format <the files you changed>
   flutter analyze
   flutter test
   ```
4. Commit with a [conventional commit message](#commit-message-convention).
5. Push to your fork and open a pull request against `main`. Say what changed and why. List any unpublished just_* version it needs, and say whether it changes how a component is saved or what the platformer template must do.
6. Answer review feedback.

Small pull requests are easier to review.

---

## Commit Message Convention

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <short summary>
```

| Type | When to use |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `perf` | Performance improvement |
| `test` | Adding or updating tests |
| `chore` | Build process, tooling, dependencies |

Use the area as the scope: `components`, `systems`, `codecs`, `camera`, `map`, `kit` or `editor`. Mark a change that breaks the public API or how levels are saved with `!` and a `BREAKING CHANGE:` footer.

**Examples:**
```
fix(systems): keep coyote time when a crumbling platform gives way
feat(map): read a knockback property on hazard tiles
docs(contributing): explain the level fixtures
```

---

## License

By contributing to Just Platformer Kit you agree that your contributions will be licensed under the terms in [LICENSE](LICENSE).
