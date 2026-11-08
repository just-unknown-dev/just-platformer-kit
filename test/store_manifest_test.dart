// The Asset Store manifest (just_store.json) agrees with the package: its
// version with the pubspec's and the CHANGELOG's newest heading, its engine
// floor with the pubspec's, and its component types with the definitions.
// A store that offered the kit to an older engine than the pubspec needs
// would install a kit that does not resolve.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_platformer_kit/just_platformer_kit.dart';

void main() {
  final manifest =
      jsonDecode(File('just_store.json').readAsStringSync())
          as Map<String, dynamic>;
  final pubspec = File('pubspec.yaml').readAsStringSync();

  /// The pubspec's constraint on [package], from its dependencies.
  String? constraintOf(String package) => RegExp(
    '^  $package:[ \\t]*([^\\s#]+)',
    multiLine: true,
  ).firstMatch(pubspec)?.group(1);

  final version = RegExp(
    r'^version:[ \t]*(\S+)',
    multiLine: true,
  ).firstMatch(pubspec)!.group(1);

  test('one version: the pubspec, the manifest and the CHANGELOG', () {
    expect(manifest['version'], version);
    final heading = RegExp(
      r'^## (.+)$',
      multiLine: true,
    ).firstMatch(File('CHANGELOG.md').readAsStringSync())!.group(1)!.trim();
    expect(heading, version, reason: "the release takes the version's notes");
  });

  test("the manifest asks for the engine the pubspec needs", () {
    final requires = manifest['requires'] as Map<String, dynamic>;
    final engine = constraintOf('just_game_engine');
    expect(engine, isNotNull);
    expect(requires['just_game_engine'], engine);
    // The editor that hosts its module: the one the tests drive.
    expect(
      requires['just_game_engine_editor'],
      constraintOf('just_game_engine_editor'),
    );
  });

  test('the manifest lists every component the kit saves', () {
    final types = [for (final d in PlatformerDefinitions.all) d.type]..sort();
    expect((manifest['runtime'] as Map)['componentTypes'], types);
  });
}
