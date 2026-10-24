import 'dart:math' as math;

import 'package:just_editor_core/just_editor_core.dart';
import 'package:just_game_engine/just_game_engine.dart' as jge;

/// The platformer's checks in the editor's Problems dock, contributed
/// through `PlatformerModule.validators`.
abstract final class PlatformerChecks {
  /// Every check.
  static const List<SceneValidator> all = [checkpoints];

  /// How far, in world units, a checkpoint's respawn point may be from the
  /// checkpoint (or past its radius, if that is larger) before it is flagged.
  static const double respawnSlack = 64;

  /// A checkpoint whose respawn point is far from where it stands: one moved
  /// since it was placed, whose respawn point (saved in world space) stayed
  /// behind. Touched where it now is, it would bring the player back to where
  /// it used to be. A warning, with a fix that puts the respawn point on the
  /// checkpoint.
  static List<SceneProblem> checkpoints(ValidationContext context) {
    final problems = <SceneProblem>[];
    for (final e in context.world.query(const [
      jge.TransformComponent,
      jge.CheckpointComponent,
    ])) {
      final at = e.getComponent<jge.TransformComponent>()!.position;
      final checkpoint = e.getComponent<jge.CheckpointComponent>()!;
      final dx = checkpoint.respawnPosition.x - at.x;
      final dy = checkpoint.respawnPosition.y - at.y;
      final distance = math.sqrt(dx * dx + dy * dy);
      if (distance <= math.max(respawnSlack, checkpoint.radius)) continue;
      problems.add(
        SceneProblem(
          message:
              '${e.name ?? 'A checkpoint'} brings the player back '
              '${distance.round()} px from where it stands.',
          entity: e,
          hint:
              'Moved since it was placed? Its respawn point (Respawn X and Y) '
              'stays where it was.',
          fixes: [
            ProblemFix(
              label: 'Respawn at the checkpoint',
              apply: () => respawnHere(context.scope, e),
            ),
          ],
        ),
      );
    }
    return problems;
  }

  /// Puts [checkpoint]'s respawn point where it stands, as one undo step.
  static void respawnHere(EditorScope scope, jge.Entity checkpoint) {
    final component = checkpoint.getComponent<jge.CheckpointComponent>();
    final transform = checkpoint.getComponent<jge.TransformComponent>();
    if (component == null || transform == null) return;
    final definition = scope.definitions.definitionFor(component);
    final x = definition?.field('respawnX'), y = definition?.field('respawnY');
    final writeX = x?.write, writeY = y?.write;
    if (x == null || y == null || writeX == null || writeY == null) return;
    ComponentFieldCommand set(
      String label,
      jge.SchemaField field,
      void Function(jge.Component, Object?) write,
      double value,
    ) => ComponentFieldCommand(
      label: label,
      component: component,
      write: write,
      before: field.read(component),
      after: value,
      sceneState: scope.sceneState,
      entity: checkpoint,
    );
    scope.history.push(
      CompositeCommand(
        label: 'Respawn at the checkpoint',
        commands: [
          set('Respawn X', x, writeX, transform.position.x),
          set('Respawn Y', y, writeY, transform.position.y),
        ],
      ),
    );
  }
}
