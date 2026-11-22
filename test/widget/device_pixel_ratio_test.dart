// Not a port of a Kotlin test: the chart widgets give Utils.devicePixelRatio the ratio of their view before the
// chart's first layout, so the offsets of the first painted frame are rounded on that view's device px grid (as
// Kotlin's Int px are), and lay the chart out again when the ratio changes.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart/src/charts/line_chart.dart' as core;

LineData _data() => LineData([
  LineDataSet([
    Entry(x: 0, y: 1),
    Entry(x: 1, y: 30),
    Entry(x: 2, y: 200),
  ], 'a'),
]);

/// The content rectangle of a chart laid out without a widget at [ratio].
List<double> _offline(double ratio) {
  final previous = Utils.devicePixelRatio;
  Utils.devicePixelRatio = ratio;
  final chart = core.LineChart()..data = _data();
  chart.onSizeChanged(400, 300);
  final r = chart.viewPortHandler.contentRect;
  Utils.devicePixelRatio = previous;
  return [r.left, r.top, r.right, r.bottom];
}

void main() {
  tearDown(() => Utils.devicePixelRatio = 1.0);

  Widget host(double ratio, void Function(core.LineChart) setup) => MediaQuery(
    data: MediaQueryData(devicePixelRatio: ratio),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 400,
          height: 300,
          child: LineChart(data: _data(), setup: setup),
        ),
      ),
    ),
  );

  testWidgets(
    'the first frame is laid out at the MediaQuery ratio, and a new ratio lays it out again',
    (tester) async {
      final at1 = _offline(1.0);
      final at2625 = _offline(2.625);
      expect(at2625, isNot(at1), reason: 'the ratio must matter here');

      late core.LineChart chart;
      final painted = <List<double>>[];
      void setup(core.LineChart c) {
        chart = c;
        c.afterDrawListeners.add(() {
          final r = c.viewPortHandler.contentRect;
          painted.add([r.left, r.top, r.right, r.bottom]);
        });
      }

      await tester.pumpWidget(host(2.625, setup));
      expect(Utils.devicePixelRatio, 2.625);
      expect(painted, isNotEmpty);
      expect(painted.first, at2625);

      painted.clear();
      await tester.pumpWidget(host(1.0, setup));
      expect(Utils.devicePixelRatio, 1.0);
      final r = chart.viewPortHandler.contentRect;
      expect([r.left, r.top, r.right, r.bottom], at1);
      expect(painted, isNotEmpty);
      expect(painted.last, at1);
    },
  );

  testWidgets('without a MediaQuery the view\'s ratio is used', (tester) async {
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 400,
            height: 300,
            child: LineChart(data: _data()),
          ),
        ),
      ),
    );
    expect(Utils.devicePixelRatio, 2.625);
  });
}
