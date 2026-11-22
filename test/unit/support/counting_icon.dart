// Support for the renderer tests that check when and where drawValues draws entry icons: an icon that counts its
// draws, and a canvas that keeps the translations `Utils.drawImage` moves each icon to (the lane D `RecordingCanvas`
// only counts them and must not be changed).
import 'dart:ui' as ui;

import 'package:mp_flutter_chart/src/graphics/chart_drawable.dart';
import 'package:mp_flutter_chart/src/graphics/mutable_rect.dart';

import 'strict_canvas.dart';

/// A 4 x 4 px [ChartDrawable] that draws nothing and counts how often it is drawn in [draws].
class CountingIcon extends ChartDrawable {
  /// How often [draw] was called.
  int draws = 0;

  @override
  int get intrinsicWidth => 4;

  @override
  int get intrinsicHeight => 4;

  @override
  void draw(ui.Canvas canvas, MutableRect bounds) => draws++;
}

/// A [StrictCanvas] that also keeps every `translate` in [translations]. `Utils.drawImage` translates to the top-left
/// corner of the icon, (x − width ~/ 2, y − height ~/ 2) of the whole-pixel position it is given.
class TranslationRecordingCanvas extends StrictCanvas {
  /// The offset of each `translate`, in order.
  final List<ui.Offset> translations = [];

  @override
  void translate(double dx, double dy) {
    translations.add(ui.Offset(dx, dy));
    super.translate(dx, dy);
  }
}
