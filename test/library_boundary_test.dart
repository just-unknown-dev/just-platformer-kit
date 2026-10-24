// The runtime library ships inside games, on every platform: it must never
// reach the editor, the editor's contract, test code or dart:io. Walks the
// kit's own imports from lib/just_platformer_kit.dart.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the runtime library never reaches the editor', () {
    const forbidden = [
      'package:just_editor_core',
      'package:just_game_engine_editor',
      'package:flutter_test',
      'dart:io',
    ];
    final seen = <String>{};
    final pending = ['lib/just_platformer_kit.dart'];
    final directive = RegExp(
      r'''^(?:import|export)\s+['"]([^'"]+)['"]''',
      multiLine: true,
    );
    while (pending.isNotEmpty) {
      final path = pending.removeLast();
      if (!seen.add(path)) continue;
      for (final m in directive.allMatches(File(path).readAsStringSync())) {
        final uri = m.group(1)!;
        for (final f in forbidden) {
          expect(uri.startsWith(f), isFalse, reason: '$path imports $uri');
        }
        if (uri.startsWith('package:just_platformer_kit/')) {
          pending.add('lib/${uri.substring('package:just_platformer_kit/'.length)}');
        } else if (!uri.contains(':')) {
          pending.add(Uri.parse(path).resolve(uri).path);
        }
      }
    }
    expect(seen, contains('lib/src/systems/player_control_system.dart'));
    expect(seen.where((p) => p.contains('src/editor/') || p.endsWith('editor.dart')), isEmpty);
  });
}
