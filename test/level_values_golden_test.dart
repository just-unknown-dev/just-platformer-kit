// A format-independent record of what level_01 *means*.
//
// The scene format is about to change (versioned, migrated). This golden reads
// the loaded component OBJECTS, never the JSON, so it holds across the format
// flip: whatever the file looks like, loading it must produce these values.
// Regenerate deliberately by deleting the .expected.json and rerunning.

import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_platformer_kit/just_platformer_kit.dart';

const _source = 'test/fixtures/level_01.scene.json';
const _expected = 'test/fixtures/level_01.expected.json';

/// What the game's boot gives its engine: the core and the kit.
final _context = EngineContext(extensions: [PlatformerKit.extension]);

Map<String, dynamic> _values(Component c) {
  final codec = _context.definitions.forComponent(c);
  // Schemas, and the camera components, are read field by field; the rest
  // of the core set keeps the hand-picked values below.
  if (codec is ComponentDefinition &&
      (codec is ComponentSchema ||
          c is VirtualCameraComponent ||
          c.runtimeType.toString().startsWith('Camera'))) {
    return {
      for (final f in codec.fields)
        f.name: FieldValueCodec.encode(f.kind, f.read(c)),
    };
  }
  return switch (c) {
    TransformComponent t => {
      'x': t.position.x,
      'y': t.position.y,
      'rotation': t.angle,
      'scaleX': t.scale.x,
      'scaleY': t.scale.y,
    },
    RectangleComponent r => {
      'width': r.width,
      'height': r.height,
      'filled': r.filled,
      'strokeWidth': r.strokeWidth,
      'cornerRadius': r.cornerRadius,
      'fill': r.fillStyle.color.toARGB32(),
      'stroke': r.strokeStyle.color.toARGB32(),
    },
    // A body was one component when the goldens were written; its rigid
    // body and collider are read together in [_snapshot].
    // Keyed as they were when the goldens were written.
    SpawnComponent s => {'tag': s.spawner},
    VelocityComponent v => {
      'vx': v.velocity.x,
      'vy': v.velocity.y,
      'maxSpeed': v.maxSpeed,
    },
    HealthComponent h => {
      'health': h.health,
      'maxHealth': h.maxHealth,
      'isInvulnerable': h.isInvulnerable,
    },
    TagComponent t => {'tag': t.tags.join(',')},
    InputComponent _ => {},
    _ => throw StateError('no value extractor for ${c.runtimeType}; add one'),
  };
}

/// A rigid body and its collider as the one body they were when the
/// goldens were written: the same values, under the old names.
Map<String, dynamic> _body(RigidBody2D b, Collider2D c) => {
  'shape': switch (c.shape) {
    ColliderShape2D.box => {'kind': 'rectangle', 'w': c.size.x, 'h': c.size.y},
    ColliderShape2D.circle => {'kind': 'circle', 'r': c.radius},
    final s => {'kind': s.name},
  },
  'mass': b.mass,
  'restitution': b.restitution,
  'drag': b.linearDamping,
  'isStatic': b.isStatic,
  'isOneWay': c.oneWay,
  'isSensor': b.isSensor,
  'bodyType': b.bodyType.name,
  'fixedRotation': b.lockRotation,
  'gravityScale': b.gravityScale,
  'oneWayDirection': c.oneWayDirection.name,
  // Saved as category and mask bits when the goldens were written.
  'categoryBits': 1 << b.layer,
  'maskBits': b.collidesWith ?? 0xFFFF,
  'groupIndex': b.groupIndex,
};

List<Map<String, dynamic>> _snapshot(List<Entity> entities) => [
  for (final e in entities)
    {
      'name': e.name,
      'components': {
        for (final c in e.components.sortedBy((c) => c.runtimeType.toString()))
          if (c is! RigidBody2D && c is! Collider2D) c.runtimeType.toString(): _values(c),
        if ((e.getComponent<RigidBody2D>(), e.getComponent<Collider2D>()) case (final b?, final c?))
          'PhysicsBodyComponent': _body(b, c),
      },
    },
];

void main() {
  test('loading level_01 yields exactly the recorded values', () {
    final world = World(context: _context)..initialize();
    addTearDown(world.dispose);
    final loaded = SceneLoader.load(
      world,
      jsonDecode(File(_source).readAsStringSync()) as Map<String, dynamic>,
    );
    final actual = jsonDecode(jsonEncode(_snapshot(loaded)));

    final file = File(_expected);
    if (!file.existsSync()) {
      file.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(actual),
      );
      fail('Seeded $_expected from the current loader; review it, then rerun.');
    }
    final expected = jsonDecode(file.readAsStringSync());
    expect(
      const DeepCollectionEquality().equals(actual, expected),
      isTrue,
      reason:
          'level_01 no longer loads to the recorded values; diff '
          '$_expected against a fresh seed to see what changed',
    );
  });
}
