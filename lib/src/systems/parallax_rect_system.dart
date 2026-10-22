library;

import 'package:just_game_engine/just_game_engine.dart';

import '../components/platformer.dart';

/// Scrolls decorative entities slower than the camera, giving depth without
/// any image assets.
///
/// The engine's [ParallaxRenderSystem] draws the image layers of a
/// [ParallaxComponent] in screen space before the camera transform. This is
/// the rectangle-only equivalent for ordinary world-space entities, so a
/// template with no art still reads as having a background.
///
/// Runs just before render, after the camera has settled for the frame —
/// running earlier would use the previous frame's camera position and the
/// background would lag by one frame during fast movement.
class ParallaxRectSystem extends System {
  ParallaxRectSystem({required this.camera});

  /// The camera parallax is measured against.
  final GameCamera camera;

  @override
  int get priority => SystemPriorities.render + 1;

  @override
  List<Type> get requiredComponents => [
    TransformComponent,
    ParallaxRectComponent,
  ];

  @override
  void update(double deltaTime) {
    final cameraPos = camera.position;

    forEach((entity) {
      if (!entity.isActive) return;

      final parallax = entity.getComponent<ParallaxRectComponent>()!;
      final transform = entity.getComponent<TransformComponent>()!;

      // Capture where the designer actually placed this entity. Everything
      // below is an offset from that, so the authored position stays the
      // source of truth and the effect is idempotent across frames.
      parallax.baseX ??= transform.position.x;
      parallax.baseY ??= transform.position.y;

      // A layer at scrollFactor 1 sits still relative to the world; at 0 it is
      // pinned to the camera (infinitely distant). Shifting by the camera's
      // displacement times (1 - factor) produces exactly that.
      transform.setPositionXY(
        parallax.baseX! + cameraPos.dx * (1.0 - parallax.scrollFactorX),
        parallax.baseY! + cameraPos.dy * (1.0 - parallax.scrollFactorY),
      );
    });
  }
}
