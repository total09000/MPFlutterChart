// Ported from MPChartExample: fragments/ComplexityFragment.kt, with res/layout/frag_simple_line.xml.
//
// The second page of Scrolling Charts / View Pager: O(n), O(nlogn), O(n²) and O(n³) read from assets/n.txt,
// assets/nlogn.txt, assets/square.txt and assets/three.txt. The fragment's State owns the chart and configures it in
// initState, as onCreateView does. The assets are read once, from didChangeDependencies; the chart shows without data
// until they are loaded, and the animation onCreateView starts with the data starts when the data is set.
import 'package:flutter/widgets.dart';
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../notimportant/demo_base.dart';
import 'simple_fragment.dart';

/// ComplexityFragment.
class ComplexityFragment extends SimpleFragment {
  const ComplexityFragment({super.key, required super.random});

  @override
  State<ComplexityFragment> createState() => _ComplexityFragmentState();
}

class _ComplexityFragmentState extends SimpleFragmentState<ComplexityFragment> {
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
    _chart.axisLeft.typeface = tf;
    _chart.axisRight.isEnabled = false;
    _chart.xAxis.isEnabled = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) return;
    _loading = true;
    getComplexity().then((data) {
      if (!mounted) return;
      _chart.data = data;
      _chart.animateX(3000);
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) => ChartHostWidget<LineChartView, LineData>(chart: _chart, data: _chart.data);
}
