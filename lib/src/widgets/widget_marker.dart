// Ported from MPAndroidChart v4.0.1: MPChartCompose/src/main/kotlin/com/github/mikephil/charting/compose/ComposeMarker.kt
//
// ComposeMarker composes its content in an invisible ComposeView child of the chart and draws that view onto the
// chart's canvas. A Flutter chart has no child views: draw() only records where the marker belongs,
// and the chart widget's overlay (a Stack above the chart, [WidgetMarker.buildOverlay]) lays the content out there,
// centered above the point and kept inside the chart as getOffsetForDrawingAtPoint computes it. So the marker is not
// part of Chart.toImage. As in Compose, the content for a newly highlighted entry shows one frame after the highlight.
import 'dart:async' show scheduleMicrotask;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../charts/chart.dart';
import '../components/i_marker.dart';
import '../data/entry.dart';
import '../highlight/highlight.dart';
import '../utils/mp_point_f.dart';
import '../utils/utils.dart';

/// A marker whose content is a widget, shown at the highlighted entry like any other [IMarker].
///
/// The chart calls [refreshContent] and [draw] for each highlighted entry while it draws; [draw] paints nothing and
/// only records the point, which [position] publishes after the chart has been drawn. The chart widgets show the
/// content in an overlay above the chart, centered above the point and kept inside the chart. The content is not
/// drawn by `Chart.toImage` (the canvas markers `MarkerView` and `MarkerImage` are), and it does not receive touches:
/// they go to the chart below it. Content for a newly highlighted entry is built on the next frame, so the marker
/// shows one frame after the highlight.
///
/// The chart widgets create one from their `marker` builder and show its overlay. To show widget content at the
/// highlight of a chart instance you own, use `ChartHostWidget(chart: myChart, data: data, marker: (entry, highlight)
/// => ...)` rather than creating a marker yourself: the overlay that shows the content is internal to those widgets.
/// [detach] ends a marker for good.
class WidgetMarker implements IMarker {
  /// Creates a marker for [chart], held weakly, whose [content] builds the marker for the highlighted entry.
  WidgetMarker(Chart chart, this.content) : _chartRef = WeakReference(chart) {
    chart.afterDrawListeners.add(_onChartDrawn);
  }

  /// Extra offset in dp applied on top of the default position, which centers the content above the entry.
  @override
  final MPPointF offset = MPPointF();

  final MPPointF _drawingOffset = MPPointF();
  final WeakReference<Chart> _chartRef;

  /// Builds the marker for the highlighted entry. Changing it rebuilds the marker when the overlay is built again.
  Widget Function(Entry entry, Highlight highlight) content;

  /// Where the marker is shown: the point in the chart's coordinates (logical pixels from its top left corner) that
  /// the chart drew the highlight at, with the entry and highlight, or null while no marker is drawn. Updated after
  /// each draw of the chart that changed it. [detach] disposes it.
  final ValueNotifier<(Offset, Entry, Highlight)?> position = ValueNotifier(
    null,
  );

  Entry? _entry;
  Highlight? _highlight;

  /// What [draw] recorded during the draw of the chart that is running.
  (Offset, Entry, Highlight)? _drawn;

  /// What the last finished draw of the chart recorded, published to [position] in a microtask.
  (Offset, Entry, Highlight)? _shown;
  bool _publishScheduled = false;
  bool _detached = false;

  /// The size of the content as the overlay last laid it out.
  Size _size = Size.zero;

  Offset? _lastPosition;

  /// The point the chart last drew the marker at, in the chart's coordinates, or null before the first draw. Unlike
  /// [position] it is not reset when the highlight goes away.
  Offset? get lastPosition => _lastPosition;

  /// Shifts the content by [offsetX] and [offsetY] dp from its default position above the entry.
  void setOffset(double offsetX, double offsetY) {
    offset.x = offsetX;
    offset.y = offsetY;
  }

  /// Stops showing the marker for good: disposes [position], stops following the chart's draws and unsets the
  /// marker as the chart's marker. Does nothing to the chart once the chart is gone. Calling it again only unsets the
  /// marker again.
  void detach() {
    if (!_detached) {
      _detached = true;
      position.dispose();
    }
    final chart = _chartRef.target;
    if (chart == null) return;
    if (identical(chart.marker, this)) chart.marker = null;
    chart.afterDrawListeners.remove(_onChartDrawn);
  }

  /// Takes [e] and [highlight] for the content shown at the next [draw].
  @override
  void refreshContent(Entry e, Highlight highlight) {
    _entry = e;
    _highlight = highlight;
  }

  /// Returns the position of the content relative to [posX], [posY] in pixels: centered above the entry, shifted by
  /// [offset] converted to pixels, and clamped so the marker stays inside the chart. Uses the size the content had
  /// when the overlay last laid it out.
  @override
  MPPointF getOffsetForDrawingAtPoint(double posX, double posY) {
    final width = _size.width;
    final height = _size.height;
    _drawingOffset.x = Utils.convertDpToPixel(offset.x) - width / 2;
    _drawingOffset.y =
        Utils.convertDpToPixel(offset.y) - height - Utils.convertDpToPixel(12);
    final chart = _chartRef.target;

    if (posX + _drawingOffset.x < 0) {
      _drawingOffset.x = -posX;
    } else if (chart != null && posX + width + _drawingOffset.x > chart.width) {
      _drawingOffset.x = chart.width - posX - width;
    }
    if (posY + _drawingOffset.y < 0) {
      _drawingOffset.y = -posY;
    } else if (chart != null &&
        posY + height + _drawingOffset.y > chart.height) {
      _drawingOffset.y = chart.height - posY - height;
    }
    return _drawingOffset;
  }

  /// Records that the marker belongs at [posX], [posY] for the entry of the last [refreshContent]; draws nothing on
  /// [canvas]. The overlay shows the content there after the chart has been drawn.
  @override
  void draw(ui.Canvas canvas, double posX, double posY) {
    final entry = _entry;
    final highlight = _highlight;
    if (entry == null || highlight == null) return;
    final point = Offset(posX, posY);
    _lastPosition = point;
    _drawn = (point, entry, highlight);
  }

  /// The end of a draw of the chart: what it drew becomes the [position], or null when it drew no marker. The chart is
  /// being painted, when no widget may be marked for a rebuild, so the value is published in a microtask.
  void _onChartDrawn() {
    _shown = _drawn;
    _drawn = null;
    if (_publishScheduled) return;
    _publishScheduled = true;
    scheduleMicrotask(() {
      _publishScheduled = false;
      if (!_detached) position.value = _shown;
    });
  }

  /// The overlay that shows the content at [position]: fills the chart, lays the content out at its own size (at most
  /// the chart's) and places it as [getOffsetForDrawingAtPoint] says. Internal API: the chart widgets put it in a
  /// `Stack` above the chart.
  @internal
  Widget buildOverlay() => IgnorePointer(child: _MarkerOverlay(marker: this));
}

class _MarkerOverlay extends StatelessWidget {
  const _MarkerOverlay({required this.marker});

  final WidgetMarker marker;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<(Offset, Entry, Highlight)?>(
        valueListenable: marker.position,
        builder: (context, shown, _) {
          if (shown == null) return const SizedBox.shrink();
          final (point, entry, highlight) = shown;
          return CustomSingleChildLayout(
            delegate: _MarkerLayoutDelegate(marker, point),
            child: marker.content(entry, highlight),
          );
        },
      );
}

/// Lays the content out at its own size and places it the way ComposeMarker draws its view.
class _MarkerLayoutDelegate extends SingleChildLayoutDelegate {
  _MarkerLayoutDelegate(this.marker, this.point);

  final WidgetMarker marker;
  final Offset point;

  /// ComposeMarker measures its view with an unspecified size; here the content may be at most as big as the chart.
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    marker._size = childSize;
    final offset = marker.getOffsetForDrawingAtPoint(point.dx, point.dy);
    return Offset(point.dx + offset.x, point.dy + offset.y);
  }

  @override
  bool shouldRelayout(_MarkerLayoutDelegate oldDelegate) =>
      !identical(oldDelegate.marker, marker) || oldDelegate.point != point;
}
