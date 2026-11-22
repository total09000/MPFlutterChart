// Not a port of a Kotlin test (task brief): locks the geometry of the seven built-in scatter shapes and of
// IShapeRenderer.fromFunction, drawn at (50, 50) with a shape size of 10 dp (1 dp is 1 px here).
//
// The expectations follow the Kotlin renderers, which differ from the brief in three places: the square and the
// circle without a hole are drawn stroked (stroke width half the size around half the radius, which covers the
// whole shape), not filled, because Kotlin branches on the shape size rather than on the hole; and a chevron's tip
// sits one whole shape size (2 * shapeHalf) from the entry, not half of it.
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/data/entry.dart';
import 'package:mp_flutter_chart/src/data/scatter_data_set.dart';
import 'package:mp_flutter_chart/src/graphics/chart_paint.dart';
import 'package:mp_flutter_chart/src/interfaces/datasets/i_scatter_data_set.dart';
import 'package:mp_flutter_chart/src/renderer/scatter/chevron_down_shape_renderer.dart';
import 'package:mp_flutter_chart/src/renderer/scatter/chevron_up_shape_renderer.dart';
import 'package:mp_flutter_chart/src/renderer/scatter/circle_shape_renderer.dart';
import 'package:mp_flutter_chart/src/renderer/scatter/cross_shape_renderer.dart';
import 'package:mp_flutter_chart/src/renderer/scatter/i_shape_renderer.dart';
import 'package:mp_flutter_chart/src/renderer/scatter/square_shape_renderer.dart';
import 'package:mp_flutter_chart/src/renderer/scatter/triangle_shape_renderer.dart';
import 'package:mp_flutter_chart/src/renderer/scatter/x_shape_renderer.dart';
import 'package:mp_flutter_chart/src/utils/view_port_handler.dart';

import 'support/paint_recording_canvas.dart';
import 'support/strict_canvas.dart';

const ui.Color _ENTRY = ui.Color(0xFF3366CC);
const ui.Color _HOLE = ui.Color(0xFFFFFFFF);

/// A set of shape size 10 with a hole of radius [holeRadius] in [holeColor] (none by default).
ScatterDataSet _set({double holeRadius = 0, ui.Color? holeColor}) {
  final set = ScatterDataSet(<Entry>[], 'shapes')
    ..scatterShapeSize = 10
    ..scatterShapeHoleRadius = holeRadius;
  if (holeColor != null) set.scatterShapeHoleColor = holeColor;
  return set;
}

/// Draws [shape] for [set] at ([x], [y]) on a fresh canvas with a paint in the entry color.
PaintRecordingCanvas _render(
  IShapeRenderer shape,
  ScatterDataSet set, {
  double x = 50,
  double y = 50,
}) => _renderOn(PaintRecordingCanvas(), shape, set, x: x, y: y);

/// Draws [shape] for [set] at ([x], [y]) on [canvas] with a paint in the entry color, and returns [canvas].
T _renderOn<T extends PaintRecordingCanvas>(
  T canvas,
  IShapeRenderer shape,
  ScatterDataSet set, {
  double x = 50,
  double y = 50,
}) {
  shape.renderShape(
    canvas,
    set,
    ViewPortHandler(),
    x,
    y,
    ChartPaint()..color = _ENTRY,
  );
  return canvas;
}

/// Also keeps a copy of every drawn path in [copies]: the triangle renderer resets its path right after drawing it.
class _PathCopyCanvas extends PaintRecordingCanvas {
  final List<ui.Path> copies = [];

  @override
  void drawPath(ui.Path path, ui.Paint paint) {
    copies.add(ui.Path.from(path)..fillType = path.fillType);
    super.drawPath(path, paint);
  }
}

void main() {
  group('SquareShapeRenderer', () {
    test('without a hole strokes half the size around the center', () {
      final canvas = _render(SquareShapeRenderer(), _set());
      expect(canvas.drawRectCalls, 1);
      expect(
        canvas.rects.single.rect,
        const ui.Rect.fromLTRB(47.5, 47.5, 52.5, 52.5),
      );
      expect(canvas.rects.single.color.toARGB32(), _ENTRY.toARGB32());
      expect(canvas.rectPaints.single.style, ui.PaintingStyle.stroke);
      expect(canvas.rectPaints.single.strokeWidth, 5);
    });

    test(
      'with a hole strokes the frame and fills the hole in the hole color',
      () {
        final canvas = _render(
          SquareShapeRenderer(),
          _set(holeRadius: 2, holeColor: _HOLE),
        );
        expect(canvas.drawRectCalls, 2);
        expect(
          canvas.rects[0].rect,
          const ui.Rect.fromLTRB(46.5, 46.5, 53.5, 53.5),
        );
        expect(canvas.rects[0].color.toARGB32(), _ENTRY.toARGB32());
        expect(canvas.rectPaints[0].style, ui.PaintingStyle.stroke);
        expect(canvas.rectPaints[0].strokeWidth, 3);
        expect(canvas.rects[1].rect, const ui.Rect.fromLTRB(48, 48, 52, 52));
        expect(canvas.rects[1].color.toARGB32(), _HOLE.toARGB32());
        expect(canvas.rectPaints[1].style, ui.PaintingStyle.fill);
      },
    );

    test('leaves the hole transparent without a hole color', () {
      final canvas = _render(SquareShapeRenderer(), _set(holeRadius: 2));
      expect(canvas.drawRectCalls, 1);
      expect(canvas.rectPaints.single.style, ui.PaintingStyle.stroke);
      expect(canvas.rectPaints.single.strokeWidth, 3);
    });

    test('fills a square of the size when the size is not positive', () {
      final set = _set()..scatterShapeSize = 0;
      final canvas = _render(SquareShapeRenderer(), set);
      expect(canvas.drawRectCalls, 1);
      expect(canvas.rects.single.rect, const ui.Rect.fromLTRB(50, 50, 50, 50));
      expect(canvas.rectPaints.single.style, ui.PaintingStyle.fill);
    });
  });

  group('CircleShapeRenderer', () {
    test('without a hole strokes half the size around half the radius', () {
      final canvas = _render(CircleShapeRenderer(), _set());
      expect(canvas.drawCircleCalls, 1);
      final circle = canvas.circles.single;
      expect([circle.x, circle.y, circle.radius], [50, 50, 2.5]);
      expect(circle.color.toARGB32(), _ENTRY.toARGB32());
      expect(circle.style, ui.PaintingStyle.stroke);
      expect(canvas.circlePaints.single.strokeWidth, 5);
    });

    test(
      'with a hole strokes the ring and fills the hole in the hole color',
      () {
        final canvas = _render(
          CircleShapeRenderer(),
          _set(holeRadius: 2, holeColor: _HOLE),
        );
        expect(canvas.drawCircleCalls, 2);
        expect(canvas.circles[0].radius, 3.5);
        expect(canvas.circles[0].color.toARGB32(), _ENTRY.toARGB32());
        expect(canvas.circles[0].style, ui.PaintingStyle.stroke);
        expect(canvas.circlePaints[0].strokeWidth, 3);
        expect(canvas.circles[1].radius, 2);
        expect(canvas.circles[1].color.toARGB32(), _HOLE.toARGB32());
        expect(canvas.circles[1].style, ui.PaintingStyle.fill);
      },
    );

    test('with a hole radius but no hole color strokes the ring only', () {
      final canvas = _render(CircleShapeRenderer(), _set(holeRadius: 2));
      expect(canvas.drawCircleCalls, 1);
      final ring = canvas.circles.single;
      expect([ring.x, ring.y, ring.radius], [50, 50, 3.5]);
      expect(ring.color.toARGB32(), _ENTRY.toARGB32());
      expect(ring.style, ui.PaintingStyle.stroke);
      expect(canvas.circlePaints.single.strokeWidth, 3);
    });

    test('when the size is not positive, fills a circle of half the size, '
        'which has a radius of 0 or less and so draws nothing', () {
      // Kotlin's else branch fills a circle of radius shapeSize / 2; Android's canvas returns early for a radius of
      // 0 or less, and so does drawCircleP (T18 BU4).
      for (final size in [0.0, -4.0]) {
        final set = _set()..scatterShapeSize = size;
        final paint = ChartPaint()
          ..color = _ENTRY
          ..style = PaintStyle.STROKE;
        final canvas = PaintRecordingCanvas();
        CircleShapeRenderer().renderShape(
          canvas,
          set,
          ViewPortHandler(),
          50,
          50,
          paint,
        );
        expect(paint.style, PaintStyle.FILL, reason: 'size $size');
        expect(canvas.calls, isEmpty, reason: 'size $size');
      }
    });
  });

  group('TriangleShapeRenderer', () {
    // A point in the band between the outer and the inner triangle, and one inside the inner triangle of a hole of
    // radius 2 (corners (48, 52), (52, 52) and (50, 48)).
    const band = ui.Offset(50, 46);
    const hole = ui.Offset(50, 51);

    test('without a hole fills one triangle of the size', () {
      final canvas = _renderOn(
        _PathCopyCanvas(),
        TriangleShapeRenderer(),
        _set(),
      );
      expect(canvas.drawPathCalls, 1);
      final path = canvas.paths.single;
      expect(path.bounds, const ui.Rect.fromLTRB(45, 45, 55, 55));
      expect(path.color.toARGB32(), _ENTRY.toARGB32());
      expect(path.style, ui.PaintingStyle.fill);
      expect(path.fillType, ui.PathFillType.nonZero);
      // Solid: the inner contour Kotlin adds collapses to the center when the stroke is half the size.
      final drawn = canvas.copies.single;
      expect(drawn.contains(band), isTrue);
      expect(drawn.contains(hole), isTrue);
    });

    test('with a hole radius fills a ring: the inner contour winds the other '
        'way and cancels the fill', () {
      for (final holeColor in [null, _HOLE]) {
        final canvas = _renderOn(
          _PathCopyCanvas(),
          TriangleShapeRenderer(),
          _set(holeRadius: 2, holeColor: holeColor),
        );
        final ring = canvas.copies.first;
        expect(
          canvas.paths.first.bounds,
          const ui.Rect.fromLTRB(45, 45, 55, 55),
        );
        expect(canvas.paths.first.color.toARGB32(), _ENTRY.toARGB32());
        expect(ring.contains(band), isTrue, reason: 'hole color $holeColor');
        expect(ring.contains(hole), isFalse, reason: 'hole color $holeColor');
      }
    });

    test('with a hole radius but no hole color draws the ring only', () {
      final canvas = _renderOn(
        _PathCopyCanvas(),
        TriangleShapeRenderer(),
        _set(holeRadius: 2),
      );
      expect(canvas.drawPathCalls, 1);
      expect(canvas.paths.single.color.toARGB32(), _ENTRY.toARGB32());
    });

    test('with a hole color fills the inner triangle in the hole color', () {
      final canvas = _renderOn(
        _PathCopyCanvas(),
        TriangleShapeRenderer(),
        _set(holeRadius: 2, holeColor: _HOLE),
      );
      expect(canvas.drawPathCalls, 2);
      expect(canvas.paths[0].bounds, const ui.Rect.fromLTRB(45, 45, 55, 55));
      expect(canvas.paths[0].color.toARGB32(), _ENTRY.toARGB32());
      expect(canvas.paths[1].bounds, const ui.Rect.fromLTRB(48, 48, 52, 52));
      expect(canvas.paths[1].color.toARGB32(), _HOLE.toARGB32());
      expect(canvas.paths[1].style, ui.PaintingStyle.fill);
      final fill = canvas.copies[1];
      expect(fill.contains(hole), isTrue);
      expect(fill.contains(band), isFalse);
    });

    test('draws the same triangle again from its reused path', () {
      final shape = TriangleShapeRenderer();
      final set = _set();
      expect(
        _render(shape, set).paths.single.bounds,
        const ui.Rect.fromLTRB(45, 45, 55, 55),
      );
      expect(
        _render(shape, set, x: 100, y: 20).paths.single.bounds,
        const ui.Rect.fromLTRB(95, 15, 105, 25),
      );
    });
  });

  group('line shapes', () {
    List<(ui.Offset, ui.Offset)> lines(IShapeRenderer shape) {
      final canvas = _render(shape, _set());
      for (final line in canvas.lines) {
        expect(line.color.toARGB32(), _ENTRY.toARGB32());
        expect(line.strokeWidth, 1);
      }
      return [for (final line in canvas.lines) (line.p1, line.p2)];
    }

    test(
      'CrossShapeRenderer draws a horizontal and a vertical line of the size',
      () {
        expect(lines(CrossShapeRenderer()), [
          (const ui.Offset(45, 50), const ui.Offset(55, 50)),
          (const ui.Offset(50, 45), const ui.Offset(50, 55)),
        ]);
      },
    );

    test('XShapeRenderer draws the two diagonals of the size', () {
      expect(lines(XShapeRenderer()), [
        (const ui.Offset(45, 45), const ui.Offset(55, 55)),
        (const ui.Offset(55, 45), const ui.Offset(45, 55)),
      ]);
    });

    test('ChevronUpShapeRenderer has its tip one size above the entry', () {
      expect(lines(ChevronUpShapeRenderer()), [
        (const ui.Offset(50, 40), const ui.Offset(60, 50)),
        (const ui.Offset(50, 40), const ui.Offset(40, 50)),
      ]);
    });

    test('ChevronDownShapeRenderer has its tip one size below the entry', () {
      expect(lines(ChevronDownShapeRenderer()), [
        (const ui.Offset(50, 60), const ui.Offset(60, 50)),
        (const ui.Offset(50, 60), const ui.Offset(40, 50)),
      ]);
    });
  });

  test('a NaN x or y draws no rectangle, circle or line', () {
    final shapes = <IShapeRenderer>[
      SquareShapeRenderer(),
      CircleShapeRenderer(),
      CrossShapeRenderer(),
      XShapeRenderer(),
      ChevronUpShapeRenderer(),
      ChevronDownShapeRenderer(),
    ];
    for (final shape in shapes) {
      for (final (x, y) in [(double.nan, 50.0), (50.0, double.nan)]) {
        final canvas = StrictCanvas();
        shape.renderShape(
          canvas,
          _set(holeRadius: 2, holeColor: _HOLE),
          ViewPortHandler(),
          x,
          y,
          ChartPaint(),
        );
        expect(canvas.calls, isEmpty, reason: '$shape at ($x, $y)');
      }
    }
  });

  test(
    'IShapeRenderer.fromFunction calls the function once with the arguments',
    () {
      final calls = <List<Object>>[];
      final shape = IShapeRenderer.fromFunction(
        (c, dataSet, viewPortHandler, posX, posY, renderPaint) =>
            calls.add([c, dataSet, viewPortHandler, posX, posY, renderPaint]),
      );
      final canvas = PaintRecordingCanvas();
      final IScatterDataSet set = _set();
      final handler = ViewPortHandler();
      final paint = ChartPaint();

      shape.renderShape(canvas, set, handler, 3, 4, paint);

      expect(calls, hasLength(1));
      expect(calls.single[0], same(canvas));
      expect(calls.single[1], same(set));
      expect(calls.single[2], same(handler));
      expect(calls.single.sublist(3, 5), [3, 4]);
      expect(calls.single[5], same(paint));
    },
  );
}
