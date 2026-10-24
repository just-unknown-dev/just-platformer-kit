library;

import 'package:just_game_engine/just_game_engine.dart';

import '../components/platformer.dart';

/// Map collision kinds for a platformer: tiles that hurt, that launch, that
/// give way.
///
/// Each kind gives the bodies built from its tiles the same components the
/// kit's prefabs use — a spike tile is a [HazardComponent] sensor, a spring
/// tile a bouncy [PlatformComponent] — so `PlatformerGameplaySystem` treats
/// a painted spike exactly as a placed one. A tile's properties (set in the
/// Tileset Editor) tune it:
///
/// | kind | properties |
/// |---|---|
/// | `hazard` | `damage` (float), `instantKill` (bool), `respawnOnHit` (bool) |
/// | `bouncy` | `bounce` (float, the launch speed) |
/// | `crumbling` | `crumbleDelay`, `respawnDelay` (float, seconds) |
abstract final class PlatformerCollisionKinds {
  /// Hurts what touches it; passed through, like the hazard prefab.
  static MapCollisionKind get hazard => MapCollisionKind(
    id: 'hazard',
    label: 'Hazard',
    color: 0xFFEF5350,
    sensor: true,
    decorate: (body, spec, p) => body.addComponent(
      HazardComponent(
        damage: p.getDouble('damage') ?? 1,
        instantKill: p.getBool('instantKill') ?? false,
        respawnOnHit: p.getBool('respawnOnHit') ?? false,
      ),
    ),
  );

  /// Launches what lands on it.
  static MapCollisionKind get bouncy => MapCollisionKind(
    id: 'bouncy',
    label: 'Bouncy',
    color: 0xFFFFCA28,
    decorate: (body, spec, p) => body.addComponent(
      PlatformComponent(
        kind: PlatformKind.bouncy,
        bounceImpulse: p.getDouble('bounce') ?? 1400,
      ),
    ),
  );

  /// Gives way a moment after it is stood on, and comes back. Never merged
  /// with its neighbours: each tile falls on its own.
  static MapCollisionKind get crumbling => MapCollisionKind(
    id: 'crumbling',
    label: 'Crumbling',
    color: 0xFFA1887F,
    merge: TileMergeMode.none,
    decorate: (body, spec, p) => body.addComponent(
      PlatformComponent(
        kind: PlatformKind.crumbling,
        crumbleDelay: p.getDouble('crumbleDelay') ?? 0.35,
        respawnDelay: p.getDouble('respawnDelay') ?? 2,
      ),
    ),
  );

  /// Every kind, made from the code as it now is: getters rather than
  /// `static final`s, so a hot reload (which never re-runs a static
  /// initialiser) reaches them through `PlatformerKit.extension`'s refresh.
  static List<MapCollisionKind> get all => [hazard, bouncy, crumbling];

  /// Makes the kinds known to [kinds] — an engine's
  /// (`context.collisionKinds`), and so to a tileset's collision editor.
  /// Safe to call again.
  static void register(MapCollisionKinds kinds) => kinds.registerAll(all);
}
