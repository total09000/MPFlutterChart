// Pins the key properties of .github/workflows/ci.yml, the upstream-stable CI job of design doc §4.2 (lane D plan
// Task 4). Plain text and regular expressions only, so no yaml dependency. No Kotlin counterpart.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String ci;

  setUpAll(() => ci = File('.github/workflows/ci.yml').readAsStringSync());

  /// Lines that are not YAML comments.
  List<String> uncommented() => [
    for (final l in ci.split('\n'))
      if (!l.trimLeft().startsWith('#')) l,
  ];

  test('the floor job pins the pubspec lower bound', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final floor = RegExp(r'flutter: ">=(\d+)\.(\d+)\.0"').firstMatch(pubspec);
    expect(floor, isNotNull, reason: 'pubspec.yaml has no flutter: ">=X.Y.0"');
    expect(
      uncommented(),
      contains(contains("flutter-version: '${floor![1]}.${floor[2]}.x'")),
    );
  });

  test('a latest stable entry runs too, and no entry cancels the other', () {
    final active = uncommented();
    expect(active, contains(contains("flutter-version: ''")));
    expect(active, contains(contains('fail-fast: false')));
  });

  test('runs on macOS and installs with subosito/flutter-action', () {
    final active = uncommented();
    expect(active, contains(contains('runs-on: macos-latest')));
    expect(active, contains(contains('uses: subosito/flutter-action@v2')));
  });

  test('analyzes and tests without the golden and perf tags', () {
    final active = uncommented();
    expect(active, contains(contains('flutter analyze')));
    expect(
      active,
      contains(contains('flutter test --exclude-tags golden,perf')),
    );
    // The root analyze also analyzes example/, so example/ gets its own pub get first.
    final examplePubGet = active.indexWhere(
      (l) => l.contains('working-directory: example'),
    );
    expect(examplePubGet, greaterThan(0));
    expect(active[examplePubGet - 1], contains('run: flutter pub get'));
    expect(
      examplePubGet,
      lessThan(active.indexWhere((l) => l.contains('run: flutter analyze'))),
    );
  });

  test('the api parity gate is prepared but commented out', () {
    expect(
      ci,
      matches(
        RegExp(
          r'^\s*#.*dart run tool/api_parity\.dart --scope=all --fail-on-missing\s*$',
          multiLine: true,
        ),
      ),
    );
    final active = uncommented();
    expect(active, isNot(contains(contains('--fail-on-missing'))));
    expect(
      active,
      contains(contains('dart run tool/api_parity.dart --scope=all')),
    );
  });

  test('does not depend on this machine', () {
    expect(ci, isNot(contains('tool/flutter.sh')));
    expect(ci, isNot(contains('/Users/')));
    expect(ci, isNot(contains('ohos-flutter')));
  });
}
