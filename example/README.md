# mp_flutter_chart_example

Example app of `mp_flutter_chart`: a home list with the sections and entries of MPChartExample's `MainActivity`
(`lib/pages.dart`), each entry opening one page.

- **All chart types / Dark style and Light style** open the port of MPChartExample's `DesignActivity`
  (`lib/pages/design_page.dart`): one card for each chart type ported so far (`lib/design/design_charts.dart`), in the
  dark or light Nightfall style (`lib/design/nightfall.dart`, `lib/design/nightfall_style.dart`), laid out in whole
  device px as Android lays out the card's XML (`lib/design/android_metrics.dart`). The line and bar cards highlight a
  value with a pill marker (`lib/custom/pill_marker_view.dart`), and the overflow menu swaps the variant. The cards'
  data is DesignCharts.kt's: fixed values, or `KotlinRandom`, Kotlin's `Random(seed)`, with its seeds, so the cards show
  the Android app's numbers.
- **Line Charts / Basic; Bar Charts / Basic, Multiple, Horizontal and Stacked; Pie Charts / Basic; Other Charts /
  Scatter Plot, Bubble Chart, Candlestick and Radar Chart** each open a page in the dark Nightfall style of
  MPChartExample (`lib/design/nightfall.dart`, `lib/pages/<name>_page.dart`). Each page shows its chart inside a
  `ListView` with a widget marker, a status line from the `ChartController`, and buttons for an animation, `zoomIn`,
  `fitScreen`, an animated data switch (`animateChanges: true`) and the page's own toggles. The data comes from seeded
  random generators, so every run shows the same charts. The pie and radar pages (`lib/pages/pie_chart_page.dart`,
  `lib/pages/radar_chart_page.dart`) differ: their status line is their own text with the chart's rotation and
  selection, the pie page has a Spin button and switches for a half pie and for values outside the slices, the radar
  page an Animate button, in place of the zoom and data buttons, and their data is fixed.

Run it with Flutter, or for HarmonyOS with the OpenHarmony Flutter SDK through `../tool/flutter.sh` (see the
package README):

```sh
cd example
flutter run
```

The All chart types page also opens from a deep link with DesignActivity's intent extras: `dark` (default `true`),
`only` (the index of the only card shown; the default -1, or any index outside the cards, shows the cards from `from`
on) and `from` (default 0). The indexes count the cards ported so far. On Android (`-S` cold-starts the app, since a
running FlutterActivity ignores the route):

```sh
adb shell "am start -S -n com.example.mp_flutter_chart_example/.MainActivity --es route '/design?dark=true&only=1'"
```

The project has Android, iOS and HarmonyOS (`ohos/`) platform folders. With Xcode 27 the iOS deployment target is
15.0, and `flutter build ios --simulator` fails in the OpenHarmony Flutter SDK's `lipo -verify_arch` step for the two-architecture
simulator build; `flutter run -d <simulator>` builds only the active architecture and works.
