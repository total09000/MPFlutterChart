// Ported from MPChartExample: fragments/PieChartFrag.kt, with res/layout/frag_simple_pie.xml.
//
// The last page of Scrolling Charts / View Pager: four random quarters from 40 to 100 with "Revenues / Quarters 2015"
// in the hole and the legend at the top right. The fragment's State owns the chart and configures it in initState, as
// onCreateView does.
//
// Not ported: the spans of the center text (twice the size for "Revenues", grey for the rest), because
// `PieChart.centerText` is a plain String; the text is drawn in the chart's center text colour and size.
import 'package:flutter/widgets.dart';
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../notimportant/demo_base.dart';
import 'simple_fragment.dart';

/// PieChartFrag.
class PieChartFrag extends SimpleFragment {
  const PieChartFrag({super.key, required super.random});

  @override
  State<PieChartFrag> createState() => _PieChartFragState();
}

class _PieChartFragState extends SimpleFragmentState<PieChartFrag> {
  /// `binding.pieChart1`.
  final PieChartView _chart = PieChartView();

  @override
  void initState() {
    super.initState();

    // `Typeface.createFromAsset(requireContext().assets, "OpenSans-Light.ttf")`.
    const tf = tfLight;

    _chart
      ..description.isEnabled = false
      ..centerTextTypeface = tf
      ..centerText = _generateCenterText()
      ..centerTextSize = 10
      ..holeRadius = 45
      ..transparentCircleRadius = 50;

    _chart.legend
      ..verticalAlignment = LegendVerticalAlignment.TOP
      ..horizontalAlignment = LegendHorizontalAlignment.RIGHT
      ..orientation = LegendOrientation.VERTICAL
      ..isDrawInsideEnabled = false;

    _chart.data = generatePieData();
  }

  /// `generateCenterText()`: the text of Kotlin's SpannableString, without its spans.
  String _generateCenterText() => 'Revenues\nQuarters 2015';

  @override
  Widget build(BuildContext context) => ChartHostWidget<PieChartView, PieData>(chart: _chart, data: _chart.data);
}
