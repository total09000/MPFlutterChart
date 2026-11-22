// Not a port of a Kotlin test: MPAndroidChart v4.0.1 has no unit test for highlight/Range.kt or
// highlight/IHighlighter.kt. Checks Range's bounds (from excluded, to included) and IHighlighter.fromFunction.
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/highlight/highlight.dart';
import 'package:mp_flutter_chart/src/highlight/i_highlighter.dart';
import 'package:mp_flutter_chart/src/highlight/range.dart';

void main() {
  test('Range excludes from and includes to', () {
    final r = Range(1, 3);
    expect(r.contains(1), isFalse);
    expect(r.contains(2), isTrue);
    expect(r.contains(3), isTrue);
    expect(r.contains(3.0001), isFalse);
    expect(r.contains(double.nan), isFalse);
  });

  test('Range isLarger / isSmaller compare against to / from', () {
    final r = Range(1, 3);
    expect(r.isLarger(3), isFalse);
    expect(r.isLarger(3.5), isTrue);
    expect(r.isSmaller(1), isFalse);
    expect(r.isSmaller(0.5), isTrue);
    expect(r.isLarger(double.nan), isFalse);
    expect(r.isSmaller(double.nan), isFalse);
  });

  test('Range bounds are mutable', () {
    final r = Range(0, 1)
      ..from = 5
      ..to = 6;
    expect(r.from, 5);
    expect(r.to, 6);
    expect(r.contains(5.5), isTrue);
  });

  test('IHighlighter.fromFunction forwards to the function', () {
    final calls = <(double, double)>[];
    final highlighter = IHighlighter.fromFunction((x, y) {
      calls.add((x, y));
      return x > 0 ? Highlight(x, y, 0) : null;
    });
    final h = highlighter.getHighlight(2, 3);
    expect(h?.x, 2);
    expect(h?.y, 3);
    expect(highlighter.getHighlight(-1, 0), isNull);
    expect(calls, [(2.0, 3.0), (-1.0, 0.0)]);
  });
}
