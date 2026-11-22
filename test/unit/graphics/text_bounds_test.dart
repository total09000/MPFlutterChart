// Not a port of a Kotlin test: checks ChartPaint.getTextBounds (approximate ink bounds from Roboto's glyph extents)
// and the rounding of text measurement on the device px grid (Utils.devicePixelRatio) against the numbers Android's
// Paint.getTextBounds and Paint.measureText give for Roboto at 10 dp on a 2.625 density screen. Horizontal edges
// depend on the advance, which flutter_test takes from its own test font, so widths are checked against the raw
// advance of the laid out text; heights, tops, bottoms and lefts come from the glyph table alone.
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/graphics/chart_paint.dart';
import 'package:mp_flutter_chart/src/graphics/text_measure.dart';
import 'package:mp_flutter_chart/src/utils/utils.dart';

/// Roboto font units per em.
const double _em = 2048;

/// The advance of [text] as Flutter lays it out, unrounded.
double _raw(ChartPaint paint, String text) =>
    TextMeasure.layout(text, paint.textStyle).width;

/// [logical] in device px at [ratio], which must be a whole number.
int _dev(double logical, double ratio) {
  final d = logical * ratio;
  expect(d, closeTo(d.roundToDouble(), 1e-6), reason: '$logical on the grid');
  return d.round();
}

void main() {
  tearDown(() => Utils.devicePixelRatio = 1.0);

  final paint = ChartPaint()..textSize = 10;

  /// Device px of the bounds of [text]: left, top, right, bottom.
  List<int> bounds(String text, double ratio) {
    Utils.devicePixelRatio = ratio;
    final r = paint.getTextBounds(text);
    return [
      _dev(r.left, ratio),
      _dev(r.top, ratio),
      _dev(r.right, ratio),
      _dev(r.bottom, ratio),
    ];
  }

  /// The right edge Android computes: the raw advance less the right side bearing of the last glyph, in font units,
  /// rounded up in device px.
  int right(String text, int rightBearing, double ratio) =>
      ((_raw(paint, text) - rightBearing * 10 / _em) * ratio).ceil();

  group('getTextBounds at 2.625 (Kotlin on a 420 dpi screen)', () {
    const r = 2.625;

    test('"Q" is (1, -19, …, 4), 23 px high', () {
      final b = bounds('Q', r);
      expect([b[0], b[1], b[3]], [1, -19, 4]);
      expect(b[3] - b[1], 23);
      expect(b[2], right('Q', 1409 - 1286, r));
    });

    test('"80" is (1, -19, …, 1), 20 px high', () {
      final b = bounds('80', r);
      expect([b[0], b[1], b[3]], [1, -19, 1]);
      expect(b[3] - b[1], 20);
      expect(b[2], right('80', 1151 - 1035, r));
    });

    test('"100" is (2, -19, …, 1)', () {
      final b = bounds('100', r);
      expect([b[0], b[1], b[3]], [2, -19, 1]);
      expect(b[2], right('100', 1151 - 1035, r));
    });

    test(
      '"0" spans its ink: left bearing 1 px, right bearing off the advance',
      () {
        final b = bounds('0', r);
        expect(b[0], 1);
        expect(b[2], right('0', 1151 - 1035, r));
      },
    );

    test('"ABC" is (0, -19, …, 1)', () {
      final b = bounds('ABC', r);
      expect([b[0], b[1], b[3]], [0, -19, 1]);
      expect(b[2], right('ABC', 1333 - 1240, r));
    });

    test('"A" is 19 px high', () {
      final b = bounds('A', r);
      expect(b[3] - b[1], 19);
      expect(b[3], 0);
    });

    test('a descender reaches below the baseline', () {
      // "g": yMin -427, yMax 1102; with "A" the top is A's.
      expect(bounds('g', r)[3], 6);
      expect(bounds('g', r)[1], -15);
      final b = bounds('Ag', r);
      expect([b[1], b[3]], [-19, 6]);
    });

    test(
      'leading and trailing spaces move the left edge and do not count on the right',
      () {
        final b = bounds(' 80 ', r);
        // The space's advance (Flutter's) plus the bearing of "8", rounded down.
        expect(b[0], ((_raw(paint, ' ') + 113 * 10 / _em) * r).floor());
        expect(b[2], right(' 80', 1151 - 1035, r));
        expect([b[1], b[3]], [-19, 1]);
      },
    );
  });

  group('getTextBounds at 1.0 (whole logical px)', () {
    const r = 1.0;

    test('"Q", "80", "100", "ABC", "A"', () {
      // Q: yMax 1476 → -7.21, yMin -246 → 1.20; digits and C: yMin -20 → 0.10; A: 0.
      expect(bounds('Q', r), [0, -8, right('Q', 123, r), 2]);
      expect(bounds('80', r), [0, -8, right('80', 116, r), 1]);
      expect(bounds('100', r), [0, -8, right('100', 116, r), 1]);
      expect(bounds('ABC', r), [0, -8, right('ABC', 93, r), 1]);
      final a = bounds('A', r);
      expect(a[3] - a[1], 8);
    });

    test('a descender', () {
      expect(bounds('g', r)[3], 3);
    });

    test('leading and trailing spaces', () {
      final b = bounds(' 80 ', r);
      expect(b[0], (_raw(paint, ' ') + 113 * 10 / _em).floor());
      expect(b[2], right(' 80', 116, r));
    });
  });

  group('getTextBounds outside the table', () {
    test('CJK text is the line box, as before', () {
      final fm = paint.getFontMetrics();
      for (final text in ['中文', '😀', '中😀']) {
        Utils.devicePixelRatio = 1.0;
        final b = paint.getTextBounds(text);
        final raw = _raw(paint, text);
        // What getTextBounds returned before ink bounds: the line box in whole logical px.
        expect(
          [b.left, b.top, b.right, b.bottom],
          [
            0,
            fm.ascent.floorToDouble(),
            raw.ceilToDouble(),
            fm.descent.ceilToDouble(),
          ],
          reason: text,
        );

        // On a finer grid it still holds the unrounded line box.
        Utils.devicePixelRatio = 2.625;
        final f = paint.getTextBounds(text);
        expect(f.left, lessThanOrEqualTo(0), reason: text);
        expect(f.top, lessThanOrEqualTo(fm.ascent), reason: text);
        expect(f.right, greaterThanOrEqualTo(raw), reason: text);
        expect(f.bottom, greaterThanOrEqualTo(fm.descent), reason: text);
      }
    });

    test('a glyph outside the table keeps the line box for itself only', () {
      Utils.devicePixelRatio = 1.0;
      final fm = paint.getFontMetrics();
      final b = paint.getTextBounds('A中');
      expect(b.top, fm.ascent.floorToDouble());
      expect(b.bottom, fm.descent.ceilToDouble());
      expect(b.right, _raw(paint, 'A中').ceilToDouble());
    });
  });

  test('empty and all-space text give the empty rectangle at the origin', () {
    for (final ratio in [1.0, 2.625]) {
      Utils.devicePixelRatio = ratio;
      for (final text in ['', ' ', '   ', ' ']) {
        final b = paint.getTextBounds(text);
        expect([b.left, b.top, b.right, b.bottom], [0, 0, 0, 0], reason: text);
      }
    }
  });

  group('measureText rounds up on the device grid', () {
    test('at 2.625 and at 1.0', () {
      for (final text in ['80', '100', 'Q', 'ABC']) {
        final raw = _raw(paint, text);
        Utils.devicePixelRatio = 2.625;
        expect(
          paint.measureText(text),
          closeTo((raw * 2.625).ceil() / 2.625, 1e-9),
          reason: text,
        );
        Utils.devicePixelRatio = 1.0;
        expect(paint.measureText(text), raw.ceilToDouble(), reason: text);
      }
      expect(paint.measureText(''), 0);
    });

    test('the result is whole device px', () {
      Utils.devicePixelRatio = 2.625;
      for (final text in ['1', '22', 'WWW', 'a b']) {
        _dev(paint.measureText(text), 2.625);
      }
    });
  });

  group('Utils.calcTextWidth and calcTextHeight', () {
    test('at 2.625', () {
      Utils.devicePixelRatio = 2.625;
      expect(
        Utils.calcTextWidth(paint, '100'),
        closeTo((_raw(paint, '100') * 2.625).ceil() / 2.625, 1e-9),
      );
      expect(Utils.calcTextHeight(paint, 'Q'), closeTo(23 / 2.625, 1e-9));
      expect(Utils.calcTextHeight(paint, '80'), closeTo(20 / 2.625, 1e-9));
      expect(Utils.calcTextHeight(paint, 'A'), closeTo(19 / 2.625, 1e-9));
      final size = Utils.calcTextSize(paint, 'Q');
      expect(size.height, closeTo(23 / 2.625, 1e-9));
    });

    test('at 1.0', () {
      Utils.devicePixelRatio = 1.0;
      expect(
        Utils.calcTextWidth(paint, '100'),
        _raw(paint, '100').ceilToDouble(),
      );
      expect(Utils.calcTextHeight(paint, 'Q'), 10);
      expect(Utils.calcTextHeight(paint, '80'), 9);
      expect(Utils.calcTextHeight(paint, 'A'), 8);
    });
  });
}
