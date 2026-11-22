// Ported from MPChartExample: HalfPieChartActivity.kt, with res/layout/activity_piechart_half.xml and
// res/menu/only_github.xml.
//
// Pie Charts / Half Pie: a donut drawn over 180 degrees, from 9 to 3 o'clock, with its lower half below the screen.
// `moveOffScreen()` gives the chart a bottom margin of minus 65 % of the display height, so the chart view is that much
// taller than the page and its lower part, the empty half of the circle, lies below the screen. The page does the same
// with ordinary widgets: an `OverflowBox` makes the white chart the height of the page plus 65 % of the screen height
// (`MediaQuery.sizeOf`), aligned to the top, and a `ClipRect` cuts off what lies below the page. Not ported: the "View
// on GitHub" menu item, the only item of the menu, so the page has no overflow button (see
// notimportant/demo_base.dart); the spans of the center text, because `PieChart.centerText` is a `String` here (the
// text and its line break are kept, without the 1.7x size of "MPAndroidChart", the gray 0.8x size of "developed by"
// and the italic holo blue of "Philipp Jahoda").
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../notimportant/demo_base.dart';

/// HalfPieChartActivity.
class HalfPieChartPage extends StatefulWidget {
  const HalfPieChartPage({super.key});

  @override
  State<HalfPieChartPage> createState() => _HalfPieChartPageState();
}

class _HalfPieChartPageState extends State<HalfPieChartPage> with DemoBase {
  /// `binding.chart1`.
  final PieChartView _chart = PieChartView();

  @override
  void initState() {
    super.initState();

    _chart
      ..isUsePercentValuesEnabled = true
      ..description.isEnabled = false
      ..centerTextTypeface = tfLight
      ..centerText = _generateCenterText()
      ..isDrawHoleEnabled = true
      ..holeColor = const Color(0xFFFFFFFF)
      ..transparentCircleColor = const Color(0xFFFFFFFF)
      ..transparentCircleAlpha = 110
      ..holeRadius = 58
      ..transparentCircleRadius = 61
      ..isDrawCenterTextEnabled = true
      ..isRotationEnabled = false
      ..isHighlightPerTapEnabled = true
      ..maxAngle = 180
      ..rotationAngle = 180
      ..setCenterTextOffset(0, -20);

    _setData(4, 100);

    _chart.legend
      ..verticalAlignment = LegendVerticalAlignment.TOP
      ..horizontalAlignment = LegendHorizontalAlignment.CENTER
      ..orientation = LegendOrientation.HORIZONTAL
      ..isDrawInsideEnabled = false
      ..xEntrySpace = 7
      ..yEntrySpace = 0
      ..yOffset = 0;

    _chart
      ..entryLabelColor = const Color(0xFFFFFFFF)
      ..entryLabelTypeface = tfRegular
      ..entryLabelTextSize = 12;
  }

  void _setData(int count, double range) {
    final values = <PieEntry>[];

    for (var i = 0; i < count; i++) {
      values.add(PieEntry(mathRandom() * range + range / 5, label: parties[i % parties.length]));
    }

    final dataSet = PieDataSet(values, 'Election Results')
      ..sliceSpace = 3
      ..selectionShift = 5
      ..colors = ColorTemplate.MATERIAL_COLORS.toList();

    final data = PieData(dataSet)
      ..setValueFormatter(PercentFormatter())
      ..setValueTextSize(11)
      ..setValueTextColor(const Color(0xFFFFFFFF))
      ..setValueTypeface(tfLight);
    _chart.data = data;

    _chart.invalidate();
  }

  /// `generateCenterSpannableText()` without its spans.
  String _generateCenterText() => 'MPAndroidChart\ndeveloped by Philipp Jahoda';

  @override
  Widget build(BuildContext context) {
    // moveOffScreen(): the bottom margin of minus 65 % of the display height.
    final offset = MediaQuery.sizeOf(context).height * 0.65;
    return DemoScaffold(
      title: 'Half Pie',
      body: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight + offset;
          return ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minHeight: height,
              maxHeight: height,
              child: ColoredBox(
                color: demoChartBackground,
                child: ChartHostWidget<PieChartView, PieData>(
                  chart: _chart,
                  data: _chart.data,
                  setup: (chart) => chart.animateY(1400, easing: Easing.EaseInOutQuad),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
