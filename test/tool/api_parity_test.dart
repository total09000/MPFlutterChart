// Tests tool/api_parity.dart, the spec §5.3 API parity checker (MPChartLib.api vs lib/src). No Kotlin counterpart.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/api_parity.dart' hide main;

const _p = 'com/github/mikephil/charting';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('api_parity_test'));
  tearDown(() => tmp.deleteSync(recursive: true));

  /// Writes [files] (relative path → Dart source) under a temp `lib/src` and parses them back.
  List<DartDeclaration> dart(Map<String, String> files) {
    for (final e in files.entries) {
      File('${tmp.path}/${e.key}')
        ..createSync(recursive: true)
        ..writeAsStringSync(e.value);
    }
    return collectDartDeclarations(tmp);
  }

  List<String> keys(List<ParitySymbol> symbols) => [
    for (final s in symbols) s.key,
  ];

  test('a 5-line dump gives 1 present / 1 whitelisted / 1 missing', () {
    const api =
        'public abstract class $_p/charts/Chart {\n'
        '\tpublic static final field INSTANCE L$_p/charts/Chart;\n'
        '\tpublic final fun saveToGallery (Ljava/lang/String;)Z\n'
        '\tpublic final fun clearValues ()V\n'
        '}\n';
    final decls = dart({
      'charts/chart.dart':
          'abstract class Chart {\n  void _clearValues() {}\n}\n',
    });
    final wl = Whitelist.parse(
      'symbols:\n'
      '  - symbol: Chart.saveToGallery\n'
      '    reason: Saving to the gallery is a non-goal (spec 3.2).\n',
    );

    final report = computeParity(api, decls, wl);

    expect(keys(report.present), ['Chart']);
    expect(keys(report.whitelisted), ['Chart.saveToGallery']);
    expect(
      report.whitelisted.single.reason,
      'Saving to the gallery is a non-goal (spec 3.2).',
    );
    expect(keys(report.missing), [
      'Chart.clearValues',
    ]); // a private Dart member does not count
    expect(report.total, 3); // INSTANCE (Kotlin object plumbing) is not API
    expect(report.coverageLine, 'coverage: 2/3 (66.7%)');
    expect(report.exitCode, 1);

    final text = report.format();
    expect(text, contains('present (1):'));
    expect(text, contains('whitelisted (1):'));
    expect(text, contains('missing (1):'));
    expect(text.trimRight().split('\n').last, 'coverage: 2/3 (66.7%)');
  });

  test(
    'getter/setter pairs map to Kotlin property names; other get/set/is funs stay methods',
    () {
      const api =
          'public abstract class $_p/components/AxisBase {\n'
          '\tpublic final fun getAxisMaximum ()F\n'
          '\tpublic final fun setAxisMaximum (F)V\n'
          '\tpublic final fun isEnabled ()Z\n'
          '\tpublic final fun setEnabled (Z)V\n'
          '\tpublic final fun getXAxis ()L$_p/components/XAxis;\n'
          '\tpublic final fun getCOLORFUL_COLORS ()Ljava/util/List;\n'
          '\tpublic final fun getAxisRange ()F\n'
          '\tprotected final fun setAxisRange (F)V\n'
          '\tpublic final fun setLabelCount (IZ)V\n'
          '\tpublic final fun getFormattedLabel (I)Ljava/lang/String;\n'
          '\tpublic final fun isInBounds (FF)Z\n'
          '\tpublic final fun setMaximumScale (F)V\n'
          '\tpublic final fun getMissingProp ()F\n'
          '\tpublic final fun setMissingProp (F)V\n'
          '\tpublic final fun getReadOnly ()F\n'
          '\tpublic final fun setReadOnly (F)V\n'
          // Kotlin `val yMax` next to `fun getYMax(axis)`: the single setter keeps the property.
          '\tpublic final fun getYMax ()F\n'
          '\tpublic final fun getYMax (I)F\n'
          '\tprotected final fun setYMax (F)V\n'
          // `fun getInstance()` next to `getInstance(x, y)`: no setter, so one method symbol.
          '\tpublic final fun getInstance ()L$_p/components/AxisBase;\n'
          '\tpublic final fun getInstance (FF)L$_p/components/AxisBase;\n'
          // Overloaded setters stay one method symbol.
          '\tpublic final fun getColors ()Ljava/util/List;\n'
          '\tpublic final fun setColors (Ljava/util/List;)V\n'
          '\tpublic final fun setColors (Ljava/util/List;I)V\n'
          '}\n';
      final decls = dart({
        'components/axis_base.dart': '''
abstract class AxisBase {
  double axisMaximum = 0;
  bool isEnabled = true;
  Object get xAxis => 0;
  static const List<int> COLORFUL_COLORS = [];
  double get axisRange => 0;
  set axisRange(double v) {}
  void setLabelCount(int count, [bool force = false]) {}
  String getFormattedLabel(int index) => '';
  bool isInBounds(double x, double y) => true;
  void setMaximumScale(double s) {}
  final double readOnly = 0;
  double get yMax => 0;
  set yMax(double v) {}
  double getYMax(int axis) => 0;
  static AxisBase? getInstance([double x = 0, double y = 0]) => null;
  List<int> get colors => [];
  void setColors(List<int> colors, [int? alpha]) {}
}
''',
      });

      final report = computeParity(api, decls, Whitelist.empty);

      expect(keys(report.present), [
        'AxisBase',
        'AxisBase.axisMaximum',
        'AxisBase.isEnabled',
        'AxisBase.xAxis',
        'AxisBase.COLORFUL_COLORS',
        'AxisBase.axisRange',
        'AxisBase.setLabelCount',
        'AxisBase.getFormattedLabel',
        'AxisBase.isInBounds',
        'AxisBase.setMaximumScale',
        'AxisBase.yMax',
        'AxisBase.getYMax',
        'AxisBase.getInstance',
        'AxisBase.colors',
        'AxisBase.setColors',
      ]);
      // get+set count once; a Kotlin setter needs a writable Dart member (a final field is not).
      expect(keys(report.missing), [
        'AxisBase.missingProp',
        'AxisBase.readOnly',
      ]);
      expect(
        report.present.firstWhere((s) => s.member == 'yMax').isProtected,
        isFalse,
      );
      expect(
        report.present.firstWhere((s) => s.member == 'axisRange').isProtected,
        isFalse,
      ); // public getter wins
    },
  );

  test(
    'nested types, companions, enums, DefaultImpls and fun-interface typedefs map to their Dart names',
    () {
      const api =
          'public class $_p/utils/Fill {\n'
          '\tpublic fun <init> (I)V\n'
          '\tpublic final fun getType ()L$_p/utils/Fill\$Type;\n'
          '}\n'
          '\n'
          'public final class $_p/utils/Fill\$Type : java/lang/Enum {\n'
          '\tpublic static final field COLOR L$_p/utils/Fill\$Type;\n'
          '\tpublic static fun getEntries ()Lkotlin/enums/EnumEntries;\n'
          '\tpublic static fun valueOf (Ljava/lang/String;)L$_p/utils/Fill\$Type;\n'
          '\tpublic static fun values ()[L$_p/utils/Fill\$Type;\n'
          '}\n'
          '\n'
          'public final class $_p/utils/MPPointF {\n'
          '\tpublic static final field Companion L$_p/utils/MPPointF\$Companion;\n'
          '\tpublic field x F\n'
          '}\n'
          '\n'
          'public final class $_p/utils/MPPointF\$Companion {\n'
          '\tpublic final fun getInstance (FF)L$_p/utils/MPPointF;\n'
          '\tpublic final fun getInstance (L$_p/utils/MPPointF;)L$_p/utils/MPPointF;\n'
          '}\n'
          '\n'
          'public abstract interface class $_p/formatter/IValueFormatter {\n'
          '\tpublic abstract fun getFormattedValue (F)Ljava/lang/String;\n'
          '}\n'
          '\n'
          'public final class $_p/formatter/IValueFormatter\$DefaultImpls {\n'
          '\tpublic static fun getFormattedValue (L$_p/formatter/IValueFormatter;F)Ljava/lang/String;\n'
          '}\n'
          '\n'
          'public abstract interface class $_p/animation/Easing\$EasingFunction : android/animation/TimeInterpolator {\n'
          '}\n'
          '\n'
          'public final class $_p/data/LineDataSet\$Mode : java/lang/Enum {\n'
          '\tpublic static final field LINEAR L$_p/data/LineDataSet\$Mode;\n'
          '}\n'
          '\n'
          'protected final class $_p/renderer/BarLineScatterCandleBubbleRenderer\$XBounds {\n'
          '\tpublic final fun getMin ()I\n'
          '}\n'
          '\n'
          'public final class $_p/data/EntryKt {\n'
          '\tpublic static final fun Entry (FFLandroid/graphics/drawable/Drawable;)L$_p/data/Entry;\n'
          '}\n';
      final decls = dart({
        'utils/fill.dart': '''
class Fill {
  Fill.ofColor(int color);
  FillType get type => FillType.COLOR;
}
enum FillType { COLOR }
''',
        'utils/mp_point_f.dart': '''
class MPPointF {
  double x = 0;
  static MPPointF getInstance([double x = 0, double y = 0]) => MPPointF();
  static MPPointF getInstanceFrom(MPPointF copy) => copy;
}
''',
        'formatter/i_value_formatter.dart':
            'abstract class IValueFormatter {\n  String getFormattedValue(double v);\n}\n',
        'animation/easing.dart':
            'typedef EasingFunction = double Function(double input);\n',
        'data/line_data_set.dart': 'enum LineDataSetMode { LINEAR }\n',
        'renderer/x_bounds.dart': 'class XBounds {\n  int min = 0;\n}\n',
      });

      final report = computeParity(api, decls, Whitelist.empty);

      expect(keys(report.present), [
        'Fill',
        'Fill.type',
        'Fill.Type',
        'Fill.Type.COLOR',
        'MPPointF',
        'MPPointF.x',
        'MPPointF.getInstance', // companion member folded into the outer class; overloads collapse
        'IValueFormatter',
        'IValueFormatter.getFormattedValue',
        'Easing.EasingFunction',
        'LineDataSet.Mode',
        'LineDataSet.Mode.LINEAR',
        'BarLineScatterCandleBubbleRenderer.XBounds',
        'BarLineScatterCandleBubbleRenderer.XBounds.min',
      ]);
      expect(report.missing, isEmpty);
      final dartNames = {for (final s in report.present) s.key: s.dartName};
      expect(dartNames['Fill.Type'], 'FillType');
      expect(dartNames['LineDataSet.Mode.LINEAR'], 'LineDataSetMode.LINEAR');
      expect(dartNames['Easing.EasingFunction'], 'EasingFunction');
      expect(
        dartNames['BarLineScatterCandleBubbleRenderer.XBounds'],
        'XBounds',
      );
    },
  );

  test(
    'overloads collapse, renames apply, Dart inheritance/extensions count, @internal is absent',
    () {
      const api =
          'public abstract class $_p/charts/Chart {\n'
          '\tpublic final fun toBitmap ()Landroid/graphics/Bitmap;\n'
          '\tpublic final fun toBitmap (II)Landroid/graphics/Bitmap;\n'
          '\tpublic static synthetic fun toBitmap\$default (L$_p/charts/Chart;IIILjava/lang/Object;)Landroid/graphics/Bitmap;\n'
          '\tpublic fun getData ()L$_p/data/ChartData;\n'
          '\tpublic final fun notifyDataSetChanged ()V\n'
          '\tpublic fun equals (Ljava/lang/Object;)Z\n'
          '}\n'
          '\n'
          'public class $_p/charts/LineChart : $_p/charts/Chart {\n'
          '\tpublic fun getData ()L$_p/data/ChartData;\n'
          '\tpublic final fun drawExtra ()V\n'
          '}\n';
      final decls = dart({
        'charts/chart.dart': '''
import 'package:flutter/foundation.dart';
abstract class Chart {
  Object? get data => null;
  Future<Object> toImage({int? width, int? height}) async => 0;
  Future<Object> toPngBytes() async => 0;
  @internal
  void notifyDataSetChanged() {}
  @override
  bool operator ==(Object other) => identical(this, other);
  @override
  int get hashCode => 0;
}
''',
        'charts/line_chart.dart': '''
class LineChart extends Chart {}
extension LineChartExtras on LineChart {
  void drawExtra() {}
}
''',
        // The widget layer reuses the core name; the core class must win.
        'widgets/line_chart_widget.dart':
            'class LineChart {\n  void build() {}\n}\n',
      });

      for (final order in [decls, decls.reversed.toList()]) {
        final report = computeParity(api, order, Whitelist.empty);
        expect(keys(report.present), [
          'Chart',
          'Chart.toBitmap',
          'Chart.data',
          'Chart.equals',
          'LineChart',
          'LineChart.data',
          'LineChart.drawExtra',
        ]);
        expect(keys(report.missing), ['Chart.notifyDataSetChanged']);
        final toBitmap = report.present.firstWhere(
          (s) => s.member == 'toBitmap',
        );
        expect(toBitmap.dartName, 'Chart.toImage/toPngBytes');
        expect(
          report.present.firstWhere((s) => s.member == 'equals').dartName,
          'Chart.==',
        );
      }
    },
  );

  test(
    'a property and a same-named method stay two symbols; the rename applies to the property',
    () {
      const getter =
          '\tprotected final fun getRenderLimitLines ()Landroid/graphics/Path;\n';
      const method =
          '\tpublic fun renderLimitLines (Landroid/graphics/Canvas;)V\n';
      for (final body in [getter + method, method + getter]) {
        final api = 'public class $_p/renderer/YAxisRenderer {\n$body}\n';
        // Dart lacks renderLimitLinesPath: the method must not stand in for the property.
        final without = computeParity(
          api,
          dart({
            'renderer/y_axis_renderer.dart':
                'class YAxisRenderer {\n  void renderLimitLines(Object c) {}\n}\n',
          }),
          Whitelist.empty,
        );
        expect(keys(without.present), [
          'YAxisRenderer',
          'YAxisRenderer.renderLimitLines()',
        ]);
        expect(keys(without.missing), ['YAxisRenderer.renderLimitLines']);
        expect(without.missing.single.isProtected, isTrue);
        expect(without.total, 3);
        expect(without.propertyMethodClashes, [
          'YAxisRenderer.renderLimitLines()',
        ]);

        final with_ = computeParity(
          api,
          dart({
            'renderer/y_axis_renderer.dart':
                'class YAxisRenderer {\n'
                '  final Object renderLimitLinesPath = 0;\n'
                '  void renderLimitLines(Object c) {}\n'
                '}\n',
          }),
          Whitelist.empty,
        );
        expect(with_.missing, isEmpty);
        expect(
          with_.present
              .firstWhere((s) => s.key == 'YAxisRenderer.renderLimitLines')
              .dartName,
          'YAxisRenderer.renderLimitLinesPath',
        );
      }
    },
  );

  test(
    'a renamed member needs every rename target; absent targets are reported',
    () {
      const api =
          'public abstract class $_p/data/BaseDataSet {\n'
          '\tprotected fun copy (L$_p/data/BaseDataSet;)V\n'
          '\tpublic final fun clear ()V\n'
          '}\n'
          '\n'
          'public abstract class $_p/data/DataSet : $_p/data/BaseDataSet {\n'
          '\tpublic abstract fun copy ()L$_p/data/DataSet;\n'
          '\tprotected fun copy (L$_p/data/DataSet;)V\n'
          '}\n';
      const renames = {
        'BaseDataSet.copy': ['copyTo'],
        'DataSet.copy': [
          'copy',
          'copyTo',
        ], // Dart keeps copy() and renames copy(DataSet)
        'BaseDataSet.clear': ['clearAll', 'clearTypo'],
      };
      // The Kotlin name alone (an inherited public copy()) must not satisfy a renamed member.
      final before = computeParity(
        api,
        dart({
          'data/base_data_set.dart':
              'abstract class BaseDataSet {\n'
              '  BaseDataSet copy() => this;\n'
              '  void clearAll() {}\n'
              '}\n'
              'abstract class DataSet extends BaseDataSet {}\n',
        }),
        Whitelist.empty,
        renames: renames,
      );
      expect(keys(before.missing), [
        'BaseDataSet.copy',
        'BaseDataSet.clear',
        'DataSet.copy',
      ]);
      expect(before.missingRenameTargets, [
        'BaseDataSet.copy -> copyTo',
        'DataSet.copy -> copyTo',
        'BaseDataSet.clear -> clearTypo',
      ]);
      expect(
        before.warnings,
        contains('rename target not found in Dart: BaseDataSet.copy -> copyTo'),
      );

      final after = computeParity(
        api,
        dart({
          'data/base_data_set.dart':
              'abstract class BaseDataSet {\n'
              '  BaseDataSet copy() => this;\n'
              '  void copyTo(BaseDataSet other) {}\n'
              '  void clearAll() {}\n'
              '}\n'
              'abstract class DataSet extends BaseDataSet {}\n',
        }),
        Whitelist.empty,
        renames: renames,
      );
      expect(keys(after.missing), ['BaseDataSet.clear']);
      expect(after.missingRenameTargets, ['BaseDataSet.clear -> clearTypo']);
      final names = {for (final s in after.present) s.key: s.dartName};
      expect(names['BaseDataSet.copy'], 'BaseDataSet.copyTo');
      expect(names['DataSet.copy'], 'DataSet.copy/copyTo');
    },
  );

  test('only named extensions count (an unnamed one is library-private)', () {
    const api =
        'public class $_p/charts/Chart {\n'
        '\tpublic final fun drawExtra ()V\n'
        '\tpublic final fun drawNamed ()V\n'
        '}\n';
    final decls = dart({
      'charts/chart.dart':
          'class Chart {}\n'
          'extension on Chart {\n  void drawExtra() {}\n}\n'
          'extension Named on Chart {\n  void drawNamed() {}\n}\n',
    });

    final report = computeParity(api, decls, Whitelist.empty);

    expect(keys(report.present), ['Chart', 'Chart.drawNamed']);
    expect(keys(report.missing), ['Chart.drawExtra']);
  });

  group('runParity (CLI)', () {
    const specPath = 'tool/api_scope.md';
    late Directory root;
    late StringBuffer out;
    late StringBuffer err;

    setUp(() {
      root = Directory('${tmp.path}/root');
      void put(String rel, String content) => File('${root.path}/$rel')
        ..createSync(recursive: true)
        ..writeAsStringSync(content);
      put(
        'tool/MPChartLib.api',
        'public abstract class $_p/charts/Chart {\n'
            '\tpublic final fun saveToGallery (Ljava/lang/String;)Z\n'
            '\tpublic final fun clearValues ()V\n'
            '}\n'
            '\n'
            'public class $_p/charts/PieChart : $_p/charts/Chart {\n'
            '\tpublic final fun getHoleRadius ()F\n'
            '}\n'
            '\n'
            // utils/Extra.kt has no Appendix A row.
            'public final class $_p/utils/Extra {\n'
            '\tpublic final fun x ()V\n'
            '}\n',
      );
      put(
        'tool/api_whitelist.yaml',
        'symbols:\n'
            '  - symbol: Chart.saveToGallery\n'
            '    reason: Non-goal.\n',
      );
      put('lib/src/charts/chart.dart', 'abstract class Chart {}\n');
      put(
        specPath,
        '| Kotlin | Dart | 行数 | 车道 |\n'
        '|---|---|---:|---|\n'
        '| `charts/Chart.kt` | `lib/src/charts/chart.dart` | 1078 | P0 |\n'
        '| `charts/PieChart.kt` | `lib/src/charts/pie_chart.dart` | 423 | P1-C |\n',
      );
      out = StringBuffer();
      err = StringBuffer();
    });

    int run(List<String> args) => runParity(args, root, out: out, err: err);
    String lastLine() => out.toString().trimRight().split('\n').last;

    test('scores the lane and writes --markdown relative to the root', () {
      expect(
        run(['--scope=P0', '--fail-on-missing', '--markdown=out/report.md']),
        1,
      );
      expect(lastLine(), 'coverage: 2/3 (66.7%)');
      expect(out.toString(), contains('  Chart.clearValues'));
      expect(out.toString(), isNot(contains('by lane:')));
      final md = File('${root.path}/out/report.md').readAsStringSync();
      expect(md, contains('`coverage: 2/3 (66.7%)`'));
      expect(
        md,
        startsWith('# API parity — P0 (LineChart core)\n'),
      );
      expect(
        md,
        contains(
          '`dart run tool/api_parity.dart --scope=P0 --markdown=out/report.md`',
        ),
      );
      expect(md, isNot(contains('By lane')));
    });

    test('an absolute --markdown path is used as is', () {
      final target = '${tmp.path}/elsewhere/abs.md';
      expect(run(['--markdown=$target']), 0);
      expect(File(target).existsSync(), isTrue);
      expect(File('${root.path}/$target').existsSync(), isFalse);
    });

    test('without --fail-on-missing missing symbols exit 0', () {
      expect(run(['--scope=P0']), 0);
      expect(out.toString(), contains('missing (1):'));
      expect(lastLine(), 'coverage: 2/3 (66.7%)');
    });

    test('--fail-on-missing exits 0 when nothing is missing', () {
      void put(String rel, String content) => File('${root.path}/$rel')
        ..createSync(recursive: true)
        ..writeAsStringSync(content);
      put(
        'lib/src/charts/chart.dart',
        'abstract class Chart {\n  void clearValues() {}\n}\n',
      );
      put(
        'lib/src/charts/pie_chart.dart',
        "import 'chart.dart';\n"
            'class PieChart extends Chart {\n  double get holeRadius => 0;\n}\n',
      );
      put('lib/src/utils/extra.dart', 'class Extra {\n  void x() {}\n}\n');
      expect(run(['--scope=all', '--fail-on-missing']), 0);
      expect(out.toString(), contains('missing (0):'));
      expect(lastLine(), 'coverage: 7/7 (100.0%)');
    });

    test(
      '--scope takes a comma-separated list and prints coverage per lane',
      () {
        expect(run(['--scope= P0 , P1-C,']), 0);
        final text = out.toString();
        expect(
          text,
          contains('by lane:\n  P0: 2/3 (66.7%)\n  P1-C: 0/2 (0.0%)\n'),
        );
        expect(text, isNot(contains('(not in Appendix A)')));
        expect(text, contains('  PieChart.holeRadius'));
        expect(text, isNot(contains('Extra')));
        expect(lastLine(), 'coverage: 2/5 (40.0%)');
        // The section comes right before the last (coverage) line.
        final lines = text.trimRight().split('\n');
        expect(lines[lines.length - 4], 'by lane:');
      },
    );

    test(
      '--scope=all scores the whole dump, every lane and the unmapped classes',
      () {
        expect(run(['--scope=all', '--markdown=out/all.md']), 0);
        final text = out.toString();
        expect(
          text,
          contains(
            'by lane:\n'
            '  P0: 2/3 (66.7%)\n'
            '  P1-C: 0/2 (0.0%)\n'
            '  (not in Appendix A): 0/2 (0.0%)\n',
          ),
        );
        expect(lastLine(), 'coverage: 2/7 (28.6%)');
        final md = File('${root.path}/out/all.md').readAsStringSync();
        expect(md, startsWith('# API parity — all lanes\n'));
        expect(
          md,
          contains(
            '`dart run tool/api_parity.dart --scope=all --markdown=out/all.md`',
          ),
        );
        expect(md, contains('- P1-C: 0/2 (0.0%)\n'));
        expect(md, contains('- (not in Appendix A): 0/2 (0.0%)\n'));
        expect(md.trimRight().split('\n').last, '`coverage: 2/7 (28.6%)`');
      },
    );

    test('a lane list titles the markdown with its lanes', () {
      expect(run(['--scope=P0,P1-C', '--markdown=out/list.md']), 0);
      final md = File('${root.path}/out/list.md').readAsStringSync();
      expect(md, startsWith('# API parity — P0, P1-C\n'));
      expect(md, contains('- P0: 2/3 (66.7%)\n'));
    });

    test('a bare --markdown writes the default path of its scope', () {
      // A P1-A lane with one class, so that a single lane other than P0 can be scored.
      File('${root.path}/$specPath').writeAsStringSync(
        '${File('${root.path}/$specPath').readAsStringSync()}'
        '| `charts/BarChart.kt` | `lib/src/charts/bar_chart.dart` | 900 | P1-A |\n',
      );
      File('${root.path}/tool/MPChartLib.api').writeAsStringSync(
        '${File('${root.path}/tool/MPChartLib.api').readAsStringSync()}'
        '\n'
        'public class $_p/charts/BarChart : $_p/charts/Chart {\n'
        '\tpublic final fun clearBars ()V\n'
        '}\n',
      );
      final phase0 = File('${root.path}/docs/api-parity-phase0.md')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          '# API parity — P0 (LineChart core)\nkept\n',
        );
      final phase0Bytes = phase0.readAsBytesSync();
      String md(String rel) => File('${root.path}/$rel').readAsStringSync();

      expect(run(['--scope=P1-A', '--markdown']), 0, reason: '$err');
      expect(
        md('docs/api-parity-p1-a.md'),
        startsWith('# API parity — P1-A\n'),
      );
      expect(
        md('docs/api-parity-p1-a.md'),
        contains('`dart run tool/api_parity.dart --scope=P1-A --markdown`'),
      );
      expect(
        err.toString(),
        contains('wrote ${root.path}/docs/api-parity-p1-a.md'),
      );
      expect(phase0.readAsBytesSync(), phase0Bytes);

      // A list: its lanes lowercased, joined with `-` in the order the report lists them.
      expect(run(['--scope=P1-C,P0', '--markdown']), 0, reason: '$err');
      expect(
        md('docs/api-parity-p1-c-p0.md'),
        startsWith('# API parity — P1-C, P0\n'),
      );
      expect(run(['--scope=all', '--markdown']), 0, reason: '$err');
      expect(
        md('docs/api-parity-all.md'),
        startsWith('# API parity — all lanes\n'),
      );
      expect(phase0.readAsBytesSync(), phase0Bytes);

      // No --scope scores the whole dump as well.
      File('${root.path}/docs/api-parity-all.md').deleteSync();
      expect(run(['--markdown']), 0, reason: '$err');
      expect(md('docs/api-parity-all.md'), startsWith('# API parity\n'));
      expect(phase0.readAsBytesSync(), phase0Bytes);

      // Only P0 writes docs/api-parity-phase0.md.
      expect(run(['--scope=P0', '--markdown']), 0, reason: '$err');
      expect(
        md('docs/api-parity-phase0.md'),
        contains('`dart run tool/api_parity.dart --scope=P0 --markdown`'),
      );
    });

    test('malformed scopes exit 2', () {
      for (final arg in ['--scope=', '--scope=,', '--scope=all,P0']) {
        err.clear();
        expect(run([arg]), 2, reason: arg);
        expect(err.toString(), contains('--scope'), reason: arg);
      }
      err.clear();
      expect(run(['--scope=P0,PX']), 2);
      expect(err.toString(), contains('no Kotlin files in lane "PX"'));
      expect(out.toString(), isEmpty);
    });

    test('bad arguments and an unknown lane exit 2; --help exits 0', () {
      expect(run(['--bogus']), 2);
      expect(err.toString(), contains('unknown argument: --bogus'));
      expect(run(['--scope=PX']), 2);
      expect(err.toString(), contains('no Kotlin files in lane "PX"'));
      expect(run(['--help']), 0);
      expect(out.toString(), contains('usage: dart run tool/api_parity.dart'));
    });

    test('a missing spec, dump or whitelist exits 2 with a message', () {
      for (final rel in [
        specPath,
        'tool/api_whitelist.yaml',
        'tool/MPChartLib.api',
      ]) {
        final f = File('${root.path}/$rel');
        final content = f.readAsStringSync();
        f.deleteSync();
        err.clear();
        expect(run(['--scope=P0']), 2, reason: rel);
        expect(err.toString(), contains(rel.split('/').last), reason: rel);
        f.writeAsStringSync(content);
      }
      expect(out.toString(), isEmpty);
    });
  });

  test(
    'a class-level whitelist entry covers every member; stale entries are reported',
    () {
      const api =
          'public class $_p/components/MarkerView : android/widget/RelativeLayout {\n'
          '\tpublic final fun inflate ()V\n'
          '}\n'
          '\n'
          'public class $_p/utils/Utils {\n'
          '\tpublic final fun init (Landroid/content/Context;)V\n'
          '\tpublic final fun convertDpToPixel (F)F\n'
          '}\n';
      final decls = dart({
        'utils/utils.dart':
            'abstract final class Utils {\n  static double convertDpToPixel(double dp) => dp;\n}\n',
      });
      final wl = Whitelist.parse('''
# A comment line.
symbols:
  - symbol: MarkerView
    reason: "Android View subclass: replaced by a canvas marker."
  - symbol: Utils.init
    reason: Display metrics need no Context in Flutter.
  - symbol: Utils.convertDpToPixel
    reason: Present, so this entry is unnecessary.
  - symbol: Utils.noSuchMember
    reason: Matches nothing in the dump.
additions:
  - symbol: Utils.convertDpToPixel
    reason: Exists in Dart.
  - symbol: Utils.gone
    reason: Does not exist in Dart.
''');

      final report = computeParity(api, decls, wl);

      expect(keys(report.whitelisted), [
        'MarkerView',
        'MarkerView.inflate',
        'Utils.init',
      ]);
      expect(
        report.whitelisted.first.reason,
        'Android View subclass: replaced by a canvas marker.',
      );
      expect(keys(report.missing), isEmpty);
      expect(report.staleWhitelist, ['Utils.noSuchMember']);
      expect(report.whitelistedButPresent, ['Utils.convertDpToPixel']);
      expect(report.missingAdditions, ['Utils.gone']);
      expect(report.exitCode, 0);
    },
  );

  test('the whitelist parser rejects malformed files', () {
    expect(
      () => Whitelist.parse('symbols:\n  - symbol: A.b\n'),
      throwsFormatException,
    ); // no reason
    expect(
      () => Whitelist.parse('symbols:\n    reason: orphan\n'),
      throwsFormatException,
    );
    expect(
      () => Whitelist.parse('other:\n  - symbol: A.b\n    reason: x\n'),
      throwsFormatException,
    );
    expect(
      () => Whitelist.parse(
        'symbols:\n  - symbol: A.b\n    reason: x\n  - symbol: A.b\n    reason: y\n',
      ),
      throwsFormatException,
    );
    // Unquoted ": " is not valid YAML; the file must stay readable by real YAML tools.
    expect(
      () => Whitelist.parse('symbols:\n  - symbol: A.b\n    reason: a: b\n'),
      throwsFormatException,
    );
  });

  test(
    '--scope reads lanes from the spec table; nested classes follow their outer file',
    () {
      const spec = '''
| Kotlin | Dart | 行数 | 车道 |
|---|---|---:|---|
| `charts/Chart.kt` | `lib/src/charts/chart.dart` | 1078 | P0 |
| `charts/PieChart.kt` | `lib/src/charts/pie_chart.dart` | 423 | P1-C |
''';
      final lanes = parseLanes(spec);
      expect(lanes, {'charts/Chart.kt': 'P0', 'charts/PieChart.kt': 'P1-C'});

      const api =
          'public abstract class $_p/charts/Chart {\n'
          '\tpublic final fun clear ()V\n'
          '}\n'
          '\n'
          'public final class $_p/charts/Chart\$Companion {\n'
          '\tpublic final fun create ()V\n'
          '}\n'
          '\n'
          'public class $_p/charts/PieChart : $_p/charts/Chart {\n'
          '\tpublic final fun getHoleRadius ()F\n'
          '}\n';
      final decls = dart({
        'charts/chart.dart': 'abstract class Chart {\n  void clear() {}\n}\n',
      });

      final p0 = computeParity(
        api,
        decls,
        Whitelist.empty,
        scopeFiles: filesInLane(lanes, 'P0'),
      );
      expect(keys(p0.present), ['Chart', 'Chart.clear']);
      expect(keys(p0.missing), ['Chart.create']);

      final all = computeParity(api, decls, Whitelist.empty);
      expect(keys(all.missing), [
        'Chart.create',
        'PieChart',
        'PieChart.holeRadius',
      ]);
      expect(
        all.coverageLineFor(filesInLane(lanes, 'P0')),
        'coverage: 2/3 (66.7%)',
      );
      expect(
        all.coverageLineFor({'charts/PieChart.kt'}),
        'coverage: 0/2 (0.0%)',
      );
      expect(all.coverageLineFor({}), 'coverage: 0/0 (100.0%)');

      expect(filesInLanes(lanes, ['P0', 'P1-C']), {
        'charts/Chart.kt',
        'charts/PieChart.kt',
      });
      expect(filesInLanes(lanes, ['P1-C', 'PX']), {'charts/PieChart.kt'});
      expect(parseScopeArg('P0'), ['P0']);
      expect(parseScopeArg(' P0 , P1-C,'), ['P0', 'P1-C']);
      expect(parseScopeArg('P0,P0'), ['P0']);
      expect(parseScopeArg(' all '), isNull);
      for (final bad in ['', ' , ', 'all,P0', 'P0,all']) {
        expect(() => parseScopeArg(bad), throwsFormatException, reason: bad);
      }
    },
  );

  test('every class of the checked-in dump belongs to a lane of Appendix A', () {
    final lanes = parseLanes(
      File(
        'tool/api_scope.md',
      ).readAsStringSync(),
    );
    final report = computeParity(
      File('tool/MPChartLib.api').readAsStringSync(),
      collectDartDeclarations(Directory('lib/src')),
      Whitelist.parse(File('tool/api_whitelist.yaml').readAsStringSync()),
      scopeFiles: null,
    );

    expect(lanes, hasLength(155)); // Appendix A: "155 个文件"
    expect(
      report.symbols
          .map((s) => s.kotlinFile)
          .toSet()
          .difference(lanes.keys.toSet()),
      isEmpty,
    );
  });

  test(
    'the checked-in dump, whitelist and lib/src agree (no stale or unnecessary entries)',
    () {
      final report = computeParity(
        File('tool/MPChartLib.api').readAsStringSync(),
        collectDartDeclarations(Directory('lib/src')),
        Whitelist.parse(File('tool/api_whitelist.yaml').readAsStringSync()),
        scopeFiles: filesInLane(
          parseLanes(
            File(
              'tool/api_scope.md',
            ).readAsStringSync(),
          ),
          'P0',
        ),
      );

      expect(report.total, greaterThan(1000));
      expect(report.staleWhitelist, isEmpty);
      expect(report.whitelistedButPresent, isEmpty);
      expect(report.missingAdditions, isEmpty);
      expect(report.unusedRenames, isEmpty);
      expect(report.missingRenameTargets, isEmpty);
      // The only Kotlin property / method name clash in the dump (R26 renamed the Dart property).
      expect(report.propertyMethodClashes, [
        'YAxisRenderer.renderLimitLines()',
      ]);
      expect(report.warnings, isEmpty);
    },
  );
}
