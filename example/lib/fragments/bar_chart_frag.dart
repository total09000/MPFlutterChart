// Ported from MPChartExample: fragments/BarChartFrag.kt, with res/layout/frag_simple_bar.xml.
//
// The third page of Scrolling Charts / View Pager: one set of 12 random bars from 5000 to 25000 with a marker, and no
// x axis or right axis. frag_simple_bar.xml is a FrameLayout the chart is added to in code, so the chart fills the
// page. The fragment's State owns the chart and configures it in initState, as onCreateView does; it is its own
// gesture listener, which logs every gesture and clears the highlight when a gesture ends.
import 'package:flutter/widgets.dart';
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../custom/my_marker_view.dart';
import '../notimportant/demo_base.dart';
import 'simple_fragment.dart';

/// BarChartFrag.
class BarChartFrag extends SimpleFragment {
  const BarChartFrag({super.key, required super.random});

  @override
  State<BarChartFrag> createState() => _BarChartFragState();
}

class _BarChartFragState extends SimpleFragmentState<BarChartFrag> {
  /// `chart`, the BarChart onCreateView creates.
  final BarChartView _chart = BarChartView();

  @override
  void initState() {
    super.initState();

    // `Typeface.createFromAsset(requireContext().assets, "OpenSans-Light.ttf")`.
    const tf = tfLight;

    _chart
      ..description.isEnabled = false
      ..onChartGestureListener = OnChartGestureListener.fromFunction(
        onChartGestureStart: (me, lastPerformedGesture) => logI('Gesture', 'START'),
        onChartGestureEnd: (me, lastPerformedGesture) {
          logI('Gesture', 'END');
          _chart.highlightValues(const []);
        },
        onChartLongPressed: (me) => logI('LongPress', 'Chart long pressed.'),
        onChartDoubleTapped: (me) => logI('DoubleTap', 'Chart double-tapped.'),
        onChartSingleTapped: (me) => logI('SingleTap', 'Chart single-tapped.'),
        onChartFling: (me1, me2, velocityX, velocityY) =>
            logI('Fling', 'Chart fling. VelocityX: $velocityX, VelocityY: $velocityY'),
        onChartScale: (me, scaleX, scaleY) => logI('Scale / Zoom', 'ScaleX: $scaleX, ScaleY: $scaleY'),
        onChartTranslate: (me, dX, dY) => logI('Translate / Move', 'dX: $dX, dY: $dY'),
      );

    final mv = MyMarkerView()..chartView = _chart;
    _chart.marker = mv;

    _chart
      ..isDrawGridBackgroundEnabled = false
      ..isDrawBarShadowEnabled = false
      ..data = generateBarData(1, 20000, 12);

    _chart.legend.typeface = tf;

    _chart.axisLeft
      ..typeface = tf
      ..axisMinimum = 0;

    _chart.axisRight.isEnabled = false;
    _chart.xAxis.isEnabled = false;
  }

  @override
  Widget build(BuildContext context) => ChartHostWidget<BarChartView, BarData>(chart: _chart, data: _chart.data);
}
