import 'dart:math' as math;

import 'package:just_editor_core/just_editor_core.dart';
import 'package:just_game_engine/just_game_engine.dart' as jge;

import '../platforms/platforms.dart';

/// The platformer's checks in the editor's Problems dock, contributed
/// through `PlatformerModule.validators`.
abstract final class PlatformerChecks {
  /// Every check.
  static const List<SceneValidator> all = [checkpoints, oneWayPlatforms];

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

  /// A one-way platform whose collider is solid — a level saved before the
  /// kit's one-way prefab built a one-way body. The player cannot jump up
  /// through it, whatever its kind says. A warning, with a fix that makes
  /// the collider one-way: the data is fixed where it is authored, and the
  /// game reads it as saved.
  static List<SceneProblem> oneWayPlatforms(ValidationContext context) {
    final problems = <SceneProblem>[];
    for (final e in context.world.query(const [
      PlatformComponent,
      jge.Collider2DComponent,
    ])) {
      final platform = e.getComponent<PlatformComponent>()!;
      final collider = e.getComponent<jge.Collider2DComponent>()!;
      if (platform.kind != PlatformKind.oneWay || collider.oneWay) continue;
      problems.add(
        SceneProblem(
          message:
              '${e.name ?? 'A platform'} is one-way, but its collider '
              'is solid.',
          entity: e,
          hint:
              'The player cannot jump up through it. Levels saved before the '
              "one-way prefab built a one-way body have these.",
          fixes: [
            ProblemFix(
              label: 'Make its collider one-way',
              apply: () => makeOneWay(context.scope, e),
            ),
          ],
        ),
      );
    }
    return problems;
  }

  /// Makes [platform]'s collider one-way, as one undo step.
  static void makeOneWay(EditorScope scope, jge.Entity platform) {
    final collider = platform.getComponent<jge.Collider2DComponent>();
    if (collider == null || collider.oneWay) return;
    final field = scope.definitions.definitionFor(collider)?.field('oneWay');
    final write = field?.write;
    if (field == null || write == null) return;
    scope.history.push(
      ComponentFieldCommand(
        label: 'Make the collider one-way',
        component: collider,
        field: field.name,
        write: write,
        before: field.read(collider),
        after: true,
        sceneState: scope.sceneState,
        entity: platform,
      ),
    );
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
      jge.FieldDefinition field,
      void Function(jge.Component, Object?) write,
      double value,
    ) => ComponentFieldCommand(
      label: label,
      component: component,
      field: field.name,
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
