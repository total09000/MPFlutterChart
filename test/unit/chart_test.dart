// Not a port of a Kotlin test: MPAndroidChart v4.0.1 has no unit test for Chart or BarLineChartBase. Checks the plain
// Dart chart of spec §6.1 without a host and with a fake one: viewport jobs that wait for a size, the zoom and move
// functions, animations that end at once without a ticker, toImage and the host hooks.
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart' show TickerProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/charts/bar_chart.dart';
import 'package:mp_flutter_chart/src/charts/chart.dart';
import 'package:mp_flutter_chart/src/charts/chart_host.dart';
import 'package:mp_flutter_chart/src/charts/line_chart.dart';
import 'package:mp_flutter_chart/src/components/i_marker.dart';
import 'package:mp_flutter_chart/src/components/y_axis.dart';
import 'package:mp_flutter_chart/src/data/bar_data.dart';
import 'package:mp_flutter_chart/src/data/bar_data_set.dart';
import 'package:mp_flutter_chart/src/data/bar_entry.dart';
import 'package:mp_flutter_chart/src/data/entry.dart';
import 'package:mp_flutter_chart/src/data/line_data.dart';
import 'package:mp_flutter_chart/src/data/line_data_set.dart';
import 'package:mp_flutter_chart/src/highlight/highlight.dart';
import 'package:mp_flutter_chart/src/listener/bar_line_chart_touch_listener.dart';
import 'package:mp_flutter_chart/src/listener/chart_touch_listener.dart';
import 'package:mp_flutter_chart/src/utils/mp_point_f.dart';
import 'package:mp_flutter_chart/src/widgets/chart_touch_event.dart';

import '../recording/recording_canvas.dart';

class _FakeHost implements ChartHost {
  _FakeHost([this.vsync]);

  @override
  final TickerProvider? vsync;

  int paints = 0;
  int scrollDisables = 0;
  int scrollEnables = 0;
  final List<void Function()> posted = [];

  /// Set by a test around `Chart.onDraw`; a repaint request while it is true is counted in [paintsDuringDraw].
  bool drawing = false;
  int paintsDuringDraw = 0;

  @override
  void markNeedsPaint() {
    paints++;
    if (drawing) paintsDuringDraw++;
  }

  @override
  void postFrame(void Function() job) => posted.add(job);

  @override
  void disableScroll() => scrollDisables++;

  @override
  void enableScroll() => scrollEnables++;

  /// Runs the posted jobs like the end of a frame.
  void flush() {
    final jobs = posted.toList();
    posted.clear();
    for (final job in jobs) {
      job();
    }
  }
}

/// Records the events it gets and consumes them.
class _RecordingTouchListener extends ChartTouchListener<Chart> {
  _RecordingTouchListener(super.chart);

  final List<ChartTouchEvent> events = [];

  @override
  bool onTouch(Chart chart, ChartTouchEvent event) {
    events.add(event);
    return true;
  }
}

/// Adds 'marker' to [calls] when it is drawn.
class _CallMarker implements IMarker {
  _CallMarker(this.calls);

  final List<String> calls;

  @override
  final MPPointF offset = MPPointF();

  @override
  MPPointF getOffsetForDrawingAtPoint(double posX, double posY) => offset;

  @override
  void refreshContent(Entry e, Highlight highlight) {}

  @override
  void draw(ui.Canvas canvas, double posX, double posY) => calls.add('marker');
}

/// Eleven entries on the line y = x for x = 0 .. 10.
LineData _data() => LineData([
  LineDataSet([
    for (var i = 0; i <= 10; i++) Entry(x: i.toDouble(), y: i.toDouble()),
  ], 'a'),
]);

LineChart _sizedChart({ChartHost? host}) {
  final chart = LineChart()..host = host;
  chart.data = _data();
  chart.onSizeChanged(300, 200);
  return chart;
}

double _centerX(LineChart chart) =>
    (chart.lowestVisibleX + chart.highestVisibleX) / 2;

double _centerY(LineChart chart) {
  final center = chart.viewPortHandler.contentCenter;
  return chart.getValuesByTouchPoint(center.x, center.y, AxisDependency.LEFT).y;
}

void main() {
  group('host', () {
    test('without a host invalidate does nothing and post runs at once', () {
      final chart = LineChart();
      expect(chart.host, isNull);
      chart.invalidate();
      var ran = false;
      chart.post(() => ran = true);
      expect(ran, isTrue);
      chart.disableScroll();
      chart.enableScroll();
    });

    test('with a host invalidate marks it and post goes through postFrame', () {
      final host = _FakeHost();
      final chart = LineChart()..host = host;

      chart.invalidate();
      expect(host.paints, 1);
      chart.noDataText = 'Nothing here';
      expect(host.paints, 2);

      var ran = false;
      chart.post(() => ran = true);
      expect(ran, isFalse);
      host.flush();
      expect(ran, isTrue);

      chart.disableScroll();
      chart.enableScroll();
      expect([host.scrollDisables, host.scrollEnables], [1, 1]);
    });

    test(
      'a loading empty state posts the next repaint instead of asking during the draw',
      () {
        final host = _FakeHost();
        final chart = LineChart()
          ..host = host
          ..onSizeChanged(300, 200)
          ..isLoading = true;
        host.flush();
        final before = host.paints;
        final canvas = RecordingCanvas();
        host.drawing = true;
        chart.onDraw(canvas);
        host.drawing = false;
        expect(host.paintsDuringDraw, 0);
        expect(host.paints, before);
        expect(host.posted, hasLength(1));
        host.flush();
        expect(host.paints, before + 1);

        expect(canvas.drawParagraphCalls, 1);
        final textWidth = chart.infoPaint.measureText(chart.loadingText);
        expect(
          canvas.paragraphs.single.offset.dx,
          closeTo(150 - textWidth / 2, 1),
        );

        // Not loading: nothing is posted.
        chart.isLoading = false;
        host.flush();
        chart.onDraw(RecordingCanvas());
        expect(host.posted, isEmpty);

        // Without a host the posted repaint runs at once and does nothing.
        final hostless = LineChart()
          ..onSizeChanged(300, 200)
          ..isLoading = true;
        expect(() => hostless.onDraw(RecordingCanvas()), returnsNormally);
      },
    );

    test(
      'afterDrawListeners hear the end of every draw, empty or not',
      () async {
        final chart = LineChart()..onSizeChanged(300, 200);
        final calls = <String>[];
        void first() => calls.add('first ${chart.highlighted.length}');
        chart.afterDrawListeners
          ..add(first)
          ..add(() => calls.add('second'));

        // The empty state.
        chart.onDraw(RecordingCanvas());
        expect(calls, ['first 0', 'second']);

        // The data, after the markers.
        chart.data = _data();
        chart.marker = _CallMarker(calls);
        chart.highlightValue(3, 0);
        calls.clear();
        chart.onDraw(RecordingCanvas());
        expect(calls, ['marker', 'first 1', 'second']);

        // toImage draws too.
        calls.clear();
        (await chart.toImage()).dispose();
        expect(calls, ['marker', 'first 1', 'second']);

        chart.afterDrawListeners.remove(first);
        calls.clear();
        chart.onDraw(RecordingCanvas());
        expect(calls, ['marker', 'second']);
      },
    );
  });

  group('viewport jobs', () {
    test('jobs added before the chart has a size run in onSizeChanged', () {
      final chart = LineChart()..data = _data();
      chart.zoom(5, 1, 5, 0, AxisDependency.LEFT);
      chart.moveViewToX(6);
      expect(chart.jobs, hasLength(2));
      expect(chart.zoomX, 1);

      chart.onSizeChanged(300, 200);
      expect(chart.jobs, isEmpty);
      expect(chart.zoomX, closeTo(5, 1e-4));
      expect(chart.lowestVisibleX, closeTo(6, 1e-3));
      expect(chart.highestVisibleX, closeTo(8, 1e-3));
    });

    test('with a host, jobs wait for postFrame once the chart has a size', () {
      final host = _FakeHost();
      final chart = _sizedChart(host: host);
      chart.zoom(5, 1, 5, 0, AxisDependency.LEFT);
      expect(chart.jobs, isEmpty);
      expect(host.posted, hasLength(1));
      expect(chart.zoomX, 1);

      host.flush();
      expect(chart.zoomX, closeTo(5, 1e-4));
      expect(_centerX(chart), closeTo(5, 1e-3));
    });

    test(
      'a waiting job can be removed and onDetachedFromWindow drops the rest',
      () {
        final chart = LineChart()..data = _data();
        chart.moveViewToX(3);
        chart.centerViewTo(3, 3, AxisDependency.LEFT);
        expect(chart.jobs, hasLength(2));
        chart.removeViewportJob(chart.jobs.first);
        expect(chart.jobs, hasLength(1));

        chart.onDetachedFromWindow();
        expect(chart.jobs, isEmpty);
        chart.onSizeChanged(300, 200);
        expect(chart.lowestVisibleX, closeTo(0, 1e-4));
      },
    );

    test(
      'without a host, keeping the position undoes moves queued before the first size',
      () {
        LineChart keeping({ChartHost? host}) {
          final chart = LineChart()
            ..host = host
            ..isKeepPositionOnRotation = true
            ..data = _data();
          chart.zoom(5, 1, 5, 0, AxisDependency.LEFT);
          chart.moveViewToX(6);
          return chart;
        }

        // The jobs run inside onSizeChanged, before the kept position is restored: the scale stays, the move is gone.
        final hostless = keeping()..onSizeChanged(300, 200);
        expect(hostless.zoomX, closeTo(5, 1e-4));
        expect(hostless.lowestVisibleX, closeTo(0, 1e-3));

        // With a host they run after the frame, as on Android.
        final host = _FakeHost();
        final hosted = keeping(host: host)..onSizeChanged(300, 200);
        expect(host.posted, hasLength(2));
        host.flush();
        expect(hosted.zoomX, closeTo(5, 1e-4));
        expect(hosted.lowestVisibleX, closeTo(6, 1e-3));
      },
    );

    test('at most 64 jobs wait for a size', () {
      final chart = LineChart();
      for (var i = 0; i < 70; i++) {
        chart.addViewportJob(() {});
      }
      expect(chart.jobs, hasLength(64));
    });

    test('moving, zooming and animating before layout does not throw', () {
      for (final chart in [LineChart(), LineChart()..data = _data()]) {
        expect(() {
          chart.moveViewToX(3);
          chart.moveViewTo(3, 2, AxisDependency.LEFT);
          chart.centerViewTo(3, 2, AxisDependency.RIGHT);
          chart.centerViewToY(2, AxisDependency.LEFT);
          chart.zoom(2, 2, 3, 2, AxisDependency.LEFT);
          chart.moveViewToAnimated(3, 2, AxisDependency.LEFT, 300);
          chart.centerViewToAnimated(3, 2, AxisDependency.LEFT, 300);
          chart.zoomAndCenterAnimated(2, 2, 3, 2, AxisDependency.LEFT, 300);
          chart.zoom(2, 2, 10, 10);
          chart.zoomIn();
          chart.zoomOut();
          chart.zoomToCenter(2, 2);
          chart.resetZoom();
          chart.fitScreen();
          chart.setVisibleXRange(1, 5);
          chart.setVisibleYRangeMaximum(4, AxisDependency.LEFT);
          chart.animateX(500);
          chart.animateY(500);
          chart.animateXY(500, 500);
          chart.highlightValue(1, 0);
        }, returnsNormally);
        expect(chart.jobs, hasLength(8));

        expect(() => chart.onSizeChanged(300, 200), returnsNormally);
        expect(chart.jobs, isEmpty);
        expect(() => chart.onDraw(RecordingCanvas()), returnsNormally);
      }
    });

    test('numbers that are not finite are ignored', () {
      final unsized = LineChart()..data = _data();
      unsized.moveViewToX(double.infinity);
      unsized.zoom(2, 2, double.nan, 0, AxisDependency.LEFT);
      unsized.centerViewTo(double.nan, 0, AxisDependency.LEFT);
      expect(unsized.jobs, isEmpty);

      final chart = _sizedChart();
      chart.zoom(double.nan, 2, 10, 10);
      chart.zoom(double.infinity, 2, 10, 10);
      chart.zoomToCenter(2, double.infinity);
      expect([chart.zoomX, chart.zoomY], [1, 1]);
    });
  });

  group('zoom and move', () {
    test('zoom, moveViewTo, centerViewTo and fitScreen round trip', () {
      final chart = _sizedChart();
      expect(chart.isFullyZoomedOut, isTrue);
      expect(chart.lowestVisibleX, closeTo(0, 1e-4));
      expect(chart.highestVisibleX, closeTo(10, 1e-4));

      final center = chart.viewPortHandler.contentCenter;
      chart.zoom(2, 2, center.x, center.y);
      expect(chart.zoomX, closeTo(2, 1e-4));
      expect(chart.zoomY, closeTo(2, 1e-4));
      expect(chart.isFullyZoomedOut, isFalse);
      expect(chart.visibleXRange, closeTo(5, 1e-3));

      chart.centerViewTo(5, 5, AxisDependency.LEFT);
      expect(_centerX(chart), closeTo(5, 1e-3));
      expect(_centerY(chart), closeTo(5, 1e-3));

      chart.moveViewTo(1, 4, AxisDependency.LEFT);
      expect(chart.lowestVisibleX, closeTo(1, 1e-3));
      expect(_centerY(chart), closeTo(4, 1e-3));

      chart.moveViewToX(4);
      expect(chart.lowestVisibleX, closeTo(4, 1e-3));

      chart.centerViewToY(3, AxisDependency.LEFT);
      expect(_centerY(chart), closeTo(3, 1e-3));

      chart.fitScreen();
      expect([chart.zoomX, chart.zoomY], [1, 1]);
      expect(chart.isFullyZoomedOut, isTrue);
      expect(chart.lowestVisibleX, closeTo(0, 1e-4));
      expect(chart.highestVisibleX, closeTo(10, 1e-4));
    });

    test('zoomIn, zoomOut, zoomToCenter and resetZoom', () {
      final chart = _sizedChart();
      final left = chart.viewPortHandler.contentLeft;
      final width = chart.viewPortHandler.contentWidth;
      // Like Kotlin, these pivot the touch matrix, which works relative to the content's left edge, at the content
      // center in view pixels, so the value in the middle moves right by left * (1 - 1 / scale) pixels.
      double centerAfterZooming(double scale) =>
          (width / 2 + left * (1 - 1 / scale)) / width * 10;

      chart.zoomIn();
      expect(chart.zoomX, closeTo(1.4, 1e-4));
      expect(_centerX(chart), closeTo(centerAfterZooming(1.4), 1e-3));
      chart.zoomOut();
      // 1.4 * 0.7 is below the minimum scale of 1.
      expect(chart.zoomX, closeTo(1, 1e-4));

      chart.zoomToCenter(4, 1);
      expect(chart.zoomX, closeTo(4, 1e-4));
      expect(chart.zoomY, closeTo(1, 1e-4));
      expect(_centerX(chart), closeTo(centerAfterZooming(4), 1e-3));

      chart.resetZoom();
      expect([chart.zoomX, chart.zoomY], [1, 1]);
    });

    test('the visible range limits zooming', () {
      final chart = _sizedChart();
      chart.setVisibleXRangeMaximum(2);
      expect(chart.zoomX, closeTo(5, 1e-4));
      expect(chart.visibleXRange, closeTo(2, 1e-3));

      chart.setVisibleXRangeMaximum(0);
      chart.setVisibleXRangeMaximum(double.nan);
      expect(chart.zoomX, closeTo(5, 1e-4));

      chart.setVisibleXRange(1, 10);
      chart.fitScreen();
      chart.zoomToCenter(100, 1);
      expect(chart.zoomX, closeTo(10, 1e-3));
      expect(chart.visibleXRange, closeTo(1, 1e-3));
    });

    test('values and pixels convert back and forth', () {
      final chart = _sizedChart();
      final pixel = chart.getPixelForValues(3, 7, AxisDependency.LEFT);
      final values = chart.getValuesByTouchPoint(
        pixel.x,
        pixel.y,
        AxisDependency.LEFT,
      );
      expect(values.x, closeTo(3, 1e-3));
      expect(values.y, closeTo(7, 1e-3));

      final entry = chart.getEntryByTouchPoint(pixel.x, pixel.y);
      expect(entry?.x, 3);
      expect(
        chart.getDataSetByTouchPoint(pixel.x, pixel.y),
        same(chart.data!.getDataSetByIndex(0)),
      );

      final position = chart.getPosition(
        Entry(x: 3, y: 7),
        AxisDependency.LEFT,
      )!;
      expect(position.x, closeTo(pixel.x, 1e-3));
      expect(position.y, closeTo(pixel.y, 1e-3));
      expect(chart.getPosition(null, AxisDependency.LEFT), isNull);
    });
  });

  group('animations without a host', () {
    test('animateX, animateY and animateXY end at once', () {
      final chart = _sizedChart();
      var ended = 0;
      chart.animateX(1000, onEnd: () => ended++);
      expect(ended, 1);
      expect(chart.isAnimating, isFalse);
      expect(chart.animator.phaseX, 1);

      chart.animateY(1000, onEnd: () => ended++);
      chart.animateXY(1000, 500, onEnd: () => ended++);
      expect(ended, 3);
      expect([chart.animator.phaseX, chart.animator.phaseY], [1, 1]);
      expect(chart.isAnimating, isFalse);
    });

    test('animated viewport jobs jump to their end state', () {
      final chart = _sizedChart();
      chart.setVisibleXRangeMaximum(2);
      chart.moveViewToAnimated(6, 5, AxisDependency.LEFT, 500);
      expect(chart.lowestVisibleX, closeTo(6, 1e-3));
      expect(_centerY(chart), closeTo(5, 1e-3));

      chart.centerViewToAnimated(3, 4, AxisDependency.LEFT, 500);
      expect(_centerX(chart), closeTo(3, 1e-3));
      expect(chart.runningViewPortJobs, isEmpty);

      final zoomed = _sizedChart();
      zoomed.zoomAndCenterAnimated(4, 1, 5, 0, AxisDependency.LEFT, 300);
      expect(zoomed.zoomX, closeTo(4, 1e-4));
      expect(zoomed.lowestVisibleX, closeTo(3.75, 1e-3));
      expect(zoomed.highestVisibleX, closeTo(6.25, 1e-3));
      expect(zoomed.runningViewPortJobs, isEmpty);
    });
  });

  group('animateValue', () {
    test('a stacked bar is refused, a plain bar moves to its value', () {
      final stacked = BarEntry.stacked(x: 0, stackValues: [1, 2]);
      final plain = BarEntry(x: 1, y: 1);
      final chart = BarChart()
        ..data = BarData([
          BarDataSet([stacked, plain], ''),
        ])
        ..onSizeChanged(400, 300);

      expect(
        () => chart.animateValue(stacked, 3, 100),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'animateValue does not animate stacked bars, use animateDataChange.',
          ),
        ),
      );
      expect(stacked.stackValues, [1, 2]);
      expect(stacked.y, 3);

      var ended = 0;
      chart.animateValue(plain, 5, 100, onEnd: () => ended++);
      expect(ended, 1);
      expect(plain.y, 5);
      expect(chart.barData!.yMax, 5);
    });

    test('the stacked check comes before the data check', () {
      final chart = BarChart()
        ..data = BarData([
          BarDataSet([BarEntry(x: 0, y: 1)], ''),
        ]);
      expect(
        () => chart.animateValue(
          BarEntry.stacked(x: 0, stackValues: [1, 2]),
          3,
          100,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'animateValue does not animate stacked bars, use animateDataChange.',
          ),
        ),
      );
      expect(
        () => chart.animateValue(BarEntry(x: 0, y: 1), 3, 100),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'The entry is not part of the chart data.',
          ),
        ),
      );
    });
  });

  group('animations with a host ticker', () {
    testWidgets('an animated move runs on the ticker and ends at its target', (
      tester,
    ) async {
      final host = _FakeHost(const TestVSync());
      final chart = _sizedChart(host: host);
      chart.setVisibleXRangeMaximum(2);
      chart.moveViewToAnimated(6, 5, AxisDependency.LEFT, 500);
      host.flush();
      expect(chart.runningViewPortJobs, hasLength(1));
      expect(chart.lowestVisibleX, closeTo(0, 1e-3));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(chart.lowestVisibleX, greaterThan(0.1));
      expect(chart.lowestVisibleX, lessThan(5.9));

      final paints = host.paints;
      await tester.pump(const Duration(milliseconds: 300));
      expect(chart.lowestVisibleX, closeTo(6, 1e-3));
      expect(chart.runningViewPortJobs, isEmpty);
      expect(host.paints, greaterThan(paints));
    });

    testWidgets(
      'onDetachedFromWindow ends a running viewport animation at its target',
      (tester) async {
        final host = _FakeHost(const TestVSync());
        final chart = _sizedChart(host: host);
        chart.zoomAndCenterAnimated(4, 1, 5, 0, AxisDependency.LEFT, 1000);
        host.flush();
        expect(chart.runningViewPortJobs, hasLength(1));

        chart.onDetachedFromWindow();
        expect(chart.runningViewPortJobs, isEmpty);
        expect(chart.zoomX, closeTo(4, 1e-4));
        expect(chart.lowestVisibleX, closeTo(3.75, 1e-3));
      },
    );
  });

  group('toImage', () {
    test('draws at the chart size by default', () async {
      final chart = _sizedChart();
      final image = await chart.toImage();
      expect([image.width, image.height], [300, 200]);
      image.dispose();
    });

    test('draws at an asked size and keeps the chart size', () async {
      final chart = _sizedChart();
      final image = await chart.toImage(width: 120, height: 80);
      expect([image.width, image.height], [120, 80]);
      image.dispose();
      expect([chart.width, chart.height], [300, 200]);
      expect(chart.viewPortHandler.chartWidth, 300);
      expect(chart.viewPortHandler.chartHeight, 200);
    });

    test('exports a chart that never had a size', () async {
      final chart = LineChart()..data = _data();
      final image = await chart.toImage(width: 50, height: 40);
      expect([image.width, image.height], [50, 40]);
      image.dispose();

      final empty = await LineChart().toImage();
      expect([empty.width, empty.height], [1, 1]);
      empty.dispose();
    });

    test('pixelRatio scales the image and not the layout', () async {
      final chart = LineChart()..data = _data();
      chart.xAxis.isEnabled = false;
      chart.axisLeft.isEnabled = false;
      chart.axisRight.isEnabled = false;
      chart.legend.isEnabled = false;
      chart.description.isEnabled = false;
      chart.isDrawGridBackgroundEnabled = true;
      chart.gridBackgroundColor = const ui.Color(0xFFFF0000);
      chart.onSizeChanged(100, 80);
      final right = chart.viewPortHandler.contentRight;
      final bottom = chart.viewPortHandler.contentBottom;

      final image = await chart.toImage(pixelRatio: 2);
      expect([image.width, image.height], [200, 160]);
      expect([chart.width, chart.height], [100, 80]);
      final pixels = (await image.toByteData())!;
      image.dispose();
      // Just inside the bottom right corner of the content, in image pixels: only red when the drawing was scaled.
      final x = (2 * right - 4).round();
      final y = (2 * bottom - 4).round();
      expect(x, greaterThan(100));
      final offset = (y * 200 + x) * 4;
      expect(
        [for (var i = 0; i < 4; i++) pixels.getUint8(offset + i)],
        [255, 0, 0, 255],
      );

      final odd = await chart.toImage(width: 33, height: 21, pixelRatio: 1.5);
      expect([odd.width, odd.height], [50, 32]);
      odd.dispose();
      expect([chart.width, chart.height], [100, 80]);

      final png = await chart.toPngBytes(width: 10, height: 10, pixelRatio: 3);
      final codec = await ui.instantiateImageCodec(png);
      final frame = await codec.getNextFrame();
      expect([frame.image.width, frame.image.height], [30, 30]);
      frame.image.dispose();
      codec.dispose();
    });

    test('a pixelRatio that is not a positive finite number throws', () async {
      final chart = _sizedChart();
      for (final ratio in [0.0, -1.0, double.nan, double.infinity]) {
        await expectLater(
          chart.toImage(pixelRatio: ratio),
          throwsArgumentError,
        );
      }
      expect([chart.width, chart.height], [300, 200]);
    });

    test('toPngBytes encodes a PNG', () async {
      final bytes = await _sizedChart().toPngBytes(width: 30, height: 20);
      expect(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      expect([frame.image.width, frame.image.height], [30, 20]);
      frame.image.dispose();
      codec.dispose();
    });
  });

  group('highlights and touches', () {
    test('onValueSelected and highlightValueOf notify the listeners', () {
      final chart = _sizedChart();
      final selected = <double>[];
      var nothing = 0;
      chart.onValueSelected(
        (e, h) => selected.add(e.x),
        onNothingSelected: () => nothing++,
      );

      chart.highlightValue(4, 0);
      expect(selected, [4]);
      expect(chart.valuesToHighlight(), isTrue);

      chart.highlightValue(4, 0, callListener: false);
      expect(selected, [4]);

      chart.highlightValueOf(null);
      expect(nothing, 1);
      expect(chart.valuesToHighlight(), isFalse);

      chart.highlightValues([Highlight(2, 2, 0)]);
      expect(chart.highlighted.single.x, 2);
      // highlightValues does not call the listeners.
      expect(selected, [4]);
    });

    // testWidgets for its fake clock: the touch listener's VelocityTracker reads the binding's sampling clock.
    testWidgets(
      'onTouchEvent goes to the touch listener only with data and touch enabled',
      (tester) async {
        final event = ChartTouchEvent(
          action: ChartTouchAction.down,
          pointerIds: [0],
          positions: [const ui.Offset(150, 100)],
          eventTimeMillis: 0,
        );

        // Touch enabled and data present: the BarLineChartTouchListener gets the event and, like Kotlin's, consumes
        // every event. The up ends the touch, so its long press timer does not stay pending.
        final chart = _sizedChart();
        expect(chart.isTouchEnabled, isTrue);
        expect(chart.chartTouchListener, isA<BarLineChartTouchListener>());
        expect(chart.onTouchEvent(event), isTrue);
        expect(
          chart.onTouchEvent(
            ChartTouchEvent(
              action: ChartTouchAction.up,
              pointerIds: [0],
              positions: [const ui.Offset(150, 100)],
              eventTimeMillis: 50,
            ),
          ),
          isTrue,
        );
        chart.computeScroll();

        final recording = _RecordingTouchListener(chart);
        chart.chartTouchListener = recording;
        expect(chart.onTouchEvent(event), isTrue);
        expect(recording.events, [same(event)]);

        chart.isTouchEnabled = false;
        expect(chart.onTouchEvent(event), isFalse);
        expect(recording.events, hasLength(1));

        final noData = LineChart();
        final noDataListener = _RecordingTouchListener(noData);
        noData.chartTouchListener = noDataListener;
        expect(noData.onTouchEvent(event), isFalse);
        expect(noDataListener.events, isEmpty);
        noData.computeScroll();
      },
    );
  });
}
