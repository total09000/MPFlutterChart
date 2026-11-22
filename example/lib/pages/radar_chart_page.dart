// Ported from MPChartExample: RadarChartActivity.kt, with res/layout/activity_radarchart.xml and res/menu/radar.xml.
//
// Other Charts / Radar Chart: two filled weeks of random ratings for five dishes on a dark slate chart, with
// RadarMarkerView. The y axis keeps the Activity's custom range of 0 to 80, where MPAndroidChart widens it on every
// notifyDataSetChanged (see "A radar chart keeps a custom yAxis.axisMinimum and axisMaximum" in MIGRATION.md). Not
// ported: the "View on GitHub" and "Save to Gallery" menu items (see notimportant/demo_base.dart).
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../custom/radar_marker_view.dart';
import '../notimportant/demo_base.dart';

/// RadarChartActivity.
class RadarChartPage extends StatefulWidget {
  const RadarChartPage({super.key});

  @override
  State<RadarChartPage> createState() => _RadarChartPageState();
}

class _RadarChartPageState extends State<RadarChartPage> with DemoBase {
  /// `binding.chart1`.
  final RadarChartView _chart = RadarChartView();

  /// `activities`, the labels of the x axis.
  static const List<String> _activities = ['Burger', 'Steak', 'Salad', 'Pasta', 'Pizza'];

  /// `chart.setBackgroundColor(Color.rgb(60, 65, 82))`.
  static const Color _background = Color.fromARGB(255, 60, 65, 82);

  @override
  void initState() {
    super.initState();

    _chart
      ..description.isEnabled = false
      ..webLineWidth = 1
      ..webColor = const Color(0xFFCCCCCC)
      ..webLineWidthInner = 1
      ..webColorInner = const Color(0xFFCCCCCC)
      ..webAlpha = 100;

    final mv = RadarMarkerView()..chartView = _chart;
    _chart.marker = mv;

    _setData();

    // animateXY(1400, 1400, Easing.EaseInOutQuad) runs in the host's setup, once the chart is shown.

    _chart.xAxis
      ..typeface = tfLight
      ..textSize = 9
      ..yOffset = 0
      ..xOffset = 0
      ..valueFormatter = IAxisValueFormatter.fromFunction(
        (value, _) => _activities[value.toInt() % _activities.length],
      )
      ..textColor = const Color(0xFFFFFFFF);

    _chart.yAxis
      ..typeface = tfLight
      ..labelCount = 5
      ..textSize = 9
      ..axisMinimum = 0
      ..axisMaximum = 80
      ..isDrawLabelsEnabled = false;

    _chart.legend
      ..verticalAlignment = LegendVerticalAlignment.TOP
      ..horizontalAlignment = LegendHorizontalAlignment.CENTER
      ..orientation = LegendOrientation.HORIZONTAL
      ..isDrawInsideEnabled = false
      ..typeface = tfLight
      ..xEntrySpace = 7
      ..yEntrySpace = 5
      ..textColor = const Color(0xFFFFFFFF);
  }

  /// `setData()`: five random ratings from 20 to 100 for each week.
  void _setData() {
    const mul = 80.0;
    const min = 20.0;
    const cnt = 5;

    final entries1 = <RadarEntry>[];
    final entries2 = <RadarEntry>[];

    for (var i = 0; i < cnt; i++) {
      final val1 = mathRandom() * mul + min;
      entries1.add(RadarEntry(val1));

      final val2 = mathRandom() * mul + min;
      entries2.add(RadarEntry(val2));
    }

    final set1 = RadarDataSet(entries1, 'Last Week')
      ..color = const Color.fromARGB(255, 103, 110, 129)
      ..fillColor = const Color.fromARGB(255, 103, 110, 129)
      ..isDrawFilledEnabled = true
      ..fillAlpha = 180
      ..lineWidth = 2
      ..isDrawHighlightCircleEnabled = true
      ..setDrawHighlightIndicators(false);

    final set2 = RadarDataSet(entries2, 'This Week')
      ..color = const Color.fromARGB(255, 121, 162, 175)
      ..fillColor = const Color.fromARGB(255, 121, 162, 175)
      ..isDrawFilledEnabled = true
      ..fillAlpha = 180
      ..lineWidth = 2
      ..isDrawHighlightCircleEnabled = true
      ..setDrawHighlightIndicators(false);

    final data = RadarData([set1, set2])
      ..setValueTypeface(tfLight)
      ..setValueTextSize(8)
      ..setDrawValues(false)
      ..setValueTextColor(const Color(0xFFFFFFFF));

    _chart.data = data;
    _chart.invalidate();
  }

  /// res/menu/radar.xml; an item `onOptionsItemSelected` has no branch for does nothing, as in Kotlin.
  List<DemoMenuItem> get _menu => [
    DemoMenuItem('Toggle Values', () {
      for (final set in _chart.data?.dataSets ?? const <IRadarDataSet>[]) {
        set.isDrawValuesEnabled = !set.isDrawValuesEnabled;
      }
      _chart.invalidate();
    }),
    DemoMenuItem('Toggle Icons', () {}),
    DemoMenuItem('Toggle Filled', () {
      for (final set in _chart.data?.dataSets ?? const <IRadarDataSet>[]) {
        set.isDrawFilledEnabled = !set.isDrawFilledEnabled;
      }
      _chart.invalidate();
    }),
    DemoMenuItem('Toggle Highlight', () {
      final data = _chart.data;
      if (data != null) {
        data.isHighlightEnabled = !data.isHighlightEnabled;
        _chart.invalidate();
      }
    }),
    DemoMenuItem('Toggle Highlight Circle', () {
      for (final set in _chart.data?.dataSets ?? const <IRadarDataSet>[]) {
        set.isDrawHighlightCircleEnabled = !set.isDrawHighlightCircleEnabled;
      }
      _chart.invalidate();
    }),
    DemoMenuItem('Toggle Rotation', () {
      _chart.isRotationEnabled = !_chart.isRotationEnabled;
      _chart.invalidate();
    }),
    DemoMenuItem('Toggle Y-Values', () {
      _chart.yAxis.isEnabled = !_chart.yAxis.isEnabled;
      _chart.invalidate();
    }),
    DemoMenuItem('Toggle X-Values', () {
      _chart.xAxis.isEnabled = !_chart.xAxis.isEnabled;
      _chart.notifyDataSetChanged();
      _chart.invalidate();
    }),
    DemoMenuItem(
      'Spin Animation',
      () => _chart.spin(2000, _chart.rotationAngle, _chart.rotationAngle + 360, easing: Easing.EaseInOutCubic),
    ),
    DemoMenuItem('Animate X', () => _chart.animateX(1400)),
    DemoMenuItem('Animate Y', () => _chart.animateY(1400)),
    DemoMenuItem('Animate XY', () => _chart.animateXY(1400, 1400)),
  ];

  @override
  Widget build(BuildContext context) => DemoScaffold(
    title: 'Radar Chart',
    menu: _menu,
    body: ColoredBox(
      color: _background,
      child: SizedBox.expand(
        child: ChartHostWidget<RadarChartView, RadarData>(
          chart: _chart,
          data: _chart.data,
          setup: (chart) => chart.animateXY(1400, 1400, easingX: Easing.EaseInOutQuad),
        ),
      ),
    ),
  );
}
