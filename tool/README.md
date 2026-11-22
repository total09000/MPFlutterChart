# Tools

## `api_parity.dart`

Checks `lib/src` against `MPChartLib.api`, the binary-compatibility dump of MPAndroidChart v4.0.1, and reports how
much of MPChartLib's public API the port covers. Run it from the package root:

```sh
dart run tool/api_parity.dart [--scope=<lane>[,<lane>…]|all] [--fail-on-missing] [--markdown[=<path>]]
```

- It scores every Kotlin class and member name as present, whitelisted or missing. Overloads are collapsed,
  getter/setter pairs count as properties, `protected` members are included, and constructors, synthetic members and
  enum/companion plumbing are skipped. Member renames and nested-type names are listed at the top of
  `api_parity.dart`.
- `--scope` takes lanes from the file mapping in `api_scope.md` (P0, P1-A, P1-B, P1-C, P2): one lane, a
  comma-separated list scored as their union, or `all`. A list or `all` adds a `by lane:` section. Without `--scope`
  the whole dump is scored.
- `--markdown=<path>` also writes a Markdown report; a bare `--markdown` writes it under `docs/`.
- The last line is always `coverage: <covered>/<total> (<pct>%)`.
- Exit codes: 0 for a report (even with missing symbols) or `--help`; 1 only with `--fail-on-missing` when a symbol is
  missing; 2 for a bad argument or an unreadable input.

`api_whitelist.yaml` lists the Kotlin symbols that are deliberately not ported, each with a one-sentence reason
(`symbols:`), plus Dart-only additions (`additions:`). `test/tool/api_parity_test.dart` fails on stale or unnecessary
entries.

## `glyph_extents.py`

Prints the ink extents and advances of Roboto's glyphs, from which `lib/src/graphics/roboto_glyph_extents.dart` (the
table behind `ChartPaint.getTextBounds`) was made. It reads Android's `/system/fonts/Roboto-Regular.ttf`
(`adb pull /system/fonts/Roboto-Regular.ttf`) and needs `fontTools`:

```sh
python3 -I tool/glyph_extents.py Roboto-Regular.ttf
```

One line per code point, `0xXXXX, xMin, yMin, xMax, yMax, advance,` in font units (2048 per em, y up); a glyph without
ink has four zero extents. The code points are listed in the script. The lines go between the brackets of `_extents`
in the Dart file.

## `flutter.sh`

Runs the OpenHarmony Flutter SDK: `$OHOS_FLUTTER`, or `$HOME/ohos_flutter/bin/flutter` when it is unset. Use it in
place of `flutter` when working on HarmonyOS.

## CI

`.github/workflows/ci.yml` runs on `macos-latest` with upstream Flutter from the stable channel, at the pubspec
floor (`3.35.x`) and at the latest stable release: `flutter pub get` (also in `example/`), `flutter analyze`,
`flutter test --exclude-tags golden,perf` and the API parity report. `test/tool/ci_workflow_test.dart` pins these
properties. Golden tests are excluded because their PNGs were rendered on a local macOS host; `perf` tests only
print timings.
