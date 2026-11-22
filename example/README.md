# mp_flutter_chart_example

Example app of `mp_flutter_chart`: a home list with the sections and entries of MPChartExample's `MainActivity`
(`lib/pages.dart`), each entry opening the port of its Activity.

| Section | Entries | Activities |
| --- | --- | --- |
| All chart types | Dark style, Light style | `DesignActivity` |
| Jetpack Compose | Compose, Compose list | `ComposeChartActivity`, `ComposeListActivity` |
| Performance | Line chart, Bar chart | `LinePerformanceActivity`, `BarPerformanceActivity` |
| Line Charts | Basic, Multiple, Dual Axis, Inverted Axis, Cubic, Colorful, Performance, Filled | `LineChartActivity1`, `MultiLineChartActivity`, `LineChartActivity2`, `InvertedLineChartActivity`, `CubicLineChartActivity`, `LineChartActivityColored`, `PerformanceLineChart`, `FilledLineActivity` |
| Bar Charts | Basic, Basic 2, Multiple, Horizontal, Stacked, Negative, Negative Horizontal, Stacked 2, Sine, Custom renderer | `BarChartActivity`, `AnotherBarActivity`, `BarChartActivityMultiDataset`, `HorizontalBarChartActivity`, `StackedBarActivity`, `BarChartPositiveNegative`, `HorizontalBarNegativeChartActivity`, `StackedBarActivityNegative`, `BarChartActivitySinus`, `CustomRendererActivity` |
| Pie Charts | Basic, Value Lines, Half Pie | `PieChartActivity`, `PiePolylineChartActivity`, `HalfPieChartActivity` |
| Other Charts | Scatter Plot, Bubble Chart, Candlestick, Radar Chart | `ScatterChartActivity`, `BubbleChartActivity`, `CandleStickChartActivity`, `RadarChartActivity` |
| Scrolling Charts | Multiple, View Pager, Tall Bar Chart, Many Bar Charts | `ListViewMultiChartActivity`, `SimpleChartDemo`, `ScrollViewActivity`, `ListViewBarChartActivity` |
| Even More Line Charts | Dynamic, Realtime, Hourly | `DynamicalAddingActivity`, `RealtimeLineChartActivity`, `LineChartTime` |
| Animation | All animations, Animated data changes | `AnimationPlaygroundActivity`, `AnimatedChangesActivity` |

Two of MainActivity's 42 entries have no page: **Other Charts / Combined Chart**, because `CombinedChart` is not
ported yet, and **Line Charts / From Java**, the Basic line chart written in Java, which has no counterpart in a Dart
package. `MIGRATION.md` ("Example app") lists how the pages differ from their Activities.

## How the pages are built

- **All chart types** is the port of `DesignActivity` (`lib/pages/design_page.dart`): one card for each chart type
  ported so far (`lib/design/design_charts.dart`), in the dark or light Nightfall style (`lib/design/nightfall.dart`,
  `lib/design/nightfall_style.dart`), laid out in whole device px as Android lays out the card's XML
  (`lib/design/android_metrics.dart`). The line and bar cards highlight a value with a pill marker
  (`lib/custom/pill_marker_view.dart`), and the overflow menu swaps the variant. The cards' data is DesignCharts.kt's:
  fixed values, or `KotlinRandom`, Kotlin's `Random(seed)`, with its seeds, so the cards show the Android app's
  numbers.
- **Every other page** is `lib/pages/<activity>_page.dart`, a port of the Activity named in its header comment,
  built on `lib/notimportant/demo_base.dart`, the port of `DemoBase`. The page owns its chart (a `LineChartView`,
  `BarChartView`, …), configures it in `initState` as the Activity does in `onCreate`, and shows it with a
  `ChartHostWidget`. The Activity's options menu is the overflow menu of the page, its SeekBars are sliders with
  their value beside them, and its other controls are the matching Material widgets. The two **Jetpack Compose** pages
  are built on the chart widgets (`LineChart`, `BarChart`, `PieChart`, …) and `ChartController`, the ports of
  MPChartCompose's composables and `rememberChartState()`.
- **Data.** Where an Activity calls `Math.random()`, the page draws from a generator with a fixed seed
  (`DemoBase.random`), so every run of a page shows the same charts; where it seeds Kotlin's `Random` itself, the page
  uses `KotlinRandom` with the same seed and shows Android's numbers. The point files of MPChartExample's assets that
  the pages read are in `assets/`.
- **Shared pieces** keep their Kotlin places: `lib/custom/` has the markers (`MyMarkerView`, `XYMarkerView`,
  `StackedBarsMarkerView`, `RadarMarkerView`, drawn on the chart canvas), the value and axis formatters, the badge bar
  renderer and the timed charts of the Performance pages; `lib/fragments/` the pages of the View Pager entry;
  `lib/listviewitems/` the rows of Scrolling Charts / Multiple.
- **Third-party files.** `assets/fonts/` holds the Open Sans faces MPChartExample ships and its charts use (Light,
  Regular and Bold; Apache License 2.0), and `assets/*.txt` are MPChartExample's point files.

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
