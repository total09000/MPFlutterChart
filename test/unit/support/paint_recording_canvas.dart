// A RecordingCanvas that also records the paint style and stroke width of each rectangle and circle (plan ruling
// A8: the lane D `RecordingCanvas` must not be changed). `RecordingCanvas.rects` keeps only the rectangle and its
// color and `circles` no stroke width, while the scatter shape renderers draw the same shape stroked or filled
// depending on the size and the hole.
import 'dart:ui' as ui;

import '../../recording/recording_canvas.dart';

/// The paint style and stroke width a rectangle or circle was drawn with.
typedef PaintRecord = ({ui.PaintingStyle style, double strokeWidth});

/// A [RecordingCanvas] that records the paint of every `drawRect` in [rectPaints] and of every `drawCircle` in
/// [circlePaints], at the index of the draw in `rects` / `circles`.
class PaintRecordingCanvas extends RecordingCanvas {
  /// The paint of each rectangle in `rects`, in the same order.
  final List<PaintRecord> rectPaints = [];

  /// The paint of each circle in `circles`, in the same order.
  final List<PaintRecord> circlePaints = [];

  @override
  void drawRect(ui.Rect rect, ui.Paint paint) {
    super.drawRect(rect, paint);
    rectPaints.add((style: paint.style, strokeWidth: paint.strokeWidth));
  }

  @override
  void drawCircle(ui.Offset c, double radius, ui.Paint paint) {
    super.drawCircle(c, radius, paint);
    circlePaints.add((style: paint.style, strokeWidth: paint.strokeWidth));
  }
}
