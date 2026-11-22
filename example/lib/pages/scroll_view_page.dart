// Ported from MPChartExample: ScrollViewActivity.kt, with res/layout/activity_scrollview.xml and
// res/menu/only_github.xml.
//
// Scrolling Charts / Tall Bar Chart: a bar chart 450dp high in a scroll view, between a 350dp and a 700dp placeholder
// and the "START OF SCROLLVIEW" and "END OF SCROLLVIEW" texts. The animation setData starts runs from the host's
// `setup`, because a chart animates only once a widget shows it.
//
// Not ported: the "View on GitHub" menu item (see notimportant/demo_base.dart), the only item of only_github.xml, so
// the page has no options menu.
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../design/nightfall.dart';
import '../notimportant/demo_base.dart';

/// ScrollViewActivity.
class ScrollViewPage extends StatefulWidget {
  const ScrollViewPage({super.key});

  @override
  State<ScrollViewPage> createState() => _ScrollViewPageState();
}

class _ScrollViewPageState extends State<ScrollViewPage> with DemoBase {
  /// `binding.chart1`.
  final BarChartView _chart = BarChartView();

  @override
  void initState() {
    super.initState();

    _chart
      ..description.isEnabled = false
      ..isPinchZoomEnabled = false
      ..isDrawBarShadowEnabled = false
      ..isDrawGridBackgroundEnabled = false;

    _chart.xAxis
      ..position = XAxisPosition.BOTTOM
      ..isDrawGridLinesEnabled = false;

    _chart.axisLeft.isDrawGridLinesEnabled = false;

    _chart.legend.isEnabled = false;

    _setData(10);
    _chart.isFitBarsEnabled = true;
  }

  void _setData(int count) {
    final values = <BarEntry>[];

    for (var i = 0; i < count; i++) {
      final value = mathRandom() * count + 15;
      values.add(BarEntry(x: i.toDouble(), y: value.toInt().toDouble()));
    }

    final set = BarDataSet(values, 'Data Set')
      ..colors = ColorTemplate.VORDIPLOM_COLORS.toList()
      ..isDrawValuesEnabled = false;

    final data = BarData([set]);

    _chart.data = data;
    _chart.invalidate();
  }

  /// activity_scrollview.xml's two TextViews, 30dp high with centred text.
  Widget _text(String text) => SizedBox(height: 30, child: Center(child: Text(text)));

  @override
  Widget build(BuildContext context) => DemoScaffold(
    title: 'Tall Bar Chart',
    body: SingleChildScrollView(
      dragStartBehavior: chartScrollDragStartBehavior,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _text('START OF SCROLLVIEW'),
          // THIS IS JUST A PLACEHOLDER
          const SizedBox(height: 350),
          SizedBox(
            height: 450,
            child: ChartHostWidget<BarChartView, BarData>(
              chart: _chart,
              data: _chart.data,
              // setData's binding.chart1.animateY(800).
              setup: (chart) => chart.animateY(800),
            ),
          ),
          // THIS IS JUST A PLACEHOLDER
          const SizedBox(height: 700),
          _text('END OF SCROLLVIEW'),
        ],
      ),
    ),
  );
}
