// Not a port of a Kotlin test: Kotlin hands DashPathEffect lengths to the canvas as device px, so the ChartCanvas
// extension divides them by Utils.devicePixelRatio when it dashes a line.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/graphics/chart_canvas.dart';
import 'package:mp_flutter_chart/src/graphics/chart_paint.dart';
import 'package:mp_flutter_chart/src/utils/utils.dart';

/// Keeps the last path drawn; every other call is ignored.
class _PathCanvas implements ui.Canvas {
  ui.Path? path;

  @override
  void drawPath(ui.Path path, ui.Paint paint) => this.path = path;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// The start and length of each dash of the last path drawn on [c].
List<(double, double)> _dashes(_PathCanvas c) => [
  for (final m in c.path!.computeMetrics())
    (m.getTangentForOffset(0)!.position.dx, m.length),
];

void main() {
  tearDown(() => Utils.devicePixelRatio = 1.0);

  final paint = ChartPaint()
    ..style = PaintStyle.STROKE
    ..strokeWidth = 1
    ..pathEffect = DashPathEffect(const [8, 8], 0);

  void expectDashes(List<(double, double)> dashes, double on, double period) {
    expect(dashes, isNotEmpty);
    for (var i = 0; i < dashes.length; i++) {
      expect(dashes[i].$1, closeTo(i * period, 1e-3));
      if (i < dashes.length - 1) expect(dashes[i].$2, closeTo(on, 1e-3));
    }
  }

  test('at ratio 2 a (8, 8, 0) effect is 4 logical px on, 4 off', () {
    Utils.devicePixelRatio = 2;
    final c = _PathCanvas();
    c.drawLineP(0, 0, 40, 0, paint);
    final dashes = _dashes(c);
    expect(dashes, hasLength(5));
    expectDashes(dashes, 4, 8);

    final lines = _PathCanvas();
    lines.drawLinesP(Float32List.fromList([0, 0, 40, 0]), 0, 4, paint);
    expectDashes(_dashes(lines), 4, 8);

    final path = _PathCanvas();
    path.drawPathP(
      ui.Path()
        ..moveTo(0, 0)
        ..lineTo(40, 0),
      paint,
    );
    expectDashes(_dashes(path), 4, 8);
  });

  test('the phase is device px too', () {
    Utils.devicePixelRatio = 2;
    final c = _PathCanvas();
    c.drawLineP(
      0,
      0,
      40,
      0,
      paint.copy()..pathEffect = DashPathEffect(const [8, 8], 4),
    );
    // 4 device px into the first dash: 2 logical px of it are left.
    expect(_dashes(c).first.$2, closeTo(2, 1e-3));
  });

  test('at ratio 1 the lengths are unchanged', () {
    final c = _PathCanvas();
    c.drawLineP(0, 0, 40, 0, paint);
    final dashes = _dashes(c);
    expect(dashes, hasLength(3));
    expectDashes(dashes, 8, 16);
  });

  test('the stored effect is not changed', () {
    Utils.devicePixelRatio = 3;
    _PathCanvas().drawLineP(0, 0, 40, 0, paint);
    expect(paint.pathEffect!.intervals, [8, 8]);
    expect(paint.pathEffect!.phase, 0);
  });
}
