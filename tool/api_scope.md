# API parity scope

File-level mapping from MPChartLib (MPAndroidChart v4.0.1) to this package, read by `tool/api_parity.dart`
(`--scope=`). Lanes: P0 = the LineChart core; P1-A, P1-B, P1-C = the bar-line, candle/bubble/scatter and
pie/radar chart types; P2 = CombinedChart.

| Kotlin (MPChartLib/src/main/kotlin/com/github/mikephil/charting/) | Dart | Lines | Lane |
|---|---|---:|---|
| `animation/ChartAnimator.kt` | `lib/src/animation/chart_animator.dart` | 166 | P0 |
| `animation/Easing.kt` | `lib/src/animation/easing.dart` | 242 | P0 |
| `animation/ValueTransition.kt` | `lib/src/animation/value_transition.dart` | 122 | P0 |
| `buffer/AbstractBuffer.kt` | `lib/src/buffer/abstract_buffer.dart` | 57 | P1-A |
| `buffer/BarBuffer.kt` | `lib/src/buffer/bar_buffer.dart` | 241 | P1-A |
| `buffer/HorizontalBarBuffer.kt` | `lib/src/buffer/horizontal_bar_buffer.dart` | 85 | P1-A |
| `charts/BarChart.kt` | `lib/src/charts/bar_chart.dart` | 133 | P1-A |
| `charts/BarLineChartBase.kt` | `lib/src/charts/bar_line_chart_base.dart` | 1033 | P0 |
| `charts/BubbleChart.kt` | `lib/src/charts/bubble_chart.dart` | 37 | P1-B |
| `charts/CandleStickChart.kt` | `lib/src/charts/candle_stick_chart.dart` | 30 | P1-B |
| `charts/Chart.kt` | `lib/src/charts/chart.dart` | 1078 | P0 |
| `charts/CombinedChart.kt` | `lib/src/charts/combined_chart.dart` | 130 | P2 |
| `charts/EmptyStateLayout.kt` | `lib/src/charts/empty_state_layout.dart` | 49 | P0 |
| `charts/HorizontalBarChart.kt` | `lib/src/charts/horizontal_bar_chart.dart` | 275 | P1-A |
| `charts/LineChart.kt` | `lib/src/charts/line_chart.dart` | 54 | P0 |
| `charts/PieChart.kt` | `lib/src/charts/pie_chart.dart` | 423 | P1-C |
| `charts/PieRadarChartBase.kt` | `lib/src/charts/pie_radar_chart_base.dart` | 343 | P1-C |
| `charts/RadarChart.kt` | `lib/src/charts/radar_chart.dart` | 221 | P1-C |
| `charts/ScatterChart.kt` | `lib/src/charts/scatter_chart.dart` | 54 | P1-B |
| `components/AxisBase.kt` | `lib/src/components/axis_base.dart` | 306 | P0 |
| `components/ComponentBase.kt` | `lib/src/components/component_base.dart` | 31 | P0 |
| `components/Description.kt` | `lib/src/components/description.dart` | 38 | P0 |
| `components/IMarker.kt` | `lib/src/components/i_marker.dart` | 40 | P0 |
| `components/Legend.kt` | `lib/src/components/legend.dart` | 362 | P0 |
| `components/LegendEntry.kt` | `lib/src/components/legend_entry.dart` | 22 | P0 |
| `components/LimitLine.kt` | `lib/src/components/limit_line.dart` | 60 | P0 |
| `components/MarkerImage.kt` | `lib/src/components/marker_image.dart` | 113 | P0 |
| `components/MarkerView.kt` | `lib/src/components/marker_view.dart` | 93 | P0 |
| `components/XAxis.kt` | `lib/src/components/x_axis.dart` | 45 | P0 |
| `components/YAxis.kt` | `lib/src/components/y_axis.dart` | 152 | P0 |
| `data/BarData.kt` | `lib/src/data/bar_data.dart` | 87 | P1-A |
| `data/BarDataSet.kt` | `lib/src/data/bar_data_set.dart` | 130 | P1-A |
| `data/BarEntry.kt` | `lib/src/data/bar_entry.dart` | 152 | P1-A |
| `data/BarLineScatterCandleBubbleData.kt` | `lib/src/data/bar_line_scatter_candle_bubble_data.dart` | 21 | P0 |
| `data/BarLineScatterCandleBubbleDataSet.kt` | `lib/src/data/bar_line_scatter_candle_bubble_data_set.dart` | 22 | P0 |
| `data/BaseDataSet.kt` | `lib/src/data/base_data_set.dart` | 229 | P0 |
| `data/BaseEntry.kt` | `lib/src/data/base_entry.dart` | 17 | P0 |
| `data/BubbleData.kt` | `lib/src/data/bubble_data.dart` | 21 | P1-B |
| `data/BubbleDataSet.kt` | `lib/src/data/bubble_data_set.dart` | 49 | P1-B |
| `data/BubbleEntry.kt` | `lib/src/data/bubble_entry.dart` | 32 | P1-B |
| `data/CandleData.kt` | `lib/src/data/candle_data.dart` | 16 | P1-B |
| `data/CandleDataSet.kt` | `lib/src/data/candle_data_set.dart` | 84 | P1-B |
| `data/CandleEntry.kt` | `lib/src/data/candle_entry.dart` | 49 | P1-B |
| `data/ChartData.kt` | `lib/src/data/chart_data.dart` | 390 | P0 |
| `data/CombinedData.kt` | `lib/src/data/combined_data.dart` | 189 | P2 |
| `data/DataSet.kt` | `lib/src/data/data_set.dart` | 373 | P0 |
| `data/Entry.kt` | `lib/src/data/entry.dart` | 91 | P0 |
| `data/LineData.kt` | `lib/src/data/line_data.dart` | 16 | P0 |
| `data/LineDataSet.kt` | `lib/src/data/line_data_set.dart` | 159 | P0 |
| `data/LineRadarDataSet.kt` | `lib/src/data/line_radar_data_set.dart` | 43 | P0 |
| `data/LineScatterCandleRadarDataSet.kt` | `lib/src/data/line_scatter_candle_radar_data_set.dart` | 66 | P0 |
| `data/PieData.kt` | `lib/src/data/pie_data.dart` | 70 | P1-C |
| `data/PieDataSet.kt` | `lib/src/data/pie_data_set.dart` | 70 | P1-C |
| `data/PieEntry.kt` | `lib/src/data/pie_entry.dart` | 34 | P1-C |
| `data/RadarData.kt` | `lib/src/data/radar_data.dart` | 29 | P1-C |
| `data/RadarDataSet.kt` | `lib/src/data/radar_data_set.dart` | 59 | P1-C |
| `data/RadarEntry.kt` | `lib/src/data/radar_entry.dart` | 27 | P1-C |
| `data/ScatterData.kt` | `lib/src/data/scatter_data.dart` | 20 | P1-B |
| `data/ScatterDataSet.kt` | `lib/src/data/scatter_data_set.dart` | 70 | P1-B |
| `data/filter/Approximator.kt` | `lib/src/data/filter/approximator.dart` | 63 | P2 |
| `formatter/DefaultAxisValueFormatter.kt` | `lib/src/formatter/default_axis_value_formatter.dart` | 19 | P0 |
| `formatter/DefaultFillFormatter.kt` | `lib/src/formatter/default_fill_formatter.dart` | 24 | P0 |
| `formatter/DefaultValueFormatter.kt` | `lib/src/formatter/default_value_formatter.dart` | 46 | P0 |
| `formatter/IAxisValueFormatter.kt` | `lib/src/formatter/i_axis_value_formatter.dart` | 18 | P0 |
| `formatter/IFillFormatter.kt` | `lib/src/formatter/i_fill_formatter.dart` | 18 | P0 |
| `formatter/IValueFormatter.kt` | `lib/src/formatter/i_value_formatter.dart` | 40 | P0 |
| `formatter/IndexAxisValueFormatter.kt` | `lib/src/formatter/index_axis_value_formatter.dart` | 25 | P0 |
| `formatter/LargeValueFormatter.kt` | `lib/src/formatter/large_value_formatter.dart` | 56 | P0 |
| `formatter/PercentFormatter.kt` | `lib/src/formatter/percent_formatter.dart` | 26 | P0 |
| `formatter/StackedValueFormatter.kt` | `lib/src/formatter/stacked_value_formatter.dart` | 51 | P0 |
| `highlight/BarHighlighter.kt` | `lib/src/highlight/bar_highlighter.dart` | 104 | P1-A |
| `highlight/ChartHighlighter.kt` | `lib/src/highlight/chart_highlighter.dart` | 157 | P0 |
| `highlight/CombinedHighlighter.kt` | `lib/src/highlight/combined_highlighter.dart` | 81 | P2 |
| `highlight/Highlight.kt` | `lib/src/highlight/highlight.dart` | 137 | P0 |
| `highlight/HighlightLineSpan.kt` | `lib/src/highlight/highlight_line_span.dart` | 17 | P0 |
| `highlight/HorizontalBarHighlighter.kt` | `lib/src/highlight/horizontal_bar_highlighter.dart` | 58 | P1-A |
| `highlight/IHighlighter.kt` | `lib/src/highlight/i_highlighter.dart` | 16 | P0 |
| `highlight/PieHighlighter.kt` | `lib/src/highlight/pie_highlighter.dart` | 18 | P1-C |
| `highlight/PieRadarHighlighter.kt` | `lib/src/highlight/pie_radar_highlighter.dart` | 42 | P1-C |
| `highlight/RadarHighlighter.kt` | `lib/src/highlight/radar_highlighter.dart` | 67 | P1-C |
| `highlight/Range.kt` | `lib/src/highlight/range.dart` | 21 | P0 |
| `interfaces/dataprovider/BarDataProvider.kt` | `lib/src/interfaces/dataprovider/bar_data_provider.dart` | 22 | P1-A |
| `interfaces/dataprovider/BarLineScatterCandleBubbleDataProvider.kt` | `lib/src/interfaces/dataprovider/bar_line_scatter_candle_bubble_data_provider.dart` | 35 | P0 |
| `interfaces/dataprovider/BubbleDataProvider.kt` | `lib/src/interfaces/dataprovider/bubble_data_provider.dart` | 13 | P1-B |
| `interfaces/dataprovider/CandleDataProvider.kt` | `lib/src/interfaces/dataprovider/candle_data_provider.dart` | 13 | P1-B |
| `interfaces/dataprovider/ChartInterface.kt` | `lib/src/interfaces/dataprovider/chart_interface.dart` | 52 | P0 |
| `interfaces/dataprovider/CombinedDataProvider.kt` | `lib/src/interfaces/dataprovider/combined_data_provider.dart` | 13 | P2 |
| `interfaces/dataprovider/LineDataProvider.kt` | `lib/src/interfaces/dataprovider/line_data_provider.dart` | 17 | P0 |
| `interfaces/dataprovider/ScatterDataProvider.kt` | `lib/src/interfaces/dataprovider/scatter_data_provider.dart` | 13 | P1-B |
| `interfaces/datasets/IBarDataSet.kt` | `lib/src/interfaces/datasets/i_bar_data_set.dart` | 46 | P1-A |
| `interfaces/datasets/IBarLineScatterCandleBubbleDataSet.kt` | `lib/src/interfaces/datasets/i_bar_line_scatter_candle_bubble_data_set.dart` | 12 | P0 |
| `interfaces/datasets/IBubbleDataSet.kt` | `lib/src/interfaces/datasets/i_bubble_data_set.dart` | 24 | P1-B |
| `interfaces/datasets/ICandleDataSet.kt` | `lib/src/interfaces/datasets/i_candle_data_set.dart` | 46 | P1-B |
| `interfaces/datasets/IDataSet.kt` | `lib/src/interfaces/datasets/i_data_set.dart` | 199 | P0 |
| `interfaces/datasets/ILineDataSet.kt` | `lib/src/interfaces/datasets/i_line_data_set.dart` | 57 | P0 |
| `interfaces/datasets/ILineRadarDataSet.kt` | `lib/src/interfaces/datasets/i_line_radar_data_set.dart` | 28 | P0 |
| `interfaces/datasets/ILineScatterCandleRadarDataSet.kt` | `lib/src/interfaces/datasets/i_line_scatter_candle_radar_data_set.dart` | 29 | P0 |
| `interfaces/datasets/IPieDataSet.kt` | `lib/src/interfaces/datasets/i_pie_data_set.dart` | 52 | P1-C |
| `interfaces/datasets/IRadarDataSet.kt` | `lib/src/interfaces/datasets/i_radar_data_set.dart` | 37 | P1-C |
| `interfaces/datasets/IScatterDataSet.kt` | `lib/src/interfaces/datasets/i_scatter_data_set.dart` | 25 | P1-B |
| `jobs/AnimatedMoveViewJob.kt` | `lib/src/jobs/animated_move_view_job.dart` | 91 | P0 |
| `jobs/AnimatedViewPortJob.kt` | `lib/src/jobs/animated_view_port_job.dart` | 103 | P0 |
| `jobs/AnimatedZoomJob.kt` | `lib/src/jobs/animated_zoom_job.dart` | 146 | P0 |
| `jobs/MoveViewJob.kt` | `lib/src/jobs/move_view_job.dart` | 74 | P0 |
| `jobs/ViewPortJob.kt` | `lib/src/jobs/view_port_job.dart` | 49 | P0 |
| `jobs/ZoomJob.kt` | `lib/src/jobs/zoom_job.dart` | 113 | P0 |
| `listener/BarLineChartTouchListener.kt` | `lib/src/listener/bar_line_chart_touch_listener.dart` | 464 | P0 |
| `listener/ChartTouchListener.kt` | `lib/src/listener/chart_touch_listener.dart` | 97 | P0 |
| `listener/OnChartGestureListener.kt` | `lib/src/listener/on_chart_gesture_listener.dart` | 61 | P0 |
| `listener/OnChartValueSelectedListener.kt` | `lib/src/listener/on_chart_value_selected_listener.dart` | 28 | P0 |
| `listener/PieRadarChartTouchListener.kt` | `lib/src/listener/pie_radar_chart_touch_listener.dart` | 234 | P1-C |
| `renderer/AxisRenderer.kt` | `lib/src/renderer/axis_renderer.dart` | 236 | P0 |
| `renderer/BarChartRenderer.kt` | `lib/src/renderer/bar_chart_renderer.dart` | 547 | P1-A |
| `renderer/BarLineScatterCandleBubbleRenderer.kt` | `lib/src/renderer/bar_line_scatter_candle_bubble_renderer.dart` | 228 | P0 |
| `renderer/BubbleChartRenderer.kt` | `lib/src/renderer/bubble_chart_renderer.dart` | 306 | P1-B |
| `renderer/CandleStickChartRenderer.kt` | `lib/src/renderer/candle_stick_chart_renderer.dart` | 323 | P1-B |
| `renderer/CombinedChartRenderer.kt` | `lib/src/renderer/combined_chart_renderer.dart` | 122 | P2 |
| `renderer/DataRenderer.kt` | `lib/src/renderer/data_renderer.dart` | 140 | P0 |
| `renderer/HorizontalBarChartRenderer.kt` | `lib/src/renderer/horizontal_bar_chart_renderer.dart` | 394 | P1-A |
| `renderer/LegendRenderer.kt` | `lib/src/renderer/legend_renderer.dart` | 352 | P0 |
| `renderer/LineChartRenderer.kt` | `lib/src/renderer/line_chart_renderer.dart` | 879 | P0 |
| `renderer/LineRadarRenderer.kt` | `lib/src/renderer/line_radar_renderer.dart` | 44 | P0 |
| `renderer/LineScatterCandleRadarRenderer.kt` | `lib/src/renderer/line_scatter_candle_radar_renderer.dart` | 61 | P0 |
| `renderer/PieChartRenderer.kt` | `lib/src/renderer/pie_chart_renderer.dart` | 994 | P1-C |
| `renderer/PointReducer.kt` | `lib/src/renderer/point_reducer.dart` | 228 | P0 |
| `renderer/RadarChartRenderer.kt` | `lib/src/renderer/radar_chart_renderer.dart` | 444 | P1-C |
| `renderer/Renderer.kt` | `lib/src/renderer/renderer.dart` | 10 | P0 |
| `renderer/ScatterChartRenderer.kt` | `lib/src/renderer/scatter_chart_renderer.dart` | 153 | P1-B |
| `renderer/XAxisRenderer.kt` | `lib/src/renderer/x_axis_renderer.dart` | 411 | P0 |
| `renderer/XAxisRendererHorizontalBarChart.kt` | `lib/src/renderer/x_axis_renderer_horizontal_bar_chart.dart` | 278 | P1-A |
| `renderer/XAxisRendererRadarChart.kt` | `lib/src/renderer/x_axis_renderer_radar_chart.dart` | 57 | P1-C |
| `renderer/YAxisRenderer.kt` | `lib/src/renderer/y_axis_renderer.dart` | 344 | P0 |
| `renderer/YAxisRendererHorizontalBarChart.kt` | `lib/src/renderer/y_axis_renderer_horizontal_bar_chart.dart` | 270 | P1-A |
| `renderer/YAxisRendererRadarChart.kt` | `lib/src/renderer/y_axis_renderer_radar_chart.dart` | 193 | P1-C |
| `renderer/scatter/ChevronDownShapeRenderer.kt` | `lib/src/renderer/scatter/chevron_down_shape_renderer.dart` | 24 | P1-B |
| `renderer/scatter/ChevronUpShapeRenderer.kt` | `lib/src/renderer/scatter/chevron_up_shape_renderer.dart` | 24 | P1-B |
| `renderer/scatter/CircleShapeRenderer.kt` | `lib/src/renderer/scatter/circle_shape_renderer.dart` | 42 | P1-B |
| `renderer/scatter/CrossShapeRenderer.kt` | `lib/src/renderer/scatter/cross_shape_renderer.dart` | 23 | P1-B |
| `renderer/scatter/IShapeRenderer.kt` | `lib/src/renderer/scatter/i_shape_renderer.dart` | 22 | P1-B |
| `renderer/scatter/SquareShapeRenderer.kt` | `lib/src/renderer/scatter/square_shape_renderer.dart` | 61 | P1-B |
| `renderer/scatter/TriangleShapeRenderer.kt` | `lib/src/renderer/scatter/triangle_shape_renderer.dart` | 67 | P1-B |
| `renderer/scatter/XShapeRenderer.kt` | `lib/src/renderer/scatter/x_shape_renderer.dart` | 23 | P1-B |
| `utils/ColorTemplate.kt` | `lib/src/utils/color_template.dart` | 94 | P0 |
| `utils/EntryXComparator.kt` | `lib/src/utils/entry_x_comparator.dart` | 15 | P0 |
| `utils/FSize.kt` | `lib/src/utils/f_size.dart` | 59 | P0 |
| `utils/FileUtils.kt` | `lib/src/utils/file_utils.dart` | 124 | P0 |
| `utils/Fill.kt` | `lib/src/utils/fill.dart` | 218 | P0 |
| `utils/HorizontalViewPortHandler.kt` | `lib/src/utils/horizontal_view_port_handler.dart` | 4 | P1-A |
| `utils/MPPointD.kt` | `lib/src/utils/mp_point_d.dart` | 52 | P0 |
| `utils/MPPointF.kt` | `lib/src/utils/mp_point_f.dart` | 60 | P0 |
| `utils/ObjectPool.kt` | `lib/src/utils/object_pool.dart` | 181 | P0 |
| `utils/Transformer.kt` | `lib/src/utils/transformer.dart` | 233 | P0 |
| `utils/TransformerHorizontalBarChart.kt` | `lib/src/utils/transformer_horizontal_bar_chart.dart` | 21 | P1-A |
| `utils/Utils.kt` | `lib/src/utils/utils.dart` | 543 | P0 |
| `utils/ViewPortHandler.kt` | `lib/src/utils/view_port_handler.dart` | 512 | P0 |

By lane:

| Lane | Files | Kotlin lines |
|---|---:|---:|
| P0 | 84 | 12783 |
| P1-A | 18 | 2904 |
| P1-B | 28 | 1664 |
| P1-C | 19 | 3414 |
| P2 | 6 | 598 |

