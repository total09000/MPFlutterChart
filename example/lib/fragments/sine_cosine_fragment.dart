// Ported from MPChartExample: fragments/SineCosineFragment.kt, with res/layout/frag_simple_line.xml.
//
// The first page of Scrolling Charts / View Pager: a sine and a cosine read from assets/sine.txt and
// assets/cosine.txt, on a left axis from -1.2 to 1.2. The fragment's State owns the chart and configures it in
// initState, as onCreateView does. The assets are read once, from didChangeDependencies; the chart shows without data
// until they are loaded, and the animation onCreateView starts with the data starts when the data is set.
import 'package:flutter/widgets.dart';
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../notimportant/demo_base.dart';
import 'simple_fragment.dart';

/// SineCosineFragment.
class SineCosineFragment extends SimpleFragment {
  const SineCosineFragment({super.key, required super.random});

  @override
  State<SineCosineFragment> createState() => _SineCosineFragmentState();
}

class _SineCosineFragmentState extends SimpleFragmentState<SineCosineFragment> {
  /// `binding.lineChart1`.
  final LineChartView _chart = LineChartView();

  /// Whether the assets were asked for.
  bool _loading = false;

  @override
  void initState() {
    super.initState();

    // `Typeface.createFromAsset(requireContext().assets, "OpenSans-Light.ttf")`.
    const tf = tfLight;

    _chart
      ..description.isEnabled = false
      ..isDrawGridBackgroundEnabled = false;

    _chart.legend.typeface = tf;

    _chart.axisLeft
      ..typeface = tf
      ..axisMaximum = 1.2
      ..axisMinimum = -1.2;

    _chart.axisRight.isEnabled = false;
    _chart.xAxis.isEnabled = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) return;
    _loading = true;
    generateLineData().then((data) {
      if (!mounted) return;
      _chart.data = data;
      _chart.animateX(3000);
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) => ChartHostWidget<LineChartView, LineData>(chart: _chart, data: _chart.data);
}
