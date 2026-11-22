// Tests for the RecordingCanvas test shim itself (test/recording/recording_canvas.dart): the typed records, the
// per-type counts, the transform it tracks and the text queries the renderer tests of the other lanes rely on.
import 'dart:math' show pi;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show TextStyle;
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/graphics/chart_canvas.dart';
import 'package:mp_flutter_chart/src/graphics/chart_paint.dart';
import 'package:mp_flutter_chart/src/graphics/text_measure.dart';
import 'package:mp_flutter_chart/src/utils/f_size.dart';
import 'package:mp_flutter_chart/src/utils/mp_point_f.dart';
import 'package:mp_flutter_chart/src/utils/utils.dart';

import 'recording_canvas.dart';

const red = ui.Color(0xFFFF0000);
const blue = ui.Color(0xFF0000FF);

void main() {
  test('drawArc records the rect, angles, useCenter and paint', () {
    final canvas = RecordingCanvas();
    canvas.drawArc(
      const ui.Rect.fromLTWH(0, 0, 100, 100),
      0.5,
      1.25,
      true,
      ui.Paint()
        ..color = red
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final arc = canvas.arcs.single;
    expect(arc.rect, const ui.Rect.fromLTWH(0, 0, 100, 100));
    expect(arc.startAngle, 0.5);
    expect(arc.sweepAngle, 1.25);
    expect(arc.useCenter, isTrue);
    expect(arc.paint.color, red);
    expect(arc.paint.style, ui.PaintingStyle.stroke);
    expect(arc.paint.strokeWidth, 2);
    expect(arc.method, 'drawArc');
    expect(arc.saveCount, 1);
    expect(canvas.count('drawArc'), 1);
    expect(canvas.countOf<ArcDraw>(), 1);
    expect(canvas.drawArcCalls, 1);
  });

  test('drawRRect records the rounded rect; drawRRectCalls still counts', () {
    final canvas = RecordingCanvas();
    final rr = ui.RRect.fromRectAndRadius(
      const ui.Rect.fromLTWH(1, 2, 30, 40),
      const ui.Radius.circular(4),
    );
    canvas.drawRRect(rr, ui.Paint()..color = red);

    expect(canvas.rrects.single.rrect, rr);
    expect(canvas.rrects.single.color, red);
    expect(canvas.rrects.single.paint.style, ui.PaintingStyle.fill);
    expect(canvas.drawRRectCalls, 1);
    expect(canvas.count('drawRRect'), 1);
    expect(canvas.countOf<RRectDraw>(), 1);
  });

  test('drawOval records the rect and paint', () {
    final canvas = RecordingCanvas();
    canvas.drawOval(
      const ui.Rect.fromLTWH(10, 20, 30, 40),
      ui.Paint()..color = blue,
    );

    expect(canvas.ovals.single.rect, const ui.Rect.fromLTWH(10, 20, 30, 40));
    expect(canvas.ovals.single.paint.color, blue);
    expect(canvas.drawOvalCalls, 1);
    expect(canvas.count('drawOval'), 1);
  });

  test('saveLayer records bounds and blend mode and pushes a save level', () {
    final canvas = RecordingCanvas();
    const r = ui.Rect.fromLTWH(0, 0, 50, 50);
    canvas.saveLayer(r, ui.Paint()..blendMode = ui.BlendMode.srcATop);

    final layer = canvas.layers.single;
    expect(layer.bounds, r);
    expect(layer.blendMode, ui.BlendMode.srcATop);
    expect(layer.alpha, 255);
    expect(layer.saveCount, 1);
    expect(canvas.saveLayerCalls, 1);
    expect(canvas.getSaveCount(), 2);

    canvas.restore();
    expect(canvas.getSaveCount(), 1);
  });

  test(
    'clips record kind, bounds and op; clipRects and clipPaths keep their old contents',
    () {
      final canvas = RecordingCanvas();
      const r = ui.Rect.fromLTWH(0, 0, 10, 10);
      final rr = ui.RRect.fromRectAndRadius(
        const ui.Rect.fromLTWH(5, 5, 20, 20),
        const ui.Radius.circular(3),
      );
      final p = ui.Path()
        ..moveTo(1, 2)
        ..lineTo(30, 40)
        ..lineTo(1, 40)
        ..close();

      canvas.clipRect(r, clipOp: ui.ClipOp.difference);
      canvas.clipRRect(rr);
      canvas.clipPath(p);

      expect(canvas.clips.map((c) => c.kind), [
        ClipKind.rect,
        ClipKind.rrect,
        ClipKind.path,
      ]);
      expect(canvas.clips.map((c) => c.bounds), [
        r,
        rr.outerRect,
        p.getBounds(),
      ]);
      expect(canvas.clips[0].clipOp, ui.ClipOp.difference);
      expect(canvas.clips[1].clipOp, ui.ClipOp.intersect);
      expect(canvas.clips[2].clipOp, ui.ClipOp.intersect);
      expect(canvas.clips.map((c) => c.method), [
        'clipRect',
        'clipRRect',
        'clipPath',
      ]);
      expect(canvas.clipCalls, 3);
      expect(canvas.clipRects, [r]);
      expect(canvas.clipPaths.single, same(p));
    },
  );

  test(
    'the transform follows translate, scale and rotate across save and restore',
    () {
      final canvas = RecordingCanvas();
      canvas.save();
      canvas.translate(10, 20);
      canvas.scale(2);
      expect(canvas.toDevice(const ui.Offset(1, 1)), const ui.Offset(12, 22));

      canvas.restore();
      expect(canvas.toDevice(const ui.Offset(1, 1)), const ui.Offset(1, 1));

      // The rotation is restored before the translate so that getTransform() reads the translate alone.
      canvas.save();
      canvas.rotate(pi / 2);
      final rotated = canvas.toDevice(const ui.Offset(1, 0));
      expect(rotated.dx, closeTo(0, 1e-9));
      expect(rotated.dy, closeTo(1, 1e-9));
      canvas.restore();

      canvas.translate(3, 4);
      final m = canvas.getTransform();
      expect(m, hasLength(16));
      expect(m[12], 3);
      expect(m[13], 4);

      expect(canvas.transforms.map((t) => t.kind), [
        TransformKind.translate,
        TransformKind.scale,
        TransformKind.rotate,
        TransformKind.translate,
      ]);
      expect(canvas.transforms.map((t) => t.values), [
        [10, 20],
        [2, 2],
        [pi / 2],
        [3, 4],
      ]);
      expect(canvas.transforms.map((t) => t.method), [
        'translate',
        'scale',
        'rotate',
        'translate',
      ]);
      expect(canvas.transforms[1].saveCount, 2);
      expect(canvas.transforms[3].saveCount, 1);
    },
  );

  test('skew, transform and restoreToCount update the transform', () {
    final canvas = RecordingCanvas();
    canvas.save();
    canvas.skew(0.5, 0);
    expect(canvas.toDevice(const ui.Offset(0, 2)), const ui.Offset(1, 2));
    canvas.restore();

    final matrix = Float64List.fromList([
      2, 0, 0, 0, //
      0, 3, 0, 0, //
      0, 0, 1, 0, //
      5, 7, 0, 1, //
    ]);
    final n = canvas.getSaveCount();
    canvas.save();
    canvas.transform(matrix);
    expect(canvas.toDevice(const ui.Offset(1, 1)), const ui.Offset(7, 10));
    expect(canvas.getTransform(), matrix);
    canvas.save();
    canvas.translate(1, 1);
    canvas.restoreToCount(n);
    expect(canvas.getSaveCount(), 1);
    expect(canvas.toDevice(const ui.Offset(1, 1)), const ui.Offset(1, 1));

    expect(canvas.transforms.map((t) => t.kind), [
      TransformKind.skew,
      TransformKind.transform,
      TransformKind.translate,
    ]);
    expect(canvas.transforms[0].values, [0.5, 0]);
    expect(canvas.transforms[1].values, matrix);
  });

  test('getTransform matches a real canvas after the same calls', () {
    final recorder = ui.PictureRecorder();
    final real = ui.Canvas(recorder);
    final canvas = RecordingCanvas();
    for (final c in <ui.Canvas>[real, canvas]) {
      c.translate(10, 20);
      c.rotate(0.3);
      c.scale(2, 0.5);
      c.save();
      c.skew(0.2, 0.1);
      c.transform(
        Float64List.fromList([
          1, 0.5, 0, 0, //
          -0.25, 1, 0, 0, //
          0, 0, 1, 0, //
          4, -3, 0, 1, //
        ]),
      );
    }

    final expected = real.getTransform();
    final actual = canvas.getTransform();
    for (var i = 0; i < 16; i++) {
      expect(actual[i], closeTo(expected[i], 1e-5), reason: 'entry $i');
    }
    real.restore();
    canvas.restore();
    final restoredExpected = real.getTransform();
    final restoredActual = canvas.getTransform();
    for (var i = 0; i < 16; i++) {
      expect(
        restoredActual[i],
        closeTo(restoredExpected[i], 1e-5),
        reason: 'entry $i after restore',
      );
    }
    recorder.endRecording().dispose();
  });

  test('drewText finds labels drawn through ChartCanvas.drawText', () {
    final canvas = RecordingCanvas();
    final p = ChartPaint()..textSize = 10;
    canvas.drawText('12.5', 10, 20, p);
    canvas.drawText('7', 30, 20, p);

    expect(canvas.drewText('12.5', p.textStyle), isTrue);
    expect(canvas.drewText('13', p.textStyle), isFalse);
    expect(canvas.textsOf(['7', '12.5', 'x'], p.textStyle), ['12.5', '7']);
    expect(
      canvas.paragraphsWithText('7', p.textStyle).single,
      same(canvas.paragraphs[1]),
    );
    expect(canvas.paragraphs[0].deviceOffset, canvas.paragraphs[0].offset);
    expect(canvas.paragraphs[0].height, greaterThan(0));
    // width is the paragraph's layout width: a label laid out without a max width is infinitely wide.
    expect(canvas.paragraphs[1].width, double.infinity);
  });

  test('stroke text matches the stroke style only', () {
    final canvas = RecordingCanvas();
    final p = ChartPaint()
      ..textSize = 10
      ..style = PaintStyle.STROKE;
    canvas.drawText('9', 10, 20, p);

    expect(canvas.drewText('9', p.textStrokeStyle), isTrue);
    expect(canvas.drewText('9', p.textStyle), isFalse);
  });

  test('a paragraph painted under a translate has a device offset', () {
    final canvas = RecordingCanvas();
    final p = ChartPaint()..textSize = 10;
    const style = TextStyle(fontSize: 10);
    canvas.translate(50, 60);
    TextMeasure.layout('a', style).paint(canvas, ui.Offset.zero);

    expect(canvas.paragraphs.single.offset, ui.Offset.zero);
    expect(canvas.paragraphs.single.deviceOffset, const ui.Offset(50, 60));

    Utils.drawMultilineText(
      canvas,
      'a long label here',
      5,
      5,
      p,
      FSize.getInstance(40, 0),
      MPPointF.getInstance(0, 0),
      0,
    );
    final multiline = canvas.paragraphsWithText(
      'a long label here',
      p.textStyle,
      maxWidth: 40,
    );
    expect(multiline, hasLength(1));
    expect(multiline.single.offset, ui.Offset.zero);
    expect(multiline.single.width, 40);
    expect(
      multiline.single.width,
      TextMeasure.layout('a long label here', p.textStyle, maxWidth: 40).width,
    );
    expect(
      canvas.paragraphsWithText('a long label here', p.textStyle),
      isEmpty,
    );
  });

  test('callCounts and count() group calls by method name', () {
    final canvas = RecordingCanvas();
    final paint = ui.Paint();
    canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 1, 1), paint);
    canvas.drawCircle(const ui.Offset(1, 1), 2, paint);
    canvas.drawRect(const ui.Rect.fromLTWH(2, 2, 1, 1), paint);

    expect(canvas.count('drawRect'), 2);
    expect(canvas.count('drawCircle'), 1);
    expect(canvas.count('drawPath'), 0);
    expect(canvas.callCounts, {'drawRect': 2, 'drawCircle': 1});
  });

  test(
    'records keeps every recorded call in order; where() filters by type and arguments',
    () {
      final canvas = RecordingCanvas();
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, 10, 10),
        ui.Paint()..color = red,
      );
      canvas.drawLine(
        ui.Offset.zero,
        const ui.Offset(5, 5),
        ui.Paint()..color = blue,
      );
      canvas.saveLayer(null, ui.Paint()..color = const ui.Color(0x80000000));
      canvas.translate(1, 2);
      canvas.drawCircle(const ui.Offset(3, 3), 1, ui.Paint()..color = blue);
      canvas.drawRect(
        const ui.Rect.fromLTWH(1, 1, 5, 5),
        ui.Paint()
          ..color = blue
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      canvas.drawPath(
        ui.Path()..addRect(const ui.Rect.fromLTWH(0, 0, 2, 2)),
        ui.Paint(),
      );
      canvas.drawRawPoints(
        ui.PointMode.lines,
        Float32List.fromList([0, 0, 1, 1]),
        ui.Paint(),
      );
      canvas.clipRect(const ui.Rect.fromLTWH(0, 0, 4, 4));

      const expected = [
        'drawRect',
        'drawLine',
        'saveLayer',
        'translate',
        'drawCircle',
        'drawRect',
        'drawPath',
        'drawRawPoints',
        'clipRect',
      ];
      expect(canvas.records.map((r) => r.method), expected);
      expect(canvas.calls, expected);
      expect(canvas.records.map((r) => r.saveCount), [
        1,
        1,
        1,
        2,
        2,
        2,
        2,
        2,
        2,
      ]);

      expect(canvas.where<RectDraw>((r) => r.color == red).length, 1);
      expect(canvas.where<RectDraw>((r) => r.color == blue).length, 1);
      expect(canvas.recordsOf<RectDraw>(), hasLength(2));
      expect(canvas.countOf<RectDraw>(), 2);
      expect(canvas.countOf<CanvasRecord>(), expected.length);

      final stroked = canvas.rects[1];
      expect(stroked.style, ui.PaintingStyle.stroke);
      expect(stroked.strokeWidth, 3);
      expect(canvas.rects[0].style, ui.PaintingStyle.fill);
      expect(canvas.lines.single.paint.color, blue);
      expect(canvas.circles.single.paint.color, blue);
      expect(canvas.paths.single.paint.style, ui.PaintingStyle.fill);
      expect(canvas.rawPoints.single.paint.isAntiAlias, isTrue);
      expect(canvas.rawPoints.single.paint.hasShader, isFalse);
      expect(canvas.rawPoints.single.paint.strokeCap, ui.StrokeCap.butt);
      expect(canvas.rawPoints.single.paint.blendMode, ui.BlendMode.srcOver);
      expect(canvas.layers.single.bounds, isNull);
      expect(canvas.layers.single.alpha, 0x80);
    },
  );

  test('methods it does not record still throw', () {
    final canvas = RecordingCanvas();
    expect(
      () => canvas.drawShadow(ui.Path(), red, 2, false),
      throwsUnimplementedError,
    );
  });
}
