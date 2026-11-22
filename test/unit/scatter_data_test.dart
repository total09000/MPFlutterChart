// Not a port of a Kotlin test (task brief): locks ScatterShape, the ScatterDataSet defaults, shape lookup and copy,
// and ScatterData.greatestShapeSize. The DataSet / ChartData behaviour of the scatter classes is covered by the
// ports of DataSetTest.kt and ChartDataTest.kt.
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/charts/scatter_shape.dart';
import 'package:mp_flutter_chart/src/data/entry.dart';
import 'package:mp_flutter_chart/src/data/scatter_data.dart';
import 'package:mp_flutter_chart/src/data/scatter_data_set.dart';
import 'package:mp_flutter_chart/src/highlight/highlight_line_span.dart';
import 'package:mp_flutter_chart/src/renderer/scatter/chevron_down_shape_renderer.dart';
import 'package:mp_flutter_chart/src/renderer/scatter/chevron_up_shape_renderer.dart';
import 'package:mp_flutter_chart/src/renderer/scatter/circle_shape_renderer.dart';
import 'package:mp_flutter_chart/src/renderer/scatter/cross_shape_renderer.dart';
import 'package:mp_flutter_chart/src/renderer/scatter/square_shape_renderer.dart';
import 'package:mp_flutter_chart/src/renderer/scatter/triangle_shape_renderer.dart';
import 'package:mp_flutter_chart/src/renderer/scatter/x_shape_renderer.dart';
import 'package:mp_flutter_chart/src/utils/color_template.dart';

void main() {
  group('ScatterShape', () {
    test('toString gives the shape identifier', () {
      expect(ScatterShape.CHEVRON_UP.toString(), 'CHEVRON_UP');
      expect(
        [for (final shape in ScatterShape.values) '$shape'],
        [
          'SQUARE',
          'CIRCLE',
          'TRIANGLE',
          'CROSS',
          'X',
          'CHEVRON_UP',
          'CHEVRON_DOWN',
        ],
      );
    });
  });

  group('ScatterDataSet', () {
    test('defaults to a 7.5 dp square without a hole', () {
      final set = ScatterDataSet([Entry(x: 0, y: 1)], 'points');
      expect(set.scatterShapeSize, 7.5);
      expect(set.shapeRenderer, isA<SquareShapeRenderer>());
      expect(set.scatterShapeHoleRadius, 0);
      expect(set.scatterShapeHoleColor, ColorTemplate.COLOR_NONE);
    });

    test('getRendererForShape gives a new built-in renderer per shape', () {
      expect(
        ScatterDataSet.getRendererForShape(ScatterShape.SQUARE),
        isA<SquareShapeRenderer>(),
      );
      expect(
        ScatterDataSet.getRendererForShape(ScatterShape.CIRCLE),
        isA<CircleShapeRenderer>(),
      );
      expect(
        ScatterDataSet.getRendererForShape(ScatterShape.TRIANGLE),
        isA<TriangleShapeRenderer>(),
      );
      expect(
        ScatterDataSet.getRendererForShape(ScatterShape.CROSS),
        isA<CrossShapeRenderer>(),
      );
      expect(
        ScatterDataSet.getRendererForShape(ScatterShape.X),
        isA<XShapeRenderer>(),
      );
      expect(
        ScatterDataSet.getRendererForShape(ScatterShape.CHEVRON_UP),
        isA<ChevronUpShapeRenderer>(),
      );
      expect(
        ScatterDataSet.getRendererForShape(ScatterShape.CHEVRON_DOWN),
        isA<ChevronDownShapeRenderer>(),
      );
      expect(
        ScatterDataSet.getRendererForShape(ScatterShape.SQUARE),
        isNot(same(ScatterDataSet.getRendererForShape(ScatterShape.SQUARE))),
      );
    });

    test('setScatterShape replaces the shape renderer', () {
      final set = ScatterDataSet([Entry(x: 0, y: 1)], 'points');
      set.setScatterShape(ScatterShape.CHEVRON_DOWN);
      expect(set.shapeRenderer, isA<ChevronDownShapeRenderer>());
    });

    test('copy keeps the shape styling and shares the renderer', () {
      final set = ScatterDataSet<String>([
        Entry(x: 0, y: 1, data: 'a'),
        Entry(x: 2, y: 3, data: 'b'),
      ], 'points');
      set
        ..scatterShapeSize = 12
        ..scatterShapeHoleRadius = 3
        ..scatterShapeHoleColor = const ui.Color(0xFF00FF00)
        ..setScatterShape(ScatterShape.TRIANGLE)
        ..verticalHighlightIndicatorSpan = HighlightLineSpan.TO_ENTRY;

      final copy = set.copy() as ScatterDataSet<String>;

      expect(copy.label, 'points');
      expect(copy.scatterShapeSize, 12);
      expect(copy.scatterShapeHoleRadius, 3);
      expect(copy.scatterShapeHoleColor, const ui.Color(0xFF00FF00));
      expect(copy.shapeRenderer, same(set.shapeRenderer));
      expect(copy.verticalHighlightIndicatorSpan, HighlightLineSpan.TO_ENTRY);
      expect(copy.entryCount, 2);
      expect(copy.entries[1], isNot(same(set.entries[1])));
      expect(
        [copy.entries[1].x, copy.entries[1].y, copy.entries[1].data],
        [2, 3, 'b'],
      );
    });
  });

  group('ScatterData', () {
    test('greatestShapeSize is the largest shape size of the sets', () {
      final a = ScatterDataSet([Entry(x: 0, y: 1)], 'a')..scatterShapeSize = 3;
      final b = ScatterDataSet([Entry(x: 0, y: 2)], 'b')..scatterShapeSize = 9;
      expect(ScatterData([a, b]).greatestShapeSize, 9);
      expect(ScatterData([b, a]).greatestShapeSize, 9);
    });

    test('greatestShapeSize is 0 without sets', () {
      expect(ScatterData().greatestShapeSize, 0);
    });
  });
}
