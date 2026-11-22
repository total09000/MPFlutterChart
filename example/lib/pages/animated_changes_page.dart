// Ported from MPChartExample: AnimatedChangesActivity.kt, with res/layout/activity_animated_changes.xml.
//
// Animated data changes: a bar chart of eight random values. Randomize, Add and Remove change the values and animate
// the new data in with animateDataChange; tapping a bar animates just that bar to a new value with animateValue.
// Kotlin's unseeded `Random.nextInt(10, 100)` is `random.nextInt(90) + 10` on the page's seeded generator. The
// Activity sets no chart background, so the window background shows behind the chart, and its Buttons show their
// text in capitals, as AppCompat's do. The Activity has no options menu, so the page shows no overflow button.
// Not ported: `saveToGallery` (see notimportant/demo_base.dart).
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../notimportant/demo_base.dart';

/// AnimatedChangesActivity.
class AnimatedChangesPage extends StatefulWidget {
  const AnimatedChangesPage({super.key});

  @override
  State<AnimatedChangesPage> createState() => _AnimatedChangesPageState();
}

class _AnimatedChangesPageState extends State<AnimatedChangesPage> with DemoBase {
  /// `binding.chart1`.
  final BarChartView _chart = BarChartView();

  /// `values`, eight random values to start with.
  late final List<double> _values = List.generate(8, (_) => _randomValue());

  @override
  void initState() {
    super.initState();

    _chart
      ..description.isEnabled = false
      ..legend.isEnabled = false
      ..isDrawGridBackgroundEnabled = false
      ..xAxis.position = XAxisPosition.BOTTOM
      ..xAxis.isDrawGridLinesEnabled = false
      ..xAxis.granularity = 1
      ..axisLeft.axisMinimum = 0
      ..axisRight.isEnabled = false
      ..data = _barData()
      ..onValueSelected((entry, _) {
        final index = entry.x.toInt();
        _values[index] = _randomValue();
        _chart.animateValue(entry, _values[index], 600, easing: Easing.EaseInOutCubic);
      });
  }

  void _randomize() {
    for (var i = 0; i < _values.length; i++) {
      _values[i] = _randomValue();
    }
    _animate();
  }

  void _add() {
    _values.add(_randomValue());
    _animate();
  }

  void _remove() {
    if (_values.length > 1) _values.removeLast();
    _animate();
  }

  void _animate() {
    _chart.animateDataChange(_barData(), 600, easing: Easing.EaseInOutCubic);
  }

  BarData _barData() {
    final set = BarDataSet([
      for (var i = 0; i < _values.length; i++) BarEntry(x: i.toDouble(), y: _values[i]),
    ], 'Values')
      ..colors = ColorTemplate.MATERIAL_COLORS.toList()
      ..valueTextSize = 10;
    return BarData([set])..barWidth = 0.7;
  }

  /// `Random.nextInt(10, 100)`.
  double _randomValue() => (random.nextInt(90) + 10).toDouble();

  Widget _button(String text, VoidCallback onPressed) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      // An AppCompat button pads its text by 8dp, which keeps "RANDOMIZE" on one line in a third of a phone's width.
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
        onPressed: onPressed,
        child: Text(text.toUpperCase(), maxLines: 1, softWrap: false),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => DemoScaffold(
    title: 'Animated data changes',
    body: Column(
      children: [
        Expanded(child: ChartHostWidget<BarChartView, BarData>(chart: _chart, data: _chart.data)),
        const Padding(
          padding: EdgeInsets.all(8),
          child: SizedBox(
            width: double.infinity,
            child: Text('Tap a bar to animate it to a new value.', textAlign: TextAlign.center),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              _button('Randomize', _randomize),
              _button('Add', _add),
              _button('Remove', _remove),
            ],
          ),
        ),
      ],
    ),
  );
}
