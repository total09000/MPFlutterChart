// Ported from MPAndroidChart v4.0.1: MPChartDeviceTest/src/androidTest/kotlin/com/github/mikephil/charting/devicetest/Fixtures.kt
//
// Only the parts the ported device tests use so far. `lay` takes the chart instead of a factory
// run on the main thread, since a chart here needs no Looper, and sizes it with `onSizeChanged` where Kotlin measures
// and lays out a View. `canvas()` is a `RecordingCanvas` (or `StrictCanvas`) in the tests, which need no bitmap.
import 'dart:math' as math;

import 'package:mp_flutter_chart/src/charts/bar_line_chart_base.dart';
import 'package:mp_flutter_chart/src/charts/chart.dart';
import 'package:mp_flutter_chart/src/data/bar_entry.dart';
import 'package:mp_flutter_chart/src/data/base_data_set.dart';
import 'package:mp_flutter_chart/src/data/bubble_data_set.dart';
import 'package:mp_flutter_chart/src/data/bubble_entry.dart';
import 'package:mp_flutter_chart/src/data/candle_data_set.dart';
import 'package:mp_flutter_chart/src/data/candle_entry.dart';
import 'package:mp_flutter_chart/src/data/entry.dart';
import 'package:mp_flutter_chart/src/graphics/matrix.dart';

/// Width in pixels every chart is laid out with by [lay]. The pixel distances of the ported tests are tuned to it.
const double WIDTH = 1080;

/// Height in pixels every chart is laid out with by [lay].
const double HEIGHT = 1200;

/// How many points stay visible after [zoomToVisiblePoints], roughly what a user looks at while panning.
const int VISIBLE_POINTS = 300;

const int _SEED = 42;

/// Lays [chart] out at [WIDTH] x [HEIGHT] and returns it. It is not drawn.
T lay<T extends Chart>(T chart) {
  chart.onSizeChanged(WIDTH, HEIGHT);
  return chart;
}

/// [n] points at x 0, 1, 2, … on a random walk from 100 that moves by less than 5 each step, the same on every call.
List<Entry> lineEntries(int n) {
  final random = math.Random(_SEED);
  final out = <Entry>[];
  var y = 100.0;
  for (var i = 0; i < n; i++) {
    y += random.nextDouble() * 10 - 5;
    out.add(Entry(x: i.toDouble(), y: y));
  }
  return out;
}

/// [n] plain bars at x 0, 1, 2, … with random heights between 0 and 100, the same on every call.
List<BarEntry> barEntries(int n) {
  final random = math.Random(_SEED);
  return [
    for (var i = 0; i < n; i++)
      BarEntry(x: i.toDouble(), y: random.nextDouble() * 100),
  ];
}

/// [n] candles at x 0, 1, 2, … around a random walk from 100 that moves by less than 3 each step, each spread 1 to 5
/// above and below it and closing above its open, the same on every call.
List<CandleEntry> candleEntries(int n) {
  final random = math.Random(_SEED);
  final out = <CandleEntry>[];
  var mid = 100.0;
  for (var i = 0; i < n; i++) {
    mid += random.nextDouble() * 6 - 3;
    final spread = random.nextDouble() * 4 + 1;
    out.add(
      CandleEntry(
        x: i.toDouble(),
        high: mid + spread,
        low: mid - spread,
        open: mid - spread / 2,
        close: mid + spread / 2,
      ),
    );
  }
  return out;
}

/// A candle set over [entries], [quiet] like every fixture set.
CandleDataSet candleSet(List<CandleEntry> entries) {
  final set = CandleDataSet(entries, 'candle');
  quiet(set);
  return set;
}

/// A bubble set over [entries], [quiet] like every fixture set.
BubbleDataSet bubbleSet(List<BubbleEntry> entries) {
  final set = BubbleDataSet(entries, 'bubble');
  quiet(set);
  return set;
}

/// Turns value labels and icons off, as for every fixture data set: nobody renders 100k of either, and they would
/// swamp every other cost. Private in Kotlin, where the fixture builds the data sets itself; a test that counts
/// fetches in a data set subclass calls it on its own set.
void quiet(BaseDataSet set) {
  set.isDrawValuesEnabled = false;
  set.isDrawIconsEnabled = false;
}

/// Scales x so that about [visible] of [total] points fill the viewport.
void zoomToVisiblePoints(
  BarLineChartBase chart,
  int total, [
  int visible = VISIBLE_POINTS,
]) {
  final scale = math.max(total / visible, 1.0);
  final matrix = Matrix()..set(chart.viewPortHandler.matrixTouch);
  matrix.postScale(scale, 1, 0, 0);
  chart.viewPortHandler.refresh(matrix, chart, false);
}

/// Moves the viewport sideways by [dx] pixels the way a drag does, without going through the touch listener.
void panBy(BarLineChartBase chart, double dx) {
  final matrix = Matrix()..set(chart.viewPortHandler.matrixTouch);
  matrix.postTranslate(dx, 0);
  chart.viewPortHandler.refresh(matrix, chart, false);
}

/// Puts the viewport back to fully zoomed out and unscrolled.
void resetViewport(BarLineChartBase chart) {
  chart.viewPortHandler.refresh(Matrix(), chart, false);
}
