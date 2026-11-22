// Not a port of a Kotlin test: MPAndroidChart v4.0.1 has no unit test for MarkerView. Checks the canvas marker base
// class against the clamping logic of MarkerView.getOffsetForDrawingAtPoint, with measure() standing in
// for the measured Android View size.
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/charts/line_chart.dart';
import 'package:mp_flutter_chart/src/components/i_marker.dart';
import 'package:mp_flutter_chart/src/components/marker_view.dart';
import 'package:mp_flutter_chart/src/data/entry.dart';
import 'package:mp_flutter_chart/src/highlight/highlight.dart';
import 'package:mp_flutter_chart/src/utils/f_size.dart';

/// A chart of [width] x [height]; the marker reads only its width and height. The marker holds it weakly, so each
/// test keeps it in a local and uses that local last.
LineChart _chart(double width, double height) =>
    LineChart()..onSizeChanged(width, height);

class _BoxMarker extends MarkerView {
  int drawContentCalls = 0;
  List<double>? transformInDrawContent;

  @override
  FSize measure() => FSize(40, 20);

  @override
  void drawContent(ui.Canvas canvas) {
    drawContentCalls++;
    transformInDrawContent = canvas.getTransform().toList();
    canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 40, 20), ui.Paint());
  }
}

void main() {
  test('getOffsetForDrawingAtPoint clamps the marker back into the chart', () {
    final marker = _BoxMarker();
    final chart = _chart(100, 100);
    marker.chartView = chart;

    final offset = marker.getOffsetForDrawingAtPoint(95, 10);
    expect(95 + offset.x + 40 <= 100, isTrue);
    expect(offset.x, closeTo(-35, 1e-4));
    expect(offset.y, closeTo(0, 1e-4));
    expect(marker.chartView, same(chart));
  });

  test('width and height come from measure()', () {
    final marker = _BoxMarker();
    expect(marker.width, 40);
    expect(marker.height, 20);
  });

  test('offset is used unchanged when the marker fits', () {
    final marker = _BoxMarker();
    final chart = _chart(100, 100);
    marker.chartView = chart;
    marker.setOffset(-20, -20);
    expect(marker.offset.x, -20);
    expect(marker.offset.y, -20);

    final offset = marker.getOffsetForDrawingAtPoint(50, 50);
    expect(offset.x, closeTo(-20, 1e-4));
    expect(offset.y, closeTo(-20, 1e-4));
    // The returned point is a separate buffer; the configured offset is not changed.
    expect(identical(offset, marker.offset), isFalse);
    expect(marker.chartView, same(chart));
  });

  test('a negative position is clamped to the left and top edge', () {
    final marker = _BoxMarker();
    final chart = _chart(100, 100);
    marker.chartView = chart;
    marker.setOffset(-20, -30);

    final offset = marker.getOffsetForDrawingAtPoint(10, 10);
    expect(offset.x, closeTo(-10, 1e-4));
    expect(offset.y, closeTo(-10, 1e-4));
    expect(marker.chartView, same(chart));
  });

  test('the bottom edge clamps the marker up', () {
    final marker = _BoxMarker();
    final chart = _chart(100, 100);
    marker.chartView = chart;

    final offset = marker.getOffsetForDrawingAtPoint(10, 95);
    expect(offset.y, closeTo(-15, 1e-4));
    expect(marker.chartView, same(chart));
  });

  test('without a chart only the left and top edge clamp', () {
    final marker = _BoxMarker();
    expect(marker.chartView, isNull);

    final offset = marker.getOffsetForDrawingAtPoint(1000, 1000);
    expect(offset.x, 0);
    expect(offset.y, 0);
  });

  test('draw translates to the clamped position and calls drawContent', () {
    final marker = _BoxMarker();
    final chart = _chart(100, 100);
    marker.chartView = chart;
    marker.refreshContent(Entry(x: 0, y: 0), Highlight(0, 0, 0));

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    marker.draw(canvas, 95, 10);
    // The translation is undone after drawing.
    expect(canvas.getTransform()[12], 0);
    expect(canvas.getTransform()[13], 0);
    recorder.endRecording().dispose();

    expect(marker.drawContentCalls, 1);
    // posX + offset.x = 95 - 35, posY + offset.y = 10 + 0.
    expect(marker.transformInDrawContent![12], closeTo(60, 1e-4));
    expect(marker.transformInDrawContent![13], closeTo(10, 1e-4));
    expect(marker.chartView, same(chart));
  });

  test('MarkerView is an IMarker', () {
    final IMarker marker = _BoxMarker();
    expect(marker.offset.x, 0);
  });
}
