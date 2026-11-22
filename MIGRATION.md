# Migrating from MPAndroidChart (Android) to mp_flutter_chart

mp_flutter_chart keeps the class and member names of MPAndroidChart v4.0.1, so the upstream documentation and
KDoc apply as written. This file lists the places where a call or a result differs from Android.

## API differences

- **Colors are `dart:ui` `Color`, not `Int`.** Every color property and parameter (`color`, `colors`,
  `valueTextColor`, `ColorTemplate.MATERIAL_COLORS`, …) takes `Color` / `List<Color>`.
  `ColorTemplate.colorWithAlpha(color, alpha)` uses `Color.withAlpha`. The pie and radar colors are `Color`s too
  (`holeColor`, `transparentCircleColor`, `centerTextColor`, `entryLabelColor`, `webColor`, `webColorInner`,
  `valueLineColor`, `highlightCircleFillColor`, `highlightCircleStrokeColor`); `PieDataSet.highlightColor` is a
  `Color?`, null for the slice's own color as Kotlin's `Int?`, and alphas such as
  `RadarDataSet.highlightCircleStrokeAlpha` stay `int`s from 0 to 255.
- **`DecimalFormat` is a minimal re-implementation of `java.text.DecimalFormat`**, not the JDK/ICU class. It
  supports only the pattern family the library uses: `#` and `0` digits, `,` grouping (the group size is the
  number of digits after the last `,`), one `.` and fraction digits `0…#…` — e.g. `###,###,###,##0.0`,
  `###,###,##0.#`, `#.##`. Prefixes, suffixes, `%`, exponents and quoting throw an `ArgumentError`. The symbols
  are fixed (`.` decimal separator, `,` grouping separator, `-` minus) and are **not locale-aware**: a formatter
  prints `1,234.5` on every device, where Android would print `1.234,5` under a German locale. Pass your own
  `IValueFormatter` / `IAxisValueFormatter` for locale-specific output.
- **`Drawable` is `ChartDrawable`.** It has `intrinsicWidth`, `intrinsicHeight`, `alpha` and
  `draw(canvas, bounds)`; it keeps no bounds of its own, so `setBounds(...)` + `draw(canvas)` becomes
  `draw(canvas, MutableRect(...))`. Use `ImageDrawable(ui.Image)` for bitmaps and
  `PainterDrawable((canvas, size) { ... }, width: w, height: h)` for vector icons. There are no resource ids:
  load images with Flutter (`AssetImage`, `decodeImageFromList`, …) and wrap the `ui.Image`. Chart coordinates
  are logical pixels, so pass the image's scale for resolution-aware assets:
  `ImageDrawable(info.image, scale: info.scale)` (the `ImageInfo` from `AssetImage`'s stream; 2 or 3 for an
  `@2x` / `@3x` variant). Without it the intrinsic size is the physical pixel size and the icon or marker is drawn
  2–3× too large.
- **Overloads have their own names, or optional parameters**, because Dart has no overloading:
  `MPPointF.getInstance(copy)` is `MPPointF.getInstanceFrom(copy)` (`getInstance()` and `getInstance(x, y)` stay);
  `ObjectPool.recycle(list)` is `ObjectPool.recycleAll(list)`; `Utils.getSizeOfRotatedRectangleByDegrees(fSize, deg)`
  / `ByRadians(fSize, rad)` are `getSizeOfRotatedRectangleByDegreesFromSize` / `ByRadiansFromSize` (the
  width/height/angle forms keep their names); `Utils.calcTextSize(paint, text[, out])` and
  `Utils.getPosition(center, dist, angle[, out])` take the output object as an optional last argument and always
  return the object they wrote to.
- **`Fill` constructors are named:** `Fill()` (empty), `Fill.ofColor(color)`, `Fill.ofColors(start, end)`,
  `Fill.ofGradient(colors[, positions])` and `Fill.ofDrawable(drawable)`. The nested enums are top-level:
  `Fill.Type` is `FillType`, `Fill.Direction` is `FillDirection`. `Fill.fillPath` takes the canvas size as a fifth
  argument, because a Flutter `Canvas` does not know its width and height.
- **`Utils.init(context)`, `Utils.postInvalidateOnAnimation(view)`, `ColorTemplate.createColors(resources, ids)` and
  the `StaticLayout` overload of `Utils.drawMultilineText` do not exist.** dp are Flutter's logical pixels, so
  `Utils.convertDpToPixel` / `convertPixelsToDp` return their argument. The density `init` read is
  `Utils.devicePixelRatio`, device px per logical px: the chart widgets set it from their view
  (`MediaQuery.devicePixelRatioOf`, else the `View`'s ratio) before each layout and paint and lay the chart out again
  when it changes. It only rounds px values the way Kotlin's `Int` px are rounded (see the next entry). It is a
  global, so with views of different ratios the chart laid out or painted last sets it; a chart drawn without a widget
  (`toImage`, tests) uses its current value, 1.0 unless set. Use the `String` overload of
  `drawMultilineText`. That overload always fills the text: Android's `StaticLayout` drew with the paint's
  `Paint.Style`, so a `STROKE` or `FILL_AND_STROKE` paint outlined it there.
- **Kotlin's `Int` px and raw px lengths are device px, as on Android.** Every other length of the port is logical
  px. The `DashPathEffect` lengths, which Kotlin hands to the canvas without `Utils.convertDpToPixel`, are device px:
  the canvas divides the intervals and the phase by `Utils.devicePixelRatio` when it dashes a line, so
  `enableDashedHighlightLine(8, 8, 0)` gives 8 px dashes at any density, as in Kotlin. This covers
  `LineScatterCandleRadarDataSet.enableDashedHighlightLine`, `LineDataSet.enableDashedLine`,
  `AxisBase.enableGridDashedLine` / `enableAxisLineDashedLine`, `LimitLine.enableDashedLine` and the legend's
  `formLineDashEffect`; the numbers stored in the `DashPathEffect` are the ones passed. Where Kotlin rounds a px value
  to an `Int` (text widths and heights, the axis label sizes, the value offset of line charts, icon positions, drawable
  bounds and the width of multi-line text), the port rounds it to whole device px on the same grid, so those values
  are fractions of a logical px when the ratio is not 1.
- **`Utils.calcTextWidth` and `Utils.calcTextHeight` return `double`, and `XAxis.labelWidth`, `labelHeight`,
  `labelRotatedWidth` and `labelRotatedHeight` are `double`; `Utils.drawImage` takes its `x` and `y` as `double`.**
  Kotlin's are `Int` device px; here they are whole device px in logical px (see the previous entry), which are not
  whole numbers. `ChartPaint.measureText` rounds up to whole device px, as Android's `Paint.measureText` does; text is
  still aligned by its unrounded advance when drawn.
- **`Utils.drawImage(canvas, drawable, x, y, width, height)` draws the drawable at `(0, 0)` of the translated
  canvas.** Kotlin kept the left and top of the drawable's previous bounds (`copyBounds` + `setBounds`), so a
  `Drawable` whose bounds had been moved elsewhere was drawn shifted by them; a `ChartDrawable` has no bounds of its
  own. Both agree for a drawable whose bounds were never set.
- **`ObjectPool.Poolable` is the top-level abstract class `Poolable`** (Dart has no nested types):
  `class MyJob extends Poolable { @override Poolable instantiate() => MyJob(); }`. `Poolable.NO_OWNER` and
  `currentOwnerId` keep their names; `ObjectPool<T extends Poolable>` is unchanged otherwise.
- **`YAxis.AxisDependency` is the top-level enum `AxisDependency`** (Dart has no nested types):
  `set.axisDependency = AxisDependency.RIGHT`.
- **`Legend.LegendForm` is the top-level enum `LegendForm`**: `set.form = LegendForm.LINE`.
- **`DataSet.Rounding` is the top-level enum `Rounding`**: `set.getEntryForXValue(x, double.nan, Rounding.UP)`.
- **`LineDataSet.Mode` is the top-level enum `LineDataSetMode`** (named after its outer class, since `Mode` alone
  would be too generic): `set.mode = LineDataSetMode.CUBIC_BEZIER`.
- **`Entry` takes named arguments, and `x` and `y` are required:** `Entry(x: 1, y: 2)`,
  `Entry(x: 1, y: 2, icon: drawable, data: order)`. Kotlin's payload-less `Entry(x, y, icon)` factory is the same
  constructor without `data`; its defaults are gone, so Kotlin's `Entry()` (0, 0) is `Entry(x: 0, y: 0)`. Dart
  generics are reified, so give the payload type on the data set where Kotlin infers it:
  `LineDataSet<Order>([...], 'orders')`. `Parcelable` (`writeToParcel`, `CREATOR`) is not ported.
- **`BarEntry`, `CandleEntry` and `BubbleEntry` take named arguments too**, each with optional `icon` and `data`:
  `BarEntry(x: 1, y: 2)` for a single bar and `BarEntry.stacked(x: 1, stackValues: [1, 2])` for a stack,
  `CandleEntry(x: 1, high: 20, low: 10, open: 12, close: 18)` and `BubbleEntry(x: 1, y: 2, size: 3)`. They replace
  Kotlin's positional constructors `BarEntry(x, y, icon, data)` / `BarEntry(x, stackValues, icon, data)`,
  `CandleEntry(x, high, low, open, close, icon, data)` and `BubbleEntry(x, y, size, icon, data)`, and the
  payload-less factories that take the same arguments without `data`.
- **`PieEntry` and `RadarEntry` take the value positionally and the rest as named arguments:**
  `PieEntry(30, label: 'Web')`, `PieEntry(30, label: 'Web', icon: drawable, data: order)` and
  `RadarEntry(4, data: order)` replace Kotlin's positional `PieEntry(value, label, icon, data)` /
  `RadarEntry(value, icon, data)` constructors and their payload-less factories. Their `x` is always 0 and `value`
  is `y`; `PieEntry.label` is writable, and `copy()` returns a `PieEntry` / `RadarEntry`.
- **`BarData.groupBars` throws a `StateError`** where Kotlin throws an `IllegalStateException`, when the data holds
  fewer than two sets. So does `BarChart.groupBars` when no data has been set.
- **The bar overloads have their own names, or optional parameters.** `BarChart.getBarBounds(e)` and
  `getBarBounds(e, outputRect)` are one `getBarBounds(e, [outputRect])`. It writes the bounds into `outputRect` when
  one is given and returns them as a `MutableRect` (Kotlin's `RectF`). `BarBuffer.feed(data)` keeps its name, since it
  overrides `AbstractBuffer.feed`. `feed(data, from, to)` is `feedRange(data, from, to)`, and
  `feed(data, indices, columnEntries, count)` is `feedIndices(data, indices, columnEntries, count)`, which takes
  `Int32List`s where Kotlin takes `IntArray`s. A subclass that overrode one of the Kotlin overloads overrides the
  renamed method.
- **`BarChartRenderer.BarCorners` and `ScatterChart.ScatterShape` are the top-level enums `BarCorners` and
  `ScatterShape`** (Dart has no nested types).
  - `ScatterShape` is in `charts/scatter_shape.dart`: `set.setScatterShape(ScatterShape.CIRCLE)`. Its `toString()`
    gives the identifier (`CIRCLE`), as in Kotlin.
  - `ScatterDataSet.getRendererForShape(shape)`, a companion function in Kotlin, is a static method.
  - `BarChartRenderer.drawBarShape(c, dataSet, left, top, right, bottom, corners, draw)` takes `draw` as a
    `void Function()`: `drawBarShape(c, set, l, t, r, b, BarCorners.TOP, () => c.drawRectP(rect, paint))`.
- **`PieDataSet.ValuePosition` is the top-level enum `ValuePosition`** (Dart has no nested types), in
  `data/pie_data_set.dart`: `set.yValuePosition = ValuePosition.OUTSIDE_SLICE`.
- **Data set and chart data overloads have their own names:** `IDataSet.getEntryIndex(e: Entry)` is
  `getEntryIndexOf(e)` (the `getEntryIndex(xValue, closestToY, rounding)` form keeps its name, with both trailing
  arguments optional like `getEntryForXValue`); `IDataSet.removeEntry(index: Int)` is `removeEntryByIndex(index)`;
  `ChartData.removeDataSet(index: Int)` is `removeDataSetByIndex(index)`; `ChartData.removeEntry(xValue, dataSetIndex)`
  is `removeEntryByXValue(xValue, dataSetIndex)`. `BaseDataSet.setColors(vararg colors)` and
  `setColors(colors, alpha)` are one `setColors(List<Color> colors, [int? alpha])`; `LineDataSet.setCircleColors(vararg)`
  takes a `List<Color>`. For subclasses, the protected overloads are `copyTo(dataSet)` (Kotlin `copy(dataSet)`),
  `DataSet.calcMinMaxForEntry(e)` / `calcMinMaxYForEntry(e)` (Kotlin `calcMinMax(e)` / `calcMinMaxY(e)`) and
  `ChartData.calcMinMaxForEntry(e, axis)` / `calcMinMaxForDataSet(d)` (Kotlin `calcMinMax(e, axis)` / `calcMinMax(d)`).
- **`ChartData` and its subclasses take one optional list** instead of the `()`, `(vararg sets)` and `(List)`
  constructors: `LineData()`, `LineData([set1, set2])`.
- **`Highlight`'s constructors are named:** `Highlight(x, y, dataSetIndex[, dataIndex])`,
  `Highlight.stacked(x, dataSetIndex, stackIndex)`, `Highlight.withPixels(x, y, xPx, yPx, dataSetIndex, axis)` and
  `Highlight.stackedWithPixels(x, y, xPx, yPx, dataSetIndex, stackIndex, axis)`.
- **`fun interface` formatters are abstract classes with a `fromFunction` factory**, because Dart has no SAM
  conversion: `IValueFormatter.fromFunction((value, entry, dataSetIndex, viewPortHandler) => '$value')`,
  `IAxisValueFormatter.fromFunction((value, axis) => '$value')`,
  `IFillFormatter.fromFunction((dataSet, dataProvider) => 0)`. Subclass `IValueFormatter` with `extends`, as the
  library's own value formatters do, because its `getStackedFormattedValue` has a default body that `implements` would
  not inherit. `IAxisValueFormatter` and `IFillFormatter` have a single abstract method and no default body, so
  `implements` works as well as `extends` for them: `PercentFormatter` and `LargeValueFormatter` extend
  `IValueFormatter` and implement `IAxisValueFormatter`. `IHighlighter` and `IShapeRenderer` have the same factory:
  `IHighlighter.fromFunction((x, y) => ...)` and
  `IShapeRenderer.fromFunction((c, set, viewPortHandler, x, y, paint) => c.drawCircleP(x, y, 4, paint))`. They too
  have a single abstract method and no default body; `ChartHighlighter` and the built-in shape renderers use
  `implements`.
- **`PercentFormatter` and `LargeValueFormatter` have one `getFormattedValue` for both interfaces.** Kotlin overloads
  it (`(value, entry, dataSetIndex, viewPortHandler)` from `IValueFormatter`, `(value, axis)` from
  `IAxisValueFormatter`); Dart has no overloading, so the single method is
  `getFormattedValue(double value, Object entryOrAxis, [int dataSetIndex = 0, ViewPortHandler? viewPortHandler])`.
  Both call forms work unchanged, and calls through an `IValueFormatter` or `IAxisValueFormatter` variable keep their
  typed signatures. A subclass overrides this one method instead of either overload.
  `PercentFormatter`'s optional format is positional: `PercentFormatter(DecimalFormat('#.##'))`.
- **`EntryXComparator` is a class with a `compare` method:** sort with `entries.sort(EntryXComparator().compare)`.
- **`FileUtils` only reads assets, asynchronously:** `await FileUtils.loadEntriesFromAssets(rootBundle, 'data.txt')`
  takes an `AssetBundle` and returns a `Future<List<Entry>>`;
  `await FileUtils.loadBarEntriesFromAssets(rootBundle, 'bars.txt')` returns a `Future<List<BarEntry>>`.
  `loadEntriesFromFile` and `saveToSdCard` (external storage) do not exist.
- **`BaseDataSet.setColors(colorResIds, context)` and `LineDataSet.setCircleColors(colorResIds, context)` do not
  exist** (no Android color resources); pass `Color`s.
- **The other nested enums of the components are top-level too:** `XAxis.XAxisPosition` is `XAxisPosition`,
  `YAxis.YAxisLabelPosition` is `YAxisLabelPosition`, `Legend.LegendHorizontalAlignment` /
  `LegendVerticalAlignment` / `LegendOrientation` / `LegendDirection` are `LegendHorizontalAlignment` /
  `LegendVerticalAlignment` / `LegendOrientation` / `LegendDirection`, and `LimitLine.LimitLabelPosition` is
  `LimitLabelPosition`: `xAxis.position = XAxisPosition.BOTTOM`, `legend.orientation = LegendOrientation.VERTICAL`.
  `y_axis.dart` re-exports `AxisDependency` and `legend.dart` re-exports `LegendForm`.
- **`Paint.Align` and `Paint.Style` are `PaintAlign` and `PaintStyle`:** `description.textAlign = PaintAlign.LEFT`,
  `limitLine.textStyle = PaintStyle.FILL`.
- **`LegendEntry` takes optional positional arguments** in Kotlin's order,
  `LegendEntry(label, form, formSize, formLineWidth, formLineDashEffect, formColor)`; Kotlin's named-argument form
  `LegendEntry("Sales", formColor = Color.BLUE)` becomes `LegendEntry('Sales')..formColor = Colors.blue`.
  `Legend()` and `Legend(entries)` are one constructor with an optional list, and `YAxis(AxisDependency.RIGHT)` takes
  the side as an optional positional argument.
- **Members that Kotlin writes from the renderers (`internal set`) are publicly writable:** `AxisBase.entries`,
  `centeredEntries`, `entryCount`, `decimals`, `XAxis.labelWidth` / `labelHeight` / `labelRotatedWidth` /
  `labelRotatedHeight` (`double` here), `Legend.neededWidth` / `neededHeight` / `textWidthMax` / `textHeightMax` and
  `Legend.setComputedEntries`. Dart has no module-internal visibility; treat them as read-only.
- **`MarkerView` is a canvas marker base class, not an Android `View`.** There is no layout resource to inflate:
  subclass it, return the marker size from `FSize measure()` and paint it in `void drawContent(Canvas canvas)` (the
  canvas is already translated to the marker's top left corner), for example with a `TextPainter`. `offset`,
  `setOffset`, `chartView`, `getOffsetForDrawingAtPoint` (which keeps the marker inside the chart),
  `refreshContent` and `draw` work as on Android; update what `measure` and `drawContent` use in `refreshContent`.
- **`MarkerImage(context, drawableResourceId)` is `MarkerImage(ChartDrawable drawable)`.** Load the image with
  Flutter and pass an `ImageDrawable`; `offset`, `size` and `chartView` are unchanged.
- **`Description` clashes with `package:matcher`'s `Description` in tests:** import
  `package:flutter_test/flutter_test.dart` with `hide Description` in a test that uses the chart description.
- **`Easing` clashes with Material's `Easing`.** `package:flutter/material.dart` exports Material 3's motion `Easing`
  too, so a file that imports both libraries and names `Easing` (`Easing.EaseInQuad`) fails with an
  `ambiguous_import` error. Import Material with `import 'package:flutter/material.dart' hide Easing;`, as the
  example app does, or import the chart library with a prefix.
- **`LineChartRenderer` has no offscreen bitmap.** `drawBitmap`, `bitmapCanvas`, `bitmapConfig` and
  `releaseBitmap()` do not exist: cubic, horizontal bezier and dashed lines are drawn straight onto the chart canvas,
  so `drawCubicBezier(canvas, dataSet)` and `drawHorizontalBezier(canvas, dataSet)` take the canvas as their first
  parameter. A subclass that overrode them must add it.
- **`PieChartRenderer` has no offscreen bitmap either.** `drawBitmap`, `bitmapCanvas` and `releaseBitmap()` do not
  exist: the slices, the highlighted slices and the hole are drawn straight onto the chart canvas. Only a transparent
  circle clipped to the slices (`isTransparentCircleClippedToSlices`) opens a layer (`saveLayer`) from `drawData` to
  `drawExtras`, where Kotlin composited its bitmap; a subclass that draws in between draws into that layer.
- **`PieChart.centerText` is a `String`**, Kotlin's `CharSequence` without spans: the styles of a `SpannableString`
  have no counterpart. Style the whole text with `centerTextColor`, `centerTextSize` and `centerTextTypeface`; line
  breaks (`'44%\nMobile'`) work as on Android.
- **Renderer overloads have their own names:** `DataRenderer.drawValue(c, formatter, value, stackIndex, …)` is
  `drawStackedValue`, `BarLineScatterCandleBubbleRenderer.shouldDrawValues(set)` is `shouldDrawValuesOf(set)` (the
  `(chart, set)` form keeps the name) and `LineRadarRenderer.drawFilledPath(c, path, fillColor, fillAlpha)` is
  `drawFilledPathColor`. `YAxisRenderer`'s `renderLimitLines` path property is `renderLimitLinesPath`, since Dart
  cannot give a field and a method the same name, and the renderers' `XBounds` is the top-level class
  `XBounds(animator)`. `HorizontalBarChartRenderer.drawValue(c, valueText, x, y, color)`, which draws an already
  formatted label, is `drawValueText`, since the inherited `DataRenderer.drawValue` has the name.
- **`Easing.EasingFunction` is the top-level function type `EasingFunction`** (`double Function(double input)`):
  where Kotlin wrote `Easing.EasingFunction { t -> t * t }`, pass a closure `(t) => t * t`. The curves keep their
  names (`Easing.EaseInOutQuad`, …) and compute in double precision; `Easing.fromCurve(Curves.fastOutSlowIn)` adapts a
  Flutter `Curve`.
- **`ChartAnimator(listener)` is `ChartAnimator({vsync, onUpdate})`**: the update listener is a plain `onUpdate`
  callback, and the `TickerProvider` in `vsync` (the host widget's `State`) drives the animations. The `@JvmOverloads`
  of `animateX` / `animateY` / `animateXY` are named optional parameters: `animateX(1000, easing: Easing.EaseInQuad,
  onEnd: () {})`, `animateXY(1000, 500, easingX: Easing.EaseInQuad, easingY: Easing.Linear, onEnd: () {})`.

- **Charts are plain Dart objects without Android constructors.** `LineChart(context)` / `LineChart(context, attrs)`
  are `LineChart()`; the widget layer shows the chart and calls its `onSizeChanged`, `onDraw` and
  `onDetachedFromWindow`. `saveToGallery`, `isHardwareAccelerationEnabled`, `onMeasure`, `onLayout` and
  `unbindDrawables` do not exist; `isUnbindEnabled` is kept but has no effect. `LineChart` does not override
  `onDetachedFromWindow` (there is no renderer bitmap to release). `PieChart` overrides it to release the renderer's
  cached center text layout instead, where Kotlin released the renderer's bitmap.
- **`toBitmap(width, height)` is `toImage({width, height, pixelRatio = 1.0})`**, which returns a
  `Future<ui.Image>`, and `toPngBytes({width, height, pixelRatio})` returns the PNG bytes as a `Future<Uint8List>`.
  `width` and `height` are the chart size in logical pixels (dp) and default to the current size; the chart is drawn
  over white, as Android does without a view background. Android's bitmap has one pixel per device pixel, while the
  default `pixelRatio` of 1 gives one image pixel per logical pixel; pass the device pixel ratio for the same
  resolution: `await chart.toPngBytes(pixelRatio: MediaQuery.devicePixelRatioOf(context))`. `pixelRatio` does not
  set `Utils.devicePixelRatio`: the chart is rounded and dashed on the grid of its current value. To replace
  `saveToGallery`, write the bytes of `toPngBytes` with a storage plugin of your choice.
- **`ChartTouchListener.ChartGesture` is the top-level enum `ChartGesture`**, and `MotionEvent` is `ChartTouchEvent`:
  `onChartGestureEnd(ChartTouchEvent me, ChartGesture lastPerformedGesture)` compares with `ChartGesture.DRAG`.
  `Chart.onTouchEvent(ChartTouchEvent)` returns whether the event was consumed.
- **The touch listeners have no Android `GestureDetector`.** `ChartTouchListener` declares the
  `GestureDetector.SimpleOnGestureListener` callbacks its built-in detector calls, with the same defaults: `onDown`,
  `onSingleTapUp`, `onLongPress`, `onScroll`, `onFling`, `onDoubleTap` and `onDoubleTapEvent`; Kotlin's
  `gestureDetector.onTouchEvent(event)` is the protected `gestureDetectorOnTouchEvent(event)`. `onShowPress`,
  `onSingleTapConfirmed` and `onContextClick` do not exist: drop overrides of them, since an `@override` of one does
  not compile (Kotlin's `PieRadarChartTouchListener` overrides `onSingleTapConfirmed` only to return `true`).
  `VelocityTracker` is `ChartVelocityTracker`, and
  `Utils.velocityTrackerPointerUpCleanUpIfNecessary` is `ChartVelocityTracker.pointerUpCleanUpIfNecessary`.
- **`AnimationUtils.currentAnimationTimeMillis()` is `BarLineChartTouchListener.clock` and
  `PieRadarChartTouchListener.clock`**, functions that return `DateTime.now().millisecondsSinceEpoch` by default. A
  test can replace them (`@visibleForTesting`) to step a fling or rotation deceleration with `computeScroll()` in
  fixed time steps.
- **`highlightValue` has one form for x values and one for `Highlight`s.** Kotlin's
  `highlightValue(x, dataSetIndex, dataIndex, stackIndex, callListener)` and
  `highlightValue(x, y, dataSetIndex, dataIndex, stackIndex, callListener)` are
  `highlightValue(x, dataSetIndex, {y = double.nan, dataIndex = -1, stackIndex = -1, callListener = true})`:
  `chart.highlightValue(3, 0, y: 5)`. `highlightValue(highlight, callListener)` is
  `highlightValueOf(highlight, {callListener = true})`.
- **`zoom(scaleX, scaleY, x, y)` and `zoom(scaleX, scaleY, xValue, yValue, axis)` are one
  `zoom(scaleX, scaleY, x, y, [AxisDependency? axis])`.** Without `axis`, `x` / `y` are the pivot in pixels and the
  zoom happens at once; with `axis`, they are values and the zoom runs as a viewport job that centers them once the
  chart has a size, as in Kotlin. Likewise `getValuesByTouchPoint(x, y, axis)` and `(x, y, axis, outputPoint)` are one
  `getValuesByTouchPoint(x, y, axis, [outputPoint])` that returns the point it wrote to.
- **`onValueSelected(onNothingSelected) { e, h -> }` takes the selection callback first:**
  `chart.onValueSelected((e, h) => ..., onNothingSelected: () => ...)`.
- **`OnChartValueSelectedListener` and `OnChartGestureListener` are abstract classes with a `fromFunction` factory**,
  because Dart has no SAM conversion:
  `OnChartValueSelectedListener.fromFunction(onValueSelected: (e, h) {}, onNothingSelected: () {})`, and
  `OnChartGestureListener.fromFunction(onChartSingleTapped: (me) {})`, where every callback is optional. Subclass them
  with `extends`, not `implements`: the gesture listener's methods have empty default bodies, which `implements`
  does not inherit.
- **The chart's `animateValue` and `animateDataChange` take named optional parameters too**:
  `animateValue(entry, toY, 500, easing: Easing.EaseOutQuad, onEnd: () {})`,
  `animateDataChange(newData, 500, easing: ..., onEnd: ...)`. `Chart.animateX` / `animateY` / `animateXY` take the
  same parameters as `ChartAnimator`'s, and `PieRadarChartBase.spin` takes `easing` and `onEnd` the same way:
  `spin(1000, 0, 360, easing: Easing.EaseInOutCubic, onEnd: () {})`.
- **Viewport jobs are `void Function()`s and their durations are `int` milliseconds.** `addViewportJob(Runnable)` and
  `removeViewportJob(Runnable)` take a `void Function()`; pass a job's `run` (`chart.addViewportJob(job.run)`). The
  `AnimatedViewPortJob` listener methods keep their names without the `Animator` argument: `onAnimationStart()`,
  `onAnimationUpdate()`, `onAnimationEnd()`, `onAnimationCancel()` and `onAnimationRepeat()`; the progress is in
  `phase`.
- **MPChartCompose's composables are the widgets of `package:mp_flutter_chart/mp_flutter_chart.dart`.** That entry
  point exports the widget layer and every core type except the chart classes, which it names `LineChartView` & co.,
  as Compose does; `package:mp_flutter_chart/core.dart` has the MPChartLib names (`LineChart` and the other chart
  names are the chart classes there). Import one of the two in a file: importing both makes the eight chart names
  (`LineChart`, `BarChart`, `HorizontalBarChart`, `ScatterChart`, `CandleStickChart`, `BubbleChart`, `PieChart` and
  `RadarChart`) ambiguous (the widget in one, the chart class in the other). A file that needs a chart class next to
  the widgets imports `core.dart` with a prefix (`import 'package:mp_flutter_chart/core.dart' as core;`, then
  `core.LineChart()`) or with `show`, or uses `LineChartView` & co. The parameters map as follows:
  - `LineChart(data, modifier, state, contentDescription, marker, animateChanges, setup, update)` is
    `LineChart(data:, controller:, contentDescription:, marker:, animateChanges:, setup:, update:)`; `modifier` has
    no counterpart (give the widget its size with its parent, e.g. a `SizedBox`). `PieChart(...)` and
    `RadarChart(...)` take the same parameters, with `data` a `PieData?` / `RadarData?`; their `setup` and `update`
    get a `PieChartView` / `RadarChartView`.
  - `state = rememberChartState()` is `controller: ChartController?`: create the controller in your `State`, dispose
    it there, and pass it to one chart. Null (the default) means no controller; there is no implicit saved state.
    The members keep their names (`selectedEntry`, `zoomX`, `highlight(x, dataSetIndex:, dataIndex:)`,
    `animateXY(..., easingX:, easingY:)`, `animateDataChange(data, ms, easing:, onEnd:)`, `fitScreen()`, …); listen
    with a `ListenableBuilder`. As in Kotlin, `highlight(x)` passes y = NaN, like Compose's `ChartState.highlight`,
    so on a `BubbleChart` no highlight or marker is drawn (`BubbleChartRenderer` skips a highlight whose y is not the
    entry's); use `chart.highlightValue(x, dataSetIndex, y: …)` there. `ChartState.Saver` is `toJson()` /
    `restoreFrom(json)` / `ChartController.fromJson`, a JSON-encodable map with one key per saved value (`zoomX`,
    `zoomY`, `lowestVisibleX`, `rotationAngle`, `hasHighlight`, `highlightX`, `highlightY`, `highlightDataSetIndex`,
    `highlightDataIndex`, `highlightStackIndex`, `topLeftX`, `topLeftY`); a value Kotlin saves as NaN is null. Use it
    from your own `RestorationMixin` or storage.
  - `setup: LineChartView.() -> Unit` / `update: LineChartView.() -> Unit` take the chart as their argument:
    `setup: (chart) { chart.axisRight.isEnabled = false; }`. `setup` runs once, before the data is set; `update`
    runs on every build of the widget, the first one included.
  - `marker: @Composable (Entry, Highlight) -> Unit` is `marker: Widget Function(Entry entry, Highlight highlight)`,
    wrapped in a `WidgetMarker` (Compose's `ComposeMarker(chart, content)` is `WidgetMarker(chart, content)`; its
    `position` notifier says where the overlay shows it, and `detach()` disposes it). To give a chart instance you own
    a widget marker, pass the builder to `ChartHostWidget(marker:)`; the overlay that shows it is internal to the
    widgets.
  - `ChartView` is the public `ChartHostWidget<C, D>(chart:, data:, …)`, which shows a chart instance you own.
- **The chart widgets are `StatefulWidget`s that own their chart.** A composable remembers the view `AndroidView`
  created; a `LineChart` widget's `State` creates its `LineChartView` once and keeps it while the widget stays in the
  tree. The chart's animations run on that `State` (a `TickerProviderStateMixin`), from `setup` on.
- **`Chart.afterDrawListeners` is a Flutter addition.** `ChartState` observed the view with a
  `ViewTreeObserver.OnDrawListener`; a chart is no view here, so the chart calls these listeners at the end of every
  `onDraw` (after the markers or the empty state), `toImage` included. `ChartController` and `WidgetMarker` use it. A
  chart type that overrides `onDraw` calls `notifyAfterDraw()` at its end.
- **`Chart.onHostVsyncChanged()` is a Flutter addition.** The chart's render object calls it when it lends the chart
  another vsync (an Android view keeps one frame clock while attached). A chart type whose touch listener runs a
  ticker of its own stops it there and calls `super`; `BarLineChartBase` stops a running fling deceleration and
  `PieRadarChartBase` a running rotation deceleration.

## Behavior differences

- **Text bounds are approximate ink bounds from Roboto's glyph extents.** Flutter exposes no glyph ink bounds, so
  `ChartPaint.getTextBounds` (Android `Paint.getTextBounds`) reads a table of the extents of Roboto's glyphs
  (`lib/src/graphics/roboto_glyph_extents.dart`, Latin-1 and a few symbols): the highest and lowest ink of the text,
  the left side bearing of its first glyph with ink and the right side bearing of its last, applied to the advance
  Flutter lays the text out with, rounded outwards to whole device px. The bounds are exact for Android's default font
  and Roboto's elsewhere: the table is used for every typeface and on every platform. A character outside the table
  (CJK, emoji and the rest) counts as the line box, the font's ascent to descent without side bearings.
  `Utils.calcTextHeight`, `calcTextSize` and the axis label sizes, legend form positions and label offsets built on
  them follow.
- **On the web, ints beyond 2^53 are not exact.** Dart ints are JavaScript numbers there, so `DecimalFormat.format`
  of such an int and `Utils.formatNumber` of a value that large print digits that differ from Android's `Long`
  arithmetic; `Utils.formatNumber` does not saturate at `Long.MAX_VALUE`. Smaller values format the same on every
  platform.
- **`Paint.FontMetrics.top` equals `ascent` and `bottom` equals `descent`.** Flutter has no separate top/bottom
  metrics, so `Utils.getLineSpacing` (`ascent - top + bottom` on Android) collapses to `descent`; multi-line
  legends are slightly tighter than on Android.
- **Thin geometry and text rasterise slightly differently from Android.** Flutter's renderers (Impeller on Android and
  iOS, Skia on HarmonyOS) anti-alias thin and fractional-px geometry differently from Android's hwui/Skia, and Flutter
  shapes text unhinted, with sub-pixel positions, where Android hints it. Measured on a 420 dpi emulator: a 1 dp grid
  line is 2 solid px plus an anti-aliased row where Android has 3 solid px, candle wicks and bodies differ by a px in
  width, stacked bar segments show no 1 px seam between them where Android shows one, and text advances are 2–4 px apart
  over a short label. No Dart code controls this; the positions, sizes and colours the library draws are the same.
- **`DecimalFormat` rounds `RoundingMode.HALF_EVEN` on the exact binary value of the double.** `#.##` formats
  1.005 as `1` (stored slightly below the tie) and 0.125 as `0.12` (an exact tie, rounded to even). Neither the
  JDK's `java.text.DecimalFormat` nor Android's ICU-backed `DecimalFormat` follows this rule exactly, and they also
  differ from each other, on rare inputs that sit next to a decimal tie:
  - `###,###,###,##0.000` formats 0.0005 (stored as 0.000500000000000000010…) as `0.001` here; the JDK prints
    `0.000`.
  - `#.#` formats 0.15 (stored as 0.149999999999999994…) as `0.1` here and on the JDK; Android's ICU rounds the
    shortest decimal `0.15` half-even and prints `0.2`.

  These inputs are not reached by the library's own formatters with Float values widened to double. A negative
  value that rounds to zero keeps its sign (`#.#` formats -0.01 as `-0`, like Java), NaN prints `NaN`, and the
  infinities print `∞` / `-∞`. The digits of a double are its shortest round-trip digits, so the trailing digits of
  a huge value (≥ 1e16) may differ from the JDK (for example `2.685968904669884e17` prints
  `268,596,890,466,988,400`, the JDK `268,596,890,466,988,416`).
- **`double.toStringAsFixed` rounds the exact binary value, unlike Java's `String.format`.** A custom formatter
  ported from `String.format("%.2f", value)` / `"%.2f".format(value)` to `value.toStringAsFixed(2)` prints `1.00`
  for the double 1.005 (stored slightly below the tie), where Java rounds the shortest decimal form `1.005` half up
  and prints `1.01` (likewise `%.1f` of 0.15 is `0.2` in Java, `0.1` in Dart). This library's `DecimalFormat` also
  rounds the exact value, but breaks exact ties to even where `toStringAsFixed` rounds them away from zero (0.125
  gives `0.12` with `#.##`, `0.13` with `toStringAsFixed(2)`). A Kotlin formatter that formats its `Float` argument
  directly already prints `1.00`, because `1.005f` widened to double lies below the tie, so the difference shows with
  double values near a decimal tie.
- **`DataSet.entries` and `ChartData.dataSets` always keep the list you pass.** Kotlin keeps an `ArrayList` by
  reference and copies any other list; Dart cannot tell the two apart, so the list is always kept. Pass a growable
  list (a list literal, not a `const` or unmodifiable one) if entries or sets will be added through the data set or
  the chart data.
- **An entry passed to `ChartData.addEntry` / `removeEntry` or `IDataSet.addEntry` / `removeEntry` / `contains` must
  have the set's payload type.** Dart generics are reified: passing an `Entry<dynamic>` to a `LineDataSet<Order>`
  throws a `TypeError`, where Kotlin's unchecked cast let it through. Create the entry as `Entry<Order>(...)`.
- **The "no data" value of the cached ranges is Kotlin's `Float.MAX_VALUE`, `3.4028234663852886e38`**, not
  `double.maxFinite`: an empty `DataSet` / `ChartData` reports `yMin == xMin == 3.4028234663852886e38` and
  `yMax == xMax == -3.4028234663852886e38`, as on Android.
- **Line circles are drawn directly instead of from cached bitmaps.** `LineChartRenderer.drawCircles` draws each
  circle and its hole onto the canvas (a transparent hole is one even-odd path) with the same colors, sizes and
  skipping as Android, where each circle was a bitmap cached per circle color. A canvas-recording test therefore sees
  `drawCircle` / `drawPath` calls at the circle centers, not `drawBitmap` calls at their top-left corners.
- **Bezier and dashed lines are drawn last without a bitmap.** Kotlin draws bezier fills and lines and dashed linear
  lines onto an offscreen bitmap that it composites after all data sets; the port draws them straight onto the chart
  canvas in a second pass, after the linear fills and plain linear lines of every data set, so the stacking matches
  Android. A canvas-recording test sees those `drawColor` / `drawPath` calls after the first pass instead of one
  `drawBitmap`. As on Android, `drawData` draws nothing while the chart has no size and such a line is visible.
- **`LineChartRenderer.drawDataSet` runs once per pass.** While any visible data set is dashed or bezier, `drawData`
  calls `drawDataSet(c, dataSet)` twice for every visible data set, once per pass, and the base implementation draws
  only the part of the set that belongs to the pass. Kotlin calls it once per set. An override that draws something
  of its own around `super.drawDataSet` draws it twice in that mode: draw such extras once per frame from an override
  of `drawData` (after `super.drawData`) or `drawExtras` instead.
- **The axis label count stops where Kotlin would hang (deliberate deviation).** `AxisRenderer.computeAxisValues`
  rounds its bounds to Float as Kotlin does, so a range below the Float resolution gives no labels. When the
  interval is still below half an ulp of the label values (adjacent Floats with a label count in the billions),
  Kotlin's label-counting loop never advances and freezes the UI thread; the port stops counting at the first label
  that no longer advances and draws the labels counted so far.
- **An animation without a ticker ends at once.** A `ChartAnimator` without a `vsync` (a chart built in code and not
  shown by a widget, or drawn with `toImage`) ends every animation at its final state and calls `onEnd` before
  `animateX` / `animateY` / `animateXY` return; so does an animation with a duration of 0, whose end Android reports on
  the next frame. Changing `vsync` (the chart moves to another host widget, or leaves it) ends the running animations
  at their final state, as leaving the window does on Android.
- **A self-restarting animation stops when it would end at once.** An `onEnd` that starts a new animation in its own
  slot, such as `void loop() => chart.animateY(1000, onEnd: loop);`, keeps looping on Android, one restart per
  animation. Where the animation ends at once (no `vsync`, or a duration of 0), each restart would end and call `onEnd`
  inside the previous `onEnd`, which used to recurse until a `StackOverflowError`. Now the restart made while its slot
  is still ending is applied at its final state (its values are written and the chart is redrawn) but its `onEnd` is
  not called, so the loop stops there; debug builds print a warning once per chart. This also covers the host widget
  going away while such a loop runs (the running animation and one restart end and call `onEnd`, the next restart
  stops the loop) and a loop through other slots that comes back (x → y → x). A chain across slots (`animateX` whose
  `onEnd` calls `animateY`) still gets every `onEnd`.
- **A restart of a slot while a new animation cancels that slot is dropped.** Starting an animation cancels the one
  running in its slot, and that one's `onEnd` runs right then. While that cancel runs, every start of the same slot
  is dropped and its `onEnd` is never called: one from that `onEnd` (a loop such as
  `void loop() => chart.animateY(1000, onEnd: loop);`, which restarts on every end, cancellations included) or from
  anything it calls in turn, other slots' animations and their callbacks included. The animation being started wins,
  and debug builds print a warning once per chart. On Android the restart keeps running unseen next to the new
  animation, both move the same phase until it ends, and its `onEnd` then restarts the loop; here the loop stops at
  the new animation. A dropped `animateDataChange` has already set its data and that data's start values, so the
  chart then shows the newest data frozen at the transition's start (the values shown before), while the animation
  that won moves data that is no longer shown, until the data changes again.
- **Reduced motion shortens animations instead of skipping them.** When the platform asks to disable animations,
  Flutter's `AnimationController` runs them at 5% of their duration; Android's animator duration scale of 0 skips them
  to their final state on the next frame.
- **`animateDataChange` pairs data sets by runtime type, type arguments included.** Kotlin compares the erased classes,
  so a `LineDataSet<Order>` replaced by a `LineDataSet<dynamic>` animates on Android; here the shapes count as
  different and the new data is set without animation. Give old and new data sets the same payload type.
- **An animation ends one frame later when a frame lands exactly on its duration.** Flutter's `AnimationController`
  finishes once the elapsed time is greater than the duration (`_InterpolationSimulation.isDone` uses `>`), Android
  once it is greater than or equal. The frame exactly at the duration already shows the final value; the end, and
  `onEnd`, follow on the next frame.
- **A chart without a host runs posted jobs at once and ignores redraw requests.** Without a widget (a chart built in
  code, for example to export an image), `post(job)` runs the job before returning instead of after the frame, and
  `invalidate()` does nothing. `setViewPortOffsets` therefore applies at once, and the viewport jobs that waited for
  a size run inside `onSizeChanged`.
- **Animated viewport jobs end at once without the host's vsync.** `moveViewToAnimated`, `centerViewToAnimated` and
  `zoomAndCenterAnimated` on a chart without a host, or with a host that has no `vsync`, jump to their target when
  they run, like the `ChartAnimator` animations. With a `vsync` they run on an `AnimationController` eased with
  `Easing.EaseInOutSine`, the curve of Android's default `AccelerateDecelerateInterpolator`.
- **`onDetachedFromWindow` also drops the waiting viewport jobs and ends running viewport animations at their
  target.** Kotlin keeps `jobs` across a detach and the next attach, so a chart in a list row that is detached before
  its first layout still applies a queued `moveViewToX` later; here the job is lost. Call it again after the chart is
  shown again.
- **Without a host, `isKeepPositionOnRotation` undoes the moves queued before the first size.** `onSizeChanged` runs
  the waiting jobs before `BarLineChartBase` restores the kept position, so with `isKeepPositionOnRotation` a
  `moveViewToX` queued before the first size is undone, and a `zoom(..., axis)` keeps its scale but not its
  centering. With a host the jobs run after the frame, as on Android.
- **The chart's render object fills the space its parent allows; a side without a bound is 300.** Android's
  `Chart.onMeasure` resolves `wrap_content` and an unspecified size to 50 dp. Here the chart takes the biggest size
  its constraints allow, so loose constraints (inside a `Center`, the width in a `Column`) are filled, and a side
  without a bound (the height in a `Column` or a vertical scroll view) is 300 logical pixels. Give the chart its
  size with a `SizedBox`, `Expanded` or similar.
- **A job posted while the chart is shown is dropped when the chart leaves the screen before the frame ends.** On
  Android a runnable that `View.post` queued while the view was attached still runs after `onDetachedFromWindow`;
  here the host drops a posted job (for example a `moveViewToX` on a laid out chart) when, at the end of the frame,
  it no longer shows the chart, as `onDetachedFromWindow` drops the jobs that wait for a size. A job posted after
  that runs at once, as on a chart without a host.
- **`onEnd` callbacks can run while the chart's widget is being removed.** When the widget that shows the chart
  goes away, its render object ends the running animations (Android's `onDetachedFromWindow`), and their `onEnd`
  callbacks run synchronously inside `RenderObject.detach`, during the build phase. An `onEnd` that calls `setState`
  on an ancestor widget must defer it then, for example with `SchedulerBinding.instance.addPostFrameCallback`.
- **The fling deceleration runs on a ticker from the host's vsync.** Android's view system calls `computeScroll`
  from every draw, and the touch listener asks for the next draw while the chart still moves. Here
  `BarLineChartTouchListener` starts a `Ticker` from `chart.host.vsync` when a drag ends in a fling and calls
  `Chart.computeScroll` on every frame until the velocity has decayed (below 0.01 px/s); a new touch,
  `stopDeceleration()`, a new vsync on the chart's render object and `onDetachedFromWindow` stop it. Android keeps the
  velocity across a detach and goes on
  when the chart is drawn again; here the deceleration ends. A chart without a host, or whose host has no `vsync`,
  does not move by itself: call `computeScroll()` once per frame. `PieRadarChartTouchListener` runs the rotation
  deceleration of a pie or radar chart the same way.
- **Gesture thresholds are Flutter's.** The touch slop is `kTouchSlop`, 18 logical pixels (Android's scaled touch
  slop is 8 dp): a tap may move up to 18 px, and on a fully zoomed out chart a highlight drag starts once the finger
  is more than 18 px away along x (along y on a `HorizontalBarChart`, whose x axis runs vertically). A long press
  fires after `kLongPressTimeout`, 500 ms (Android's long press timeout is 400 or 500 ms depending on the version). A
  double tap is a second down within `kDoubleTapTimeout` (300 ms) of the first down, at least `kDoubleTapMinTime`
  (40 ms) after the first up and within `kDoubleTapSlop` (100 px), as on Android. A fling needs
  `Utils.minimumFlingVelocity` (50 px/s) and is limited to `Utils.maximumFlingVelocity` (8000 px/s), Android's
  defaults in dp. The drag trigger distance stays 3 dp.
- **Starting a rotation cancels the tap, long press and double tap of that touch (deliberate deviation).** On
  Android the gesture detector's touch slop (8 dp) is the rotation threshold of `PieRadarChartTouchListener`, so a
  touch that starts rotating a pie or radar chart has already left the tap region. Flutter's slop is 18 px, so the
  move that starts a rotation also sends the detector a cancel: a touch that rotated the chart by 8 to 18 px reports
  no tap on its up (which would highlight a slice and leave the listener rotating for the next touch), no long press
  and no double tap.
- **A pending long press is cancelled when a drag or zoom ends.** The gesture detector stops getting events once a
  drag or zoom has started, as on Android, so after a drag that started within the touch slop Android still reported
  `onChartLongPressed` after the long press timeout, even when the finger had lifted by then. Here the up (or cancel)
  of the touch cancels it. A drag that is still held at the long press timeout reports a long press, as on Android.
  `onDetachedFromWindow` cancels a pending long press too.
- **Touch events need Flutter's gesture binding.** `ChartVelocityTracker` uses Flutter's `VelocityTracker`, which
  reads the sampling clock of the `GestureBinding`. Every Flutter app has one; a test that feeds `ChartTouchEvent`s to
  a chart by hand does it inside `testWidgets`, whose fake clock the tracker then uses.
- **A scrolling parent can take a touch over until the chart claims it, as on Android.** The chart's
  `ChartGestureRecognizer` joins Flutter's gesture arena for every finger on the chart and wins it at the moment the
  touch listener calls `disableScroll()`, Android's `requestDisallowInterceptTouchEvent(true)`: a zoomed in or dragged
  chart on its second move past the 3 dp drag trigger, a pinch when the second finger goes down. Fingers that go down
  later in that gesture stay with the chart. After a finger's down the chart handles each event of that finger after the
  other recognizers in the arena, as Android's parent sees each `MotionEvent` in `onInterceptTouchEvent` before the
  chart: a parent such as a `ListView` that wins the arena on a move cancels the chart's gesture
  (`ChartTouchAction.cancel`, Android's `ACTION_CANCEL`) before the chart sees that move. A list wins once its drag
  passes its touch slop along its own axis. Flutter's `Scrollable` takes that slop from the platform through the
  `MediaQuery` gesture settings: 8 dp on Android (`ViewConfiguration`'s scaled touch slop), `kTouchSlop` (18 px) on iOS,
  which reports none, and 8 dp in the source of the HarmonyOS embedding, not verified on a device. A list that wins this
  way scrolls from the move that passed its slop: with Flutter's default `DragStartBehavior.start` it drops the travel
  up to and including that move (at least the slop given above), so a swipe that starts on a chart, as on any child with
  a recognizer (a tap detector, a button), scrolls the list that much less than one that starts outside it, where the
  list is alone in the arena and follows the finger from the down. `dragStartBehavior: DragStartBehavior.down` on the
  scrollable gives the list that travel when it wins, as one update. With `ClampingScrollPhysics`, the default on
  Android and HarmonyOS, a swipe then scrolls the list as far from a chart as from outside it, as on Android. iOS's
  default `BouncingScrollPhysics` scrolls nothing of a drag until it has moved 3.5 px and then at most 3.5 / 3 px for
  the update that passes that, unless that update is a single jump of more than 24 px. The one update
  `DragStartBehavior.down` gives the list on iOS is the travel up to and including the move that passed the 18 px slop,
  so it is eased like that when it is 24 px or less, which still scrolls the list less from a chart than from outside it
  (40 px instead of 54 px for a 57 px swipe in 400 ms); a swipe of 10 px moves at 60 Hz gives a 20 px update and is
  eased too. Only an update of more than 24 px is kept whole, and it then scrolls the list a few px farther from a
  chart. The chart's own slop is always `kTouchSlop`. So on a fully zoomed out chart a swipe along the list's axis
  scrolls the list and keeps the selection, also on a `HorizontalBarChart` in a vertical list, whose x axis runs along
  the list; a swipe along the chart's x axis across the list's axis highlights. A first move that already passes the
  list's slop goes to the list even on a zoomed in chart, and so does a zoomed in chart's claiming move when it passes
  the list's slop too. The chart starts a highlight drag on the straight-line distance and the list on the distance
  along its axis, so where both slops are equal (iOS) a swipe that drifts sideways can highlight once before the list
  takes it over; MPAndroidChart has the same gap, as its chart and Android's list both use the scaled touch slop.
  Disposing the recognizer during a touch (the chart's widget goes away) delivers a cancel too, as Android's `ViewGroup`
  does for a removed child. Positions are measured against the chart's position at the finger's down; Android measures
  every event against the view's current position.
- **Where a scrollable's touch slop is 8 dp, a straight swipe along it that starts on a pie's ring or a radar's web goes
  to the scrollable, as on Android**, however small its moves are. 8 dp is Android's slop and, according to the source
  of the HarmonyOS embedding, HarmonyOS's. A straight swipe on the ring scrolls the list on the HarmonyOS emulator too;
  no HarmonyOS device has been tried. `PieRadarChartTouchListener` starts a rotation once the finger is more than 8 dp
  from its down, so along the scrollable's axis the rotation's threshold and the slop are passed on the same move. The
  scrollable sees that move first, as Android's parent does in `onInterceptTouchEvent`, so the chart gets a cancel and
  does not turn. A drag with a component across the scrollable's axis, the round gesture that turns a chart, still
  rotates it. On iOS the slop is `kTouchSlop` (18 px), so the rotation claims the touch first, at 8 dp, and a straight
  swipe on the ring or the web rotates the chart.
- **Trackpad gestures and the mouse wheel do not reach the chart.** A trackpad's pan and zoom gestures
  (`PointerPanZoomStartEvent` and the rest) and pointer signals are not handed to the chart (trackpad and wheel zoom
  are not in scope); an enclosing scrollable gets them. A mouse drags the chart with its primary button only, like
  Flutter's drag recognizers; presses of other buttons are ignored.
- **A widget marker is an overlay: not in `toImage`, no touches, one frame late.** `ComposeMarker` drew its
  `ComposeView` onto the chart's canvas. A `WidgetMarker`'s `draw` only records the point; the chart widget lays the
  content out in a `Stack` above the chart, centered above the point with a 12 dp gap and moved inside the chart, at
  most as big as the chart. So `Chart.toImage` does not show it (the canvas markers `MarkerView` and `MarkerImage` are
  drawn there), it is clipped to the chart like the chart itself, and touches on it go to the chart (it is wrapped in
  an `IgnorePointer`). As in Compose, the content for a new highlight appears one frame after the highlight.
- **`ChartController` notifies its listeners in a microtask, once per batch of changes.** Compose's snapshot state
  defers recomposition to the next frame; a `ChangeNotifier` that notified synchronously would mark widgets for a
  rebuild while Flutter builds or paints (the controller refreshes after every draw of the chart, and while the
  chart's widget is built or removed), which Flutter does not allow. The properties themselves change at once; the
  listeners run after the current task, and only when a property's value changed (a new `Highlight` instance counts
  as a change, as in Kotlin).
- **A change of the system fonts lays the chart out again.** The chart widget drops the cached text layouts
  (`TextMeasure.clearCache()`) and calls `notifyDataSetChanged()` when the platform reports new fonts, so labels
  measured with a fallback font are measured again; on Android the text metrics come from the `Typeface` directly.
- **Shapes with a NaN coordinate, and circles with a radius of 0 or less, are left out before they reach the canvas.**
  Skia draws nothing for a rectangle, rounded rectangle, circle or line with a NaN coordinate, while Flutter's canvas
  asserts on it in debug builds. So `ChartCanvas.drawRectP`, `drawRoundRectP`, `drawCircleP` and `drawLineP`,
  `Fill.fillRect` and `BarChartRenderer.drawBarShape` return without drawing for such a shape (a stack section whose
  value is NaN, the highlight of a bar whose value is NaN, a bar that is infinite at a y animation phase of 0), which
  looks the same as on Android. `ChartCanvas.drawText` likewise draws nothing at a NaN x or y, such as the value label
  of a −∞ bar at a y animation phase of 0. Infinite coordinates are drawn as Flutter draws them. One difference shows: a
  `Fill.ofDrawable` bar fill with a NaN edge draws nothing, where Kotlin truncates the NaN edge to 0 and draws the
  drawable there. `drawCircleP` also skips a circle with a radius of 0 or less, as Android's canvas does, where
  Flutter's Impeller renderer would stroke a dot as wide as the stroke (the highlight ring of a bubble of size 0).
- **Pie and radar geometry that is not finite is left out before it reaches the canvas.** NaN or infinite values, a
  NaN rotation angle, a radius of 0 with slice space or a radar y axis range of 0 give slices, holes, rings, polygons,
  web lines, labels, value lines and highlight circles with coordinates that are not finite, which Kotlin hands to
  Android and Android does not draw. Here the renderers skip them: a pie slice that is left out still takes its
  angle, so the slices after it stay in place, and a radar polygon with such a corner is left out entirely (fill
  and outline).
- **A radar position counts as finite only when it is finite as a `Float`.** Kotlin computes radar positions in
  `Float`, which overflows to infinity for values far beyond a small axis range, so Android draws nothing there;
  Flutter would clamp such a double to the `Float` range and draw it at the edge. The radar renderers therefore skip
  a position beyond `Float`'s range as not finite. Pie positions are checked as doubles.
- **Pie sums are doubles.** `PieData.yValueSum` and `PieChart.absoluteValueSum` add in double precision, so two
  slices of `3e38` make two half circles, where Kotlin's `Float` sum overflows to infinity and every slice angle is
  0. The slice angles themselves (`drawAngles`, `absoluteAngles`) are `Float32List`s, Kotlin's `FloatArray`, so a
  touch at a slice edge selects the same slice as on Android.
- **A radar chart keeps a custom `yAxis.axisMinimum` and `axisMaximum` (deliberate deviation).** MPAndroidChart
  v4.0.1's `YAxisRendererRadarChart.computeAxisValues` applies its first and last label as the axis range
  (`YAxisRendererRadarChart.kt:118`), into the fields that also hold a custom minimum and maximum
  (`AxisBase.kt:275-305`), and the next `notifyDataSetChanged()` (a size change calls it too) starts from there. It
  always adds one label step above the range (`:89`, `n++`), so a custom maximum grows on every call:
  RadarChartActivity's `axisMaximum = 80` with five labels becomes 100, then 120, 140, 150, 180, 200, 240, 250, 300,
  400, 500 and so on. With centered labels, which take effect once the axis has labels, the first label lies below
  the range (`:76`), so a custom minimum falls too: 0 .. 80 becomes -20 .. 120, then -30 .. 180, -40 .. 240 and
  -100 .. 400. Without them a custom minimum between two labels moves up to the first label once: 5 becomes 20 with
  five labels up to 80. Here neither custom limit is ever written back, and no label lies beyond either one by more
  than a `Float` rounding: the extra step above a custom maximum is left out, and so is the label that centered labels
  add beyond a custom limit. The web ends at a custom maximum even where no label falls on it (a custom 100 with four
  labels has rings at 0, 30, 60 and 90), and its center is a custom minimum even below the first ring (5 with rings
  from 20).
- **The highlight ring of a bubble can differ from Android by 1 in a color channel.** `BubbleChartRenderer` darkens
  the entry color by halving its HSV value with Flutter's `HSVColor`, where Kotlin uses `Color.RGBToHSV` /
  `Color.HSVToColor`. Android computes in Float and Flutter in double, and they round differently, so a red, green or
  blue channel may be 1 apart (`0xFF3F51B5` gives `0xFF1F285B` on Android, `0xFF20295B` here). The alpha is kept
  exactly.
- **A `HorizontalBarChart` marker sits at the end of its bar, vertically centered (deliberate deviation).**
  MPAndroidChart v4.0.1's `HorizontalBarChartRenderer` lost the `setHighlightDrawPos` override of 3.x, so
  `HorizontalBarChart.getMarkerPosition`, which swaps the draw position back, put the marker at a transposed point:
  the bar's top edge as x and its horizontal center as y. The port restores the 3.x override,
  `high.setDraw(bar.centerY(), bar.right)`: `Highlight.drawX` is the bar's vertical center, `drawY` its right edge,
  and the marker is drawn at the right end of the bar (the tip of a positive bar), vertically centered.

## Example app

`example/` follows MPChartExample page for page: its home list has MainActivity's sections and entries, and each
entry opens the port of its Activity. These are its differences from the Android app on top of the library's above,
each with its reason; a page's header comment lists what else that page leaves out.

- **Two of MainActivity's 42 entries have no page.** Other Charts / Combined Chart (`CombinedChartActivity`) is
  blocked: `CombinedChart` is not ported yet. Line Charts / From Java (`JavaChartActivity`) shows that the Kotlin
  library can be called from Java; a Dart package has no second language to show it from, so the entry is left out.
  The other entries keep MainActivity's order and text.
- **A page is titled with the name of its entry** ("Dual Axis"), where the Activity shows its class name
  ("LineChartActivity2"). The All chart types pages have DesignActivity's titles.
- **The "View on GitHub" and "Save to Gallery" menu items are not ported**, on any page: the first needs a URL
  launcher and the second a gallery plugin and the storage permission, and the example has no plugins. An Activity
  whose menu is `only_github.xml` therefore has no overflow button. Every other item of an Activity's menu is there,
  in the menu file's order, including the items the Activity's `onOptionsItemSelected` has no branch for, which do
  nothing here as on Android. `Chart.toPngBytes` gives the image `saveToGallery` would save.
- **`Math.random()` is a generator with a fixed seed** (`DemoBase.random` in `lib/notimportant/demo_base.dart`), so
  every run of a page shows the same charts, where Android shows new numbers on every start. A page draws from it in
  the Activity's order. Where Kotlin seeds its generator itself, the page shows Android's numbers: `KotlinRandom` is
  Kotlin's `Random(seed)` (the Compose pages) and `JavaRandom` is `java.util.Random(seed)` (the Performance pages).
  Entry values are Dart doubles, where Kotlin rounds them to `Float`.
- **Setting a SeekBar's progress in `onCreate` loads the data once.** On Android each `seekBar.progress = …` calls
  `onProgressChanged`, so an Activity with two seek bars builds its data twice before the first frame, the first time
  with the second bar still at its XML value. A page sets both values and loads once, which shows the same chart from
  fewer random draws. Basic 2 and Negative Horizontal keep Kotlin's two calls.
- **The pages are Material widgets on the Activities' light background.** A SeekBar is a `Slider` with the layout's
  maximum and its value text beside it, a RadioGroup, Switch or Button the Material widget of that name, a Toast a
  snack bar, an AlertDialog Material's, a ListView row a widget that is built again when it scrolls back into view
  (its data is built once and kept by the page), the ViewPager a `PageView` that keeps a page alive once it was
  shown instead of preloading three pages, and a Fragment a widget. A chart's `setBackgroundColor` is a `ColoredBox`
  behind it. The action bar and the home list keep the app's dark Nightfall colours.
- **The markers and the entry icon are painted, not decoded.** `MyMarkerView`, `XYMarkerView`,
  `StackedBarsMarkerView` and `RadarMarkerView` (`lib/custom/`) draw the layouts `custom_marker_view.xml` and
  `radar_markerview.xml` on the chart canvas, with the bitmaps `marker2.png` and `radar_marker.png` as paths, and
  `R.drawable.star` and `R.drawable.fade_red` are `PainterDrawable`s (`lib/custom/demo_drawables.dart`). A decoded
  image arrives later than the first frame; a painted one is there when the page builds its entries.
- **An animation `onCreate` starts runs when the chart's widget is created** (the `setup` of its `ChartHostWidget`),
  because a chart without a widget ends an animation at once. Where the data comes from an asset, which Flutter reads
  asynchronously, the chart shows without data until it has arrived: Sine's `animateXY` may then already be running,
  and the two asset pages of the View Pager start their animation when the data is set.
- **The center text of the pie charts has one style.** `PieChart.centerText` is a `String`, so the sizes, colours
  and italics of the Activities' `SpannableString`s are gone on Pie Charts / Basic, Value Lines and Half Pie, the pie
  rows of Scrolling Charts / Multiple and the pie page of the View Pager; the text and its line breaks are kept.
- **Half Pie puts the lower half of the chart below the page with an `OverflowBox`.** `moveOffScreen()` gives the
  chart view a bottom margin of minus 65 % of the display height; the page makes the chart that much taller than
  its body, aligned to the top, and clips what lies below.
- **Realtime's "Add Multiple" has one feeder, which stops when the page is left.** The Activity feeds 1000 entries
  from a `Thread` that sleeps 25 ms between them; `thread?.interrupt()` only cuts one sleep short there, because the
  loop catches the exception, so choosing the item again runs two feeders at once and the feed goes on after
  `onPause`. The page runs one periodic `Timer` of 25 ms on the UI isolate; choosing the item again restarts the 1000
  entries, and the feed ends when the app becomes inactive, when the page is popped and when it is disposed.
- **Hourly takes the time from `DateTime.now`**, a constructor parameter of the page so that a test can fix it, and
  writes `SimpleDateFormat("dd MMM HH:mm", Locale.ENGLISH)` out by hand, in the device's time zone as on Android.
- **The Performance pages build their data on the UI isolate.** The Activities build it on a single-thread executor
  and post it back; the pages build it in a `Timer(Duration.zero)`, after the frame that shows "Building … entries...",
  and drop a build a newer one has superseded, as the Activities' generation check does. The 500k entries therefore
  block one frame for as long as they take to build. The readout's clock is a `Stopwatch` with microsecond resolution
  where Android has `System.nanoTime()`, and the timed charts measure `onDraw`, which records the draw calls; Flutter
  rasterises them on another thread, which the readout does not see. As on Android, the Decimation switch starts
  checked while the chart's decimation is still off, because the switch's listener only runs on a change.
- **The Compose pages are built on the chart widgets and `ChartController`**, the ports of MPChartCompose's
  composables and `rememberChartState()`: `remember` and `rememberSaveable` values are fields of the page's `State`
  (not saved across a restart of the app), a `LaunchedEffect(key)` is a call made after the frame that follows a
  change of its key, and the `LazyColumn` is a `ListView.builder`. The colour scheme has no `background` (Flutter's
  `ColorScheme` has deprecated it); the pages paint the stage colour themselves.
- **All animations and Animated data changes poll and report as the Activities do**, with a periodic `Timer` for the
  Runnable that polls `chart.isAnimating` every 80 ms; the status chip says "Idle" from the first frame, where the
  Activity's is empty until its first poll. The tabs, chips and action buttons, clickable TextViews in the layout, are
  `GestureDetector`s.
- **The Open Sans faces and the point files are MPChartExample's assets** (`example/assets/`): Light, Regular and
  Bold, which the Activities load with `Typeface.createFromAsset` and the pages name as `tfLight`, `tfRegular` and
  `tfBold`, and the `.txt` files `FileUtils.loadEntriesFromAssets` reads through the page's `DefaultAssetBundle`.
- **The scrollables that host charts start a drag from the down** (`DragStartBehavior.down`), so a swipe that starts on
  a chart scrolls the list as far as one that starts beside it, as on Android; with Flutter's default
  `DragStartBehavior.start` the list drops the travel up to its touch slop. See "A scrolling parent can take a touch
  over until the chart claims it, as on Android" under Behavior differences, which also gives the iOS exception.

The All chart types page:

- **The All chart types page keeps Flutter's automatic back button**, which DesignActivity does not show, because iOS
  has no system back button. So the title starts about 72 dp from the left, where Android's starts at 16 dp.
- **The overflow menu is a Material 3 popup**, with Material 3's shape and elevation, because Flutter has no AppCompat
  popup; its colours and text sizes are AppCompat's light popup's.
- **The Light variant / Dark variant item swaps the page with Flutter's default page transition** (`MaterialPageRoute`),
  where DesignActivity's `startActivity` and `finish` use Android's activity transition.
- **The pill markers and the card texts follow the system font size**, as their sp sizes do on Android. Android
  recreates DesignActivity when the font size or the density changes; the page builds its cards again instead.
- **The cards sit on whole device px only while the list is at its top.** The page lays them out in whole px, as
  Android's layout rounds them, but Flutter scroll offsets are fractional, so a scrolled list can move them by a
  fraction of a px, where Android scrolls by whole px.
- **A card text that wraps has Android's box but not quite its line spacing.** The box's height follows Android's
  formula, the line box plus Roboto's ascent and descent in whole px for each line after the first, and the first
  baseline sits where Android's does. Flutter rounds a paragraph's line height to a whole logical px, so the later lines
  drift from Android's by up to half a logical px per line (1.25 px per line at 2.625 for 15 sp). At the default font
  size the card texts fit on one line, and no wrapped text has been checked on a device.
- **The action bar's shadow is fitted to AppCompat's for Impeller's `drawShadow`**, which Android and iOS render with
  (elevation 2.25 at 40 % black instead of Material's 4 dp), because Impeller's shadow at Android's elevation is about
  twice as tall. HarmonyOS renders with Skia (GL): its embedding logs "enable Skia in Ohos" although the HAP sets
  `enable_impeller` to true. Skia draws the shadow there, slightly differently, and the fit does not cover it.
- **The `/design` deep link's `only` and `from` count the ported cards.** Until the combined card is ported,
  the cards Kotlin numbers 8, 9 and 10 are 7 to 9 here; 0 to 6 match Kotlin's.
