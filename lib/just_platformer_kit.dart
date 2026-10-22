/// Platformer gameplay for `just_game_engine` — the components and systems a
/// side-scroller needs, as a package rather than as engine built-ins.
///
/// This library is the **runtime** half and deliberately imports no editor
/// code, so it is safe in a shipped build. The design-time half — inspector
/// descriptors, prefabs, tools and overlays — lives in `editor.dart` and is
/// only reachable from a debug entry point.
///
/// ```dart
/// // Game entry point.
/// import 'package:just_platformer_kit/just_platformer_kit.dart';
///
/// final engine = Engine(
///   config: const EngineConfig(extensions: [PlatformerKit.extension]),
/// );
/// await engine.initialize();
/// PlatformerKit.registerSystems(engine.world, physics: ..., camera: ...);
/// ```
library;

export 'src/camera/platformer_camera.dart';
export 'src/codecs/platformer_schemas.dart';
export 'src/components/platformer.dart';
export 'src/systems/platformer.dart';
export 'src/platformer_kit.dart';
export 'src/platformer_tags.dart';
export 'src/map/platformer_collision_kinds.dart';
