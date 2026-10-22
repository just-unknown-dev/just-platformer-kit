/// Components for a 2D platformer.
///
/// Gameplay meaning layered over the generic ECS: a rectangle with a physics
/// body becomes a platform, a hazard or a pickup depending on which of these
/// it carries. The level editor builds its prefab palette from exactly this
/// set.
library;

export 'collectible_component.dart';
export 'goal_component.dart';
export 'hazard_component.dart';
export 'level_bounds_component.dart';
export 'moving_platform_component.dart';
export 'parallax_rect_component.dart';
export 'patrol_enemy_component.dart';
export 'platform_component.dart';
export 'player_control_component.dart';
