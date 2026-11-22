// Not a port of a Kotlin test: locks the NaN geometry guard of plan ruling A11 (Review Focus #1). Skia draws nothing
// for a shape with a NaN coordinate; Flutter's canvas asserts in debug builds, so the ChartCanvas calls and
// Fill.fillRect leave such shapes out. StrictCanvas throws where Flutter would. Also locks that drawCircleP leaves out
// a circle of radius 0 or less, as Android's canvas does (T18 BU4).
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/graphics/chart_canvas.dart';
import 'package:mp_flutter_chart/src/graphics/chart_paint.dart';
import 'package:mp_flutter_chart/src/graphics/mutable_rect.dart';
import 'package:mp_flutter_chart/src/utils/fill.dart';

import '../support/strict_canvas.dart';

const _nan = double.nan;
const _red = ui.Color(0xFFFF0000);
const _blue = ui.Color(0xFF0000FF);

/// The number of pixels [draw] inks on a real 60 x 60 px canvas scaled to 2.625 px per dp (emulator-5554's 420 dpi).
Future<int> _inked(void Function(ui.Canvas c) draw) async {
  final recorder = ui.PictureRecorder();
  draw(ui.Canvas(recorder)..scale(2.625));
  final image = await recorder.endRecording().toImage(60, 60);
  final pixels = (await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!.buffer.asUint8List();
  image.dispose();

  var inked = 0;
  for (var alpha = 3; alpha < pixels.length; alpha += 4) {
    if (pixels[alpha] != 0) inked++;
  }
  return inked;
}

void main() {
  group('StrictCanvas', () {
    test('throws for NaN geometry, as Flutter debug builds do', () {
      final canvas = StrictCanvas();
      final paint = ui.Paint();
      expect(
        () => canvas.drawRect(const ui.Rect.fromLTRB(0, _nan, 1, 1), paint),
        throwsStateError,
      );
      expect(
        () => canvas.drawCircle(const ui.Offset(_nan, 0), 1, paint),
        throwsStateError,
      );
      expect(
        () => canvas.drawLine(ui.Offset.zero, const ui.Offset(0, _nan), paint),
        throwsStateError,
      );
      expect(
        () => canvas.clipRect(const ui.Rect.fromLTRB(_nan, 0, 1, 1)),
        throwsStateError,
      );
      expect(canvas.calls, isEmpty);
    });

    test('records finite and infinite geometry like RecordingCanvas', () {
      final canvas = StrictCanvas();
      canvas.drawRect(
        const ui.Rect.fromLTRB(0, double.negativeInfinity, 1, 1),
        ui.Paint(),
      );
      expect(canvas.rects, hasLength(1));
    });
  });

  group('ChartCanvas', () {
    final paint = ChartPaint()..color = _red;

    test('drawRectP leaves out a rect with a NaN edge', () {
      final canvas = StrictCanvas();
      canvas.drawRectP(MutableRect()..set(0, _nan, 1, 1), paint);
      canvas.drawRectP(MutableRect()..set(0, 0, _nan, 1), paint);
      expect(canvas.rects, isEmpty);

      canvas.drawRectP(MutableRect(1, 2, 3, 4), paint);
      expect(canvas.rects.single.rect, const ui.Rect.fromLTRB(1, 2, 3, 4));
    });

    test('drawRectP keeps an infinite edge, which Flutter draws', () {
      final canvas = StrictCanvas();
      canvas.drawRectP(MutableRect(0, double.negativeInfinity, 1, 1), paint);
      expect(canvas.rects, hasLength(1));
    });

    test('drawRectP leaves out a NaN rect in every style', () {
      final canvas = StrictCanvas();
      final dashed = ChartPaint()
        ..style = PaintStyle.FILL_AND_STROKE
        ..pathEffect = DashPathEffect([2, 2], 0);
      canvas.drawRectP(MutableRect(0, _nan, 1, 1), dashed);
      expect(canvas.calls, isEmpty);
    });

    test('drawRoundRectP leaves out a NaN rect or radius', () {
      final canvas = StrictCanvas();
      canvas.drawRoundRectP(MutableRect(_nan, 0, 1, 1), 2, 2, paint);
      canvas.drawRoundRectP(MutableRect(0, 0, 10, 10), _nan, 2, paint);
      expect(canvas.drawRRectCalls, 0);

      canvas.drawRoundRectP(MutableRect(0, 0, 10, 10), 2, 2, paint);
      expect(canvas.drawRRectCalls, 1);
    });

    test('drawCircleP leaves out a NaN center or radius', () {
      final canvas = StrictCanvas();
      canvas.drawCircleP(_nan, 0, 1, paint);
      canvas.drawCircleP(0, _nan, 1, paint);
      canvas.drawCircleP(0, 0, _nan, paint);
      expect(canvas.circles, isEmpty);

      canvas.drawCircleP(1, 2, 3, paint);
      expect(canvas.circles.single.radius, 3);
    });

    test('drawCircleP leaves out a radius of 0 or less in every style, dashed '
        'or not, as Android does', () {
      // hwui's SkiaCanvas::drawCircle returns early for radius <= 0, which a bubble of size 0 (or a negative size)
      // reaches; Impeller, Flutter's renderer on Android, would stroke a dot there (T18 BU4).
      final canvas = StrictCanvas();
      for (final style in PaintStyle.values) {
        for (final effect in [
          null,
          DashPathEffect([2, 2], 0),
        ]) {
          final p = ChartPaint()
            ..color = _red
            ..style = style
            ..strokeWidth = 1.5
            ..pathEffect = effect;
          for (final radius in [0.0, -0.0, -1.0, double.negativeInfinity]) {
            canvas.drawCircleP(20, 20, radius, p);
          }
        }
      }
      expect(canvas.calls, isEmpty);

      canvas.drawCircleP(20, 20, 0.5, ChartPaint()..style = PaintStyle.STROKE);
      expect(canvas.circles.single.radius, 0.5);
    });

    test('drawCircleP inks no pixel for a radius of 0 or less on a real '
        'canvas, filled or stroked', () async {
      // Device-like pixels: emulator-5554 has 420 dpi, 2.625 px per dp, so the 1.5 dp ring of a bubble highlight is
      // about 4 px wide. Impeller (the emulator's renderer) strokes a dot of that width for a radius of 0; Skia,
      // which `flutter test` uses unless run with --enable-impeller, inks nothing either way.
      final zeroOrLess = await _inked((c) {
        for (final style in PaintStyle.values) {
          final p = ChartPaint()
            ..color = _red
            ..style = style
            ..strokeWidth = 1.5;
          for (final radius in [-10.0, -0.0, 0.0]) {
            c.drawCircleP(10, 10, radius, p);
          }
        }
      });
      expect(zeroOrLess, 0);

      // The probe sees a ring as thin as that.
      final small = await _inked(
        (c) => c.drawCircleP(
          10,
          10,
          0.5,
          ChartPaint()
            ..color = _red
            ..style = PaintStyle.STROKE
            ..strokeWidth = 1.5,
        ),
      );
      expect(small, greaterThan(0));
    });

    test('drawCircleP hands an infinite radius to a real canvas without an '
        'assertion, which inks nothing for it', () async {
      // A bubble gets such a radius from an infinite size with normalizing off.
      final inked = await _inked((c) {
        for (final style in PaintStyle.values) {
          c.drawCircleP(
            10,
            10,
            double.infinity,
            ChartPaint()
              ..color = _red
              ..style = style
              ..strokeWidth = 1.5,
          );
        }
      });
      expect(inked, 0);
    });

    test('drawLineP leaves out a line with a NaN end, dashed or not', () {
      final canvas = StrictCanvas();
      canvas.drawLineP(_nan, 0, 1, 1, paint);
      canvas.drawLineP(0, 0, 1, _nan, paint);
      canvas.drawLineP(
        0,
        _nan,
        1,
        1,
        ChartPaint()..pathEffect = DashPathEffect([2, 2], 0),
      );
      expect(canvas.calls, isEmpty);

      canvas.drawLineP(0, 0, 1, 1, paint);
      expect(canvas.lines, hasLength(1));
    });

    // drawLinesP needs no guard: Flutter's drawRawPoints only checks the float count, and a dashed drawLinesP builds a
    // path with moveTo / lineTo, which do not assert either. The candle shadows rely on this.
    test('drawLinesP hands NaN and infinite points to a real canvas without '
        'an assertion, dashed or not', () {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final pts = Float32List.fromList([
        0, _nan, 1, 1, //
        _nan, 0, double.infinity, 1, //
      ]);
      expect(() => canvas.drawLinesP(pts, 0, 8, paint), returnsNormally);
      expect(
        () => canvas.drawLinesP(
          pts,
          0,
          8,
          ChartPaint()..pathEffect = DashPathEffect([2, 2], 0),
        ),
        returnsNormally,
      );
      recorder.endRecording().dispose();
    });

    test('drawText leaves out text anchored at a NaN x or y', () {
      final canvas = StrictCanvas();
      canvas.drawText('5', _nan, 10, paint);
      canvas.drawText('5', 10, _nan, paint);
      canvas.drawText(
        '5',
        10,
        _nan,
        ChartPaint()..style = PaintStyle.FILL_AND_STROKE,
      );
      expect(canvas.paragraphs, isEmpty);

      canvas.drawText('5', 10, 10, paint);
      expect(canvas.paragraphs, hasLength(1));
    });
  });

  group('Fill.fillRect', () {
    test('a color fill leaves out a NaN rect', () {
      final canvas = StrictCanvas();
      Fill.ofColor(
        _red,
      ).fillRect(canvas, ChartPaint(), 0, _nan, 1, 1, FillDirection.UP);
      expect(canvas.calls, isEmpty);

      Fill.ofColor(
        _red,
      ).fillRect(canvas, ChartPaint(), 0, 0, 1, 1, FillDirection.UP);
      expect(canvas.clipRects.single, const ui.Rect.fromLTRB(0, 0, 1, 1));
      expect(canvas.colors.single, _red);
    });

    test('a gradient fill leaves out a NaN rect', () {
      final canvas = StrictCanvas();
      final paint = ChartPaint();
      Fill.ofColors(
        _red,
        _blue,
      ).fillRect(canvas, paint, _nan, 0, 1, 1, FillDirection.DOWN);
      expect(canvas.calls, isEmpty);
      expect(paint.shader, isNull);
    });

    test('a NaN in any one edge leaves the rect out, and infinite edges do '
        'not', () {
      for (final fill in [Fill.ofColor(_red), Fill.ofColors(_red, _blue)]) {
        for (var edge = 0; edge < 4; edge++) {
          final ltrb = [0.0, 0.0, 1.0, 1.0]..[edge] = _nan;
          final canvas = StrictCanvas();
          final paint = ChartPaint();
          fill.fillRect(
            canvas,
            paint,
            ltrb[0],
            ltrb[1],
            ltrb[2],
            ltrb[3],
            FillDirection.DOWN,
          );
          expect(canvas.calls, isEmpty, reason: '${fill.type}, edge $edge');
          expect(paint.shader, isNull, reason: '${fill.type}, edge $edge');
        }
      }

      final canvas = StrictCanvas();
      Fill.ofColor(_red).fillRect(
        canvas,
        ChartPaint(),
        0,
        double.negativeInfinity,
        1,
        double.infinity,
        FillDirection.DOWN,
      );
      expect(canvas.colors.single, _red);
    });
  });
}
