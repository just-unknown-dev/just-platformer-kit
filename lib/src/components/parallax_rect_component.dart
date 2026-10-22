library;

import 'package:just_game_engine/just_game_engine.dart';

/// Makes a purely decorative entity scroll slower than the camera, producing
/// depth without any image assets.
///
/// The engine's `ParallaxRenderSystem` draws the image layers of a
/// `ParallaxComponent` in screen space before the camera transform; this is
/// the rectangle-only equivalent that works on ordinary world-space entities,
/// so a template with no art still reads as having a background.
///
/// Attach only to entities with no [Collider2D] — this rewrites the
/// transform every frame and would fight the physics sync.
class ParallaxRectComponent extends Component {
  ParallaxRectComponent({this.scrollFactorX = 0.5, this.scrollFactorY = 0.5});

  /// 0 pins the entity to the camera (infinitely far away), 1 makes it move
  /// with the world (no parallax). Values above 1 push it in front.
  double scrollFactorX;

  /// Vertical equivalent of [scrollFactorX].
  double scrollFactorY;

  /// The entity's authored world position, captured on first update. Parallax
  /// is applied as an offset from here, so the value the designer placed stays
  /// the source of truth.
  double? baseX;

  /// Vertical counterpart of [baseX].
  double? baseY;
}
