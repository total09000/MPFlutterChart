// Not a port of a Kotlin test: MPAndroidChart v4.0.1 has no unit test for highlight/Highlight.kt (HighlighterTest
// covers the highlighters, Task 10). Checks the four constructors, equalTo and setDraw against the Kotlin source.
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/components/y_axis_dependency.dart';
import 'package:mp_flutter_chart/src/highlight/highlight.dart';

void main() {
  test('value-only highlight has no pixels, no axis and is not stacked', () {
    final h = Highlight(2, 5, 1);
    expect(h.x, 2);
    expect(h.y, 5);
    expect(h.dataSetIndex, 1);
    expect(h.dataIndex, -1);
    expect(h.stackIndex, -1);
    expect(h.isStacked, isFalse);
    expect(h.xPx, 0);
    expect(h.yPx, 0);
    expect(h.axis, isNull);
    expect(Highlight(2, 5, 1, 3).dataIndex, 3);
  });

  test('stacked highlight has a NaN y', () {
    final h = Highlight.stacked(4, 0, 2);
    expect(h.y.isNaN, isTrue);
    expect(h.stackIndex, 2);
    expect(h.isStacked, isTrue);
  });

  test('pixel highlights keep position and axis', () {
    final h = Highlight.withPixels(1, 2, 30, 40, 0, AxisDependency.RIGHT);
    expect(h.xPx, 30);
    expect(h.yPx, 40);
    expect(h.axis, AxisDependency.RIGHT);
    expect(h.stackIndex, -1);

    final s = Highlight.stackedWithPixels(
      1,
      2,
      30,
      40,
      0,
      1,
      AxisDependency.LEFT,
    );
    expect(s.stackIndex, 1);
    expect(s.axis, AxisDependency.LEFT);
    expect(s.isStacked, isTrue);
  });

  test('equalTo compares data set, x, stack and data index but not y', () {
    final h = Highlight(1, 2, 0);
    expect(h.equalTo(Highlight(1, 99, 0)), isTrue);
    expect(h.equalTo(Highlight(1, 2, 1)), isFalse);
    expect(h.equalTo(Highlight(1.5, 2, 0)), isFalse);
    expect(h.equalTo(Highlight(1, 2, 0, 4)), isFalse);
    expect(h.equalTo(Highlight.stacked(1, 0, 0)), isFalse);
    expect(h.equalTo(null), isFalse);
  });

  test('setDraw records the drawn position', () {
    final h = Highlight(0, 0, 0)..setDraw(12, 34);
    expect(h.drawX, 12);
    expect(h.drawY, 34);
    expect(
      h.toString(),
      'Highlight, x: 0.0, y: 0.0, dataSetIndex: 0, stackIndex (only stacked barentry): -1',
    );
  });
}
