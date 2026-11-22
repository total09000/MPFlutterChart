// Not a port of a Kotlin test: MPAndroidChart has no unit test for TransformerHorizontalBarChart.kt or
// HorizontalViewPortHandler.kt. Locks the offset matrix of the horizontal bar chart, which mirrors an inverted axis
// along x instead of y, on a viewport handler of the horizontal bar chart.
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/utils/horizontal_view_port_handler.dart';
import 'package:mp_flutter_chart/src/utils/mp_point_d.dart';
import 'package:mp_flutter_chart/src/utils/transformer.dart';
import 'package:mp_flutter_chart/src/utils/transformer_horizontal_bar_chart.dart';
import 'package:mp_flutter_chart/src/utils/view_port_handler.dart';

/// A 400x300 chart with offsets (10, 20, 30, 40): content rect (10, 20, 370, 260), 360x240.
ViewPortHandler _handler() => HorizontalViewPortHandler()
  ..setChartDimens(400, 300)
  ..restrainViewPort(10, 20, 30, 40);

/// Values 0..10 along the transformer's x and 0..4 along its y, spread over the content rect.
TransformerHorizontalBarChart _transformer(
  ViewPortHandler h, {
  bool inverted = false,
}) => TransformerHorizontalBarChart(h)
  ..prepareMatrixValuePx(0, 10, 4, 0)
  ..prepareMatrixOffset(inverted);

void _expectPoint(MPPointD p, double x, double y) {
  expect(p.x, closeTo(x, 1e-4));
  expect(p.y, closeTo(y, 1e-4));
}

void main() {
  test(
    'HorizontalViewPortHandler is a ViewPortHandler that behaves the same',
    () {
      final h = _handler();
      expect(h, isA<ViewPortHandler>());
      expect(h.contentLeft, 10);
      expect(h.contentTop, 20);
      expect(h.contentRight, 370);
      expect(h.contentBottom, 260);
    },
  );

  test('without inversion the offset matrix is the one of Transformer', () {
    final h = _handler();
    final t = _transformer(h);
    _expectPoint(t.getPixelForValues(0, 0), h.contentLeft, h.contentBottom);
    _expectPoint(t.getPixelForValues(10, 4), h.contentRight, h.contentTop);

    final plain = Transformer(h)
      ..prepareMatrixValuePx(0, 10, 4, 0)
      ..prepareMatrixOffset(false);
    expect(t.offsetMatrix.values, plain.offsetMatrix.values);
  });

  test('an inverted axis mirrors the values along x and keeps y', () {
    final h = _handler();
    final t = _transformer(h, inverted: true);
    _expectPoint(t.getPixelForValues(0, 0), h.contentRight, h.contentBottom);
    _expectPoint(t.getPixelForValues(10, 4), h.contentLeft, h.contentTop);
    _expectPoint(t.getPixelForValues(2.5, 1), 280, 200);

    // The touch conversion inverts the same mapping.
    final values = t.getValuesByTouchPoint(280, 200);
    _expectPoint(values, 2.5, 1);
  });

  test('preparing again without inversion resets the mirrored matrix', () {
    final h = _handler();
    final t = _transformer(h, inverted: true)..prepareMatrixOffset(false);
    _expectPoint(t.getPixelForValues(0, 0), h.contentLeft, h.contentBottom);
    _expectPoint(t.getPixelForValues(10, 4), h.contentRight, h.contentTop);
  });
}
