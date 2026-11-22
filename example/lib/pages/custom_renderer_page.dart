// Ported from MPChartExample: CustomRendererActivity.kt, with res/layout/activity_custom_renderer.xml.
//
// Bar Charts / Custom renderer: a week of fixed values as rounded bars whose renderer, a BadgeBarRenderer, draws each
// value on a dark badge. Everything else about the chart is ordinary. The Activity has no options menu, so neither
// has the page. Not ported: `saveToGallery`, which no menu item reaches (see notimportant/demo_base.dart).
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../custom/badge_bar_renderer.dart';
import '../design/nightfall.dart';
import '../notimportant/demo_base.dart';

/// Android's `Color.WHITE`.
const Color _white = Color(0xFFFFFFFF);

/// CustomRendererActivity.
class CustomRendererPage extends StatefulWidget {
  const CustomRendererPage({super.key});

  @override
  State<CustomRendererPage> createState() => _CustomRendererPageState();
}

class _CustomRendererPageState extends State<CustomRendererPage> with DemoBase {
  /// `binding.chart1`.
  final BarChartView _chart = BarChartView();

  static const List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();

    const values = [42.0, 55.0, 48.0, 71.0, 66.0, 34.0, 29.0];
    final entries = [
      for (var index = 0; index < values.length; index++) BarEntry(x: index.toDouble(), y: values[index]),
    ];

    final set = BarDataSet(entries, 'Sessions')
      ..color = Nightfall.accent
      ..barCornerRadius = 8
      ..valueTextColor = _white
      ..valueTextSize = 11
      ..valueTypeface = tfRegular
      ..valueFormatter = IValueFormatter.fromFunction((value, _, _, _) => '${value.round()}');

    _chart
      ..description.isEnabled = false
      ..legend.isEnabled = false
      ..isDrawGridBackgroundEnabled = false
      ..setExtraOffsets(8, 24, 8, 8);

    _chart.xAxis
      ..position = XAxisPosition.BOTTOM
      ..isDrawGridLinesEnabled = false
      ..typeface = tfRegular
      ..valueFormatter = IAxisValueFormatter.fromFunction((value, _) => _days[value.toInt() % _days.length]);
    _chart.axisLeft.isEnabled = false;
    _chart.axisRight.isEnabled = false;
    _chart.axisLeft.axisMinimum = 0;

    // The renderer needs the chart, the animator and the viewport handler the chart already owns.
    _chart.renderer = BadgeBarRenderer(_chart, _chart.animator, _chart.viewPortHandler, Nightfall.dark.card);

    _chart.data = BarData([set])..barWidth = 0.55;
  }

  @override
  Widget build(BuildContext context) => DemoScaffold(
    title: 'Custom renderer',
    body: ChartHostWidget<BarChartView, BarData>(
      chart: _chart,
      data: _chart.data,
      setup: (chart) => chart.animateY(900),
    ),
  );
}
