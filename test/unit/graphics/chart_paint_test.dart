// Tests for the android.graphics.Paint / Typeface / Canvas shims; no Kotlin counterpart.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/graphics/chart_canvas.dart';
import 'package:mp_flutter_chart/src/graphics/chart_paint.dart';
import 'package:mp_flutter_chart/src/graphics/mutable_rect.dart';
import 'package:mp_flutter_chart/src/graphics/text_measure.dart';
import 'package:mp_flutter_chart/src/graphics/typeface.dart';

void main() {
  setUp(TextMeasure.clearCache);

  group('ChartPaint', () {
    test('alpha writes the alpha of color and keeps r, g, b', () {
      final paint = ChartPaint()
        ..color = const Color(0xFF112233)
        ..alpha = 128;
      expect(paint.alpha, 128);
      expect((paint.color.a * 255).round(), 128);
      expect(paint.color.toARGB32() & 0x00FFFFFF, 0x112233);
    });

    test('setting color replaces the alpha, like Android', () {
      final paint = ChartPaint()..alpha = 10;
      paint.color = const Color(0xFF000000);
      expect(paint.alpha, 255);
    });

    test('Android defaults', () {
      final paint = ChartPaint();
      expect(paint.color.toARGB32(), 0xFF000000);
      expect(paint.style, PaintStyle.FILL);
      expect(paint.strokeWidth, 0);
      expect(paint.textAlign, PaintAlign.LEFT);
      expect(paint.textSize, 12);
      expect(paint.typeface, Typeface.DEFAULT);
      expect(paint.pathEffect, isNull);
      expect(paint.strokeCap, StrokeCap.butt);
      expect(paint.strokeJoin, StrokeJoin.miter);
      expect(paint.isAntiAlias, isTrue);
      expect(ChartPaint(antiAlias: false).isAntiAlias, isFalse);
    });

    test(
      'style maps to PaintingStyle; FILL_AND_STROKE fills (the stroke pass is drawn separately)',
      () {
        final paint = ChartPaint()..style = PaintStyle.STROKE;
        expect(paint.toPaint().style, PaintingStyle.stroke);
        paint.style = PaintStyle.FILL;
        expect(paint.toPaint().style, PaintingStyle.fill);
        paint.style = PaintStyle.FILL_AND_STROKE;
        expect(paint.toPaint().style, PaintingStyle.fill);
      },
    );

    test('toPaint carries the stroke and blend state', () {
      final shader = ui.Gradient.linear(Offset.zero, const Offset(1, 1), const [
        Color(0xFF000000),
        Color(0xFFFFFFFF),
      ]);
      final p =
          (ChartPaint(antiAlias: false)
                ..color = const Color(0x80FF0000)
                ..strokeWidth = 3
                ..strokeCap = StrokeCap.round
                ..strokeJoin = StrokeJoin.round
                ..shader = shader
                ..xfermode = BlendMode.srcATop)
              .toPaint();
      expect(p.color.toARGB32(), 0x80FF0000);
      expect(p.strokeWidth, 3);
      expect(p.strokeCap, StrokeCap.round);
      expect(p.strokeJoin, StrokeJoin.round);
      expect(p.shader, same(shader));
      expect(p.blendMode, BlendMode.srcATop);
      expect(p.isAntiAlias, isFalse);
      expect(ChartPaint().toPaint().blendMode, BlendMode.srcOver);
    });

    test('toPaint is rebuilt only after a setter changes state', () {
      final paint = ChartPaint();
      final first = paint.toPaint();
      expect(paint.toPaint(), same(first));
      paint.strokeWidth = 2;
      final second = paint.toPaint();
      expect(second.strokeWidth, 2);
      expect(paint.toPaint(), same(second));
    });

    test('textStyle is cached and follows color, textSize and typeface', () {
      final paint = ChartPaint()
        ..color = const Color(0xFF00FF00)
        ..textSize = 20
        ..typeface = Typeface.DEFAULT_BOLD;
      final style = paint.textStyle;
      expect(paint.textStyle, same(style));
      expect(style.color, const Color(0xFF00FF00));
      expect(style.fontSize, 20);
      expect(style.fontWeight, FontWeight.bold);
      paint.strokeWidth = 4;
      expect(paint.textStyle, same(style));
      paint.textSize = 21;
      expect(paint.textStyle.fontSize, 21);
    });

    test('typeface setter accepts null as the default typeface', () {
      final paint = ChartPaint()..typeface = Typeface.DEFAULT_BOLD;
      paint.typeface = null;
      expect(paint.typeface, Typeface.DEFAULT);
    });

    test('text styles survive value round trips (limit line replay)', () {
      final paint = ChartPaint();
      // The setter sequence of XAxisRenderer/YAxisRenderer.renderLimitLines: the line, then its label.
      void frame(Color labelColor) {
        paint
          ..style = PaintStyle.STROKE
          ..color = const Color(0xFFFF0000)
          ..strokeWidth = 2
          ..pathEffect = DashPathEffect(const [4, 2], 0);
        paint
          ..style = PaintStyle.FILL_AND_STROKE
          ..pathEffect = null
          ..color = labelColor
          ..strokeWidth = 0.5
          ..textSize = 10;
      }

      frame(const Color(0xFF000000));
      final stroke = paint.textStrokeStyle;
      final fill = paint.textStyle;
      final strokeLayout = TextMeasure.layout('Limit', stroke);
      final fillLayout = TextMeasure.layout('Limit', fill);
      final size = TextMeasure.cacheSize;

      for (var i = 0; i < 3; i++) {
        frame(const Color(0xFF000000));
        expect(paint.textStrokeStyle, same(stroke));
        expect(
          TextMeasure.layout('Limit', paint.textStrokeStyle),
          same(strokeLayout),
        );
        expect(TextMeasure.layout('Limit', paint.textStyle), same(fillLayout));
        expect(TextMeasure.cacheSize, size);
      }

      // A second limit line with another label color in the same frame does not evict the first one's style.
      frame(const Color(0xFF00FF00));
      expect(paint.textStrokeStyle, isNot(same(stroke)));
      TextMeasure.layout('Limit', paint.textStrokeStyle);
      frame(const Color(0xFF000000));
      expect(paint.textStrokeStyle, same(stroke));
      expect(
        TextMeasure.layout('Limit', paint.textStrokeStyle),
        same(strokeLayout),
      );
    });

    test('a color change gives the stroke text style a new layout', () {
      final paint = ChartPaint()
        ..style = PaintStyle.FILL_AND_STROKE
        ..strokeWidth = 0.5
        ..color = const Color(0xFFFF0000);
      final a = TextMeasure.layout('Label', paint.textStrokeStyle);
      expect(paint.textStrokeStyle.foreground!.style, PaintingStyle.stroke);
      expect(paint.textStrokeStyle.foreground!.strokeWidth, 0.5);
      paint.color = const Color(0xFF0000FF);
      final b = TextMeasure.layout('Label', paint.textStrokeStyle);
      expect(b, isNot(same(a)));
      expect(paint.textStrokeStyle.foreground!.color, const Color(0xFF0000FF));
    });

    test(
      'measureText: empty is 0, longer text is wider, larger size is wider',
      () {
        final paint = ChartPaint()..textSize = 10;
        expect(paint.measureText(''), 0);
        final one = paint.measureText('A');
        expect(one, greaterThan(0));
        expect(paint.measureText('AAAA'), greaterThan(one));
        paint.textSize = 20;
        expect(paint.measureText('A'), greaterThan(one));
      },
    );

    test(
      'getFontMetrics: ascent negative, descent positive, independent of text',
      () {
        final paint = ChartPaint()..textSize = 10;
        final fm = paint.getFontMetrics();
        expect(fm.ascent, lessThan(0));
        expect(fm.descent, greaterThan(0));
        expect(fm.top, lessThanOrEqualTo(fm.ascent));
        expect(fm.bottom, greaterThanOrEqualTo(fm.descent));
        expect(paint.ascent(), fm.ascent);
        expect(paint.descent(), fm.descent);
        expect(
          paint.getFontSpacing(),
          closeTo(fm.descent - fm.ascent + fm.leading, 1e-4),
        );

        paint.measureText('gjpqy WWW');
        final buffer = FontMetrics();
        expect(paint.getFontMetrics(buffer), same(buffer));
        expect(buffer.ascent, fm.ascent);
        expect(buffer.descent, fm.descent);

        paint.textSize = 20;
        expect(
          paint.getFontMetrics().descent - paint.getFontMetrics().ascent,
          greaterThan(fm.descent - fm.ascent),
        );
      },
    );

    test(
      'getTextBounds: empty is the zero rect, otherwise integral and within the advance of the text',
      () {
        final paint = ChartPaint()..textSize = 10;
        final empty = paint.getTextBounds('');
        expect(
          [empty.left, empty.top, empty.right, empty.bottom],
          [0, 0, 0, 0],
        );

        final out = MutableRect(1, 2, 3, 4);
        final r = paint.getTextBounds('AB', out);
        expect(r, same(out));
        for (final v in [r.left, r.top, r.right, r.bottom]) {
          expect(v, v.roundToDouble());
        }
        expect(r.left, 0);
        expect(r.top, lessThan(0));
        // "AB" has no ink below the baseline.
        expect(r.bottom, 0);
        // Ink bounds: the right side bearing of "B" is left out of the advance.
        expect(r.right, lessThanOrEqualTo(paint.measureText('AB')));
        expect(r.width(), greaterThan(0));
        expect(paint.getTextBounds('ABCD').width(), greaterThan(r.width()));
      },
    );

    test('copy is an independent snapshot', () {
      final effect = DashPathEffect(const [1, 2], 0);
      final paint = ChartPaint(antiAlias: false)
        ..color = const Color(0xFF123456)
        ..style = PaintStyle.STROKE
        ..strokeWidth = 2
        ..textAlign = PaintAlign.RIGHT
        ..textSize = 15
        ..typeface = Typeface.DEFAULT_BOLD
        ..pathEffect = effect
        ..strokeCap = StrokeCap.square
        ..strokeJoin = StrokeJoin.bevel
        ..xfermode = BlendMode.multiply;
      final c = paint.copy();
      expect(c.color, paint.color);
      expect(c.style, PaintStyle.STROKE);
      expect(c.strokeWidth, 2);
      expect(c.textAlign, PaintAlign.RIGHT);
      expect(c.textSize, 15);
      expect(c.typeface, Typeface.DEFAULT_BOLD);
      expect(c.pathEffect, same(effect));
      expect(c.strokeCap, StrokeCap.square);
      expect(c.strokeJoin, StrokeJoin.bevel);
      expect(c.xfermode, BlendMode.multiply);
      expect(c.isAntiAlias, isFalse);
      c.strokeWidth = 9;
      expect(paint.strokeWidth, 2);
      expect(paint.toPaint(), isNot(same(c.toPaint())));
    });
  });

  group('Typeface', () {
    test('DEFAULT and DEFAULT_BOLD', () {
      expect(Typeface.DEFAULT.fontFamily, isNull);
      expect(Typeface.DEFAULT.weight, FontWeight.normal);
      expect(Typeface.DEFAULT.style, FontStyle.normal);
      expect(Typeface.DEFAULT_BOLD.weight, FontWeight.bold);
    });

    test(
      'apply sets family, weight and style; null family keeps the base family',
      () {
        const base = TextStyle(fontFamily: 'Base', fontSize: 9);
        final bold = Typeface.DEFAULT_BOLD.apply(base);
        expect(bold.fontFamily, 'Base');
        expect(bold.fontWeight, FontWeight.bold);
        expect(bold.fontSize, 9);
        final custom = const Typeface(
          fontFamily: 'Mono',
          style: FontStyle.italic,
        ).apply(base);
        expect(custom.fontFamily, 'Mono');
        expect(custom.fontStyle, FontStyle.italic);
        expect(custom.fontWeight, FontWeight.normal);
      },
    );

    test('value equality', () {
      expect(const Typeface(weight: FontWeight.bold), Typeface.DEFAULT_BOLD);
      expect(
        const Typeface(weight: FontWeight.bold).hashCode,
        Typeface.DEFAULT_BOLD.hashCode,
      );
      expect(const Typeface(fontFamily: 'X'), isNot(Typeface.DEFAULT));
    });
  });

  group('DashPathEffect', () {
    test(
      'needs at least two intervals; an odd count drops the last, like Android',
      () {
        expect(() => DashPathEffect(const [1], 0), throwsArgumentError);
        expect(DashPathEffect(const [1, 2, 3], 0).intervals, [1, 2]);
        expect(DashPathEffect(const [1, 2], 3).phase, 3);
      },
    );
  });

  group('ChartCanvas', () {
    Future<ui.Image> render(
      void Function(ui.Canvas c) draw, {
      int w = 40,
      int h = 20,
    }) {
      final recorder = ui.PictureRecorder();
      final c = ui.Canvas(recorder);
      draw(c);
      return recorder.endRecording().toImage(w, h);
    }

    Future<int> alphaAt(ui.Image image, int x, int y) async {
      final data = (await image.toByteData())!;
      return data.getUint8((y * image.width + x) * 4 + 3);
    }

    test('saveCount returns getSaveCount', () {
      final c = ui.Canvas(ui.PictureRecorder());
      final n = c.saveCount();
      expect(n, c.getSaveCount());
      c.save();
      expect(c.saveCount(), n + 1);
      c.restoreToCount(n);
      expect(c.saveCount(), n);
    });

    testWidgets('drawLinesP draws count floats from offset, whole lines only', (
      tester,
    ) async {
      // Line A at y = 5, line B at y = 15, then 3 floats of a partial line at y = 25.
      final pts = Float32List.fromList([
        0, 5, 40, 5, //
        0, 15, 40, 15, //
        0, 25, 40,
      ]);
      for (final effect in [
        null,
        DashPathEffect(const [100, 1], 0),
      ]) {
        final paint = ChartPaint()
          ..strokeWidth = 2
          ..pathEffect = effect;
        Future<ui.Image> draw(int offset, int count) => tester
            .runAsync(
              () =>
                  render((c) => c.drawLinesP(pts, offset, count, paint), h: 30),
            )
            .then((i) => i!);
        Future<int> a(ui.Image i, int y) =>
            tester.runAsync(() => alphaAt(i, 20, y)).then((v) => v!);

        // From offset 4, one line: only B.
        final onlyB = await draw(4, 4);
        expect(await a(onlyB, 5), 0);
        expect(await a(onlyB, 15), greaterThan(0));

        // From offset 4, 7 floats: B, and the trailing 3 floats are ignored.
        final partial = await draw(4, 7);
        expect(await a(partial, 15), greaterThan(0));
        expect(await a(partial, 25), 0);

        // Fewer than 4 floats draw nothing.
        final none = await draw(0, 3);
        expect(await a(none, 5), 0);
      }
    });

    testWidgets('drawText with textAlign anchors x; y is the baseline', (
      tester,
    ) async {
      final paint = ChartPaint()
        ..textSize = 10
        ..color = const Color(0xFF000000);
      final fm = paint.getFontMetrics();
      final w = paint.measureText('WW');

      Future<ui.Image> draw(PaintAlign align, double x) => tester
          .runAsync(
            () => render(
              (c) => c.drawText('WW', x, 15, paint..textAlign = align),
              w: 60,
            ),
          )
          .then((i) => i!);

      // LEFT: ink starts at x. CENTER: ink centered on x. RIGHT: ink ends at x.
      final left = await draw(PaintAlign.LEFT, 20);
      final center = await draw(PaintAlign.CENTER, 20);
      final right = await draw(PaintAlign.RIGHT, 20);
      final midY = (15 + (fm.ascent + fm.descent) / 2).round();
      Future<int> a(ui.Image i, double x) =>
          tester.runAsync(() => alphaAt(i, x.round(), midY)).then((v) => v!);

      expect(await a(left, 20 + w / 2), greaterThan(0));
      expect(await a(left, 20 - w / 2), 0);
      expect(await a(center, 20), greaterThan(0));
      expect(await a(center, 20 + w * 0.75), 0);
      expect(await a(right, 20 - w / 2), greaterThan(0));
      expect(await a(right, 20 + w / 2), 0);

      // Nothing is drawn below the descent of the baseline at y = 15.
      Future<int> below(ui.Image i) => tester
          .runAsync(
            () =>
                alphaAt(i, (20 + w / 2).round(), (15 + fm.descent + 1).ceil()),
          )
          .then((v) => v!);
      expect(await below(left), 0);
    });

    testWidgets('drawPathP with a dash effect leaves gaps', (tester) async {
      final paint = ChartPaint()
        ..style = PaintStyle.STROKE
        ..strokeWidth = 2
        ..pathEffect = DashPathEffect(const [4, 4], 0);
      final path = ui.Path()
        ..moveTo(0, 10)
        ..lineTo(40, 10);
      final image = (await tester.runAsync(
        () => render((c) => c.drawPathP(path, paint)),
      ))!;
      expect(
        await tester.runAsync(() => alphaAt(image, 2, 10)),
        greaterThan(0),
      );
      expect(await tester.runAsync(() => alphaAt(image, 6, 10)), 0);
    });

    testWidgets(
      'a dash effect does not apply to fills: FILL shapes are drawn whole',
      (tester) async {
        // A sparse dash would leave almost nothing of an outline; a fill must stay solid, as in Skia.
        final paint = ChartPaint()
          ..style = PaintStyle.FILL
          ..pathEffect = DashPathEffect(const [1, 40], 0);
        final image = (await tester.runAsync(
          () => render((c) {
            c.drawCircleP(10, 10, 8, paint);
            c.drawRectP(MutableRect(22, 2, 38, 18), paint);
          }),
        ))!;
        Future<int> a(int x, int y) =>
            tester.runAsync(() => alphaAt(image, x, y)).then((v) => v!);
        expect(await a(10, 10), 255);
        expect(await a(10, 4), 255);
        expect(await a(30, 10), 255);
        expect(await a(23, 17), 255);
      },
    );

    testWidgets(
      'FILL_AND_STROKE fills whole and dashes only the stroke pass; STROKE dashes',
      (tester) async {
        // Rect (4, 4)-(36, 16), stroke 4 wide: along the top edge the dash covers x 4..8, the gap x 8..12.
        for (final style in [PaintStyle.FILL_AND_STROKE, PaintStyle.STROKE]) {
          final paint = ChartPaint()
            ..style = style
            ..strokeWidth = 4
            ..pathEffect = DashPathEffect(const [4, 4], 0);
          final image = (await tester.runAsync(
            () => render((c) => c.drawRectP(MutableRect(4, 4, 36, 16), paint)),
          ))!;
          Future<int> a(int x, int y) =>
              tester.runAsync(() => alphaAt(image, x, y)).then((v) => v!);
          // Outside the rect only the stroke reaches: a dash, then a gap.
          expect(await a(5, 2), greaterThan(0), reason: '$style');
          expect(await a(10, 2), 0, reason: '$style');
          // The interior is filled only for FILL_AND_STROKE.
          expect(
            await a(20, 10),
            style == PaintStyle.FILL_AND_STROKE ? 255 : 0,
            reason: '$style',
          );
        }
      },
    );

    testWidgets('a zero-length dash with a round cap draws a dot', (
      tester,
    ) async {
      final paint = ChartPaint()
        ..style = PaintStyle.STROKE
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..pathEffect = DashPathEffect(const [0, 8], 0);
      final image = (await tester.runAsync(
        () => render((c) => c.drawLineP(4, 10, 36, 10, paint)),
      ))!;
      expect(
        await tester.runAsync(() => alphaAt(image, 12, 10)),
        greaterThan(0),
      );
      expect(await tester.runAsync(() => alphaAt(image, 8, 10)), 0);
    });

    testWidgets('clipRectM clips and drawColorP fills the clip', (
      tester,
    ) async {
      final image = (await tester.runAsync(
        () => render((c) {
          c.clipRectM(MutableRect(0, 0, 10, 20));
          c.drawColorP(const Color(0xFF00FF00));
        }),
      ))!;
      expect(await tester.runAsync(() => alphaAt(image, 5, 5)), 255);
      expect(await tester.runAsync(() => alphaAt(image, 15, 5)), 0);
    });

    testWidgets('FILL_AND_STROKE rect covers the stroke outside the fill', (
      tester,
    ) async {
      final paint = ChartPaint()
        ..style = PaintStyle.FILL_AND_STROKE
        ..strokeWidth = 4;
      final image = (await tester.runAsync(
        () => render((c) => c.drawRectP(MutableRect(10, 5, 20, 15), paint)),
      ))!;
      expect(await tester.runAsync(() => alphaAt(image, 15, 10)), 255);
      expect(await tester.runAsync(() => alphaAt(image, 9, 10)), 255);
      final fillOnly = (await tester.runAsync(
        () => render(
          (c) => c.drawRectP(
            MutableRect(10, 5, 20, 15),
            paint..style = PaintStyle.FILL,
          ),
        ),
      ))!;
      expect(await tester.runAsync(() => alphaAt(fillOnly, 9, 10)), 0);
    });
  });
}
