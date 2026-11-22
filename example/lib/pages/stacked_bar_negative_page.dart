// Ported from MPChartExample: StackedBarActivityNegative.kt, with res/layout/activity_age_distribution.xml and
// res/menu/bar.xml.
//
// Bar Charts / Stacked 2: an age pyramid, horizontal stacked bars with the men as negative and the women as positive
// values on the right axis, every value and axis label shown without its sign and in metres ("10m"). Not ported: the
// "View on GitHub" and "Save to Gallery" menu items (see notimportant/demo_base.dart).
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../custom/demo_drawables.dart';
import '../notimportant/demo_base.dart';

/// StackedBarActivityNegative.
class StackedBarNegativePage extends StatefulWidget {
  const StackedBarNegativePage({super.key});

  @override
  State<StackedBarNegativePage> createState() => _StackedBarNegativePageState();
}

class _StackedBarNegativePageState extends State<StackedBarNegativePage> with DemoBase {
  /// `binding.chart1`.
  final HorizontalBarChartView _chart = HorizontalBarChartView();

  @override
  void initState() {
    super.initState();

    _chart
      ..onChartValueSelectedListener = OnChartValueSelectedListener.fromFunction(
        onValueSelected: (e, h) {
          final stackValues = (e as BarEntry).stackValues;
          if (stackValues == null) return;
          logI('VAL SELECTED', 'Value: ${stackValues[h.stackIndex].abs()}');
        },
        onNothingSelected: () => logI('NOTING SELECTED', ''),
      )
      ..isDrawGridBackgroundEnabled = false
      ..description.isEnabled = false
      ..isPinchZoomEnabled = false
      ..isDrawBarShadowEnabled = false
      ..isDrawValueAboveBarEnabled = true
      ..isHighlightFullBarEnabled = false;

    _chart.axisLeft.isEnabled = false;
    _chart.axisRight
      ..axisMaximum = 25
      ..axisMinimum = -25
      ..isDrawGridLinesEnabled = false
      ..isDrawZeroLineEnabled = true
      ..labelCount = 7
      ..valueFormatter = _CustomFormatter()
      ..textSize = 9;

    final format = DecimalFormat('###');
    _chart.xAxis
      ..position = XAxisPosition.BOTH_SIDED
      ..isDrawGridLinesEnabled = false
      ..isDrawAxisLineEnabled = false
      ..textSize = 9
      ..axisMinimum = 0
      ..axisMaximum = 110
      ..isCenterAxisLabelsEnabled = true
      ..labelCount = 12
      ..granularity = 10
      ..valueFormatter = IAxisValueFormatter.fromFunction(
        (value, _) => '${format.format(value)}-${format.format(value + 10)}',
      );

    _chart.legend
      ..verticalAlignment = LegendVerticalAlignment.BOTTOM
      ..horizontalAlignment = LegendHorizontalAlignment.RIGHT
      ..orientation = LegendOrientation.HORIZONTAL
      ..isDrawInsideEnabled = false
      ..formSize = 8
      ..formToTextSpace = 4
      ..xEntrySpace = 6;

    // Negative values must come first in each stack
    final values = [
      BarEntry.stacked(x: 5, stackValues: [-10, 10]),
      BarEntry.stacked(x: 15, stackValues: [-12, 13]),
      BarEntry.stacked(x: 25, stackValues: [-15, 15]),
      BarEntry.stacked(x: 35, stackValues: [-17, 17]),
      BarEntry.stacked(x: 45, stackValues: [-19, 20]),
      BarEntry.stacked(x: 45, stackValues: [-19, 20], icon: starDrawable),
      BarEntry.stacked(x: 55, stackValues: [-19, 19]),
      BarEntry.stacked(x: 65, stackValues: [-16, 16]),
      BarEntry.stacked(x: 75, stackValues: [-13, 14]),
      BarEntry.stacked(x: 85, stackValues: [-10, 11]),
      BarEntry.stacked(x: 95, stackValues: [-5, 6]),
      BarEntry.stacked(x: 105, stackValues: [-1, 2]),
    ];

    final set = BarDataSet(values, 'Age Distribution')
      ..isDrawIconsEnabled = false
      ..valueFormatter = _CustomFormatter()
      ..valueTextSize = 7
      ..axisDependency = AxisDependency.RIGHT
      ..setColors([const Color.fromARGB(255, 67, 67, 72), const Color.fromARGB(255, 124, 181, 236)])
      ..stackLabels = ['Men', 'Women'];

    _chart.data = BarData([set])..barWidth = 8.5;
    _chart.invalidate();
  }

  List<IBarDataSet> get _dataSets => _chart.data?.dataSets ?? const <IBarDataSet>[];

  /// res/menu/bar.xml; an item `onOptionsItemSelected` has no branch for does nothing, as in Kotlin.
  List<DemoMenuItem> get _menu => [
    DemoMenuItem('Toggle Bar Borders', () {
      for (final set in _dataSets) {
        (set as BarDataSet).barBorderWidth = set.barBorderWidth == 1 ? 0 : 1;
      }
      _chart.invalidate();
    }),
    DemoMenuItem('Toggle Rounded Sections', () {}),
    DemoMenuItem('Toggle Values', () {
      for (final set in _dataSets) {
        set.isDrawValuesEnabled = !set.isDrawValuesEnabled;
      }
      _chart.invalidate();
    }),
    DemoMenuItem('Toggle Icons', () {
      for (final set in _dataSets) {
        set.isDrawIconsEnabled = !set.isDrawIconsEnabled;
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
    DemoMenuItem('Toggle PinchZoom', () {
      _chart.isPinchZoomEnabled = !_chart.isPinchZoomEnabled;
      _chart.invalidate();
    }),
    DemoMenuItem('Toggle Auto Scale', () {
      _chart.isAutoScaleMinMaxEnabled = !_chart.isAutoScaleMinMaxEnabled;
      _chart.notifyDataSetChanged();
    }),
    DemoMenuItem('Animate X', () => _chart.animateX(3000)),
    DemoMenuItem('Animate Y', () => _chart.animateY(3000)),
    DemoMenuItem('Animate XY', () => _chart.animateXY(3000, 3000)),
  ];

  @override
  Widget build(BuildContext context) => DemoScaffold(
    title: 'Stacked 2',
    menu: _menu,
    body: ColoredBox(
      color: demoChartBackground,
      child: ChartHostWidget<HorizontalBarChartView, BarData>(chart: _chart, data: _chart.data),
    ),
  );
}

/// StackedBarActivityNegative's `CustomFormatter`, a value and an axis formatter: the value without its sign and with
/// an "m".
///
/// Kotlin overloads `getFormattedValue` for the two interfaces; Dart has no overloading, so one [getFormattedValue]
/// takes either signature, as the library's `PercentFormatter` does.
class _CustomFormatter extends IValueFormatter implements IAxisValueFormatter {
  final DecimalFormat _format = DecimalFormat('###');

  @override
  String getFormattedValue(
    double value,
    Object entryOrAxis, [
    int dataSetIndex = 0,
    ViewPortHandler? viewPortHandler,
  ]) => '${_format.format(value.abs())}m';
}
