// Extra tests for renderer/XAxisRenderer.kt, YAxisRenderer.kt and LegendRenderer.kt on a RecordingCanvas; no Kotlin
// unit-test counterpart (the device tests' AxisDrawTest covers the axes on Android).
//
// Chart 200 x 100 px with the content rect inset by 10 px on every side (10..190 x 10..90); x 0..10 → 10..190 px,
// y 0..100 → 90..10 px.
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/components/legend.dart';
import 'package:mp_flutter_chart/src/components/legend_entry.dart';
import 'package:mp_flutter_chart/src/components/limit_line.dart';
import 'package:mp_flutter_chart/src/components/x_axis.dart';
import 'package:mp_flutter_chart/src/components/y_axis.dart';
import 'package:mp_flutter_chart/src/data/bar_data.dart';
import 'package:mp_flutter_chart/src/data/bar_data_set.dart';
import 'package:mp_flutter_chart/src/data/bar_entry.dart';
import 'package:mp_flutter_chart/src/data/candle_data.dart';
import 'package:mp_flutter_chart/src/data/candle_data_set.dart';
import 'package:mp_flutter_chart/src/data/candle_entry.dart';
import 'package:mp_flutter_chart/src/data/entry.dart';
import 'package:mp_flutter_chart/src/data/line_data.dart';
import 'package:mp_flutter_chart/src/data/line_data_set.dart';
import 'package:mp_flutter_chart/src/data/pie_data.dart';
import 'package:mp_flutter_chart/src/data/pie_data_set.dart';
import 'package:mp_flutter_chart/src/data/pie_entry.dart';
import 'package:mp_flutter_chart/src/graphics/chart_paint.dart';
import 'package:mp_flutter_chart/src/renderer/legend_renderer.dart';
import 'package:mp_flutter_chart/src/renderer/x_axis_renderer.dart';
import 'package:mp_flutter_chart/src/renderer/y_axis_renderer.dart';
import 'package:mp_flutter_chart/src/utils/color_template.dart';
import 'package:mp_flutter_chart/src/utils/transformer.dart';
import 'package:mp_flutter_chart/src/utils/view_port_handler.dart';

import '../../recording/recording_canvas.dart';

ViewPortHandler _handler() => ViewPortHandler()
  ..setChartDimens(200, 100)
  ..restrainViewPort(10, 10, 10, 10);

Transformer _transformer(ViewPortHandler handler) => Transformer(handler)
  ..prepareMatrixValuePx(0, 10, 100, 0)
  ..prepareMatrixOffset(false);

void main() {
  group('YAxisRenderer', () {
    test('draws one label and one grid line per entry, then the zero line', () {
      final handler = _handler();
      final axis = YAxis()
        ..labelCount = 6
        ..isDrawZeroLineEnabled = true;
      final renderer = YAxisRenderer(handler, axis, _transformer(handler));
      renderer.computeAxis(0, 100, false);
      expect(axis.entryCount, 6);

      final canvas = RecordingCanvas();
      renderer.renderAxisLabels(canvas);
      expect(canvas.drawParagraphCalls, 6);

      renderer.renderGridLines(canvas);
      // Six grid lines and the zero line.
      expect(canvas.drawPathCalls, 7);
      expect(canvas.paths.first.bounds.left, closeTo(10, 1e-4));
      expect(canvas.paths.first.bounds.right, closeTo(190, 1e-4));
      expect(canvas.paths.first.bounds.top, closeTo(90, 1e-4));
      expect(canvas.getSaveCount(), 1);

      renderer.renderAxisLine(canvas);
      expect(canvas.drawLineCalls, 1);
      // The left axis line runs down the content left edge.
      final line = canvas.lines.single;
      expect(line.p1, const ui.Offset(10, 10));
      expect(line.p2, const ui.Offset(10, 90));
      expect(line.color.toARGB32(), axis.axisLineColor.toARGB32());
    });

    test('limit lines draw their line and a label for every label position', () {
      for (final position in LimitLabelPosition.values) {
        final handler = _handler();
        final axis = YAxis()
          ..addLimitLine(LimitLine(50, 'limit')..labelPosition = position)
          ..addLimitLine(LimitLine(500, 'outside'));
        final renderer = YAxisRenderer(handler, axis, _transformer(handler));

        final canvas = RecordingCanvas();
        renderer.renderLimitLines(canvas);
        expect(canvas.drawPathCalls, 2, reason: '$position');
        // FILL_AND_STROKE text is a fill and a stroke paragraph; the line outside the content has no label.
        expect(canvas.drawParagraphCalls, 2, reason: '$position');
        expect(canvas.getSaveCount(), 1);
      }
    });

    test('rotated labels go through drawXAxisValue', () {
      final handler = _handler();
      final axis = YAxis()..labelRotationAngle = 45;
      final renderer = YAxisRenderer(handler, axis, _transformer(handler));
      renderer.computeAxis(0, 100, false);

      final canvas = RecordingCanvas();
      renderer.renderAxisLabels(canvas);
      expect(canvas.rotateCalls, axis.entryCount);
      expect(canvas.getSaveCount(), 1);
    });
  });

  group('XAxisRenderer', () {
    test(
      'computeAxis measures the labels and keeps them a label width apart',
      () {
        final handler = _handler();
        final axis = XAxis();
        final renderer = XAxisRenderer(handler, axis, _transformer(handler));
        renderer.computeAxis(0, 10, false);
        expect(axis.entryCount, greaterThan(1));
        expect(axis.labelWidth, greaterThan(0));
        expect(axis.labelHeight, greaterThan(0));
        final step = axis.entries[1] - axis.entries[0];
        // In pixels, neighbouring labels are at least one rotated label width apart.
        expect(step * 18, greaterThanOrEqualTo(axis.labelRotatedWidth - 1e-3));
      },
    );

    test('draws the labels inside the content width for every position', () {
      for (final position in XAxisPosition.values) {
        final handler = _handler();
        final axis = XAxis()..position = position;
        final renderer = XAxisRenderer(handler, axis, _transformer(handler));
        renderer.computeAxis(0, 10, false);

        final canvas = RecordingCanvas();
        renderer.renderAxisLabels(canvas);
        final perSide = position == XAxisPosition.BOTH_SIDED ? 2 : 1;
        expect(
          canvas.drawParagraphCalls,
          axis.entryCount * perSide,
          reason: '$position',
        );

        renderer.renderAxisLine(canvas);
        expect(canvas.drawLineCalls, perSide, reason: '$position');
      }
    });

    test('grid lines are vertical and clipped to the widened content rect', () {
      final handler = _handler();
      final axis = XAxis();
      final renderer = XAxisRenderer(handler, axis, _transformer(handler));
      renderer.computeAxis(0, 10, false);

      final canvas = RecordingCanvas();
      renderer.renderGridLines(canvas);
      expect(canvas.drawPathCalls, axis.entryCount);
      expect(canvas.paths.first.bounds.top, closeTo(10, 1e-4));
      expect(canvas.paths.first.bounds.bottom, closeTo(90, 1e-4));
      expect(
        canvas.clipRects.single.left,
        closeTo(10 - axis.gridLineWidth, 1e-4),
      );
      expect(canvas.getSaveCount(), 1);
    });

    test('limit lines draw their line and label for every label position', () {
      for (final position in LimitLabelPosition.values) {
        final handler = _handler();
        final axis = XAxis()
          ..addLimitLine(LimitLine(5, 'limit')..labelPosition = position);
        final renderer = XAxisRenderer(handler, axis, _transformer(handler));

        final canvas = RecordingCanvas();
        renderer.renderLimitLines(canvas);
        expect(canvas.drawPathCalls, 1, reason: '$position');
        expect(canvas.paths.single.bounds.left, closeTo(100, 1e-4));
        expect(canvas.drawParagraphCalls, 2, reason: '$position');
        expect(canvas.getSaveCount(), 1);
      }
    });
  });

  group('LegendRenderer', () {
    LineData data() {
      final set =
          LineDataSet([
              Entry(x: 0, y: 1),
              Entry(x: 1, y: 2),
              Entry(x: 2, y: 3),
            ], 'three colors')
            ..colors = [
              const ui.Color(0xFFFF0000),
              const ui.Color(0xFF00FF00),
              const ui.Color(0xFF0000FF),
            ];
      return LineData([
        set,
        LineDataSet([Entry(x: 0, y: 1)], 'single'),
      ]);
    }

    test('computeLegend builds one entry per color, labelling the last', () {
      final legend = Legend()
        ..extraEntries = [LegendEntry('extra', LegendForm.CIRCLE)];
      LegendRenderer(_handler(), legend).computeLegend(data());

      expect(legend.isLegendCustom, isFalse);
      expect(legend.entries.map((e) => e.label).toList(), [
        null,
        null,
        'three colors',
        'single',
        'extra',
      ]);
      expect(legend.entries[1].formColor.toARGB32(), 0xFF00FF00);
      expect(legend.neededWidth, greaterThan(0));
    });

    BarData stackedBars(List<String> stackLabels) => BarData([
      BarDataSet([
          BarEntry.stacked(x: 0, stackValues: [1, 2]),
          BarEntry(x: 1, y: 3),
        ], 'stacked')
        ..colors = [
          const ui.Color(0xFFFF0000),
          const ui.Color(0xFF00FF00),
          const ui.Color(0xFF0000FF),
        ]
        ..stackLabels = stackLabels,
    ]);

    test(
      'computeLegend gives a stacked bar set one entry per stack value and an unformed label',
      () {
        final legend = Legend();
        final data = stackedBars(['a', 'b']);
        expect(data.dataSets[0].stackSize, 2);
        LegendRenderer(_handler(), legend).computeLegend(data);

        expect(legend.entries.map((e) => e.label).toList(), [
          'a',
          'b',
          'stacked',
        ]);
        expect(legend.entries[0].form, LegendForm.DEFAULT);
        expect(legend.entries[0].formColor.toARGB32(), 0xFFFF0000);
        expect(legend.entries[1].form, LegendForm.DEFAULT);
        expect(legend.entries[1].formColor.toARGB32(), 0xFF00FF00);
        final setLabel = legend.entries[2];
        expect(setLabel.form, LegendForm.NONE);
        expect(setLabel.formSize, isNaN);
        expect(setLabel.formLineWidth, isNaN);
        expect(setLabel.formLineDashEffect, isNull);
        expect(setLabel.formColor, ColorTemplate.COLOR_NONE);
      },
    );

    test(
      'computeLegend leaves the stack entries unlabelled without stack labels',
      () {
        final legend = Legend();
        LegendRenderer(_handler(), legend).computeLegend(stackedBars(const []));
        expect(legend.entries.map((e) => e.label).toList(), [
          null,
          null,
          'stacked',
        ]);

        // Fewer labels than stack values: the rest stay unlabelled.
        LegendRenderer(_handler(), legend).computeLegend(stackedBars(['a']));
        expect(legend.entries.map((e) => e.label).toList(), [
          'a',
          null,
          'stacked',
        ]);
      },
    );

    test(
      'computeLegend gives a stack with fewer colors than values one entry per color, as in Kotlin',
      () {
        // min(colors, stackSize) entries: the third stack value has no color and no legend entry, and its label is
        // left out.
        final legend = Legend();
        final set =
            BarDataSet([
                BarEntry.stacked(x: 0, stackValues: [1, 2, 3]),
              ], 'three values')
              ..colors = [
                const ui.Color(0xFFFF0000),
                const ui.Color(0xFF00FF00),
              ]
              ..stackLabels = ['a', 'b', 'c'];
        expect(set.stackSize, 3);
        LegendRenderer(_handler(), legend).computeLegend(BarData([set]));

        expect(legend.entries.map((e) => e.label).toList(), [
          'a',
          'b',
          'three values',
        ]);
        expect(legend.entries[0].formColor.toARGB32(), 0xFFFF0000);
        expect(legend.entries[1].formColor.toARGB32(), 0xFF00FF00);
        expect(legend.entries[2].form, LegendForm.NONE);
      },
    );

    test('computeLegend treats an unstacked bar set like any other set', () {
      final legend = Legend();
      final bars =
          BarDataSet([BarEntry(x: 0, y: 1), BarEntry(x: 1, y: 2)], 'plain')
            ..colors = [const ui.Color(0xFFFF0000), const ui.Color(0xFF00FF00)]
            ..stackLabels = ['ignored'];
      LegendRenderer(_handler(), legend).computeLegend(BarData([bars]));
      expect(legend.entries.map((e) => e.label).toList(), [null, 'plain']);
      expect(legend.entries[1].form, LegendForm.DEFAULT);
    });

    test(
      'computeLegend gives a pie set one entry per slice label and an unformed set label',
      () {
        PieData pie(String label) => PieData(
          PieDataSet([
              PieEntry(1, label: 'North\nEast'),
              PieEntry(2, label: 'South'),
              PieEntry(3),
            ], label)
            ..colors = [const ui.Color(0xFFFF0000), const ui.Color(0xFF00FF00)],
        );
        final legend = Legend();
        LegendRenderer(_handler(), legend).computeLegend(pie('regions'));

        // Two colors for three slices: one entry per color, as in Kotlin's loop.
        expect(legend.entries.map((e) => e.label).toList(), [
          'North East',
          'South',
          'regions',
        ]);
        expect(legend.entries[0].form, LegendForm.DEFAULT);
        expect(legend.entries[0].formColor.toARGB32(), 0xFFFF0000);
        expect(legend.entries[1].formColor.toARGB32(), 0xFF00FF00);
        final setLabel = legend.entries[2];
        expect(setLabel.form, LegendForm.NONE);
        expect(setLabel.formSize, isNaN);
        expect(setLabel.formColor, ColorTemplate.COLOR_NONE);

        // A blank set label adds no entry.
        LegendRenderer(_handler(), legend).computeLegend(pie('  '));
        expect(legend.entries.map((e) => e.label).toList(), [
          'North East',
          'South',
        ]);
      },
    );

    test(
      'computeLegend gives a pie slice without a label an entry without a label',
      () {
        // Kotlin adds the entry with a null label (LegendRenderer.kt:82); only a blank set label is skipped.
        final legend = Legend();
        LegendRenderer(_handler(), legend).computeLegend(
          PieData(
            PieDataSet([PieEntry(1, label: 'North'), PieEntry(2)], 'regions')
              ..colors = [
                const ui.Color(0xFFFF0000),
                const ui.Color(0xFF0000FF),
              ],
          ),
        );

        expect(legend.entries.map((e) => e.label).toList(), [
          'North',
          null,
          'regions',
        ]);
        expect(legend.entries[1].form, LegendForm.DEFAULT);
        expect(legend.entries[1].formColor.toARGB32(), 0xFF0000FF);
      },
    );

    test(
      'computeLegend gives a candle set with a decreasing color a decreasing '
      'and an increasing entry, labelling the second',
      () {
        final legend = Legend();
        final candles =
            CandleDataSet([
                CandleEntry(x: 0, high: 20, low: 10, open: 12, close: 18),
                CandleEntry(x: 1, high: 20, low: 10, open: 18, close: 12),
              ], 'candles')
              ..colors = [
                const ui.Color(0xFF111111),
                const ui.Color(0xFF222222),
                const ui.Color(0xFF333333),
              ]
              ..decreasingColor = const ui.Color(0xFFFF0000)
              ..increasingColor = const ui.Color(0xFF00FF00)
              ..form = LegendForm.CIRCLE;
        LegendRenderer(_handler(), legend).computeLegend(CandleData([candles]));

        expect(legend.entries.map((e) => e.label).toList(), [null, 'candles']);
        expect(legend.entries[0].formColor.toARGB32(), 0xFFFF0000);
        expect(legend.entries[1].formColor.toARGB32(), 0xFF00FF00);
        for (final entry in legend.entries) {
          expect(entry.form, LegendForm.CIRCLE);
        }

        // The increasing color is taken as it is, even COLOR_NONE.
        candles.increasingColor = ColorTemplate.COLOR_NONE;
        LegendRenderer(_handler(), legend).computeLegend(CandleData([candles]));
        expect(legend.entries.map((e) => e.label).toList(), [null, 'candles']);
        expect(legend.entries[1].formColor, ColorTemplate.COLOR_NONE);
      },
    );

    test(
      'computeLegend treats a candle set without a decreasing color like any '
      'other set',
      () {
        final legend = Legend();
        final candles =
            CandleDataSet([
                CandleEntry(x: 0, high: 20, low: 10, open: 12, close: 18),
                CandleEntry(x: 1, high: 20, low: 10, open: 18, close: 12),
              ], 'candles')
              ..colors = [
                const ui.Color(0xFF111111),
                const ui.Color(0xFF222222),
                const ui.Color(0xFF333333),
              ]
              ..increasingColor = const ui.Color(0xFF00FF00);
        LegendRenderer(_handler(), legend).computeLegend(CandleData([candles]));

        // One entry per color up to the entry count, the last labelled.
        expect(legend.entries.map((e) => e.label).toList(), [null, 'candles']);
        expect(legend.entries[0].formColor.toARGB32(), 0xFF111111);
        expect(legend.entries[1].formColor.toARGB32(), 0xFF222222);
      },
    );

    test('a custom legend keeps its entries', () {
      final custom = [LegendEntry('mine', LegendForm.LINE)];
      final legend = Legend(custom);
      LegendRenderer(_handler(), legend).computeLegend(data());
      expect(legend.entries, same(custom));
    });

    test('renders forms and labels in every orientation and alignment', () {
      for (final orientation in LegendOrientation.values) {
        for (final horizontal in LegendHorizontalAlignment.values) {
          for (final vertical in LegendVerticalAlignment.values) {
            for (final direction in LegendDirection.values) {
              final legend = Legend()
                ..orientation = orientation
                ..horizontalAlignment = horizontal
                ..verticalAlignment = vertical
                ..direction = direction;
              final renderer = LegendRenderer(_handler(), legend);
              renderer.computeLegend(data());

              final canvas = RecordingCanvas();
              renderer.renderLegend(canvas);
              final where = '$orientation $horizontal $vertical $direction';
              // Four colored entries with the default SQUARE form, two labels.
              expect(canvas.drawRectCalls, 4, reason: where);
              expect(canvas.drawParagraphCalls, 2, reason: where);
              expect(canvas.getSaveCount(), 1, reason: where);
            }
          }
        }
      }
    });

    test(
      'drawForm draws circles and lines, and skips entries without a color',
      () {
        final legend = Legend([
          LegendEntry(
            'circle',
            LegendForm.CIRCLE,
            double.nan,
            double.nan,
            null,
            const ui.Color(0xFFFF0000),
          ),
          LegendEntry(
            'line',
            LegendForm.LINE,
            double.nan,
            double.nan,
            null,
            const ui.Color(0xFF00FF00),
          ),
          LegendEntry(
            'none',
            LegendForm.SQUARE,
            double.nan,
            double.nan,
            null,
            const ui.Color(0x00112233),
          ),
          LegendEntry('empty', LegendForm.EMPTY),
        ]);
        final renderer = LegendRenderer(_handler(), legend);
        renderer.computeLegend(data());

        final canvas = RecordingCanvas();
        renderer.renderLegend(canvas);
        expect(canvas.drawCircleCalls, 1);
        expect(canvas.drawPathCalls, 1);
        expect(canvas.drawRectCalls, 0);
        expect(canvas.drawParagraphCalls, 4);
      },
    );

    test(
      'a dashed LINE form does not dash the fill of a later CIRCLE or SQUARE form',
      () {
        // drawForm leaves the LINE dash on formPaint, as on Android; fills are never dashed, as in Skia.
        final legend = Legend([
          LegendEntry(
            'line',
            LegendForm.LINE,
            double.nan,
            double.nan,
            DashPathEffect(const [2, 2], 0),
            const ui.Color(0xFF00FF00),
          ),
          LegendEntry(
            'circle',
            LegendForm.CIRCLE,
            double.nan,
            double.nan,
            null,
            const ui.Color(0xFFFF0000),
          ),
          LegendEntry(
            'square',
            LegendForm.SQUARE,
            double.nan,
            double.nan,
            null,
            const ui.Color(0xFF0000FF),
          ),
        ]);
        final renderer = LegendRenderer(_handler(), legend);
        renderer.computeLegend(data());

        final canvas = RecordingCanvas();
        renderer.renderLegend(canvas);
        // The dashed line is a path; the circle and the square are drawn whole, filled.
        expect(canvas.drawPathCalls, 1);
        expect(canvas.paths.single.style, ui.PaintingStyle.stroke);
        expect(canvas.drawCircleCalls, 1);
        expect(canvas.circles.single.style, ui.PaintingStyle.fill);
        expect(canvas.circles.single.color.toARGB32(), 0xFFFF0000);
        expect(canvas.drawRectCalls, 1);
        expect(canvas.rects.single.color.toARGB32(), 0xFF0000FF);
      },
    );

    test('a disabled legend draws nothing', () {
      final legend = Legend()..isEnabled = false;
      final renderer = LegendRenderer(_handler(), legend);
      renderer.computeLegend(data());
      final canvas = RecordingCanvas();
      renderer.renderLegend(canvas);
      expect(canvas.calls, isEmpty);
    });
  });
}
