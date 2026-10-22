/// The tags the platformer kit's code looks for.
library;

import 'dart:ui' show Color;

import 'package:just_game_engine/just_game_engine.dart';

/// Tags the kit relies on. Use these rather than string literals, and a
/// typo becomes a compile error instead of a player the enemies never see.
abstract final class PlatformerTags {
  /// Whoever is being played: the engine's own player tag. The kit's systems
  /// find players by it, and its camera zones follow it.
  static const String player = EngineTags.player;

  /// What the kit's enemy prefabs carry. The Level Designer shows an entity
  /// with it as an enemy.
  static const String enemy = 'enemy';

  /// The kit's tags, for an editor's tag list: they cannot be deleted or
  /// renamed there, since code looks for them by name.
  static const List<TagDefinition> declared = [
    TagDefinition(
      enemy,
      color: Color(0xFFFF8A65),
      description:
          "Given to the kit's enemies. The Level Designer shows them with an "
          'enemy icon.',
      declaredBy: 'just_platformer_kit',
    ),
  ];
}
