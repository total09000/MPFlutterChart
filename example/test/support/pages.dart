// What the page tests under test/pages/ share: showing a page, reaching its chart, its options menu and its seek
// bars, and an asset bundle that reads the example's assets without leaving the test's fake clock.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide Easing;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/notimportant/demo_base.dart';

/// Shows [page] alone, as the home list would push it, on a surface of [size] logical pixels with the example's
/// assets from [TestAssetBundle]. One frame is pumped; a test settles animations itself.
Future<void> pumpPage(WidgetTester tester, Widget page, {Size size = const Size(800, 1600)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    DefaultAssetBundle(
      bundle: TestAssetBundle(),
      child: MaterialApp(home: page),
    ),
  );
  await tester.pump();
}

/// The example's assets, read from the `assets/` folder with `dart:io`. `rootBundle` decodes a big text asset on
/// another isolate, which never completes on the fake clock of `testWidgets`; this bundle completes in microtasks.
/// Tests run with the example folder as their working directory.
class TestAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(File(key).readAsBytesSync());

  @override
  Future<String> loadString(String key, {bool cache = true}) async => utf8.decode(File(key).readAsBytesSync());
}

/// The host widgets of the charts the page shows, in tree order.
Finder get chartHosts => find.byWidgetPredicate((widget) => widget is ChartHostWidget);

/// The core chart of the [index]th chart host of the page.
C chartOf<C extends Chart>(WidgetTester tester, [int index = 0]) =>
    tester.widget<ChartHostWidget>(chartHosts.at(index)).chart as C;

/// Every y value of [data], set by set.
List<double> ysOf(ChartData data) => [
  for (final set in data.dataSets)
    for (var i = 0; i < set.entryCount; i++) set.getEntryForIndex(i).y,
];

/// Opens the options menu of the page and returns the titles of its items in order. The menu stays open.
Future<List<String>> openMenu(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.more_vert));
  await tester.pumpAndSettle();
  return [
    for (final item in tester.widgetList<PopupMenuItem<DemoMenuItem>>(find.byType(PopupMenuItem<DemoMenuItem>)))
      item.value!.title,
  ];
}

/// The titles of the options menu of the page, in order; the menu is closed again.
Future<List<String>> menuTitles(WidgetTester tester) async {
  final titles = await openMenu(tester);
  await tester.tapAt(const Offset(1, 1));
  await tester.pumpAndSettle();
  return titles;
}

/// Chooses the item titled [title] from the options menu of the page. With [settle] the animations the item starts
/// run to their end; pass false on a page that never settles (a timer, a repeating animation) and pump yourself.
Future<void> selectMenuItem(WidgetTester tester, String title, {bool settle = true}) async {
  await tester.tap(find.byIcon(Icons.more_vert));
  // The popup's own route animation, which ends even on a page that never settles.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  final item = find.widgetWithText(PopupMenuItem<DemoMenuItem>, title);
  await tester.ensureVisible(item);
  await tester.pump();
  await tester.tap(item);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  if (settle) await tester.pumpAndSettle();
}

/// Moves the [index]th seek bar of the page to [progress], as a drag by the user does.
Future<void> setSeekBar(WidgetTester tester, int index, int progress) async {
  tester.widget<Slider>(find.byType(Slider).at(index)).onChanged!(progress.toDouble());
  await tester.pump();
}

/// The progress of every seek bar of the page, in order.
List<int> seekBars(WidgetTester tester) => [
  for (final slider in tester.widgetList<Slider>(find.byType(Slider))) slider.value.round(),
];
