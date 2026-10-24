// A checkpoint's respawn point is saved in world space, so a checkpoint
// moved after it was placed would bring the player back where it used to
// be. The kit's Problems-dock check says so, and its fix is one undo step.

import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart' as jge;
import 'package:just_game_engine_editor/just_game_engine_editor.dart';
import 'package:just_platformer_kit/editor.dart';

void main() {
  late jge.World world;
  late EditorScope scope;

  setUp(() {
    world = jge.World()..initialize();
    scope = EditorScope(
      builtIns: const [BuiltInEditorModule.new],
      world: world,
      modules: [PlatformerModule()],
    );
  });
  tearDown(() {
    scope.dispose();
    world.dispose();
  });

  jge.Entity checkpoint() {
    final prefab = PlatformerPrefabs.all.firstWhere(
      (p) => p.id == 'platformer.checkpoint',
    );
    return world.createEntityWithComponents(
      prefab.build(const Offset(100, 200), prefab.defaultSize),
      name: 'Checkpoint',
    );
  }

  List<SceneProblem> problems() => [
    for (final check in scope.validators)
      ...check(ValidationContext(scope: scope)),
  ].where((p) => p.entity?.name == 'Checkpoint').toList();

  test('the module adds the check', () {
    expect(scope.validators, containsAll(PlatformerChecks.all));
  });

  test('a checkpoint where it was placed is fine', () {
    checkpoint();
    expect(problems(), isEmpty);
  });

  test('a moved checkpoint is flagged, and the fix respawns at it', () {
    final e = checkpoint();
    e.getComponent<jge.TransformComponent>()!.setPositionXY(900, 200);
    final found = problems();
    expect(found, hasLength(1));
    expect(found.single.message, contains('800 px'));

    found.single.fixes.single.apply();
    final respawn = e.getComponent<jge.CheckpointComponent>()!.respawnPosition;
    expect([respawn.x, respawn.y], [900, 200]);
    expect(problems(), isEmpty);

    scope.history.undo();
    final undone = e.getComponent<jge.CheckpointComponent>()!.respawnPosition;
    expect([undone.x, undone.y], [100, 200], reason: 'one undo step');
  });
}
