// Ported from MPAndroidChart v4.0.1: MPChartLib/src/test/kotlin/com/github/mikephil/charting/test/RendererEdgeCaseTest.kt
//
// Kotlin's FakeChart is a CombinedDataProvider (Phase 2); the line part runs here on a LineDataProvider fake with the
// same values, the bar, candle and bubble parts on FakeBarChart, FakeCandleChart and FakeBubbleChart from
// support/fake_providers.dart given those values and on a StrictCanvas, which also fails on NaN geometry. As in Kotlin,
// the transformers are unprepared (every value is its own pixel) and the content rectangle is the single point (0, 0).
// The pie and radar parts look the highlights up in PieData and RadarData; Kotlin's `Highlight(2f, 0, -1)` (Float, Int,
// Int) is the stacked constructor, so it is `Highlight.stacked` there.
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/animation/chart_animator.dart';
import 'package:mp_flutter_chart/src/components/y_axis.dart';
import 'package:mp_flutter_chart/src/data/bar_data.dart';
import 'package:mp_flutter_chart/src/data/bar_data_set.dart';
import 'package:mp_flutter_chart/src/data/bar_entry.dart';
import 'package:mp_flutter_chart/src/data/bubble_data.dart';
import 'package:mp_flutter_chart/src/data/bubble_data_set.dart';
import 'package:mp_flutter_chart/src/data/bubble_entry.dart';
import 'package:mp_flutter_chart/src/data/candle_data.dart';
import 'package:mp_flutter_chart/src/data/candle_data_set.dart';
import 'package:mp_flutter_chart/src/data/candle_entry.dart';
import 'package:mp_flutter_chart/src/data/entry.dart';
import 'package:mp_flutter_chart/src/data/line_data.dart';
import 'package:mp_flutter_chart/src/data/line_data_set.dart';
import 'package:mp_flutter_chart/src/data/pie_data.dart';
import 'package:mp_flutter_chart/src/data/pie_data_set.dart';
import 'package:mp_flutter_chart/src/data/pie_entry.dart';
import 'package:mp_flutter_chart/src/data/radar_data.dart';
import 'package:mp_flutter_chart/src/data/radar_data_set.dart';
import 'package:mp_flutter_chart/src/data/radar_entry.dart';
import 'package:mp_flutter_chart/src/formatter/default_value_formatter.dart';
import 'package:mp_flutter_chart/src/formatter/i_value_formatter.dart';
import 'package:mp_flutter_chart/src/graphics/mutable_rect.dart';
import 'package:mp_flutter_chart/src/highlight/highlight.dart';
import 'package:mp_flutter_chart/src/interfaces/dataprovider/line_data_provider.dart';
import 'package:mp_flutter_chart/src/renderer/bar_chart_renderer.dart';
import 'package:mp_flutter_chart/src/renderer/bubble_chart_renderer.dart';
import 'package:mp_flutter_chart/src/renderer/candle_stick_chart_renderer.dart';
import 'package:mp_flutter_chart/src/renderer/line_chart_renderer.dart';
import 'package:mp_flutter_chart/src/utils/mp_point_f.dart';
import 'package:mp_flutter_chart/src/utils/transformer.dart';
import 'package:mp_flutter_chart/src/utils/view_port_handler.dart';

import 'support/fake_providers.dart';
import 'support/strict_canvas.dart';

/// Without a real matrix every value is its own pixel, and the content rectangle is the single point (0, 0).
class _FakeChart extends LineDataProvider {
  _FakeChart(this.lineData);

  final ViewPortHandler _handler = ViewPortHandler();

  @override
  LineData? lineData;

  @override
  LineData? get data => lineData;

  @override
  YAxis getAxis(AxisDependency axis) => YAxis(axis);

  @override
  Transformer getTransformer(AxisDependency axis) => Transformer(_handler);

  @override
  bool isInverted(AxisDependency axis) => false;

  @override
  double get lowestVisibleX => -10;

  @override
  double get highestVisibleX => 10;

  @override
  double get xChartMin => -10;

  @override
  double get xChartMax => 10;

  @override
  double get xRange => 20;

  @override
  double get yChartMin => 0;

  @override
  double get yChartMax => 10;

  @override
  double get maxHighlightDistance => 0;

  @override
  MPPointF get centerOfView => MPPointF.getInstance(0, 0);

  @override
  MPPointF get centerOffsets => MPPointF.getInstance(0, 0);

  @override
  MutableRect get contentRect => MutableRect();

  @override
  IValueFormatter get defaultValueFormatter => DefaultValueFormatter(0);

  @override
  int get maxVisibleCount => 100;
}

ui.Canvas _canvas() => ui.Canvas(ui.PictureRecorder());

const _RED = ui.Color(0xFFFF0000);
const _GREEN = ui.Color(0xFF00FF00);
const _BLUE = ui.Color(0xFF0000FF);

/// Gives [chart] the values of Kotlin's FakeChart, which [_FakeChart] has for the line part.
T _kotlinFake<T extends FakeBarLineChart>(T chart) => chart
  ..lowestVisibleX = -10
  ..highestVisibleX = 10
  ..xChartMin = -10
  ..xChartMax = 10
  ..yChartMin = 0
  ..yChartMax = 10
  ..maxHighlightDistance = 0;

/// The bar side of Kotlin's FakeChart: [FakeBarChart] with the values of the Kotlin fake.
FakeBarChart _fakeBarChart(BarData barData) =>
    _kotlinFake(FakeBarChart(barData));

void main() {
  test('drawingSkipsWhatCannotBeDrawn (line)', () {
    final canvas = _canvas();

    final line = LineDataSet([Entry(x: 0, y: 0)], 'line')..resetCircleColors();
    final noCircleColors = _FakeChart(LineData([line]));
    LineChartRenderer(
      noCircleColors,
      ChartAnimator(),
      ViewPortHandler(),
    ).drawExtras(canvas);
  });

  test('drawingSkipsWhatCannotBeDrawn (candle part)', () {
    final canvas = StrictCanvas();

    final emptyCandles = _kotlinFake(
      FakeCandleChart(CandleData([CandleDataSet(<CandleEntry>[], 'candles')])),
    );
    CandleStickChartRenderer(
      emptyCandles,
      ChartAnimator(),
      ViewPortHandler(),
    ).drawData(canvas);
    expect(canvas.calls, isEmpty);
  });

  test('drawingSkipsWhatCannotBeDrawn (bar part)', () {
    final canvas = StrictCanvas();

    final stacked = BarEntry.stacked(x: 0, stackValues: [1, 2]);
    final bars = _fakeBarChart(
      BarData([
        BarDataSet([stacked], 'bars'),
      ]),
    );
    final barRenderer = BarChartRenderer(
      bars,
      ChartAnimator(),
      ViewPortHandler(),
    );
    barRenderer.drawData(canvas);
    stacked.stackValues = [1, 2, 3];
    barRenderer.drawData(canvas);
  });

  test('highlightsThatPointPastTheDataAreIgnored (bar part)', () {
    final canvas = StrictCanvas();

    final bars = _fakeBarChart(
      BarData([
        BarDataSet([
          BarEntry.stacked(x: 0, stackValues: [1, 2]),
        ], 'bars'),
      ]),
    );
    final stackPastTheEnd = Highlight(0, 3, 0)..stackIndex = 5;
    BarChartRenderer(
      bars,
      ChartAnimator(),
      ViewPortHandler(),
    ).drawHighlighted(canvas, [stackPastTheEnd]);
    // Not in Kotlin's test, which only checks that nothing throws: the stack has no range 5, so no highlight is drawn.
    expect(canvas.calls, isEmpty);
  });

  test('highlightsThatPointPastTheDataAreIgnored (bubble part)', () {
    final canvas = StrictCanvas();

    final bubbleSet = BubbleDataSet([
      BubbleEntry(x: -1, y: 0, size: 1),
    ], 'bubbles')..colors = [_RED, _GREEN, _BLUE];
    final bubbles = _kotlinFake(FakeBubbleChart(BubbleData([bubbleSet])));
    BubbleChartRenderer(
      bubbles,
      ChartAnimator(),
      ViewPortHandler(),
    ).drawHighlighted(canvas, [Highlight(-1, 0, 0)]);
    // Not in Kotlin's test, which only checks that nothing throws: the bubble lies left of the content rect, the
    // single point (0, 0), whose height of 0 also makes its radius 0, so no highlight ring is drawn.
    expect(canvas.calls, isEmpty);
  });

  test('highlightsThatPointPastTheDataAreIgnored (pie and radar part)', () {
    final pie = PieData(PieDataSet([PieEntry(1), PieEntry(2)], ''));
    expect(pie.getEntryForHighlight(Highlight.stacked(2, 0, -1)), isNull);
    expect(pie.getEntryForHighlight(Highlight.stacked(-1, 0, -1)), isNull);
    expect(PieData().getEntryForHighlight(Highlight.stacked(0, 0, -1)), isNull);

    final radar = RadarData([
      RadarDataSet([RadarEntry(1)], 'short'),
      RadarDataSet([RadarEntry(1), RadarEntry(2)], 'long'),
    ]);
    expect(radar.getEntryForHighlight(Highlight.stacked(1, 0, -1)), isNull);
  });
}
