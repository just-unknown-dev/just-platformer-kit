// The kit's Problems-dock checks, each with a fix that is one undo step:
// - a checkpoint's respawn point is saved in world space, so a checkpoint
//   moved after it was placed would bring the player back where it used to
//   be;
// - a one-way platform saved with a solid collider (before the prefab built
//   a one-way body) cannot be jumped up through.

import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart' as jge;
import 'package:just_game_engine_editor/just_game_engine_editor.dart';
import 'package:just_platformer_kit/editor.dart';
import 'package:just_platformer_kit/just_platformer_kit.dart';

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

  group('one-way platforms', () {
    jge.Entity platform({required bool oneWayBody}) =>
        world.createEntityWithComponents([
          jge.TransformComponent(),
          jge.RigidBody2DComponent(bodyType: jge.Body2DType.static),
          jge.Collider2DComponent(
            size: jge.Vector2(128, 16),
            oneWay: oneWayBody,
          ),
          PlatformComponent(kind: PlatformKind.oneWay),
        ], name: 'Ledge');

    List<SceneProblem> ledgeProblems() => [
      for (final check in scope.validators)
        ...check(ValidationContext(scope: scope)),
    ].where((p) => p.entity?.name == 'Ledge').toList();

    test('one with a one-way body is fine', () {
      platform(oneWayBody: true);
      expect(ledgeProblems(), isEmpty);
    });

    test('one with a solid body is flagged, and the fix makes it one-way', () {
      final e = platform(oneWayBody: false);
      final found = ledgeProblems();
      expect(found, hasLength(1));
      expect(found.single.message, contains('solid'));

      found.single.fixes.single.apply();
      final collider = e.getComponent<jge.Collider2DComponent>()!;
      expect(collider.oneWay, isTrue);
      expect(ledgeProblems(), isEmpty);

      scope.history.undo();
      expect(collider.oneWay, isFalse, reason: 'one undo step');
    });
  });
}
