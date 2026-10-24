/// The design-time half of the platformer kit: everything the Level Designer
/// needs to author a platformer.
///
/// Builds on `just_editor_core` alone, and is kept out of
/// `just_platformer_kit.dart` so the runtime library carries no editor code.
/// Import this only from a debug entry point.
///
/// ```dart
/// // lib/main_editor.dart
/// import 'package:just_platformer_kit/editor.dart';
///
/// JustGameEditorPlugin.register(engine: engine, modules: [PlatformerModule()]);
/// ```
library;

export 'src/editor/platformer_checks.dart';
export 'src/editor/platformer_module.dart';
export 'src/editor/platformer_prefabs.dart';
export 'src/editor/platformer_overlays.dart';
