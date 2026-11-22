// Android shim: android.graphics.RectF (mutable float rectangle) for MPAndroidChart v4.0.1 port
import 'dart:ui' as ui;

/// A mutable rectangle with the semantics of `android.graphics.RectF`.
///
/// Renderers reuse rectangle fields across frames, so unlike [ui.Rect] the edges can be changed in place. Use
/// [toRect] and [setFromRect] at the boundary with `dart:ui`.
class MutableRect {
  double left;
  double top;
  double right;
  double bottom;

  /// Creates a rectangle with the given edges; with no arguments it is empty at the origin, like `RectF()`.
  MutableRect([this.left = 0, this.top = 0, this.right = 0, this.bottom = 0]);

  /// The width, `right - left`.
  double width() => right - left;

  /// The height, `bottom - top`.
  double height() => bottom - top;

  /// The horizontal center, `(left + right) / 2`.
  double centerX() => (left + right) * 0.5;

  /// The vertical center, `(top + bottom) / 2`.
  double centerY() => (top + bottom) * 0.5;

  /// True if the rectangle has no area: `left >= right` or `top >= bottom`.
  bool get isEmpty => left >= right || top >= bottom;

  /// Sets all four edges.
  void set(double left, double top, double right, double bottom) {
    this.left = left;
    this.top = top;
    this.right = right;
    this.bottom = bottom;
  }

  /// Copies the edges of [src] (Android `set(RectF src)`).
  void setFrom(MutableRect src) {
    left = src.left;
    top = src.top;
    right = src.right;
    bottom = src.bottom;
  }

  /// Copies the edges of [src].
  void setFromRect(ui.Rect src) {
    left = src.left;
    top = src.top;
    right = src.right;
    bottom = src.bottom;
  }

  /// True if the rectangle is not empty and ([x], [y]) lies inside it; the left and top edges are inside, the right
  /// and bottom edges are outside.
  bool contains(double x, double y) =>
      left < right &&
      top < bottom &&
      x >= left &&
      x < right &&
      y >= top &&
      y < bottom;

  /// Moves the left and right edges in by [dx] and the top and bottom edges in by [dy]; negative values move them
  /// out.
  void inset(double dx, double dy) {
    left += dx;
    top += dy;
    right -= dx;
    bottom -= dy;
  }

  /// Moves the rectangle by [dx] horizontally and [dy] vertically.
  void offset(double dx, double dy) {
    left += dx;
    top += dy;
    right += dx;
    bottom += dy;
  }

  /// Returns an immutable copy as a [ui.Rect].
  ui.Rect toRect() => ui.Rect.fromLTRB(left, top, right, bottom);
}
