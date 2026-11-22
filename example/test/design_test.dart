// The "All chart types" pages: MPChartExample's DesignActivity and the cards of DesignCharts but the combined one,
// in the Nightfall style. The seeded data is checked against fixtures/design_random.json, the JVM's
// kotlin.random numbers.
import 'dart:convert';
import 'dart:io';

// Material has its own `Easing`; the chart's is MPAndroidChart's Easing.
import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/core.dart';
import 'package:mp_flutter_chart/mp_flutter_chart.dart' show ChartHostWidget;
import 'package:mp_flutter_chart_example/custom/pill_marker_view.dart';
import 'package:mp_flutter_chart_example/design/android_metrics.dart';
import 'package:mp_flutter_chart_example/design/design_charts.dart';
import 'package:mp_flutter_chart_example/design/nightfall.dart';
import 'package:mp_flutter_chart_example/main.dart';
import 'package:mp_flutter_chart_example/pages/design_page.dart';

import 'support/baseline.dart';
import 'support/strict_canvas.dart';

final Map<String, dynamic> _truth =
    jsonDecode(File('test/fixtures/design_random.json').readAsStringSync())
        as Map<String, dynamic>;

/// The JVM's `nextInt(from, until)` results for one entry, as ints.
List<int> _ints(Object? row) => [for (final v in row! as List) v as int];

/// Kotlin's `sortedBy`, which is stable, written as an insertion sort: [list] ordered by [key], ties in list order.
List<T> _stableSortedBy<T>(List<T> list, double Function(T) key) {
  final out = <T>[];
  for (final e in list) {
    var i = out.length;
    while (i > 0 && key(out[i - 1]) > key(e)) {
      i--;
    }
    out.insert(i, e);
  }
  return out;
}

/// The entries of the only data set of [chart], or of data set [index].
List<Entry> _entries(Chart chart, [int index = 0]) {
  final set = chart.data!.getDataSetByIndex(index)!;
  return [for (var i = 0; i < set.entryCount; i++) set.getEntryForIndex(i)];
}

/// The cards of DesignCharts.all, Kotlin's without the combined card: (title, subtitle, delta, chart class).
const List<(String, String, String?, Type)> _cards = [
  ('Revenue', 'Monthly, in k€', '+9.4%', LineChart),
  ('Orders per quarter', '2025 to 2026', null, BarChart),
  ('Budget', 'Share of monthly spend', null, HorizontalBarChart),
  ('Sessions by platform', 'Last 30 days', null, PieChart),
  ('Spend by category', 'Stacked, in k€', null, BarChart),
  ('ACME Corp', '5 min candles', '+2.1%', CandleStickChart),
  ('Team profile', 'Skills, 0 to 100', null, RadarChart),
  ('Deal size', 'By probability', null, BubbleChart),
  ('Samples', 'Three data sets', null, ScatterChart),
  ('Traffic', 'Full width, no side padding', null, LineChart),
];

/// The chart hosts on screen, top to bottom.
List<Chart> _shownCharts(WidgetTester tester) => [
  for (final widget in tester.widgetList<ChartHostWidget>(
    find.byWidgetPredicate((widget) => widget is ChartHostWidget),
  ))
    widget.chart,
];

/// The card titles on screen, top to bottom.
List<String> _shownTitles(WidgetTester tester) {
  final titles = [for (final (title, _, _, _) in _cards) title];
  final shown = [
    for (final title in titles)
      if (find.text(title).evaluate().isNotEmpty) title,
  ];
  shown.sort(
    (a, b) => tester
        .getTopLeft(find.text(a))
        .dy
        .compareTo(tester.getTopLeft(find.text(b)).dy),
  );
  return shown;
}

/// The style [text] is drawn with: the enclosing DefaultTextStyle merged with the Text's own, as Text.build does.
TextStyle _effectiveStyle(WidgetTester tester, String text) {
  final finder = find.text(text);
  return DefaultTextStyle.of(
    tester.element(finder),
  ).style.merge(tester.widget<Text>(finder).style);
}

/// The Pixel 8 emulator of the C2 comparison walk: 420 dpi, 2.625 px per dp, 1080 × 2400 px.
const double _dpr = 2.625;

/// Lays the test view out as the Pixel 8 emulator's screen.
void _usePixel8(WidgetTester tester) {
  tester.view.devicePixelRatio = _dpr;
  tester.view.physicalSize = const Size(1080, 2400);
  addTearDown(tester.view.reset);
}

/// [rect], in logical px, in device px.
Rect _px(Rect rect) => Rect.fromLTRB(
  rect.left * _dpr,
  rect.top * _dpr,
  rect.right * _dpr,
  rect.bottom * _dpr,
);

/// Expects [rect] (device px) to be [expected], to floating-point accuracy.
void _expectPx(Rect rect, Rect expected, String reason) {
  expect(rect.left, closeTo(expected.left, 1e-6), reason: '$reason left');
  expect(rect.top, closeTo(expected.top, 1e-6), reason: '$reason top');
  expect(rect.right, closeTo(expected.right, 1e-6), reason: '$reason right');
  expect(rect.bottom, closeTo(expected.bottom, 1e-6), reason: '$reason bottom');
}

/// The cards' backgrounds (design_card.xml's root), top to bottom: the DecoratedBox inside the card's margin.
Finder _cardBoxes(NightfallTheme theme) => find.byWidgetPredicate(
  (widget) =>
      widget is DecoratedBox &&
      widget.decoration is BoxDecoration &&
      (widget.decoration as BoxDecoration).color == theme.card,
);

/// The TextView that shows [text].
Finder _textView(String text) =>
    find.ancestor(of: find.text(text), matching: find.byType(AndroidTextView));

/// Expects [text] to be a TextView of [sp]: its text size and line box from [AndroidTextView], bold or not, no letter
/// spacing, and no line height of its own.
void _expectTextView(
  WidgetTester tester,
  String text, {
  required double sp,
  required bool bold,
  required Color color,
}) {
  expect(tester.widget<AndroidTextView>(_textView(text)).sp, sp, reason: text);
  final style = _effectiveStyle(tester, text);
  expect(
    style.fontSize,
    androidTextSize(sp, tester.view.devicePixelRatio),
    reason: text,
  );
  expect(
    style.fontWeight ?? FontWeight.normal,
    bold ? FontWeight.bold : FontWeight.normal,
    reason: text,
  );
  expect(style.letterSpacing ?? 0, 0, reason: text);
  expect(style.wordSpacing ?? 0, 0, reason: text);
  // The line box is AndroidTextView's, so the text keeps Flutter's natural line inside it.
  expect(style.height, isNull, reason: text);
  expect(style.color, color, reason: text);
}

String _appBarTitle(WidgetTester tester) =>
    (tester.widget<AppBar>(find.byType(AppBar)).title! as Text).data!;

void main() {
  group('Nightfall', () {
    test('the constants the T16 pages use are Nightfall.kt\'s dark values', () {
      const dark = Nightfall.dark;
      expect(dark.isDark, isTrue);
      expect(dark.stage, Nightfall.stage);
      expect(dark.card, Nightfall.card);
      expect(dark.text, Nightfall.text);
      expect(dark.muted, Nightfall.muted);
      expect(dark.grid, Nightfall.grid);
      expect(dark.track, Nightfall.track);
      expect(dark.pillBackground, Nightfall.pillBackground);
      expect(dark.pillText, Nightfall.pillText);
      expect(Nightfall.palette, const [
        Color(0xFF2FB4B6),
        Color(0xFFF97066),
        Color(0xFFF5B041),
        Color(0xFF8B7CF6),
        Color(0xFF5DD39E),
      ]);
    });

    test('the light variant has Nightfall.kt\'s values', () {
      const light = Nightfall.light;
      expect(light.isDark, isFalse);
      expect(light.stage, const Color(0xFFF8FAFC));
      expect(light.card, const Color(0xFFFFFFFF));
      expect(light.text, const Color(0xFF0F172A));
      expect(light.muted, const Color(0xFF64748B));
      expect(light.grid, const Color(0xFFE2E8F0));
      expect(light.track, const Color(0xFFEEF2F7));
      expect(light.pillBackground, const Color(0xFF0F172A));
      expect(light.pillText, const Color(0xFFFFFFFF));
    });

    test('withAlpha replaces the alpha and keeps the colour', () {
      expect(
        Nightfall.withAlpha(Nightfall.green, 30),
        const Color.fromARGB(30, 0x5D, 0xD3, 0x9E),
      );
      expect(
        Nightfall.withAlpha(Nightfall.grid, 255),
        const Color.fromARGB(255, 148, 163, 184),
      );
    });
  });

  group('DesignCharts', () {
    for (final theme in [Nightfall.dark, Nightfall.light]) {
      final variant = theme.isDark ? 'dark' : 'light';

      test('all() has the cards in Kotlin\'s order, without the combined '
          'card ($variant)', () {
        final cards = DesignCharts.all(
          theme,
          devicePixelRatio: _dpr,
          textScaler: TextScaler.noScaling,
        );
        expect([
          for (final card in cards)
            (card.title, card.subtitle, card.delta, card.chart.runtimeType),
        ], _cards);
      });

      test('every card draws on a strict canvas ($variant)', () {
        for (final card in DesignCharts.all(
          theme,
          devicePixelRatio: _dpr,
          textScaler: TextScaler.noScaling,
        )) {
          final canvas = StrictCanvas();
          addTearDown(canvas.dispose);
          card.chart.onSizeChanged(360, 230);
          card.chart.onDraw(canvas);

          expect(canvas.paragraphs, isNotEmpty, reason: card.title);
          final pills = [
            for (final draw in canvas.rrects)
              if (draw.color.toARGB32() == theme.pillBackground.toARGB32())
                draw,
          ];
          // Only the line and the bar card highlight a value, so only they show the pill marker. The pie and the
          // radar card, like Kotlin's, set no marker and draw no pill.
          expect(
            pills,
            hasLength(
              card.title == 'Revenue' || card.title == 'Orders per quarter'
                  ? 1
                  : 0,
            ),
            reason: card.title,
          );
          switch (card.title) {
            case 'Deal size':
              expect(canvas.circles, hasLength(16));
            case 'Samples':
              expect(canvas.circles, hasLength(45));
            case 'Sessions by platform' || 'Team profile':
              expect(card.chart.marker, isNull, reason: card.title);
          }
        }
      });
    }

    test('the line and the bar card highlight their selected value with a '
        'pill', () {
      final cards = DesignCharts.all(
        Nightfall.dark,
        devicePixelRatio: _dpr,
        textScaler: TextScaler.noScaling,
      );
      final line = cards[0].chart;
      final bar = cards[1].chart;
      expect(line.highlighted.single.x, 9);
      expect(bar.highlighted.single.x, 5);
      expect(line.marker, isA<PillMarkerView>());
      expect(bar.marker, isA<PillMarkerView>());

      final marker = line.marker! as PillMarkerView;
      final e = line.data!.getEntryForHighlight(line.highlighted.single)!;
      marker.refreshContent(e, line.highlighted.single);
      expect(marker.text, 'Oct · 92');
      final barMarker = bar.marker! as PillMarkerView;
      barMarker.refreshContent(
        bar.data!.getEntryForHighlight(bar.highlighted.single)!,
        bar.highlighted.single,
      );
      expect(barMarker.text, '82');
    });

    test('the radar card keeps its custom 0 to 100 range: rings at 0, 30, 60 '
        'and 90, the web ending at 100', () {
      // Deliberate deviation: a custom limit is kept and no entry lies beyond it. Four labels
      // over 0 .. 100 are 30 apart (roundToNextSignificant(25)); Kotlin adds a fifth, 120, writes it into the custom
      // maximum, and grows the maximum on every notifyDataSetChanged.
      final chart = DesignCharts.radar(Nightfall.dark).chart as RadarChart;
      final y = chart.yAxis;
      void expectKept(String when) {
        expect(y.isAxisMaxCustom, isTrue, reason: when);
        expect(y.axisMinimum, 0, reason: when);
        expect(y.axisMaximum, 100, reason: when);
        final rings = y.entries.sublist(0, y.entryCount);
        expect(rings, [0, 30, 60, 90], reason: when);
        expect(chart.yChartMax, 100, reason: when);
        expect(chart.yRange, 100, reason: when);
      }

      // Chart.kt:1037: a size change calls notifyDataSetChanged.
      chart.onSizeChanged(360, 230);
      expectKept('after the first layout');
      chart.notifyDataSetChanged();
      chart.notifyDataSetChanged();
      expectKept('after two more notifyDataSetChanged calls');
    });

    test('the candle card is the walk from 118 that the JVM numbers give', () {
      final chart = DesignCharts.candle(Nightfall.dark).chart;
      var price = 118.0;
      final expected = <(double, double, double, double, double)>[];
      for (final (i, row) in (_truth['candle_seed11'] as List).indexed) {
        final [delta, up, down] = _ints(row);
        final open = price;
        final close = open + delta;
        final high = (open > close ? open : close) + up;
        final low = (open < close ? open : close) - down;
        price = close;
        expected.add((i.toDouble(), high, low, open, close));
      }
      expect(expected.first, (0.0, 129.0, 114.0, 118.0, 127.0));
      expect([
        for (final e in _entries(chart).cast<CandleEntry>())
          (e.x, e.high, e.low, e.open, e.close),
      ], expected);
    });

    test('the bubble card is the JVM numbers sorted by x, ties kept in '
        'order', () {
      final chart = DesignCharts.bubble(Nightfall.dark).chart;
      final drawn = [
        for (final row in _truth['bubble_seed5'] as List)
          (
            _ints(row)[0] / 10,
            _ints(row)[1].toDouble(),
            _ints(row)[2].toDouble(),
          ),
      ];
      final expected = _stableSortedBy(drawn, (e) => e.$1);
      // x 4.1, 2.3 and 0.6 come twice; the earlier draw stays first.
      expect(expected.where((e) => e.$1 == 4.1), [
        (4.1, 41.0, 31.0),
        (4.1, 30.0, 15.0),
      ]);
      expect([
        for (final e in _entries(chart).cast<BubbleEntry>()) (e.x, e.y, e.size),
      ], expected);
    });

    test('the scatter card is the JVM numbers, each set sorted by x with '
        'ties kept in order', () {
      final chart = DesignCharts.scatter(Nightfall.dark).chart;
      final sets = _truth['scatter_seed3'] as List;
      expect(chart.data!.dataSetCount, 3);
      for (final (index, set) in sets.indexed) {
        final expected = _stableSortedBy([
          for (final row in set as List)
            (_ints(row)[0] / 10, _ints(row)[1].toDouble()),
        ], (e) => e.$1);
        expect(
          [for (final e in _entries(chart, index)) (e.x, e.y)],
          expected,
          reason: 'set $index',
        );
      }
      expect(
        [for (final e in _entries(chart)) (e.x, e.y)].where((e) => e.$1 == 4.3),
        [(4.3, 65.0), (4.3, 83.0)],
      );
    });
  });

  group('PillMarkerView', () {
    /// tvPill's text, 12sp bold, as the marker lays it out at [dpr].
    TextPainter label(String text, NightfallTheme theme, double dpr) =>
        TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              color: theme.pillText,
              fontSize: androidTextSize(12, dpr),
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

    test('is the label with marker_pill.xml\'s padding in whole device px, '
        'centred 14 dp above the point', () {
      final marker = PillMarkerView(
        Nightfall.dark,
        (e) => '${e.y.round()}',
        devicePixelRatio: _dpr,
        textScaler: TextScaler.noScaling,
      );
      marker.refreshContent(Entry(x: 0, y: 42), Highlight(0, 42, 0));
      final text = label('42', Nightfall.dark, _dpr);
      addTearDown(text.dispose);

      // paddingHorizontal 10dp = 26 px, paddingVertical 6dp = 16 px, and the 12sp line is 43 px: 16 + 43 + 16 = 75.
      // wrap_content: the text's width rounded up to a whole px, plus the padding.
      expect(
        marker.width,
        closeTo(androidTextViewWidth(text.width, _dpr) + 2 * 26 / _dpr, 1e-9),
      );
      expect(
        marker.width * _dpr,
        closeTo((marker.width * _dpr).roundToDouble(), 1e-9),
      );
      expect(marker.height * _dpr, closeTo(75, 1e-9));
      expect(marker.offset.x, closeTo(-marker.width / 2, 1e-9));
      // Utils.convertDpToPixel(14f) is a float, not rounded to a whole px.
      expect(marker.offset.y, closeTo(-marker.height - 14, 1e-9));
    });

    test('is laid out in whole px of its own density', () {
      final marker = PillMarkerView(
        Nightfall.dark,
        (e) => '${e.y.round()}',
        devicePixelRatio: 3.5,
        textScaler: TextScaler.noScaling,
      );
      // 6dp = 21 px; 12sp = 42 px, top floor(-44.36) = -45, bottom ceil(11.38) = 12: 21 + 57 + 21 = 99.
      expect(marker.height * 3.5, closeTo(99, 1e-9));
    });

    test('follows the system font size, as its sp text size does', () {
      final marker = PillMarkerView(
        Nightfall.dark,
        (e) => '${e.y.round()}',
        devicePixelRatio: _dpr,
        textScaler: const TextScaler.linear(1.3),
      );
      marker.refreshContent(Entry(x: 0, y: 42), Highlight(0, 42, 0));
      final canvas = StrictCanvas();
      addTearDown(canvas.dispose);
      marker.draw(canvas, 100, 100);

      // 12sp × 1.3 = 41 px, a 56 px line with its baseline 44 px down; the padding stays 16 px: 16 + 56 + 16 = 88.
      expect(marker.height * _dpr, closeTo(88, 1e-9));
      // The test font draws each glyph one em wide: two 41 px glyphs and 2 × 26 px of padding.
      expect(marker.width * _dpr, closeTo(2 * 41 + 2 * 26, 1e-9));
      // The text is drawn at 41 px with its baseline 16 + 44 px below the pill's top.
      final text = TextPainter(
        text: TextSpan(
          text: '42',
          style: TextStyle(fontSize: 41 / _dpr, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      addTearDown(text.dispose);
      expect(
        canvas.paragraphs.single.dy +
            text.computeDistanceToActualBaseline(TextBaseline.alphabetic),
        closeTo((16 + 44) / _dpr, 1e-9),
      );
    });

    for (final theme in [Nightfall.dark, Nightfall.light]) {
      test('draws a pill with 8 dp corners in the theme\'s pill colours '
          '(${theme.isDark ? 'dark' : 'light'})', () {
        final marker = PillMarkerView(
          theme,
          (e) => 'Oct · ${e.y.round()}',
          devicePixelRatio: _dpr,
          textScaler: TextScaler.noScaling,
        );
        marker.refreshContent(Entry(x: 9, y: 92), Highlight(9, 92, 0));
        final text = label('Oct · 92', theme, _dpr);
        addTearDown(text.dispose);
        final canvas = StrictCanvas();
        addTearDown(canvas.dispose);
        marker.draw(canvas, 100, 100);

        final pill = canvas.rrects.single;
        // A Paint keeps its colour in 32-bit floats, so compare the ARGB values.
        expect(pill.color.toARGB32(), theme.pillBackground.toARGB32());
        expect(pill.rrect.left, 0);
        expect(pill.rrect.top, 0);
        expect(pill.rrect.width, closeTo(marker.width, 1e-9));
        expect(pill.rrect.height, closeTo(marker.height, 1e-9));
        expect(pill.rrect.tlRadiusX, 8);
        expect(pill.rrect.brRadiusY, 8);
        // The text starts after the 26 px padding, with its baseline 16 + 34 px below the pill's top.
        final at = canvas.paragraphs.single;
        expect(at.dx * _dpr, closeTo(26, 1e-9));
        expect(
          at.dy + text.computeDistanceToActualBaseline(TextBaseline.alphabetic),
          closeTo((16 + 34) / _dpr, 1e-9),
        );
      });
    }
  });

  group('DesignPage', () {
    test('shows the cards DesignActivity\'s only and from extras select', () {
      const cards = [0, 1, 2, 3, 4, 5, 6, 7];
      expect(DesignPage.shown(cards, only: -1, from: 0), cards);
      expect(DesignPage.shown(cards, only: 1, from: 0), [1]);
      expect(DesignPage.shown(cards, only: 7, from: 0), [7]);
      // only wins over from.
      expect(DesignPage.shown(cards, only: 2, from: 5), [2]);
      // An only outside the cards falls back to from.
      expect(DesignPage.shown(cards, only: 8, from: 0), cards);
      expect(DesignPage.shown(cards, only: 8, from: 3), [3, 4, 5, 6, 7]);
      expect(DesignPage.shown(cards, only: -2, from: 6), [6, 7]);
      // from is clamped to the cards, so at least the last one shows.
      expect(DesignPage.shown(cards, only: -1, from: 20), [7]);
      expect(DesignPage.shown(cards, only: -1, from: -5), cards);
    });

    for (final dark in [true, false]) {
      final theme = dark ? Nightfall.dark : Nightfall.light;
      final variant = dark ? 'dark' : 'light';

      testWidgets('the $variant page shows every card on the stage colour', (
        tester,
      ) async {
        await tester.pumpWidget(MaterialApp(home: DesignPage(dark: dark)));
        await tester.pump();

        expect(_appBarTitle(tester), 'All chart types, $variant');
        expect(
          tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
          theme.stage,
        );
        expect(_shownTitles(tester), [for (final (t, _, _, _) in _cards) t]);
        expect(
          [for (final chart in _shownCharts(tester)) chart.runtimeType],
          [for (final (_, _, _, type) in _cards) type],
        );
        for (final (_, subtitle, delta, _) in _cards) {
          final text = tester.widget<Text>(find.text(subtitle));
          expect(text.style!.color, theme.muted, reason: subtitle);
          if (delta != null) {
            expect(
              tester.widget<Text>(find.text(delta)).style!.color,
              Nightfall.green,
            );
          }
        }
        expect(find.text('+9.4%'), findsOneWidget);
        expect(find.text('+2.1%'), findsOneWidget);
        // The hosted line and bar charts keep their canvas marker.
        expect(_shownCharts(tester)[0].marker, isA<PillMarkerView>());
        expect(_shownCharts(tester)[1].marker, isA<PillMarkerView>());

        final host = find.byWidgetPredicate((w) => w is ChartHostWidget).first;
        expect(tester.getSize(host).height, 230);
        final decoration =
            tester.widget<DecoratedBox>(_cardBoxes(theme).first).decoration
                as BoxDecoration;
        expect(decoration.color, theme.card);
        expect(decoration.borderRadius, BorderRadius.circular(18));
        final border = decoration.border! as Border;
        expect(border.top.color, theme.grid);
        // setStroke(1, grid): one device pixel inside the card's bounds.
        expect(
          border.top.width * tester.view.devicePixelRatio,
          closeTo(1, 1e-12),
        );
        expect(border.top.strokeAlign, BorderSide.strokeAlignInside);
        expect(border.isUniform, isTrue);

        for (final (title, subtitle, delta, _) in _cards) {
          _expectTextView(tester, title, sp: 15, bold: true, color: theme.text);
          _expectTextView(
            tester,
            subtitle,
            sp: 12,
            bold: false,
            color: theme.muted,
          );
          if (delta != null) {
            _expectTextView(
              tester,
              delta,
              sp: 12,
              bold: true,
              color: Nightfall.green,
            );
          }
        }

        // DemoBase's action bar, Theme.AppCompat.Light.DarkActionBar's, with the shadow fitted to AppCompat's.
        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.backgroundColor, const Color(0xFF212121));
        expect(appBar.foregroundColor, const Color(0xFFFFFFFF));
        expect(appBar.elevation, 2.25);
        expect(appBar.scrolledUnderElevation, 2.25);
        expect(appBar.shadowColor, const Color(0x66000000));
        final title = _effectiveStyle(tester, 'All chart types, $variant');
        expect(title.fontSize, 20);
        expect(title.fontWeight, FontWeight.w500);
        expect(title.color, const Color(0xFFFFFFFF));
        expect(title.letterSpacing ?? 0, 0);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the $variant cards are laid out in whole device px as '
          'Android lays out design_card.xml', (tester) async {
        _usePixel8(tester);
        await tester.pumpWidget(MaterialApp(home: DesignPage(dark: dark)));
        await tester.pump();

        final appBarBottom = tester.getRect(find.byType(AppBar)).bottom * _dpr;
        expect(_cardBoxes(theme), findsNWidgets(_cards.length));
        final cards = [
          for (var i = 0; i < _cards.length; i++)
            _px(tester.getRect(_cardBoxes(theme).at(i))),
        ];

        // The cards container's padding is 12dp = 32 px; a card is 14dp + header + 10dp + 230dp + 14dp =
        // 37 + 96 + 26 + 604 + 37 = 800 px, with a 14dp = 37 px margin below it.
        _expectPx(
          cards[0],
          Rect.fromLTWH(32, appBarBottom + 32, 1080 - 2 * 32, 800),
          'card 1',
        );
        for (var i = 1; i < cards.length; i++) {
          _expectPx(
            cards[i],
            cards[i - 1].translate(0, 800 + 37),
            'card ${i + 1}',
          );
        }

        // Card 1, Revenue: the header row is the title (53 px) over the subtitle (43 px), next to the delta pill
        // (4dp = 11 px, a 43 px line, 11 px), at the card's 37 px padding.
        final card = cards[0];
        final title = _px(tester.getRect(_textView('Revenue')));
        final subtitle = _px(tester.getRect(_textView('Monthly, in k€')));
        final header = _px(
          tester.getRect(
            find.ancestor(of: _textView('Revenue'), matching: find.byType(Row)),
          ),
        );
        final pill = _px(
          tester.getRect(
            find
                .ancestor(
                  of: _textView('+9.4%'),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          ),
        );
        expect(title.top, closeTo(card.top + 37, 1e-6));
        expect(title.left, closeTo(card.left + 37, 1e-6));
        expect(title.height, closeTo(53, 1e-6));
        expect(subtitle.top, closeTo(title.bottom, 1e-6));
        expect(subtitle.height, closeTo(43, 1e-6));
        expect(header.top, closeTo(card.top + 37, 1e-6));
        expect(header.height, closeTo(96, 1e-6));
        expect(pill.top, closeTo(card.top + 37, 1e-6));
        expect(pill.right, closeTo(card.right - 37, 1e-6));
        expect(pill.height, closeTo(65, 1e-6));
        // wrap_content: the text's width rounded up to a whole px, inside the 8dp = 21 px side padding.
        final deltaText = _px(tester.getRect(_textView('+9.4%')));
        expect(deltaText.width, closeTo(deltaText.width.roundToDouble(), 1e-6));
        expect(pill.width, closeTo(deltaText.width + 2 * 21, 1e-6));
        expect(
          _px(tester.getRect(_textView('+9.4%'))).top,
          closeTo(pill.top + 11, 1e-6),
        );
        // The baselines sit -floor(fTop) below each line's top.
        for (final (text, baseline) in [
          ('Revenue', 42),
          ('Monthly, in k€', 34),
          ('+9.4%', 34),
        ]) {
          expect(
            baselineIn(tester, _textView(text)) * _dpr,
            closeTo(baseline, 1e-6),
            reason: text,
          );
        }

        // The chart container: 10dp = 26 px below the header, 230dp = 604 px high, at the card's 37 px padding.
        final chart = _px(
          tester.getRect(
            find.byWidgetPredicate((w) => w is ChartHostWidget).first,
          ),
        );
        _expectPx(
          chart,
          Rect.fromLTRB(
            card.left + 37,
            header.bottom + 26,
            card.right - 37,
            header.bottom + 26 + 604,
          ),
          'chart 1',
        );

        // setStroke(1, grid): one device pixel inside the card's whole-pixel bounds. The stroke is painted as the
        // ring between the card's bounds and the bounds one device px further in. (Under an opaque stroke, as in the
        // light variant, Flutter insets the card colour by half the stroke, which the stroke covers.) The corners
        // stay Utils.convertDpToPixel(18f), not rounded to a whole px.
        final cardBox = tester.renderObject<RenderBox>(_cardBoxes(theme).first);
        final bounds = BorderRadius.circular(
          18,
        ).toRRect(Offset.zero & cardBox.size);
        expect(
          cardBox,
          paints..drrect(
            outer: bounds,
            inner: bounds.deflate(1 / _dpr),
            color: theme.grid,
          ),
        );

        // The hosted markers are laid out at the page's density: 16 + 43 + 16 px.
        for (final chart in _shownCharts(tester).take(2)) {
          expect(
            (chart.marker! as PillMarkerView).height * _dpr,
            closeTo(75, 1e-9),
          );
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a density change builds the cards again at the new density, '
        'as Android recreates the activity', (tester) async {
      _usePixel8(tester);
      await tester.pumpWidget(const MaterialApp(home: DesignPage(dark: true)));
      await tester.pump();
      final before = _shownCharts(tester)[0];
      expect(
        (before.marker! as PillMarkerView).height * _dpr,
        closeTo(75, 1e-9),
      );

      tester.view.devicePixelRatio = 3.5;
      await tester.pump();
      final after = _shownCharts(tester)[0];
      expect(after, isNot(same(before)));
      // 6dp = 21 px and a 57 px line for 12sp at 3.5.
      expect((after.marker! as PillMarkerView).height * 3.5, closeTo(99, 1e-9));
      expect(after.highlighted.single.x, 9);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a change of the system font size builds the cards again with '
        'the marker text scaled, as Android recreates the activity', (
      tester,
    ) async {
      _usePixel8(tester);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(const MaterialApp(home: DesignPage(dark: true)));
      await tester.pump();
      final before = _shownCharts(tester)[0];
      expect(
        (before.marker! as PillMarkerView).height * _dpr,
        closeTo(75, 1e-9),
      );

      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      await tester.pump();
      final after = _shownCharts(tester)[0];
      expect(after, isNot(same(before)));
      // 12sp × 1.3 is a 56 px line: 16 + 56 + 16.
      for (final chart in _shownCharts(tester).take(2)) {
        expect(
          (chart.marker! as PillMarkerView).height * _dpr,
          closeTo(88, 1e-9),
        );
      }
      expect(after.highlighted.single.x, 9);
      expect(tester.takeException(), isNull);
    });

    // Densities that are not a multiple of 1/8, so 56dp is not a whole px: 450 dpi (157.5 px) and tvdpi (74.55 px).
    for (final (dpr, statusBar) in [
      (2.8125, 0.0),
      (2.8125, 74.0),
      (1.33125, 33.0),
    ]) {
      testWidgets('the action bar ends on a whole device px at $dpr with a '
          '${statusBar.toInt()} px status bar', (tester) async {
        tester.view.devicePixelRatio = dpr;
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.padding = FakeViewPadding(top: statusBar);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          const MaterialApp(home: DesignPage(dark: true)),
        );
        await tester.pump();

        // ?attr/actionBarSize, 56dp, read with getDimensionPixelSize: 158 px at 2.8125, 75 px at 1.33125.
        final appBarBottom = tester.getRect(find.byType(AppBar)).bottom * dpr;
        expect(
          appBarBottom,
          closeTo(statusBar + androidDimensionPixelSize(56, dpr), 1e-6),
        );
        // So the first card starts on a whole px too, the 12dp container padding below the bar.
        final cardTop = tester.getRect(_cardBoxes(Nightfall.dark).first).top;
        expect(
          cardTop * dpr,
          closeTo(appBarBottom + androidDimensionPixelSize(12, dpr), 1e-6),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the variant menu item swaps the page and keeps only', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: DesignPage(dark: true, only: 2, from: 5)),
      );
      await tester.pump();
      expect(_shownTitles(tester), ['Budget']);

      await tester.tap(find.byType(PopupMenuButton<int>));
      await tester.pumpAndSettle();
      expect(find.text('Dark variant'), findsNothing);
      // The light overflow menu of a DarkActionBar.
      expect(
        tester
            .widget<PopupMenuButton<int>>(find.byType(PopupMenuButton<int>))
            .color,
        const Color(0xFFFFFFFF),
      );
      final item = _effectiveStyle(tester, 'Light variant');
      expect(item.color, const Color(0xDE000000));
      expect(item.fontSize, 16);
      expect(item.letterSpacing ?? 0, 0);
      await tester.tap(find.text('Light variant'));
      await tester.pumpAndSettle();

      expect(_appBarTitle(tester), 'All chart types, light');
      expect(find.byType(DesignPage), findsOneWidget);
      expect(_shownTitles(tester), ['Budget']);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        Nightfall.light.stage,
      );

      await tester.tap(find.byType(PopupMenuButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark variant'));
      await tester.pumpAndSettle();
      expect(_appBarTitle(tester), 'All chart types, dark');
      expect(find.byType(DesignPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the /design route opens the page with its extras', (
      tester,
    ) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          '/design?dark=false&only=1';
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      expect(_appBarTitle(tester), 'All chart types, light');
      expect(_shownTitles(tester), ['Orders per quarter']);
      expect(_shownCharts(tester).single.runtimeType, BarChart);

      // The home page is below it.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(DesignPage), findsNothing);
      expect(find.text('All chart types'), findsOneWidget);
    });

    testWidgets('the /design route defaults to the dark page with every card', (
      tester,
    ) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue = '/design';
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      expect(_appBarTitle(tester), 'All chart types, dark');
      expect(_shownCharts(tester), hasLength(_cards.length));
    });

    testWidgets('from shows the cards from that index on', (tester) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          '/design?from=5';
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      expect(_shownTitles(tester), [
        'ACME Corp',
        'Team profile',
        'Deal size',
        'Samples',
        'Traffic',
      ]);
    });
  });
}
