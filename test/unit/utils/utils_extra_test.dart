// Tests for Utils members the Kotlin UtilsTest does not cover (text measuring and drawing, nextUp, rounding); no
// Kotlin counterpart.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/graphics/chart_drawable.dart';
import 'package:mp_flutter_chart/src/graphics/chart_paint.dart';
import 'package:mp_flutter_chart/src/graphics/text_measure.dart';
import 'package:mp_flutter_chart/src/utils/f_size.dart';
import 'package:mp_flutter_chart/src/utils/mp_point_f.dart';
import 'package:mp_flutter_chart/src/utils/utils.dart';

/// Draws [draw] into a [width]×[height] image and returns its RGBA bytes.
Future<ByteData> _render(
  int width,
  int height,
  void Function(ui.Canvas canvas) draw,
) async {
  final recorder = ui.PictureRecorder();
  draw(ui.Canvas(recorder));
  final image = recorder.endRecording().toImageSync(width, height);
  final bytes = (await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  ))!;
  image.dispose();
  return bytes;
}

/// The bounding box of the pixels with any alpha, or null if there are none.
ui.Rect? _ink(ByteData bytes, int width, int height) {
  int? l, t, r, b;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (bytes.getUint8((y * width + x) * 4 + 3) == 0) continue;
      l = l == null || x < l ? x : l;
      t ??= y;
      r = r == null || x + 1 > r ? x + 1 : r;
      b = y + 1;
    }
  }
  if (l == null) return null;
  return ui.Rect.fromLTRB(
    l.toDouble(),
    t!.toDouble(),
    r!.toDouble(),
    b!.toDouble(),
  );
}

void main() {
  setUp(TextMeasure.clearCache);

  group('text measuring', () {
    final paint = ChartPaint()..textSize = 10;

    test(
      'calcTextWidth / calcTextHeight / calcTextSize use measureText and getTextBounds',
      () {
        final bounds = paint.getTextBounds('AB');
        expect(
          Utils.calcTextWidth(paint, 'AB'),
          paint.measureText('AB').toInt(),
        );
        expect(Utils.calcTextHeight(paint, 'AB'), bounds.height().toInt());
        final size = Utils.calcTextSize(paint, 'AB');
        expect(size, FSize(bounds.width(), bounds.height()));
        final out = FSize(0, 0);
        expect(identical(Utils.calcTextSize(paint, 'AB', out), out), isTrue);
        expect(out, size);
      },
    );

    test(
      'getLineHeight is descent - ascent, getLineSpacing ascent - top + bottom',
      () {
        final fm = paint.getFontMetrics();
        expect(Utils.getLineHeight(paint), fm.descent - fm.ascent);
        expect(Utils.getLineSpacing(paint), fm.ascent - fm.top + fm.bottom);
        final buffer = FontMetrics();
        Utils.getLineHeight(paint, buffer);
        expect(buffer.ascent, fm.ascent);
      },
    );
  });

  group('numbers', () {
    test('formatNumber saturates like Kotlin roundToLong', () {
      expect(Utils.formatNumber(1e30, 0, false), '9223372036854775807');
      expect(Utils.formatNumber(1234.5, 1, true), '1.234,5');
      expect(Utils.formatNumber(0.5, 0, false), '01');
    });

    test(
      'roundToNextSignificant rounds ties towards positive infinity, like Math.round',
      () {
        expect(Utils.roundToNextSignificant(0.25), closeTo(0.3, 1e-6));
        expect(Utils.roundToNextSignificant(-0.25), closeTo(-0.2, 1e-6));
        expect(Utils.roundToNextSignificant(double.nan), 0);
        expect(Utils.roundToNextSignificant(double.infinity), 0);
      },
    );

    test('roundToNextSignificant keeps the Float precision of Kotlin', () {
      // 1 / 0.001f in Float.
      expect(Utils.roundToNextSignificant(1234), 999.9999389648438);
      // 10^-49 underflows to 0f, so Kotlin returns 0 / 0f.
      expect(Utils.roundToNextSignificant(1e50).isNaN, isTrue);
    });

    test('getDecimals', () {
      expect(Utils.getDecimals(0), 0);
      expect(Utils.getDecimals(100), 0);
      expect(Utils.getDecimals(5), 2);
      expect(Utils.getDecimals(0.02), 4);
      expect(Utils.getDecimals(double.infinity), 0);
    });

    test('getNormalizedAngle stays in [0, 360) for tiny negative angles', () {
      expect(Utils.getNormalizedAngle(-1e-20), 0);
      expect(Utils.getNormalizedAngle(720), 0);
      expect(Utils.getNormalizedAngle(double.nan).isNaN, isTrue);
    });

    test('nextUp', () {
      expect(Utils.nextUp(1.0), 1.0000000000000002);
      expect(Utils.nextUp(-1.0), -0.9999999999999999);
      expect(Utils.nextUp(0.0), double.minPositive);
      expect(Utils.nextUp(-0.0), double.minPositive);
      expect(Utils.nextUp(double.infinity), double.infinity);
      expect(Utils.nextUp(double.negativeInfinity), -double.maxFinite);
      expect(Utils.nextUp(-double.minPositive), -0.0);
      expect(Utils.nextUp(4294967295.9999995), 4294967296.0);
    });

    test('constants', () {
      expect(Utils.DEG2RAD, closeTo(0.017453292519943295, 1e-18));
      expect(Utils.FDEG2RAD, closeTo(0.017453292, 1e-9));
      expect(Utils.FLOAT_EPSILON, 1.401298464324817e-45);
      expect(Utils.DOUBLE_EPSILON, double.minPositive);
      expect(Utils.minimumFlingVelocity, 50);
      expect(Utils.maximumFlingVelocity, 8000);
    });
  });

  group('geometry', () {
    test('getPosition measures the angle clockwise from 3 o\'clock', () {
      final center = MPPointF(10, 10);
      final p = Utils.getPosition(center, 5, 90);
      expect(p.x, closeTo(10, 1e-4));
      expect(p.y, closeTo(15, 1e-4));
      final out = MPPointF();
      expect(identical(Utils.getPosition(center, 5, 0, out), out), isTrue);
      expect(out.x, closeTo(15, 1e-4));
      expect(out.y, closeTo(10, 1e-4));
    });

    test('getSizeOfRotatedRectangle', () {
      final s = Utils.getSizeOfRotatedRectangleByDegrees(10, 20, 90);
      expect(s.width, closeTo(20, 1e-4));
      expect(s.height, closeTo(10, 1e-4));
      final r = Utils.getSizeOfRotatedRectangleByRadians(10, 20, 0);
      expect([r.width, r.height], [10, 20]);
      final f = Utils.getSizeOfRotatedRectangleByDegreesFromSize(
        FSize(10, 20),
        90,
      );
      expect(f.width, closeTo(20, 1e-4));
      final g = Utils.getSizeOfRotatedRectangleByRadiansFromSize(
        FSize(10, 20),
        0,
      );
      expect([g.width, g.height], [10, 20]);
    });
  });

  group('drawing', () {
    test('drawImage centers the drawable on (x, y)', () async {
      final drawable = PainterDrawable(
        (c, size) => c.drawRect(
          ui.Offset.zero & size,
          ui.Paint()..color = const ui.Color(0xFF00FF00),
        ),
        width: 1,
        height: 1,
      );
      final bytes = await _render(
        20,
        20,
        (c) => Utils.drawImage(c, drawable, 10, 10, 4, 6),
      );
      expect(_ink(bytes, 20, 20), const ui.Rect.fromLTRB(8, 7, 12, 13));
    });

    test('drawImage restores the canvas', () {
      final c = ui.Canvas(ui.PictureRecorder());
      final drawable = PainterDrawable((c, s) {}, width: 1, height: 1);
      Utils.drawImage(c, drawable, 10, 10, 4, 6);
      expect(c.getSaveCount(), 1);
      expect(c.getTransform()[12], 0);
    });

    test('drawXAxisValue places the text box by its anchor', () async {
      final paint = ChartPaint()
        ..textSize = 10
        ..textAlign = PaintAlign.RIGHT;
      final width = paint.measureText('AB');
      final lineHeight = paint.getFontSpacing();

      // Anchor (0, 0): the top left of the line box sits on (x, y).
      var bytes = await _render(
        60,
        60,
        (c) => Utils.drawXAxisValue(c, 'AB', 20, 20, paint, MPPointF(0, 0), 0),
      );
      var ink = _ink(bytes, 60, 60)!;
      expect(ink.left, closeTo(20, 1));
      expect(ink.top, greaterThanOrEqualTo(20));
      expect(ink.bottom, lessThanOrEqualTo(20 + lineHeight + 1));
      expect(paint.textAlign, PaintAlign.RIGHT);

      // Anchor (1, 1): the bottom right of the line box sits on (x, y).
      bytes = await _render(
        60,
        60,
        (c) => Utils.drawXAxisValue(c, 'AB', 40, 40, paint, MPPointF(1, 1), 0),
      );
      ink = _ink(bytes, 60, 60)!;
      expect(ink.right, closeTo(40, 1));
      expect(ink.left, closeTo(40 - width, 1));
      expect(ink.bottom, lessThanOrEqualTo(41));
    });

    test(
      'drawXAxisValue rotated by 90 degrees around a centered anchor',
      () async {
        final paint = ChartPaint()..textSize = 10;
        final width = paint.measureText('ABCD');
        final bytes = await _render(
          80,
          80,
          (c) => Utils.drawXAxisValue(
            c,
            'ABCD',
            40,
            40,
            paint,
            MPPointF(0.5, 0.5),
            90,
          ),
        );
        final ink = _ink(bytes, 80, 80)!;
        // The text now runs downwards: tall and narrow, centered on (40, 40).
        expect(ink.height, closeTo(width, 1));
        expect(ink.width, lessThanOrEqualTo(paint.getFontSpacing() + 1));
        expect(ink.center.dy, closeTo(40, 1));
        expect(ink.center.dx, closeTo(40, 3));
      },
    );

    test(
      'drawXAxisValue rotated with an off-center anchor shifts by the rotated size',
      () async {
        final paint = ChartPaint()..textSize = 10;
        final width = paint.measureText('ABCD');
        final bytes = await _render(
          80,
          80,
          (c) => Utils.drawXAxisValue(
            c,
            'ABCD',
            40,
            20,
            paint,
            MPPointF(0.5, 0),
            90,
          ),
        );
        final ink = _ink(bytes, 80, 80)!;
        // Anchor y 0: the top of the rotated box sits on y.
        expect(ink.top, closeTo(20, 1));
        expect(ink.bottom, closeTo(20 + width, 1));
      },
    );

    test('drawMultilineText wraps within the constrained width', () async {
      final paint = ChartPaint()..textSize = 10;
      final lineHeight = paint.getFontSpacing();
      final bytes = await _render(
        100,
        100,
        (c) => Utils.drawMultilineText(
          c,
          'AAAA AAAA AAAA',
          10,
          10,
          paint,
          FSize(45, 0),
          MPPointF(0, 0),
          0,
        ),
      );
      final ink = _ink(bytes, 100, 100)!;
      expect(ink.width, lessThanOrEqualTo(45));
      // Three lines; like Kotlin, the block is drawn drawHeight (= 3 line heights) below y for anchor (0, 0).
      expect(ink.top, closeTo(10 + 3 * lineHeight, 1));
      expect(ink.height, closeTo(3 * lineHeight, 1));
      expect(ink.left, closeTo(10, 1));
    });
  });
}
