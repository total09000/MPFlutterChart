// Ported from MPChartExample: design/DesignCharts.kt, every card but the combined one (CombinedChart is not ported yet). The charts are the
// imperative core charts of package:mp_flutter_chart/core.dart, configured as Kotlin's `apply` blocks configure them.
// Kotlin's `context` is the devicePixelRatio and the TextScaler where a card uses it, for the PillMarkerView's whole-px
// layout and its font scale, and is dropped elsewhere. Kotlin's `kotlin.random.Random(seed)` is [KotlinRandom], so the
// seeded data is the same as on Android.
import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter/painting.dart' show TextScaler;
import 'package:mp_flutter_chart/core.dart';

import '../custom/pill_marker_view.dart';
import 'kotlin_random.dart';
import 'nightfall.dart';
import 'nightfall_style.dart';

/// One card of the Design screen: a titled chart in the Nightfall style.
class DesignCard {
  const DesignCard(this.title, this.subtitle, this.delta, this.chart);

  final String title;
  final String subtitle;
  final String? delta;
  final Chart chart;
}

/// Builds every chart of the Nightfall design. Data is fixed so screenshots repeat exactly.
abstract final class DesignCharts {
  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static List<DesignCard> all(
    NightfallTheme theme, {
    required double devicePixelRatio,
    required TextScaler textScaler,
  }) => [
    line(theme, devicePixelRatio: devicePixelRatio, textScaler: textScaler),
    bar(theme, devicePixelRatio: devicePixelRatio, textScaler: textScaler),
    horizontalBar(theme),
    pie(theme),
    stackedBar(theme),
    candle(theme),
    radar(theme),
    // combined: not ported yet.
    bubble(theme),
    scatter(theme),
    fullWidthLine(theme),
  ];

  static DesignCard line(
    NightfallTheme theme, {
    required double devicePixelRatio,
    required TextScaler textScaler,
  }) {
    const values = <double>[42, 48, 45, 60, 58, 72, 70, 84, 79, 92, 88, 97];
    final set = LineDataSet([
      for (final (i, v) in values.indexed) Entry(x: i.toDouble(), y: v),
    ], 'Revenue');
    nightfallLine(set, theme);
    final chart = LineChart();
    nightfallBase(chart, theme);
    chart.xAxis.valueFormatter = IndexAxisValueFormatter(_months);
    nightfallPaddedX(chart, _months.length);
    chart.axisLeft.axisMinimum = 30;
    chart.axisLeft.axisMaximum = 110;
    chart.axisLeft.labelCount = 5;
    chart.axisLeft.isForceLabelsEnabled = true;
    chart.data = LineData([set]);
    chart.marker = PillMarkerView(
      theme,
      (e) => '${_months[e.x.toInt()]} · ${_roundToInt(e.y)}',
      devicePixelRatio: devicePixelRatio,
      textScaler: textScaler,
    );
    chart.highlightValue(9, 0);
    return DesignCard('Revenue', 'Monthly, in k€', '+9.4%', chart);
  }

  /// The same line, but spread over the full width instead of leaving half a slot at each side.
  static DesignCard fullWidthLine(NightfallTheme theme) {
    const values = <double>[
      18, 26, 22, 34, 30, 46, 52, 44, 58, 66, 62, 78, 74, 88, //
    ];
    final hours = List.generate(
      values.length,
      (it) => ((it * 2) % 24).toString().padLeft(2, '0'),
    );
    final set = LineDataSet([
      for (final (i, v) in values.indexed) Entry(x: i.toDouble(), y: v),
    ], 'Traffic');
    nightfallLine(set, theme, Nightfall.green);
    final chart = LineChart();
    nightfallBase(chart, theme);
    chart.xAxis.valueFormatter = IndexAxisValueFormatter(hours);
    nightfallFullWidthX(chart, values.length);
    chart.xAxis.labelCount = 7;
    chart.axisLeft.axisMinimum = 0;
    chart.axisLeft.axisMaximum = 100;
    chart.axisLeft.labelCount = 5;
    chart.axisLeft.isForceLabelsEnabled = true;
    chart.data = LineData([set]);
    return DesignCard('Traffic', 'Full width, no side padding', null, chart);
  }

  static DesignCard bar(
    NightfallTheme theme, {
    required double devicePixelRatio,
    required TextScaler textScaler,
  }) {
    const values = <double>[38, 52, 46, 70, 64, 82, 58, 74];
    const selected = 5;
    final set = BarDataSet([
      for (final (i, v) in values.indexed) BarEntry(x: i.toDouble(), y: v),
    ], 'Orders');
    nightfallBars(set, selected: selected);
    final chart = BarChart();
    nightfallBase(chart, theme);
    chart.xAxis.valueFormatter = IndexAxisValueFormatter(const [
      'Q1',
      'Q2',
      'Q3',
      'Q4',
      'Q1',
      'Q2',
      'Q3',
      'Q4',
    ]);
    chart.axisLeft.axisMinimum = 0;
    chart.axisLeft.axisMaximum = 100;
    chart.axisLeft.labelCount = 5;
    chart.axisLeft.isForceLabelsEnabled = true;
    chart.data = BarData([set])..barWidth = 0.55;
    chart.marker = PillMarkerView(
      theme,
      (e) => _roundToInt(e.y).toString(),
      devicePixelRatio: devicePixelRatio,
      textScaler: textScaler,
    );
    chart.highlightValue(selected.toDouble(), 0);
    return DesignCard('Orders per quarter', '2025 to 2026', null, chart);
  }

  static DesignCard horizontalBar(NightfallTheme theme) {
    const items = <(String, double)>[
      ('Rent', 64),
      ('Food', 48),
      ('Travel', 36),
      ('Fun', 28),
      ('Other', 18),
    ];
    final entries = [
      for (final (i, (_, v)) in items.indexed)
        BarEntry(x: (items.length - 1 - i).toDouble(), y: v),
    ];
    final set = BarDataSet(entries, 'Budget')
      ..barCornerRadius = 11
      ..barShadowColor = theme.track
      ..colors = [
        for (var it = items.length - 1; it >= 0; it--)
          Nightfall.palette[it % Nightfall.palette.length],
      ]
      ..valueTextColor = theme.text
      ..valueTextSize = 11
      ..valueFormatter = IValueFormatter.fromFunction(
        (value, _, _, _) => '${_roundToInt(value)}%',
      );
    final chart = HorizontalBarChart();
    nightfallBase(chart, theme);
    chart.isDrawBarShadowEnabled = true;
    chart.xAxis.valueFormatter = IndexAxisValueFormatter([
      for (final (label, _) in items.reversed) label,
    ]);
    chart.xAxis.labelCount = items.length;
    chart.xAxis.granularity = 1;
    chart.xAxis.textColor = theme.text;
    chart.xAxis.textSize = 11;
    chart.axisLeft.isEnabled = false;
    chart.axisRight.isEnabled = false;
    chart.axisLeft.axisMinimum = 0;
    chart.axisLeft.axisMaximum = 80;
    chart.setExtraOffsets(4, 4, 4, 4);
    chart.data = BarData([set])..barWidth = 0.5;
    return DesignCard('Budget', 'Share of monthly spend', null, chart);
  }

  static DesignCard pie(NightfallTheme theme) {
    const items = <(String, double)>[
      ('Mobile', 44),
      ('Web', 28),
      ('Desktop', 18),
      ('Other', 10),
    ];
    final set = PieDataSet([
      for (final (label, v) in items) PieEntry(v, label: label),
    ], '');
    nightfallSlices(set);
    final chart = PieChart();
    nightfallDonut(chart, theme);
    // Kotlin's SpannableString draws "44%" 2.2 times as large and bold, and "Mobile" in the muted colour. The centre
    // text is a plain String here, so both lines are drawn in nightfallDonut's 11 dp and text colour,
    // as on the pie page.
    chart.centerText = '44%\nMobile';
    chart.data = PieData(set);
    return DesignCard('Sessions by platform', 'Last 30 days', null, chart);
  }

  static DesignCard stackedBar(NightfallTheme theme) {
    const stacks = <List<double>>[
      [30, 20, 12], [42, 18, 16], [36, 26, 10], [50, 22, 20], //
      [44, 30, 14], [58, 24, 18], [40, 20, 22], [52, 28, 16], //
    ];
    final set =
        BarDataSet([
            for (final (i, s) in stacks.indexed)
              BarEntry.stacked(x: i.toDouble(), stackValues: s),
          ], 'Spend')
          ..barCornerRadius = 6
          ..colors = const [Nightfall.accent, Nightfall.coral, Nightfall.amber]
          ..isDrawValuesEnabled = false
          ..highlightAlpha = 0;
    final chart = BarChart();
    nightfallBase(chart, theme);
    chart.xAxis.valueFormatter = IndexAxisValueFormatter(
      _months.take(8).toList(),
    );
    chart.axisLeft.axisMinimum = 0;
    chart.axisLeft.axisMaximum = 100;
    chart.axisLeft.labelCount = 5;
    chart.axisLeft.isForceLabelsEnabled = true;
    chart.data = BarData([set])..barWidth = 0.55;
    return DesignCard('Spend by category', 'Stacked, in k€', null, chart);
  }

  static DesignCard candle(NightfallTheme theme) {
    final random = KotlinRandom(11);
    var price = 118.0;
    final entries = List.generate(20, (i) {
      final open = price;
      final close = open + random.nextIntRange(-8, 10);
      final high = math.max(open, close) + random.nextIntRange(1, 6);
      final low = math.min(open, close) - random.nextIntRange(1, 6);
      price = close;
      return CandleEntry(
        x: i.toDouble(),
        high: high,
        low: low,
        open: open,
        close: close,
      );
    });
    final set = CandleDataSet(entries, 'ACME')
      ..shadowColorSameAsCandle = true
      ..shadowWidth = 1.5
      ..increasingColor = Nightfall.green
      ..increasingPaintStyle = PaintStyle.FILL
      ..decreasingColor = Nightfall.coral
      ..decreasingPaintStyle = PaintStyle.FILL
      ..neutralColor = Nightfall.amber
      ..barSpace = 0.25
      ..isDrawValuesEnabled = false
      ..isHighlightEnabled = false;
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    final chart = CandleStickChart();
    nightfallBase(chart, theme);
    // Kotlin's Int `/` and `%` truncate; `remainder` keeps the sign of the dividend as `%` does.
    chart.xAxis.valueFormatter = IAxisValueFormatter.fromFunction(
      (value, _) => days[(_roundToInt(value) ~/ 2).remainder(days.length)],
    );
    chart.xAxis.labelCount = 10;
    chart.xAxis.granularity = 2;
    chart.axisLeft.axisMinimum = 80;
    chart.axisLeft.axisMaximum = 160;
    chart.axisLeft.labelCount = 5;
    chart.axisLeft.isForceLabelsEnabled = true;
    chart.data = CandleData([set]);
    return DesignCard('ACME Corp', '5 min candles', '+2.1%', chart);
  }

  static DesignCard radar(NightfallTheme theme) {
    const labels = ['Speed', 'Power', 'Range', 'Agility', 'Stealth', 'Armor'];
    RadarDataSet set(List<double> values, String label, Color color) =>
        RadarDataSet([for (final it in values) RadarEntry(it)], label)
          ..color = color
          ..fillColor = color
          ..fillAlpha = 56
          ..isDrawFilledEnabled = true
          ..lineWidth = 2.5
          ..cornerRadius = 10
          ..isDrawValuesEnabled = false
          ..isDrawHighlightCircleEnabled = false
          ..setDrawHighlightIndicators(false);
    final chart = RadarChart();
    nightfallBase(chart, theme);
    chart.webLineWidth = 1;
    chart.webLineWidthInner = 1;
    chart.webColor = theme.muted;
    chart.webColorInner = theme.muted;
    chart.webAlpha = 40;
    chart.isRotationEnabled = false;
    // Deliberate deviation: the custom 0 and 100 are kept and no ring lies beyond them, so
    // the four labels, 30 apart, put the rings at 0, 30, 60 and 90 and the web ends at 100. Kotlin adds a ring beyond
    // the maximum and makes it the new maximum on every notifyDataSetChanged: once when the data is set and again in
    // the first layout's onSizeChanged, both before the first draw, so its first frame shows 0 to 150 (100 → 120 →
    // 150), and the maximum grows on each later layout.
    chart.yAxis.isDrawLabelsEnabled = false;
    chart.yAxis.axisMinimum = 0;
    chart.yAxis.axisMaximum = 100;
    chart.yAxis.labelCount = 4;
    chart.xAxis.valueFormatter = IndexAxisValueFormatter(labels);
    chart.xAxis.textColor = theme.muted;
    chart.xAxis.textSize = 10;
    chart.legend
      ..isEnabled = true
      ..form = LegendForm.SQUARE
      ..formSize = 10
      ..textColor = theme.text
      ..textSize = 11
      ..horizontalAlignment = LegendHorizontalAlignment.CENTER
      ..xEntrySpace = 16;
    chart.data = RadarData([
      set(const [50, 85, 40, 90, 80, 45], 'Last week', Nightfall.violet),
      set(const [90, 60, 80, 70, 50, 85], 'This week', Nightfall.accent),
    ]);
    return DesignCard('Team profile', 'Skills, 0 to 100', null, chart);
  }

  // combined (CombinedChart): not ported yet.

  static DesignCard bubble(NightfallTheme theme) {
    final random = KotlinRandom(5);
    final entries = _sortedBy(
      List.generate(
        16,
        (_) => BubbleEntry(
          x: random.nextIntRange(0, 60) / 10,
          y: random.nextIntRange(15, 95).toDouble(),
          size: random.nextIntRange(8, 40).toDouble(),
        ),
      ),
      (it) => it.x,
    );
    final set = BubbleDataSet(entries, 'Deals')
      ..colors = [
        for (final it in Nightfall.palette.take(4))
          Nightfall.withAlpha(it, 150),
      ]
      ..isDrawValuesEnabled = false
      ..isHighlightEnabled = false;
    final chart = BubbleChart();
    nightfallBase(chart, theme);
    chart.xAxis.valueFormatter = IndexAxisValueFormatter(const [
      'Q1',
      'Q2',
      'Q3',
      'Q4',
      'Q1',
      'Q2',
      'Q3',
    ]);
    chart.xAxis.granularity = 1;
    chart.xAxis.axisMinimum = -0.5;
    chart.xAxis.axisMaximum = 6.5;
    chart.axisLeft.axisMinimum = 0;
    chart.axisLeft.axisMaximum = 100;
    chart.axisLeft.labelCount = 5;
    chart.axisLeft.isForceLabelsEnabled = true;
    chart.data = BubbleData([set]);
    return DesignCard('Deal size', 'By probability', null, chart);
  }

  static DesignCard scatter(NightfallTheme theme) {
    final random = KotlinRandom(3);
    ScatterDataSet set(String label, Color color) =>
        ScatterDataSet(
            _sortedBy(
              List.generate(
                15,
                (_) => Entry(
                  x: random.nextIntRange(0, 100) / 10,
                  y: random.nextIntRange(5, 98).toDouble(),
                ),
              ),
              (it) => it.x,
            ),
            label,
          )
          ..setScatterShape(ScatterShape.CIRCLE)
          ..scatterShapeSize = 9
          ..color = Nightfall.withAlpha(color, 217)
          ..isDrawValuesEnabled = false
          ..isHighlightEnabled = false;
    final chart = ScatterChart();
    nightfallBase(chart, theme);
    chart.xAxis.labelCount = 6;
    chart.xAxis.axisMinimum = 0;
    chart.xAxis.axisMaximum = 10;
    chart.axisLeft.axisMinimum = 0;
    chart.axisLeft.axisMaximum = 100;
    chart.axisLeft.labelCount = 5;
    chart.axisLeft.isForceLabelsEnabled = true;
    chart.data = ScatterData([
      set('A', Nightfall.accent),
      set('B', Nightfall.coral),
      set('C', Nightfall.amber),
    ]);
    return DesignCard('Samples', 'Three data sets', null, chart);
  }

  /// Kotlin's `Float.roundToInt()`, `Math.round`: halves round up, towards positive infinity.
  static int _roundToInt(double value) => (value + 0.5).floor();

  /// Kotlin's `sortedBy`, which is stable: elements with equal keys keep their order. Dart's `List.sort` does not
  /// promise that, so ties are ordered by index.
  static List<T> _sortedBy<T>(List<T> list, double Function(T) selector) {
    final indexed = list.indexed.toList()
      ..sort((a, b) {
        final byKey = selector(a.$2).compareTo(selector(b.$2));
        return byKey != 0 ? byKey : a.$1.compareTo(b.$1);
      });
    return [for (final (_, it) in indexed) it];
  }
}
