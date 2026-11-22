// Ported from MPAndroidChart v4.0.1: MPChartCompose/src/test/kotlin/com/github/mikephil/charting/compose/ChartStateSaverTest.kt
//
// Compose's ChartState.Saver (a list of 12 or 10 Floats) is ChartController.toJson / restoreFrom here, a map with one
// key per saved value; values Kotlin saves as NaN are null, so the map survives jsonEncode. The second group is not in
// Kotlin: it checks the change notifications that stand in for Compose's snapshot state. The two pie chart tests are
// not in Kotlin either: they cover the PieRadarChartBase branches of ChartState.restore and refresh
// (ChartState.kt:273, :310).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/charts/line_chart.dart';
import 'package:mp_flutter_chart/src/charts/pie_chart.dart';
import 'package:mp_flutter_chart/src/data/entry.dart';
import 'package:mp_flutter_chart/src/data/line_data.dart';
import 'package:mp_flutter_chart/src/data/line_data_set.dart';
import 'package:mp_flutter_chart/src/data/pie_data.dart';
import 'package:mp_flutter_chart/src/data/pie_data_set.dart';
import 'package:mp_flutter_chart/src/data/pie_entry.dart';
import 'package:mp_flutter_chart/src/widgets/chart_controller.dart';

import '../recording/recording_canvas.dart';

/// Kotlin's `listOf(2f, 1.5f, 3f, 90f, 1f, 4f, 20f, 0f, -1f, -1f, 3f, 12f)`.
const Map<String, Object?> _withYScroll = {
  'zoomX': 2.0,
  'zoomY': 1.5,
  'lowestVisibleX': 3.0,
  'rotationAngle': 90.0,
  'hasHighlight': true,
  'highlightX': 4.0,
  'highlightY': 20.0,
  'highlightDataSetIndex': 0,
  'highlightDataIndex': -1,
  'highlightStackIndex': -1,
  'topLeftX': 3.0,
  'topLeftY': 12.0,
};

/// Three entries: (0, 1), (1, 3), (2, 2).
LineData _data() => LineData([
  LineDataSet([Entry(x: 0, y: 1), Entry(x: 1, y: 3), Entry(x: 2, y: 2)], 'a'),
]);

/// A 400 x 300 line chart without a host, so posted jobs run at once.
LineChart _chart() => LineChart()
  ..data = _data()
  ..onSizeChanged(400, 300);

/// A 300 x 300 pie chart of three slices without a host, so posted jobs run at once.
PieChart _pieChart() => PieChart()
  ..data = PieData(PieDataSet([PieEntry(1), PieEntry(2), PieEntry(3)], 'p'))
  ..onSizeChanged(300, 300);

/// Lets the microtask that delivers the change notifications run.
Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  group('saver', () {
    test('restored values survive another save before the chart exists', () {
      final withoutYScroll = Map.of(_withYScroll)
        ..remove('topLeftX')
        ..remove('topLeftY');

      for (final saved in [_withYScroll, withoutYScroll]) {
        final restored = ChartController()..restoreFrom(saved);
        expect(restored.isAttached, isFalse);
        expect(restored.toJson(), saved);
        expect(ChartController.fromJson(saved).toJson(), saved);
      }
    });

    test('malformed saved values are ignored', () {
      final restored = ChartController()
        ..restoreFrom({'zoomX': 2.0, 'zoomY': 1.5});

      restored.highlight(1);
      restored.zoomIn();
      expect(restored.toJson(), {
        'zoomX': 1.0,
        'zoomY': 1.0,
        'lowestVisibleX': 0.0,
        'rotationAngle': 270.0,
        'hasHighlight': false,
        'highlightX': 0.0,
        'highlightY': null,
        'highlightDataSetIndex': 0,
        'highlightDataIndex': -1,
        'highlightStackIndex': -1,
        'topLeftX': null,
        'topLeftY': null,
      });
    });

    test('values of the wrong type or half of the y scroll are ignored', () {
      for (final broken in <Map<String, Object?>>[
        {..._withYScroll, 'zoomX': '2'},
        {..._withYScroll, 'hasHighlight': 1.0},
        {..._withYScroll, 'highlightDataSetIndex': 0.5},
        Map.of(_withYScroll)..remove('topLeftY'),
        Map.of(_withYScroll)..remove('rotationAngle'),
      ]) {
        final restored = ChartController()..restoreFrom(broken);
        expect(restored.toJson()['zoomX'], 1.0, reason: '$broken');
      }
    });

    test('the saved map survives jsonEncode, NaN included', () {
      final fresh = ChartController().toJson();
      final decoded = jsonDecode(jsonEncode(fresh)) as Map<String, Object?>;
      expect(ChartController.fromJson(decoded).toJson(), fresh);

      final restored = ChartController.fromJson(
        jsonDecode(jsonEncode(_withYScroll)) as Map<String, Object?>,
      );
      expect(restored.toJson(), _withYScroll);
    });

    test('an attached controller saves the chart it observes', () {
      final chart = _chart();
      final controller = ChartController()..attach(chart);
      chart.highlightValue(1, 0);
      chart.zoom(2, 1, 0, 0);
      controller.refresh();

      final saved = controller.toJson();
      expect(saved['zoomX'], closeTo(2, 1e-4));
      expect(saved['zoomY'], closeTo(1, 1e-4));
      expect(saved['lowestVisibleX'], controller.lowestVisibleX);
      expect(saved['hasHighlight'], isTrue);
      expect(saved['highlightX'], 1.0);
      // highlightValue leaves y NaN, which is saved as null.
      expect(saved['highlightY'], isNull);
      expect(saved['topLeftX'], isA<double>());
      expect(saved['topLeftY'], isA<double>());
      controller.detach(chart);
    });

    test(
      'a restored controller applies zoom, position and highlight once it is attached',
      () {
        final source = _chart();
        final saving = ChartController()..attach(source);
        source.zoom(2, 2, 0, 0);
        source.moveViewToX(0.5);
        source.highlightValue(2, 0);
        saving.refresh();
        final saved = saving.toJson();

        final chart = _chart();
        final restored = ChartController.fromJson(saved)..attach(chart);
        expect(chart.zoomX, closeTo(2, 1e-4));
        expect(chart.zoomY, closeTo(2, 1e-4));
        expect(chart.lowestVisibleX, closeTo(source.lowestVisibleX, 1e-4));
        expect(chart.highlighted.single.x, 2);
        expect(restored.selectedEntry?.x, 2);
        expect(restored.zoomX, closeTo(2, 1e-4));
        // Applied once: from now on a save is the chart's state again.
        restored.zoomIn();
        expect(restored.toJson()['zoomX'], closeTo(2.8, 1e-4));
      },
    );

    test('restoreFrom rotates a pie chart', () {
      final saved = Map.of(_withYScroll)..['hasHighlight'] = false;
      final chart = _pieChart();
      final restored = ChartController.fromJson(saved)..attach(chart);
      expect(chart.rotationAngle, closeTo(90, 1e-4));
      expect(restored.rotationAngle, closeTo(90, 1e-4));
      expect(restored.toJson()['rotationAngle'], closeTo(90, 1e-4));
      // The zoom and scroll values are for bar-line charts only.
      expect(restored.zoomX, 1);
    });
  });

  group('attached', () {
    test('attach reads the chart, detach lets it go', () {
      final chart = _chart();
      final controller = ChartController();
      expect(controller.isAttached, isFalse);
      expect(controller.zoomX, 1);
      expect(controller.rotationAngle, 270);

      controller.attach(chart);
      expect(controller.isAttached, isTrue);
      expect(controller.lowestVisibleX, chart.lowestVisibleX);
      expect(controller.highestVisibleX, chart.highestVisibleX);
      expect(chart.valueSelectedListeners, hasLength(1));
      expect(chart.gestureListeners, hasLength(1));
      expect(chart.afterDrawListeners, hasLength(1));

      // Another chart's host may not detach it.
      controller.detach(LineChart());
      expect(controller.isAttached, isTrue);

      controller.detach(chart);
      expect(controller.isAttached, isFalse);
      expect(chart.valueSelectedListeners, isEmpty);
      expect(chart.gestureListeners, isEmpty);
      expect(chart.afterDrawListeners, isEmpty);

      controller.highlight(1);
      expect(chart.highlighted, isEmpty);
    });

    test('attaching to a second chart moves the controller there', () {
      final first = _chart();
      final second = _chart();
      final controller = ChartController()..attach(first);
      controller.attach(second);
      expect(first.valueSelectedListeners, isEmpty);
      expect(second.valueSelectedListeners, hasLength(1));

      controller.highlight(1);
      expect(first.highlighted, isEmpty);
      expect(second.highlighted.single.x, 1);
    });

    test('highlight and clearHighlight select through the listeners', () {
      final chart = _chart();
      final controller = ChartController()..attach(chart);

      controller.highlight(1);
      expect(
        controller.selectedEntry,
        same(chart.data!.dataSets[0].getEntryForIndex(1)),
      );
      expect(controller.selectedHighlight, same(chart.highlighted.single));

      controller.clearHighlight();
      expect(controller.selectedEntry, isNull);
      expect(controller.selectedHighlight, isNull);
      expect(chart.highlighted, isEmpty);

      // An index outside the data clears the selection.
      controller.highlight(1);
      controller.highlight(1, dataSetIndex: 3);
      expect(controller.selectedEntry, isNull);
    });

    test('the viewport functions zoom and refresh the viewport values', () {
      final chart = _chart();
      final controller = ChartController()..attach(chart);

      controller.zoomIn();
      expect(controller.zoomX, closeTo(1.4, 1e-4));
      expect(controller.zoomY, closeTo(1.4, 1e-4));
      controller.zoomIn();
      controller.zoomOut();
      expect(controller.zoomX, closeTo(1.372, 1e-4));
      controller.resetZoom();
      expect(controller.zoomX, 1);

      chart.zoom(4, 1, 0, 0);
      controller.moveViewToX(1);
      expect(controller.lowestVisibleX, closeTo(1, 1e-4));
      controller.fitScreen();
      expect(controller.zoomX, 1);
      expect(controller.lowestVisibleX, 0);
      expect(controller.highestVisibleX, 2);
    });

    test('notifyDataChanged picks up entries changed in place', () {
      final chart = _chart();
      final controller = ChartController()..attach(chart);
      chart.data!.dataSets[0].addEntry(Entry(x: 3, y: 5));

      controller.notifyDataChanged();
      expect(chart.xAxis.axisMaximum, 3);
      expect(controller.highestVisibleX, 3);
    });

    test('animateDataChange refreshes the selection when it ends', () {
      final chart = _chart();
      final controller = ChartController()..attach(chart);
      controller.highlight(1);
      var ends = 0;

      controller.animateDataChange(_data(), 300, onEnd: () => ends++);
      // No vsync: the animation ends at once, on the new data.
      expect(ends, 1);
      expect(
        controller.selectedEntry,
        same(chart.data!.dataSets[0].getEntryForIndex(1)),
      );
    });
  });

  group('notifications', () {
    test('listeners hear about a change once, after it happened', () async {
      final chart = _chart();
      final controller = ChartController();
      var notified = 0;
      controller.addListener(() => notified++);

      controller.attach(chart);
      expect(notified, 0);
      await _flush();
      // highestVisibleX went from 0 to 2.
      expect(notified, 1);

      controller.highlight(1);
      controller.zoomIn();
      await _flush();
      expect(notified, 2);
    });

    test('nothing that stays the same notifies', () async {
      final chart = _chart();
      final controller = ChartController()..attach(chart);
      controller.highlight(1);
      await _flush();
      var notified = 0;
      controller.addListener(() => notified++);

      controller.refresh();
      controller.syncSelection();
      chart.onDraw(RecordingCanvas());
      await _flush();
      expect(notified, 0);
    });

    test('every draw of the chart refreshes the viewport values', () async {
      final chart = _chart();
      final controller = ChartController()..attach(chart);
      await _flush();
      var notified = 0;
      controller.addListener(() => notified++);

      // A zoom that bypasses the controller shows up with the next draw.
      chart.zoom(2, 1, 0, 0);
      expect(controller.zoomX, 1);
      chart.onDraw(RecordingCanvas());
      expect(controller.zoomX, closeTo(2, 1e-4));
      await _flush();
      expect(notified, 1);
    });

    test('refresh reads the rotation of a pie chart', () async {
      final chart = _pieChart();
      final controller = ChartController()..attach(chart);
      await _flush();
      expect(controller.rotationAngle, 270);
      var notified = 0;
      controller.addListener(() => notified++);

      chart.rotationAngle = 45;
      controller.refresh();
      expect(controller.rotationAngle, closeTo(45, 1e-4));
      await _flush();
      expect(notified, 1);

      // A rotation that bypasses the controller shows up with the next draw, normalized to 0 ..< 360.
      chart.rotationAngle = 400;
      chart.onDraw(RecordingCanvas());
      expect(controller.rotationAngle, closeTo(40, 1e-4));
      await _flush();
      expect(notified, 2);
    });

    test(
      'a disposed controller lets go of its chart and stays silent',
      () async {
        final chart = _chart();
        final controller = ChartController()..attach(chart);
        controller.highlight(1);
        controller.dispose();
        await _flush();
        expect(chart.valueSelectedListeners, isEmpty);
        expect(controller.isAttached, isFalse);
      },
    );
  });
}
