// Ported from MPChartExample: PiePolylineChartActivity.kt, with res/layout/activity_piechart.xml and res/menu/pie.xml.
//
// Pie Charts / Value Lines: a donut whose percentages sit outside the slices at the end of value lines, with a seek
// bar for the number of slices and one for their range. Not ported: the "View on GitHub" and "Save to Gallery" menu
// items (see notimportant/demo_base.dart); the spans of the center text, because `PieChart.centerText` is a `String`
// here (the text and its line break are kept, without the 1.5x size of "MPAndroidChart", the gray 0.65x size of
// "developed by" and the italic holo blue of "Philipp Jahoda"); setting both seek bars in `onCreate` calls
// `onProgressChanged` twice in Kotlin, the first time with the range still 0; the page sets the data once, with both
// progresses.
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../notimportant/demo_base.dart';

/// PiePolylineChartActivity.
class PiePolylineChartPage extends StatefulWidget {
  const PiePolylineChartPage({super.key});

  @override
  State<PiePolylineChartPage> createState() => _PiePolylineChartPageState();
}

class _PiePolylineChartPageState extends State<PiePolylineChartPage> with DemoBase {
  /// `binding.chart1`.
  final PieChartView _chart = PieChartView();

  /// `binding.seekBar1.progress`.
  int _seekBar1 = 4;

  /// `binding.seekBar2.progress`.
  int _seekBar2 = 100;

  @override
  void initState() {
    super.initState();

    _chart
      ..isUsePercentValuesEnabled = true
      ..description.isEnabled = false
      ..setExtraOffsets(5, 10, 5, 5)
      ..dragDecelerationFrictionCoef = 0.95
      ..centerTextTypeface = tfLight
      ..centerText = _generateCenterText()
      ..setExtraOffsets(20, 0, 20, 0)
      ..isDrawHoleEnabled = true
      ..holeColor = const Color(0xFFFFFFFF)
      ..transparentCircleColor = const Color(0xFFFFFFFF)
      ..transparentCircleAlpha = 110
      ..holeRadius = 58
      ..transparentCircleRadius = 61
      ..isDrawCenterTextEnabled = true
      ..rotationAngle = 0
      ..isRotationEnabled = true
      ..isHighlightPerTapEnabled = true
      ..onChartValueSelectedListener = OnChartValueSelectedListener.fromFunction(
        onValueSelected: (e, h) =>
            logI('VAL SELECTED', 'Value: ${e.y}, xIndex: ${e.x}, DataSet index: ${h.dataSetIndex}'),
        onNothingSelected: () => logI('PieChart', 'nothing selected'),
      );

    // Setting the progress of the seek bars calls onProgressChanged, which sets the data.
    _onProgressChanged();

    _chart.legend
      ..verticalAlignment = LegendVerticalAlignment.TOP
      ..horizontalAlignment = LegendHorizontalAlignment.RIGHT
      ..orientation = LegendOrientation.VERTICAL
      ..isDrawInsideEnabled = false
      ..isEnabled = false;
  }

  /// `generateCenterSpannableText()` without its spans.
  String _generateCenterText() => 'MPAndroidChart\ndeveloped by Philipp Jahoda';

  /// `onProgressChanged`: new random data for the progress of the two seek bars.
  void _onProgressChanged() => _setData(_seekBar1, _seekBar2.toDouble());

  void _setData(int count, double range) {
    final entries = <PieEntry>[];

    for (var i = 0; i < count; i++) {
      entries.add(PieEntry(mathRandom() * range + range / 5, label: parties[i % parties.length]));
    }

    final dataSet = PieDataSet(entries, 'Election Results')
      ..sliceSpace = 3
      ..selectionShift = 5;

    final colors = <Color>[
      ...ColorTemplate.VORDIPLOM_COLORS,
      ...ColorTemplate.JOYFUL_COLORS,
      ...ColorTemplate.COLORFUL_COLORS,
      ...ColorTemplate.LIBERTY_COLORS,
      ...ColorTemplate.PASTEL_COLORS,
      ColorTemplate.holoBlue,
    ];

    dataSet
      ..colors = colors
      ..valueLinePart1OffsetPercentage = 80
      ..valueLinePart1Length = 0.2
      ..valueLinePart2Length = 0.4
      ..yValuePosition = ValuePosition.OUTSIDE_SLICE;

    final data = PieData(dataSet)
      ..setValueFormatter(PercentFormatter())
      ..setValueTextSize(11)
      ..setValueTextColor(const Color(0xFF000000))
      ..setValueTypeface(tfRegular);
    _chart.data = data;

    _chart.highlightValues([]);

    _chart.invalidate();
  }

  /// res/menu/pie.xml; an item `onOptionsItemSelected` has no branch for does nothing, as in Kotlin.
  List<DemoMenuItem> get _menu => [
    DemoMenuItem('Toggle Y-Values', () {
      for (final set in _chart.data?.dataSets ?? const <IPieDataSet>[]) {
        set.isDrawValuesEnabled = !set.isDrawValuesEnabled;
      }
      _chart.invalidate();
    }),
    DemoMenuItem('Toggle X-Values', () {
      _chart.isDrawEntryLabelsEnabled = !_chart.isDrawEntryLabelsEnabled;
      _chart.invalidate();
    }),
    DemoMenuItem('Toggle Icons', () {}),
    DemoMenuItem('Toggle Percent', () {
      _chart.isUsePercentValuesEnabled = !_chart.isUsePercentValuesEnabled;
      _chart.invalidate();
    }),
    DemoMenuItem('Toggle Minimum Angles', () {
      _chart.minAngleForSlices = _chart.minAngleForSlices == 0 ? 36 : 0;
      _chart.notifyDataSetChanged();
      _chart.invalidate();
    }),
    DemoMenuItem('Toggle Hole', () {
      _chart.isDrawHoleEnabled = !_chart.isDrawHoleEnabled;
      _chart.invalidate();
    }),
    DemoMenuItem('Toggle Curved Slices', () {
      final toSet = !_chart.isDrawRoundedSlicesEnabled || !_chart.isDrawHoleEnabled;
      _chart.isDrawRoundedSlicesEnabled = toSet;
      if (toSet && !_chart.isDrawHoleEnabled) {
        _chart.isDrawHoleEnabled = true;
      }
      if (toSet && _chart.isDrawSlicesUnderHoleEnabled) {
        _chart.isDrawSlicesUnderHoleEnabled = false;
      }
      _chart.invalidate();
    }),
    DemoMenuItem('Draw Center Text', () {
      _chart.isDrawCenterTextEnabled = !_chart.isDrawCenterTextEnabled;
      _chart.invalidate();
    }),
    DemoMenuItem(
      'Spin Animation',
      () => _chart.spin(1000, _chart.rotationAngle, _chart.rotationAngle + 360, easing: Easing.EaseInOutCubic),
    ),
    DemoMenuItem('Animate X', () => _chart.animateX(1400)),
    DemoMenuItem('Animate Y', () => _chart.animateY(1400)),
    DemoMenuItem('Animate XY', () => _chart.animateXY(1400, 1400)),
  ];

  @override
  Widget build(BuildContext context) => DemoScaffold(
    title: 'Value Lines',
    menu: _menu,
    body: Column(
      children: [
        Expanded(
          child: ChartHostWidget<PieChartView, PieData>(
            chart: _chart,
            data: _chart.data,
            setup: (chart) => chart.animateY(1400, easing: Easing.EaseInOutQuad),
          ),
        ),
        DemoSeekBar(
          progress: _seekBar1,
          max: 25,
          onProgressChanged: (progress) => setState(() {
            _seekBar1 = progress;
            _onProgressChanged();
          }),
        ),
        DemoSeekBar(
          progress: _seekBar2,
          max: 200,
          onProgressChanged: (progress) => setState(() {
            _seekBar2 = progress;
            _onProgressChanged();
          }),
        ),
      ],
    ),
  );
}
