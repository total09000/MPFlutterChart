// Ported from MPChartExample: fragments/ScatterChartFrag.kt, with res/layout/frag_simple_scatter.xml.
//
// The fourth page of Scrolling Charts / View Pager: six sets of 200 random points from 2500 to 12500, one per
// scatter shape, with a marker and a wrapping legend. The fragment's State owns the chart and configures it in
// initState, as onCreateView does.
import 'package:flutter/widgets.dart';
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../custom/my_marker_view.dart';
import '../notimportant/demo_base.dart';
import 'simple_fragment.dart';

/// ScatterChartFrag.
class ScatterChartFrag extends SimpleFragment {
  const ScatterChartFrag({super.key, required super.random});

  @override
  State<ScatterChartFrag> createState() => _ScatterChartFragState();
}

class _ScatterChartFragState extends SimpleFragmentState<ScatterChartFrag> {
  /// `binding.scatterChart1`.
  final ScatterChartView _chart = ScatterChartView();

  @override
  void initState() {
    super.initState();

    // `Typeface.createFromAsset(requireContext().assets, "OpenSans-Light.ttf")`.
    const tf = tfLight;

    _chart.description.isEnabled = false;

    final mv = MyMarkerView()..chartView = _chart;
    _chart.marker = mv;

    _chart
      ..isDrawGridBackgroundEnabled = false
      ..data = generateScatterData(6, 10000, 200);

    _chart.xAxis
      ..isEnabled = true
      ..position = XAxisPosition.BOTTOM;

    _chart.axisLeft.typeface = tf;

    _chart.axisRight
      ..typeface = tf
      ..isDrawGridLinesEnabled = false;

    _chart.legend
      ..isWordWrapEnabled = true
      ..typeface = tf
      ..formSize = 14
      ..textSize = 9
      ..yOffset = 13;
    _chart.extraBottomOffset = 16;
  }

  @override
  Widget build(BuildContext context) =>
      ChartHostWidget<ScatterChartView, ScatterData>(chart: _chart, data: _chart.data);
}
