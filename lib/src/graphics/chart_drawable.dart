// Android shim: android.graphics.drawable.Drawable for MPAndroidChart v4.0.1 port
import 'dart:ui' as ui;

import 'mutable_rect.dart';

/// Something that can be drawn into a rectangle, standing in for `android.graphics.drawable.Drawable`.
///
/// The library uses drawables for entry icons (`BaseEntry.icon`), `Fill` and the line fill drawable, `MarkerImage`
/// and the chart's no-data icon.
///
/// Unlike an Android `Drawable`, a [ChartDrawable] keeps no bounds: the rectangle is passed to every [draw]. Kotlin
/// code that calls `drawable.setBounds(l, t, r, b)` and then `drawable.draw(canvas)` becomes
/// `drawable.draw(canvas, MutableRect(l, t, r, b))`. The `copyBounds` / restore-bounds bookkeeping of
/// `Utils.drawImage` and `MarkerImage.draw` (which keep the previous bounds origin, (0, 0) for a drawable whose bounds
/// were never set, and only change the size) is not needed: after translating the canvas those call sites draw into
/// `MutableRect(0, 0, width, height)`.
abstract class ChartDrawable {
  /// The opacity the drawable is drawn with, 0 (transparent) to 255 (opaque), like `Drawable.setAlpha`. Default 255.
  ///
  /// The chart sets it on its no-data icon while it pulses during loading.
  int alpha = 255;

  /// The natural width in pixels (`Drawable.getIntrinsicWidth`), or -1 if the drawable has none.
  int get intrinsicWidth;

  /// The natural height in pixels (`Drawable.getIntrinsicHeight`), or -1 if the drawable has none.
  int get intrinsicHeight;

  /// Draws the drawable stretched to fill [bounds] on [canvas] (`setBounds` + `Drawable.draw`).
  void draw(ui.Canvas canvas, MutableRect bounds);
}

/// A [ChartDrawable] that draws a decoded [ui.Image], like a `BitmapDrawable`.
class ImageDrawable extends ChartDrawable {
  /// The image to draw. The drawable does not own it; the caller disposes it.
  final ui.Image image;

  /// Physical image pixels per logical pixel, like `ImageInfo.scale`: 2 or 3 for an `@2x` / `@3x` asset.
  ///
  /// Chart coordinates are logical pixels, so the intrinsic size is the image size divided by [scale]. Default 1.
  final double scale;

  final ui.Paint _paint = ui.Paint()..filterQuality = ui.FilterQuality.low; // bilinear, like BitmapDrawable

  /// Creates a drawable for [image]; its intrinsic size is the image size divided by [scale], rounded.
  ImageDrawable(this.image, {this.scale = 1.0});

  @override
  int get intrinsicWidth => (image.width / scale).round();

  @override
  int get intrinsicHeight => (image.height / scale).round();

  @override
  void draw(ui.Canvas canvas, MutableRect bounds) {
    _paint.color = ui.Color.fromARGB(alpha.clamp(0, 255), 0, 0, 0);
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      bounds.toRect(),
      _paint,
    );
  }
}

/// A [ChartDrawable] that draws with a callback, for vector icons and custom shapes.
///
/// [painter] is called with the canvas translated to the top-left corner of the bounds and the size of the bounds, so
/// it paints into `Offset.zero & size`.
class PainterDrawable extends ChartDrawable {
  /// Paints the drawable into a rectangle of the given size at the canvas origin.
  final void Function(ui.Canvas canvas, ui.Size size) painter;

  final int _width;
  final int _height;

  /// Creates a drawable that paints with [painter]; [width] and [height] are its intrinsic size in pixels.
  PainterDrawable(this.painter, {required int width, required int height}) : _width = width, _height = height;

  @override
  int get intrinsicWidth => _width;

  @override
  int get intrinsicHeight => _height;

  @override
  void draw(ui.Canvas canvas, MutableRect bounds) {
    final a = alpha.clamp(0, 255);
    if (a == 0) return;
    final size = ui.Size(bounds.width(), bounds.height());
    canvas.save();
    canvas.translate(bounds.left, bounds.top);
    if (a < 255) {
      canvas.saveLayer(null, ui.Paint()..color = ui.Color.fromARGB(a, 0, 0, 0));
    }
    painter(canvas, size);
    if (a < 255) canvas.restore();
    canvas.restore();
  }
}
