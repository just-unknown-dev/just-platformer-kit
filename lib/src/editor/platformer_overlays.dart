import 'package:flutter/material.dart';
import 'package:just_editor_core/just_editor_core.dart';

import '../../just_platformer_kit.dart';

/// Colours the platformer overlays draw in.
abstract final class PlatformerOverlayColors {
  /// Level bounds outline.
  static const Color bounds = Color(0xFFFFB300);

  /// Kill plane.
  static const Color killPlane = Color(0xFFE53935);

  /// Moving-platform paths.
  static const Color path = Color(0xFF4FC3F7);

  /// The first waypoint, so the direction of travel is readable.
  static const Color pathStart = Color(0xFF00E676);
}

/// The playable area, with everything outside it dimmed, and the kill plane.
class LevelBoundsOverlay extends DesignerOverlay {
  @override
  String get id => 'platformer.bounds';

  @override
  String get label => 'Level bounds';

  @override
  IconData get icon => Icons.crop_din;

  @override
  String get description => 'Playable area and kill plane';

  @override
  int get order => OverlayOrder.region;

  @override
  void paint(OverlayPaintContext context) {
    final entities = context.world
        .query([LevelBoundsComponent])
        .where(context.showsGizmosOf)
        .toList();
    if (entities.isEmpty) return;
    final bounds = entities.first.getComponent<LevelBoundsComponent>()!;
    final draw = context.draw;

    final rect = draw.toScreenRect(bounds.bounds);

    // Everything outside the playable area, dimmed — the clearest way to show
    // where the level actually ends.
    draw.canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & draw.size),
        Path()..addRect(rect),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );
    draw.strokeWorldRect(
      bounds.bounds,
      PlatformerOverlayColors.bounds.withValues(alpha: 0.85),
      strokeWidth: 2,
    );

    final killY = draw.toScreen(Offset(0, bounds.killPlaneY)).dy;
    draw.dashedLine(
      Offset(0, killY),
      Offset(draw.size.width, killY),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = PlatformerOverlayColors.killPlane.withValues(alpha: 0.9)
        ..strokeWidth = 2,
    );
    draw.label(
      Offset(8, killY - 16),
      'kill plane',
      PlatformerOverlayColors.killPlane,
    );
  }
}

/// Moving-platform routes, with draggable handles on the one being edited.
class PlatformPathOverlay extends DesignerOverlay {
  PlatformPathOverlay({required this.pathToolId});

  /// Id of the tool that edits these paths. Handles only appear while it is
  /// active, otherwise every platform in the level sprouts dots.
  final String pathToolId;

  @override
  String get id => 'platformer.paths';

  @override
  String get label => 'Platform paths';

  @override
  IconData get icon => Icons.timeline;

  @override
  String get description => 'Moving-platform routes';

  @override
  int get order => OverlayOrder.content;

  @override
  void paint(OverlayPaintContext context) {
    final draw = context.draw;
    final editing = context.controller.toolId.value == pathToolId;
    final selectedId = context.selected?.id;

    for (final entity in context.world.query([MovingPlatformComponent])) {
      if (!entity.isActive || !context.showsGizmosOf(entity)) continue;
      final platform = entity.getComponent<MovingPlatformComponent>()!;
      final points = platform.waypoints;
      if (points.length < 2) continue;

      final isSelected = entity.id == selectedId;
      final color = PlatformerOverlayColors.path.withValues(
        alpha: isSelected ? 0.95 : 0.45,
      );
      final width = isSelected ? 2.5 : 1.5;

      for (var i = 0; i < points.length - 1; i++) {
        draw.worldLine(points[i], points[i + 1], color, strokeWidth: width);
      }
      if (platform.loopMode == PlatformLoopMode.loop) {
        draw.worldLine(points.last, points.first, color, strokeWidth: width);
      }

      if (!editing || !isSelected) continue;
      for (var i = 0; i < points.length; i++) {
        final screen = draw.toScreen(points[i]);
        draw.canvas
          ..drawCircle(
            screen,
            6,
            Paint()
              ..color = i == 0
                  ? PlatformerOverlayColors.pathStart
                  : PlatformerOverlayColors.path,
          )
          ..drawCircle(
            screen,
            6,
            Paint()
              ..style = PaintingStyle.stroke
              ..color = Colors.white.withValues(alpha: 0.9)
              ..strokeWidth = 1.5,
          );
      }
    }
  }
}
