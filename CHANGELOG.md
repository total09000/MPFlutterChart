# Changelog

## 0.1.3

- README: the title is now MPFlutterChart, the name of the GitHub repository, with the package name `mp_flutter_chart`
  under it.
- README and `pubspec.yaml`: links to the website (<https://www.famakeji.top/mpflutterchart/en/>) and its live web
  demo; the pubspec `homepage` is now the website, and `repository` stays the GitHub repository.
- No changes to the library code.

## 0.1.2

- README in Simplified Chinese (`README.zh-CN.md`), with language links at the top of both READMEs.
- No changes to the library code.

## 0.1.1

- README: a Gallery with screenshots of the example app, in the dark and the light style.
- `pubspec.yaml` lists the two gallery images as screenshots for pub.dev.
- No changes to the library code.

## 0.1.0

First public release: a Flutter port of MPAndroidChart v4.0.1.

- Chart types: `LineChart`, `BarChart`, `HorizontalBarChart`, `ScatterChart`, `CandleStickChart`, `BubbleChart`,
  `PieChart` and `RadarChart`, each as an MPChartLib chart class (`package:mp_flutter_chart/core.dart`) and as a
  Flutter widget (`package:mp_flutter_chart/mp_flutter_chart.dart`).
- Data sets, axes, legend, description, markers (including `WidgetMarker` for Flutter widgets), value formatters,
  renderers, highlighting, animations and viewport jobs as in MPChartLib.
- Touch: drag, pinch and double-tap zoom and fling for bar-line charts; touch rotation and `spin` for pie and radar
  charts.
- `ChartController` for selection, zoom and animations from outside the chart.
- Android, iOS and HarmonyOS (OpenHarmony Flutter); differences from Android are listed in `MIGRATION.md`.
- `CombinedChart` is not ported yet.
