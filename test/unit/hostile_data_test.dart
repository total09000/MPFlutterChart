// Ported from MPAndroidChart v4.0.1: MPChartLib/src/test/kotlin/com/github/mikephil/charting/test/HostileDataTest.kt
//
// The line, bar data, bar buffer, candle, pie and radar parts run; Kotlin's vararg RadarData(RadarDataSet(...)) takes a
// list here. The chart level tests at the end are not in the Kotlin test: they feed the same kind of
// hostile data to a whole LineChart, and then to each of the five bar-line chart types of Phase 1 (bar, horizontal
// bar, scatter, candle stick and bubble) drawn on a StrictCanvas, which fails on the NaN geometry Flutter's debug
// canvas asserts on (Review Focus #1, ruling A11), and highlighted past their data (Review Focus #3).
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/buffer/bar_buffer.dart';
import 'package:mp_flutter_chart/src/charts/bar_chart.dart';
import 'package:mp_flutter_chart/src/charts/bar_line_chart_base.dart';
import 'package:mp_flutter_chart/src/charts/bubble_chart.dart';
import 'package:mp_flutter_chart/src/charts/candle_stick_chart.dart';
import 'package:mp_flutter_chart/src/charts/chart.dart';
import 'package:mp_flutter_chart/src/charts/horizontal_bar_chart.dart';
import 'package:mp_flutter_chart/src/charts/line_chart.dart';
import 'package:mp_flutter_chart/src/charts/scatter_chart.dart';
import 'package:mp_flutter_chart/src/data/bar_data.dart';
import 'package:mp_flutter_chart/src/data/bar_data_set.dart';
import 'package:mp_flutter_chart/src/data/bar_entry.dart';
import 'package:mp_flutter_chart/src/data/bar_line_scatter_candle_bubble_data.dart';
import 'package:mp_flutter_chart/src/data/bubble_data.dart';
import 'package:mp_flutter_chart/src/data/bubble_data_set.dart';
import 'package:mp_flutter_chart/src/data/bubble_entry.dart';
import 'package:mp_flutter_chart/src/data/candle_data.dart';
import 'package:mp_flutter_chart/src/data/candle_data_set.dart';
import 'package:mp_flutter_chart/src/data/candle_entry.dart';
import 'package:mp_flutter_chart/src/data/data_set.dart';
import 'package:mp_flutter_chart/src/data/entry.dart';
import 'package:mp_flutter_chart/src/data/line_data.dart';
import 'package:mp_flutter_chart/src/data/line_data_set.dart';
import 'package:mp_flutter_chart/src/data/pie_data.dart';
import 'package:mp_flutter_chart/src/data/pie_data_set.dart';
import 'package:mp_flutter_chart/src/data/pie_entry.dart';
import 'package:mp_flutter_chart/src/data/radar_data.dart';
import 'package:mp_flutter_chart/src/data/radar_data_set.dart';
import 'package:mp_flutter_chart/src/data/radar_entry.dart';
import 'package:mp_flutter_chart/src/data/scatter_data.dart';
import 'package:mp_flutter_chart/src/data/scatter_data_set.dart';
import 'package:mp_flutter_chart/src/highlight/highlight.dart';
import 'package:mp_flutter_chart/src/utils/entry_x_comparator.dart';
import 'package:mp_flutter_chart/src/utils/fill.dart';

import '../recording/recording_canvas.dart';
import 'support/strict_canvas.dart';

const Color _BLACK = Color(0xFF000000);

/// The color of the hostile data sets of the chart level tests, which no axis, grid or legend uses.
const Color _DATA = Color(0xFF123456);

/// The color of the second, stacked data set of the bar charts.
const Color _STACKS = Color(0xFF654321);

/// The rectangles [canvas] drew in [color] whose geometry is finite.
int _finiteRects(RecordingCanvas canvas, Color color) => canvas.rects
    .where((r) => r.color.toARGB32() == color.toARGB32() && r.rect.isFinite)
    .length;

/// The circles [canvas] drew in [color] whose center and radius are finite.
int _finiteCircles(RecordingCanvas canvas, Color color) => canvas.circles
    .where(
      (c) =>
          c.color.toARGB32() == color.toARGB32() &&
          c.x.isFinite &&
          c.y.isFinite &&
          c.radius.isFinite,
    )
    .length;

/// One of the five bar-line chart types of Phase 1, with the data the chart level tests feed it.
class _ChartType {
  const _ChartType(
    this.name,
    this.create, {
    required this.withoutEntries,
    required this.threeEntries,
    required this.hostile,
    required this.expectOutline,
    required this.expectFiniteEntriesDrawn,
  });

  final String name;

  /// A new chart of this type, without data or size.
  final BarLineChartBase Function() create;

  /// Data with one data set that has no entries.
  final BarLineScatterCandleBubbleData Function() withoutEntries;

  /// Data with one data set of three entries at x 0, 1 and 2; the one at x 2 is stacked on the bar charts.
  final BarLineScatterCandleBubbleData Function() threeEntries;

  /// Data whose entries hold NaN and ±∞ values next to finite ones, in [_DATA] (and [_STACKS]).
  final BarLineScatterCandleBubbleData Function() hostile;

  /// Checks the outline of this chart type that the empty state draws above its text.
  final void Function(RecordingCanvas canvas) expectOutline;

  /// Checks that the finite entries of [hostile] were still drawn.
  final void Function(RecordingCanvas canvas) expectFiniteEntriesDrawn;
}

BarData _threeBars() => BarData([
  BarDataSet([
    BarEntry(x: 0, y: 1),
    BarEntry(x: 1, y: 2),
    BarEntry.stacked(x: 2, stackValues: [1, 2]),
  ], 'a'),
]);

/// A plain set and a stacked set with NaN and ±∞ bars and stack sections. Two plain bars and the stack [1, 2] are
/// wholly finite.
BarData _hostileBars() => BarData([
  BarDataSet([
    BarEntry(x: 0, y: 1),
    BarEntry(x: 1, y: double.nan),
    BarEntry(x: 2, y: double.infinity),
    BarEntry(x: 3, y: double.negativeInfinity),
    BarEntry(x: 4, y: 2),
  ], 'plain')..color = _DATA,
  BarDataSet([
    BarEntry.stacked(x: 0, stackValues: [1, double.nan]),
    BarEntry.stacked(x: 1, stackValues: [double.infinity, 2]),
    BarEntry.stacked(x: 2, stackValues: [double.negativeInfinity, 1]),
    BarEntry.stacked(x: 3, stackValues: [double.nan]),
    BarEntry.stacked(x: 4, stackValues: [1, 2]),
  ], 'stacked')..color = _STACKS,
]);

void _expectBarOutline(RecordingCanvas canvas) {
  expect(canvas.drawRRectCalls, 3, reason: 'the three bars of the outline');
  expect(canvas.rects, isEmpty, reason: 'no bar of the data');
}

void _expectFiniteBarsDrawn(RecordingCanvas canvas) {
  expect(_finiteRects(canvas, _DATA), greaterThanOrEqualTo(2));
  expect(_finiteRects(canvas, _STACKS), greaterThanOrEqualTo(2));
}

final List<_ChartType> _chartTypes = [
  _ChartType(
    'BarChart',
    BarChart.new,
    withoutEntries: () => BarData([BarDataSet([], 'a')]),
    threeEntries: _threeBars,
    hostile: _hostileBars,
    expectOutline: _expectBarOutline,
    expectFiniteEntriesDrawn: _expectFiniteBarsDrawn,
  ),
  _ChartType(
    'HorizontalBarChart',
    HorizontalBarChart.new,
    withoutEntries: () => BarData([BarDataSet([], 'a')]),
    threeEntries: _threeBars,
    hostile: _hostileBars,
    expectOutline: _expectBarOutline,
    expectFiniteEntriesDrawn: _expectFiniteBarsDrawn,
  ),
  _ChartType(
    'ScatterChart',
    ScatterChart.new,
    withoutEntries: () => ScatterData([ScatterDataSet([], 'a')]),
    threeEntries: () => ScatterData([
      ScatterDataSet([
        Entry(x: 0, y: 1),
        Entry(x: 1, y: 2),
        Entry(x: 2, y: 3),
      ], 'a'),
    ]),
    // Two finite entries; the default square shape is a rectangle.
    hostile: () => ScatterData([
      ScatterDataSet([
        Entry(x: 0, y: 1),
        Entry(x: 1, y: double.nan),
        Entry(x: 2, y: double.infinity),
        Entry(x: 3, y: double.negativeInfinity),
        Entry(x: 4, y: 2),
      ], 'points')..color = _DATA,
    ]),
    expectOutline: (canvas) {
      expect(canvas.circles, hasLength(4), reason: 'the outline');
      expect(canvas.rects, isEmpty, reason: 'no shape of the data');
    },
    expectFiniteEntriesDrawn: (canvas) =>
        expect(_finiteRects(canvas, _DATA), greaterThanOrEqualTo(2)),
  ),
  _ChartType(
    'CandleStickChart',
    CandleStickChart.new,
    withoutEntries: () => CandleData([CandleDataSet([], 'a')]),
    threeEntries: () => CandleData([
      CandleDataSet([
        CandleEntry(x: 0, high: 4, low: 1, open: 2, close: 3),
        CandleEntry(x: 1, high: 5, low: 2, open: 4, close: 3),
        CandleEntry(x: 2, high: 6, low: 3, open: 4, close: 5),
      ], 'a'),
    ]),
    // Two finite candles, whose bodies are rectangles.
    hostile: () => CandleData([
      CandleDataSet([
        CandleEntry(x: 0, high: 4, low: 1, open: 2, close: 3),
        CandleEntry(x: 1, high: double.nan, low: 1, open: 2, close: 3),
        CandleEntry(x: 2, high: double.infinity, low: 0, open: 1, close: 2),
        CandleEntry(
          x: 3,
          high: 3,
          low: double.negativeInfinity,
          open: 2,
          close: 1,
        ),
        CandleEntry(x: 4, high: 4, low: 1, open: double.nan, close: 3),
        CandleEntry(x: 5, high: 5, low: 2, open: 4, close: 3),
      ], 'candles')..color = _DATA,
    ]),
    // The candle chart keeps Chart's default outline of three bars.
    expectOutline: (canvas) {
      expect(canvas.drawRRectCalls, 3, reason: 'the three bars of the outline');
      expect(canvas.rects, isEmpty, reason: 'no candle body of the data');
    },
    expectFiniteEntriesDrawn: (canvas) =>
        expect(_finiteRects(canvas, _DATA), greaterThanOrEqualTo(2)),
  ),
  _ChartType(
    'BubbleChart',
    BubbleChart.new,
    withoutEntries: () => BubbleData([BubbleDataSet([], 'a')]),
    threeEntries: () => BubbleData([
      BubbleDataSet([
        BubbleEntry(x: 0, y: 1, size: 1),
        BubbleEntry(x: 1, y: 2, size: 2),
        BubbleEntry(x: 2, y: 3, size: 3),
      ], 'a'),
    ]),
    // Two finite bubbles.
    hostile: () => BubbleData([
      BubbleDataSet([
        BubbleEntry(x: 0, y: 1, size: 1),
        BubbleEntry(x: 1, y: double.nan, size: 1),
        BubbleEntry(x: 2, y: double.infinity, size: 1),
        BubbleEntry(x: 3, y: double.negativeInfinity, size: 1),
        BubbleEntry(x: 4, y: 2, size: double.nan),
        BubbleEntry(x: 5, y: 2, size: 2),
      ], 'bubbles')..color = _DATA,
    ]),
    expectOutline: (canvas) {
      expect(canvas.circles, hasLength(2), reason: 'the outline');
      expect(canvas.rects, isEmpty, reason: 'no bubble of the data');
    },
    expectFiniteEntriesDrawn: (canvas) =>
        expect(_finiteCircles(canvas, _DATA), greaterThanOrEqualTo(2)),
  ),
];

void main() {
  test(
    'lookupsFinishWhenAnXIsNotANumber',
    () {
      final set = LineDataSet([
        Entry(x: 0, y: 1),
        Entry(x: 1, y: 2),
        Entry(x: 2, y: 3),
      ], '');
      expect(set.getEntryIndex(double.nan, double.nan, Rounding.CLOSEST), -1);
      set.calcMinMaxY(double.nan, double.nan);

      final brokenX = LineDataSet([
        Entry(x: 0, y: 1),
        Entry(x: double.nan, y: 2),
        Entry(x: 2, y: 3),
      ], '');
      expect(
        brokenX.getEntryIndex(1.5, double.nan, Rounding.CLOSEST),
        inInclusiveRange(0, 2),
      );

      final comparator = EntryXComparator();
      expect(
        comparator.compare(Entry(x: double.nan, y: 0), Entry(x: 1, y: 0)),
        -comparator.compare(Entry(x: 1, y: 0), Entry(x: double.nan, y: 0)),
      );
    },
    timeout: const Timeout(Duration(seconds: 5)),
  );

  test('infiniteValuesStayOutOfTheRanges', () {
    final line = LineDataSet([
      Entry(x: 0, y: 1),
      Entry(x: 1, y: double.infinity),
      Entry(x: 2, y: -3),
    ], '');
    expect(line.yMax, 1);
    expect(line.yMin, -3);
    expect(line.hasNonFiniteY, isTrue);

    final data = LineData([
      LineDataSet([Entry(x: 0, y: 1)], ''),
    ]);
    data.addEntry(Entry(x: 1, y: double.infinity), 0);
    expect(data.yMax, 1);
    expect(data.xMax, 1);
  });

  test('infiniteValuesStayOutOfTheRanges (bar part)', () {
    final bars = BarDataSet([
      BarEntry(x: 0, y: 2),
      BarEntry(x: 1, y: double.negativeInfinity),
    ], '');
    expect(bars.yMax, 2);
    expect(bars.yMin, 2);
  });

  test('infiniteValuesStayOutOfTheRanges (candle part)', () {
    final candles = CandleDataSet([
      CandleEntry(x: 0, high: 4, low: 1, open: 2, close: 3),
      CandleEntry(x: 1, high: double.infinity, low: 0, open: 1, close: 1),
    ], '');
    expect(candles.yMax, 4);
    expect(candles.yMin, 1);
  });

  test('barBufferStaysInBoundsWhenAStackGrows', () {
    final set = BarDataSet([
      BarEntry.stacked(x: 0, stackValues: [1, 2]),
    ], '');
    set.addEntry(BarEntry.stacked(x: 1, stackValues: [1, 2, 3]));
    expect(set.stackSize, 3);

    final entry = BarEntry.stacked(x: 0, stackValues: [1, 2]);
    final grown = BarDataSet([entry], '');
    entry.stackValues = [1, 2, 3, 4];
    final buffer = BarBuffer(grown.entryCount * 4 * grown.stackSize, 1, true);
    buffer.feed(grown);
    expect(buffer.filledSize, 8);
  });

  test('highlightsForMissingEntriesFindNothing', () {
    final pie = PieData(PieDataSet([PieEntry(1), PieEntry(2)], 'pie'));
    expect(pie.getEntryForHighlight(Highlight(5, 0, 0)), isNull);
    expect(pie.getEntryForHighlight(Highlight(-1, 0, 0)), isNull);

    final noSet = PieData();
    expect(noSet.getEntryForHighlight(Highlight(0, 0, 0)), isNull);
    expect(noSet.dataSet, isNull);
    expect(noSet.getDataSetByIndex(0), isNull);
    expect(noSet.getDataSetByLabel('pie', true), isNull);
    expect(noSet.yValueSum, 0);

    final radar = RadarData([
      RadarDataSet([RadarEntry(1)], 'radar'),
    ]);
    expect(radar.getEntryForHighlight(Highlight(3, 0, 0)), isNull);
  });

  test('emptyColorListsFallBackInsteadOfThrowing', () {
    final line = LineDataSet([Entry(x: 0, y: 1)], '')
      ..colors = []
      ..valueTextColors = []
      ..resetCircleColors();
    expect(line.getColor(3), _BLACK);
    expect(line.color, _BLACK);
    expect(line.getValueTextColor(3), _BLACK);
    expect(line.getCircleColor(3), _BLACK);
  });

  test('emptyColorListsFallBackInsteadOfThrowing (bar part)', () {
    final bars = BarDataSet([BarEntry(x: 0, y: 1)], '')..fills = [];
    expect(bars.getFill(0).type, FillType.EMPTY);
  });

  group('chart level', () {
    LineChart sizedChart() => LineChart()..onSizeChanged(300, 200);

    List<Entry> threePoints() => [
      Entry(x: 0, y: 1),
      Entry(x: 1, y: 2),
      Entry(x: 2, y: 3),
    ];

    /// The one paragraph of the empty state: [Chart.noDataText], centered in the 300 px wide chart.
    void expectOnlyTheEmptyStateText(RecordingCanvas canvas, Chart chart) {
      expect(canvas.drawParagraphCalls, 1);
      final textWidth = chart.infoPaint.measureText(chart.noDataText);
      expect(textWidth, greaterThan(0));
      expect(
        canvas.paragraphs.single.offset.dx,
        closeTo(150 - textWidth / 2, 1),
      );
    }

    test('a data set without entries draws the empty state', () {
      final chart = sizedChart()..data = LineData([LineDataSet([], 'a')]);
      final canvas = RecordingCanvas();
      chart.onDraw(canvas);
      expectOnlyTheEmptyStateText(canvas, chart);
      // The line chart's icon: one stroked path.
      expect(canvas.drawPathCalls, 1);
    });

    test('highlighting a missing data set clears the highlight', () {
      final chart = sizedChart()
        ..data = LineData([LineDataSet(threePoints(), 'a')]);
      chart.highlightValue(1, 0);
      expect(chart.highlighted, hasLength(1));

      chart.highlightValue(1, 99);
      expect(chart.highlighted, isEmpty);
      chart.highlightValue(1, -1);
      expect(chart.highlighted, isEmpty);
      chart.onDraw(RecordingCanvas());
    });

    test(
      'highlighting an x past the data highlights the closest entry like Kotlin',
      () {
        final chart = sizedChart()
          ..data = LineData([LineDataSet(threePoints(), 'a')]);
        chart.highlightValue(99, 0);
        // getEntryForXValue rounds to the closest entry, so x = 99 finds the entry at x = 2.
        expect(chart.highlighted, hasLength(1));
        expect(
          chart.data!.getEntryForHighlight(chart.highlighted.single)!.x,
          2,
        );
        chart.onDraw(RecordingCanvas());

        // A NaN x matches no entry, so the highlight of x 99 is cleared rather than kept.
        chart.highlightValue(double.nan, 0);
        expect(chart.highlighted, isEmpty);
        chart.onDraw(RecordingCanvas());
      },
    );

    test('an x that is not a number does not break drawing', () {
      final chart = sizedChart()
        ..data = LineData([
          LineDataSet([
            Entry(x: 0, y: 1),
            Entry(x: double.nan, y: 2),
            Entry(x: 2, y: 3),
          ], 'a'),
        ]);
      chart.onDraw(RecordingCanvas());
      chart.highlightValue(1, 0);
      chart.onDraw(RecordingCanvas());
    });

    test('infinite values do not break drawing', () {
      final chart = sizedChart()
        ..data = LineData([
          LineDataSet([
            Entry(x: 0, y: 1),
            Entry(x: 1, y: double.infinity),
            Entry(x: 2, y: double.negativeInfinity),
          ], 'a'),
        ]);
      chart.onDraw(RecordingCanvas());
    });

    test('setting data to null draws the empty state again', () {
      final chart = sizedChart()
        ..data = LineData([LineDataSet(threePoints(), 'a')]);
      chart.onDraw(RecordingCanvas());

      chart.data = null;
      final canvas = RecordingCanvas();
      chart.onDraw(canvas);
      expectOnlyTheEmptyStateText(canvas, chart);
    });

    test('a chart without a size draws nothing visible but does not throw', () {
      final chart = LineChart()
        ..data = LineData([LineDataSet(threePoints(), 'a')]);
      chart.onDraw(RecordingCanvas());
      LineChart().onDraw(RecordingCanvas());
    });

    for (final type in _chartTypes) {
      group(type.name, () {
        BarLineChartBase sized() => type.create()..onSizeChanged(300, 200);

        test('a data set without entries draws the empty state', () {
          final chart = sized()..data = type.withoutEntries();
          final canvas = StrictCanvas();
          chart.onDraw(canvas);
          expectOnlyTheEmptyStateText(canvas, chart);
          type.expectOutline(canvas);
        });

        test('setting data to null draws the empty state again', () {
          final chart = sized()..data = type.threeEntries();
          chart.onDraw(StrictCanvas());

          chart.data = null;
          final canvas = StrictCanvas();
          chart.onDraw(canvas);
          expectOnlyTheEmptyStateText(canvas, chart);
          type.expectOutline(canvas);
        });

        test('NaN and infinite values draw without NaN geometry, highlighted '
            'too', () {
          final chart = sized()..data = type.hostile();
          // The legend would add a square in each data set color.
          chart.legend.isEnabled = false;

          final canvas = StrictCanvas();
          chart.onDraw(canvas);
          type.expectFiniteEntriesDrawn(canvas);

          chart.highlightValues([
            for (final (i, set) in chart.data!.dataSets.indexed)
              for (var j = 0; j < set.entryCount; j++)
                Highlight(
                  set.getEntryForIndex(j).x,
                  set.getEntryForIndex(j).y,
                  i,
                ),
          ]);
          chart.onDraw(StrictCanvas());
        });

        if (type.create() is BarChart) {
          test('stack sections with NaN and infinite ranges are highlighted '
              'without NaN geometry, by section and as full bars', () {
            final chart = (sized() as BarChart)..data = _hostileBars();
            chart.legend.isEnabled = false;
            // Every section of every stacked entry, and one past the single section at x 3.
            chart.highlightValues([
              for (var x = 0; x < 5; x++)
                for (var stackIndex = 0; stackIndex < 2; stackIndex++)
                  Highlight.stacked(x.toDouble(), 1, stackIndex),
            ]);
            int highlightRects() {
              final canvas = StrictCanvas();
              chart.onDraw(canvas);
              return canvas.rects
                  .where(
                    (r) =>
                        r.color.toARGB32() ==
                        const Color.fromARGB(120, 0, 0, 0).toARGB32(),
                  )
                  .length;
            }

            // By section: (0, 1] at x 0, both infinite sections at x 1, (0, 1] at x 2 and both of x 4; the NaN ends of
            // x 0, x 2 (−∞ − −∞) and x 3 are left out, and x 3 has no second section.
            expect(highlightRects(), 6);
            // Full bars: x 1 (0..∞), x 2 (−∞..1) and x 4, once per highlight; the NaN sums of x 0 and x 3 are left out.
            chart.isHighlightFullBarEnabled = true;
            expect(highlightRects(), 6);
          });
        }

        test('highlights that point past the data do not throw', () {
          final chart = sized()..data = type.threeEntries();

          chart.highlightValue(1, 99);
          expect(chart.highlighted, isEmpty);
          chart.highlightValue(1, -1);
          expect(chart.highlighted, isEmpty);
          chart.onDraw(StrictCanvas());

          // Like the line chart, an x past the data finds the closest entry.
          chart.highlightValue(99, 0);
          expect(chart.highlighted, hasLength(1));
          chart.onDraw(StrictCanvas());

          // A NaN x matches no entry, so the highlight of x 99 is cleared rather than kept.
          chart.highlightValue(double.nan, 0);
          expect(chart.highlighted, isEmpty);
          chart.onDraw(StrictCanvas());

          // A stack index past the stack of the entry at x 2, which the bar charts read.
          chart.highlightValue(2, 0, stackIndex: 5);
          expect(chart.highlighted, hasLength(1));
          chart.onDraw(StrictCanvas());

          // highlightValues takes the list without checking it: a data set that does not exist and an x past
          // every entry reach the renderer.
          chart.highlightValues([Highlight(1, 2, 5), Highlight(99, 99, 0)]);
          chart.onDraw(StrictCanvas());
        });
      });
    }
  });
}
