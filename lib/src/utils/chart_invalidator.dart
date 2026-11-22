// Android shim: android.view.View.invalidate() for MPAndroidChart v4.0.1 port
/// Something that can be asked to redraw, the part of `android.view.View` that `ViewPortHandler` needs.
///
/// `ViewPortHandler.refresh` and `ViewPortHandler.centerViewPort` take the chart as a `View` in MPAndroidChart only
/// to call `invalidate()` on it. Taking this interface instead keeps `utils/` free of a dependency on `charts/`;
/// `Chart` implements it.
abstract interface class ChartInvalidator {
  /// Requests a redraw of the chart.
  void invalidate();
}
