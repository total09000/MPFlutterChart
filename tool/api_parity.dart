// API parity checker: compares the Kotlin binary-compatibility dump tool/MPChartLib.api
// (MPAndroidChart v4.0.1) with the public declarations under lib/src, read with package:analyzer.
//
// Run from the package root with the HarmonyOS SDK's dart:
//   dart run tool/api_parity.dart [--scope=<lane>[,<lane>…]|all]
//       [--fail-on-missing] [--markdown[=<path>]]
// A bare --markdown writes docs/api-parity-phase0.md for --scope=P0, docs/api-parity-<lanes>.md for other lanes (each
// lowercased, joined with `-` in the order given, as the report lists them: docs/api-parity-p1-a-p1-b.md), and
// docs/api-parity-all.md for --scope=all or no --scope; --markdown=<path> writes <path>.
//
// Prints three sections (present / whitelisted / missing), then for a lane list or `all` a `by lane:` section
// (`  <lane>: <covered>/<total> (<pct>%)`), and ends with `coverage: <present+whitelisted>/<total> (<pct>%)`.
// Exit code 0 (a report, even with missing symbols), 1 only with --fail-on-missing when `missing` is not empty,
// 2 on a bad argument or input. Counting rules: see [computeParity] and tool/README.md.
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

/// Package prefix of every class in the dump.
const String kotlinPackagePrefix = 'com/github/mikephil/charting/';

/// Kotlin nested types → their top-level Dart names (Ruling R22: the nested name is kept when it is distinctive,
/// the outer class is prefixed when it is generic). Unlisted nested types fall back to the nested name itself.
/// Keys are JVM binary names relative to the package (`Outer$Inner`).
const Map<String, String> nestedTypeNames = {
  r'Fill$Type': 'FillType',
  r'Fill$Direction': 'FillDirection',
  r'LineDataSet$Mode': 'LineDataSetMode',
  r'DataSet$Rounding': 'Rounding',
  r'YAxis$AxisDependency': 'AxisDependency',
  r'YAxis$YAxisLabelPosition': 'YAxisLabelPosition',
  r'XAxis$XAxisPosition': 'XAxisPosition',
  r'LimitLine$LimitLabelPosition': 'LimitLabelPosition',
  r'Legend$LegendForm': 'LegendForm',
  r'Legend$LegendDirection': 'LegendDirection',
  r'Legend$LegendHorizontalAlignment': 'LegendHorizontalAlignment',
  r'Legend$LegendOrientation': 'LegendOrientation',
  r'Legend$LegendVerticalAlignment': 'LegendVerticalAlignment',
  r'ChartTouchListener$ChartGesture': 'ChartGesture',
  r'Easing$EasingFunction':
      'EasingFunction', // fun interface → typedef
  r'ObjectPool$Poolable': 'Poolable',
  // Phase 1 lane A (Ruling A2): the nested names themselves, listed for the record like XBounds.
  r'BarChartRenderer$BarCorners': 'BarCorners',
  r'ScatterChart$ScatterShape': 'ScatterShape', // charts/scatter_shape.dart
};

/// Kotlin members whose Dart counterpart has a different name, keyed by the Kotlin symbol as this tool prints it
/// (`Class.member`, nested classes dotted). Kotlin overloads collapse into one symbol; the list holds every Dart name
/// that symbol maps to, and all of them must exist for it to be present. The Kotlin name counts only when listed
/// (Dart kept it for some overloads and renamed the others), so deleting a renamed overload is reported, and an
/// inherited member that happens to carry the Kotlin name (DataSet's public `copy()`) cannot stand in for a renamed
/// one. Every target is also checked on its own ([ParityReport.missingRenameTargets]). Provenance in the comments.
const Map<String, List<String>> memberRenames = {
  // Task 12 / spec §6.1: toBitmap(w, h) → toImage({width, height, pixelRatio}) / toPngBytes(...).
  'Chart.toBitmap': ['toImage', 'toPngBytes'],
  // Task 12: highlightValue(Highlight?, callListener) → highlightValueOf.
  'Chart.highlightValue': ['highlightValue', 'highlightValueOf'],
  // Task 5 / Ruling R18.
  'MPPointF.getInstance': ['getInstance', 'getInstanceFrom'],
  'ObjectPool.recycle': ['recycle', 'recycleAll'],
  'Utils.getSizeOfRotatedRectangleByDegrees': [
    'getSizeOfRotatedRectangleByDegrees',
    'getSizeOfRotatedRectangleByDegreesFromSize',
  ],
  'Utils.getSizeOfRotatedRectangleByRadians': [
    'getSizeOfRotatedRectangleByRadians',
    'getSizeOfRotatedRectangleByRadiansFromSize',
  ],
  // Task 7 / Ruling R23.
  'IDataSet.getEntryIndex': ['getEntryIndex', 'getEntryIndexOf'],
  'DataSet.getEntryIndex': ['getEntryIndex', 'getEntryIndexOf'],
  'IDataSet.removeEntry': ['removeEntry', 'removeEntryByIndex'],
  'BaseDataSet.removeEntry': ['removeEntry', 'removeEntryByIndex'],
  'ChartData.removeDataSet': ['removeDataSet', 'removeDataSetByIndex'],
  'ChartData.removeEntry': ['removeEntry', 'removeEntryByXValue'],
  'DataSet.calcMinMax': ['calcMinMax', 'calcMinMaxForEntry'],
  'DataSet.calcMinMaxY': ['calcMinMaxY', 'calcMinMaxYForEntry'],
  'ChartData.calcMinMax': [
    'calcMinMax',
    'calcMinMaxForEntry',
    'calcMinMaxForDataSet',
  ],
  // Task 7: the protected copier copy(dataSet) → @protected copyTo (it would clash with the public DataSet.copy()).
  // Every later data set needs the same entry when it is ported (lane A's are below; PieDataSet and RadarDataSet are
  // lane C's).
  'BaseDataSet.copy': ['copyTo'],
  'BarLineScatterCandleBubbleDataSet.copy': ['copyTo'],
  'LineScatterCandleRadarDataSet.copy': ['copyTo'],
  'LineRadarDataSet.copy': ['copyTo'],
  'DataSet.copy': ['copy', 'copyTo'],
  'LineDataSet.copy': ['copy', 'copyTo'],
  // Lane C / Ruling R45: PieDataSet and RadarDataSet keep the public copy() and rename copy(dataSet) to copyTo.
  'PieDataSet.copy': ['copy', 'copyTo'],
  'RadarDataSet.copy': ['copy', 'copyTo'],
  // Task 11 / Ruling R26.
  'DataRenderer.drawValue': ['drawValue', 'drawStackedValue'],
  'BarLineScatterCandleBubbleRenderer.shouldDrawValues': [
    'shouldDrawValues',
    'shouldDrawValuesOf',
  ],
  'LineRadarRenderer.drawFilledPath': ['drawFilledPath', 'drawFilledPathColor'],
  // The protected Path property `renderLimitLines` (Dart cannot also have the method `renderLimitLines()`, which
  // keeps its name and is scored as `YAxisRenderer.renderLimitLines()`).
  'YAxisRenderer.renderLimitLines': ['renderLimitLinesPath'],
  // Phase 1 lane A (Ruling A5). Each data set's copy() + protected copy(dataSet) → copy() + @protected copyTo, as
  // LineDataSet (Tasks 1, 10, 12, 13).
  'BarDataSet.copy': ['copy', 'copyTo'],
  'ScatterDataSet.copy': ['copy', 'copyTo'],
  'CandleDataSet.copy': ['copy', 'copyTo'],
  'BubbleDataSet.copy': ['copy', 'copyTo'],
  // calcMinMax() keeps its name; the protected calcMinMax(e) is calcMinMaxForEntry (Tasks 1, 13). CandleDataSet
  // declares only the entry overloads, so the Kotlin names are not listed for it (Task 12).
  'BarDataSet.calcMinMax': ['calcMinMax', 'calcMinMaxForEntry'],
  'BubbleDataSet.calcMinMax': ['calcMinMax', 'calcMinMaxForEntry'],
  'CandleDataSet.calcMinMax': ['calcMinMaxForEntry'],
  'CandleDataSet.calcMinMaxY': ['calcMinMaxYForEntry'],
  // Task 2: feed(data) overrides AbstractBuffer.feed; feed(data, from, to) and feed(data, indices, columnEntries,
  // count) are feedRange / feedIndices. HorizontalBarBuffer declares no feed.
  'BarBuffer.feed': ['feed', 'feedRange', 'feedIndices'],
  // Task 8: the only drawValue Kotlin's HorizontalBarChartRenderer declares, drawValue(c, valueText, x, y, color), is
  // drawValueText; the inherited formatter-based DataRenderer.drawValue must not stand in for it.
  'HorizontalBarChartRenderer.drawValue': ['drawValueText'],
};

// ---------------------------------------------------------------------------------------------------------------
// Kotlin side
// ---------------------------------------------------------------------------------------------------------------

/// One member line of the dump.
class KotlinMember {
  KotlinMember({
    required this.name,
    required this.isField,
    required this.modifiers,
    required this.isProtected,
    required this.params,
    required this.returnType,
  });

  final String name;
  final bool isField;
  final Set<String> modifiers;
  final bool isProtected;

  /// JVM parameter descriptors (empty for fields).
  final List<String> params;

  /// JVM return descriptor (the field type for fields).
  final String returnType;

  bool get isStatic => modifiers.contains('static');
}

/// One `class … {` block of the dump.
class KotlinClass {
  KotlinClass({
    required this.binaryName,
    required this.pkg,
    required this.isProtected,
    required this.modifiers,
    required this.supertypes,
  });

  /// JVM binary name below the package, e.g. `Legend$LegendForm`.
  final String binaryName;

  /// Package below [kotlinPackagePrefix], e.g. `interfaces/datasets`.
  final String pkg;
  final bool isProtected;
  final Set<String> modifiers;

  /// Supertypes as `pkg/Name` for library types; foreign types (android/…, java/…) keep their full name.
  final List<String> supertypes;
  final List<KotlinMember> members = [];

  String get qualifiedName => '$pkg/$binaryName';
  bool get isEnum => supertypes.contains('java/lang/Enum');

  /// Scored method names declared more than once (overloads): such a `getFoo()` / `isFoo()` / `setFoo(x)` is an
  /// overload of the method `getFoo` / `isFoo` / `setFoo`, not a property accessor.
  late final Set<String> overloaded = () {
    final seen = <String>{};
    return {
      for (final m in members)
        if (!m.isField && !_skip(m, this) && !seen.add(m.name)) m.name,
    };
  }();
}

final RegExp _classLine = RegExp(
  r'^(public|protected) ((?:[a-z]+ )*)class (\S+)(?: : (.+))? \{$',
);
final RegExp _memberLine = RegExp(
  r'^\t(public|protected) ((?:[a-z]+ )*)(fun|field) (\S+) (.+)$',
);

/// Parses the Kotlin binary-compatibility dump. Throws [FormatException] on a line it does not understand.
List<KotlinClass> parseApiDump(String text) {
  final classes = <KotlinClass>[];
  KotlinClass? current;
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].replaceAll('\r', '');
    if (line.trim().isEmpty) continue;
    if (current == null) {
      final m = _classLine.firstMatch(line);
      if (m == null) {
        throw FormatException(
          'MPChartLib.api line ${i + 1}: expected a class header',
          line,
        );
      }
      final jvm = m.group(3)!;
      if (!jvm.startsWith(kotlinPackagePrefix)) {
        throw FormatException(
          'MPChartLib.api line ${i + 1}: class outside $kotlinPackagePrefix',
          line,
        );
      }
      final rel = jvm.substring(kotlinPackagePrefix.length);
      final slash = rel.lastIndexOf('/');
      current = KotlinClass(
        binaryName: rel.substring(slash + 1),
        pkg: slash < 0 ? '' : rel.substring(0, slash),
        isProtected: m.group(1) == 'protected',
        modifiers: _words(m.group(2)!),
        supertypes: [
          for (final s in (m.group(4) ?? '').split(','))
            if (s.trim().isNotEmpty)
              s.trim().startsWith(kotlinPackagePrefix)
                  ? s.trim().substring(kotlinPackagePrefix.length)
                  : s.trim(),
        ],
      );
      classes.add(current);
    } else if (line == '}') {
      current = null;
    } else {
      final m = _memberLine.firstMatch(line);
      if (m == null) {
        throw FormatException(
          'MPChartLib.api line ${i + 1}: expected a member line',
          line,
        );
      }
      final isField = m.group(3) == 'field';
      final rest = m.group(5)!;
      var params = const <String>[];
      var ret = rest;
      if (!isField) {
        final close = rest.indexOf(')');
        if (!rest.startsWith('(') || close < 0) {
          throw FormatException(
            'MPChartLib.api line ${i + 1}: bad method descriptor',
            line,
          );
        }
        params = _jvmTypes(rest.substring(1, close));
        ret = rest.substring(close + 1);
      }
      current.members.add(
        KotlinMember(
          name: m.group(4)!,
          isField: isField,
          modifiers: _words(m.group(2)!),
          isProtected: m.group(1) == 'protected',
          params: params,
          returnType: ret,
        ),
      );
    }
  }
  if (current != null) {
    throw const FormatException('MPChartLib.api: unterminated class block');
  }
  return classes;
}

Set<String> _words(String s) => {
  for (final w in s.split(' '))
    if (w.isNotEmpty) w,
};

/// Splits a JVM descriptor list such as `IL…;[F` into its types.
List<String> _jvmTypes(String desc) {
  final out = <String>[];
  var i = 0;
  while (i < desc.length) {
    final start = i;
    while (desc[i] == '[') {
      i++;
    }
    if (desc[i] == 'L') {
      i = desc.indexOf(';', i);
      if (i < 0) throw FormatException('bad JVM descriptor', desc);
    }
    i++;
    out.add(desc.substring(start, i));
  }
  return out;
}

// ---------------------------------------------------------------------------------------------------------------
// Dart side
// ---------------------------------------------------------------------------------------------------------------

enum DartDeclarationKind { type, extension, topLevel }

/// A public Dart declaration: a class / mixin / enum / typedef ([DartDeclarationKind.type]), an extension, or the
/// top-level functions and variables of one file.
class DartDeclaration {
  DartDeclaration({
    required this.name,
    required this.kind,
    required this.path,
    Set<String>? members,
    Set<String>? writable,
    List<String>? supertypes,
    this.onType,
  }) : members = members ?? {},
       writable = writable ?? {},
       supertypes = supertypes ?? [];

  /// Type name; the extension name for extensions; empty for [DartDeclarationKind.topLevel].
  final String name;
  final DartDeclarationKind kind;
  final String path;

  /// Public member names: methods, getters, setters, fields, operators (`==`), named constructors, enum constants.
  final Set<String> members;

  /// Members that can be assigned: non-final fields and setters.
  final Set<String> writable;

  /// Names of extended / implemented / mixed-in types.
  final List<String> supertypes;

  /// The extended type of an extension.
  final String? onType;
}

/// Parses every `.dart` file below [dir] (sorted by path).
List<DartDeclaration> collectDartDeclarations(Directory dir) {
  final files = [
    for (final f in dir.listSync(recursive: true))
      if (f is File && f.path.endsWith('.dart')) f,
  ]..sort((a, b) => a.path.compareTo(b.path));
  return [
    for (final f in files)
      ...parseDartSource(f.readAsStringSync(), path: f.path),
  ];
}

/// Parses the public declarations of one Dart file. `_private` names and `@internal` declarations are absent;
/// `@protected` and `@visibleForTesting` ones are public.
List<DartDeclaration> parseDartSource(String content, {required String path}) {
  final unit = parseString(
    content: content,
    path: path,
    throwIfDiagnostics: false,
  ).unit;
  final out = <DartDeclaration>[];
  final topLevel = DartDeclaration(
    name: '',
    kind: DartDeclarationKind.topLevel,
    path: path,
  );
  for (final d in unit.declarations) {
    if (_isInternal(d.metadata)) continue;
    switch (d) {
      case ClassDeclaration():
        final body = d.body;
        out.add(
          _type(
            d.namePart.typeName.lexeme,
            path,
            body is BlockClassBody ? body.members : const <ClassMember>[],
            [
              if (d.extendsClause case final e?) e.superclass,
              ...?d.withClause?.mixinTypes,
              ...?d.implementsClause?.interfaces,
            ],
          ),
        );
      case MixinDeclaration():
        out.add(
          _type(d.name.lexeme, path, d.body.members, [
            ...?d.onClause?.superclassConstraints,
            ...?d.implementsClause?.interfaces,
          ]),
        );
      case EnumDeclaration():
        final decl = _type(d.namePart.typeName.lexeme, path, d.body.members, [
          ...?d.withClause?.mixinTypes,
          ...?d.implementsClause?.interfaces,
        ]);
        for (final c in d.body.constants) {
          if (!_isInternal(c.metadata) && !c.name.lexeme.startsWith('_')) {
            decl.members.add(c.name.lexeme);
          }
        }
        out.add(decl);
      case ClassTypeAlias():
        out.add(
          _type(d.name.lexeme, path, const [], [
            d.superclass,
            ...d.withClause.mixinTypes,
            ...?d.implementsClause?.interfaces,
          ]),
        );
      case GenericTypeAlias():
        out.add(_type(d.name.lexeme, path, const [], const []));
      case FunctionTypeAlias():
        out.add(_type(d.name.lexeme, path, const [], const []));
      case ExtensionDeclaration():
        // An unnamed extension is only visible in its own library, like a private one.
        final name = d.name?.lexeme ?? '';
        final on = d.onClause?.extendedType;
        if (name.isEmpty || name.startsWith('_') || on is! NamedType) continue;
        final ext = _type(name, path, d.body.members, const []);
        out.add(
          DartDeclaration(
            name: name,
            kind: DartDeclarationKind.extension,
            path: path,
            members: ext.members,
            writable: ext.writable,
            onType: on.name.lexeme,
          ),
        );
      case FunctionDeclaration():
        final name = d.name.lexeme;
        if (!name.startsWith('_')) {
          topLevel.members.add(name);
          if (d.isSetter) topLevel.writable.add(name);
        }
      case TopLevelVariableDeclaration():
        for (final v in d.variables.variables) {
          if (v.name.lexeme.startsWith('_')) continue;
          topLevel.members.add(v.name.lexeme);
          if (!d.variables.isFinal && !d.variables.isConst) {
            topLevel.writable.add(v.name.lexeme);
          }
        }
      default:
        break; // extension types and anything newer: not used by the port
    }
  }
  return [
    ...out.where((d) => !d.name.startsWith('_')),
    if (topLevel.members.isNotEmpty) topLevel,
  ];
}

DartDeclaration _type(
  String name,
  String path,
  List<ClassMember> body,
  List<NamedType> supertypes,
) {
  final decl = DartDeclaration(
    name: name,
    kind: DartDeclarationKind.type,
    path: path,
    supertypes: [for (final t in supertypes) t.name.lexeme],
  );
  for (final m in body) {
    if (_isInternal(m.metadata)) continue;
    switch (m) {
      case MethodDeclaration():
        final n = m.name.lexeme;
        if (n.startsWith('_')) continue;
        decl.members.add(n);
        if (m.isSetter) decl.writable.add(n);
      case FieldDeclaration():
        for (final v in m.fields.variables) {
          final n = v.name.lexeme;
          if (n.startsWith('_')) continue;
          decl.members.add(n);
          if (!m.fields.isFinal && !m.fields.isConst) decl.writable.add(n);
        }
      case ConstructorDeclaration():
        final n = m.name?.lexeme;
        if (n != null && !n.startsWith('_')) decl.members.add(n);
      default:
        break;
    }
  }
  return decl;
}

bool _isInternal(List<Annotation> metadata) =>
    metadata.any((a) => a.name.name.split('.').last == 'internal');

/// Name lookup over the Dart declarations, with members inherited through extends / with / implements / on and
/// extension members added to their extended type.
class DartIndex {
  DartIndex(Iterable<DartDeclaration> declarations) {
    for (final d in declarations) {
      switch (d.kind) {
        case DartDeclarationKind.type:
          final existing = _types[d.name];
          // The widget layer reuses core names (LineChart): a declaration outside widgets/ wins.
          if (existing == null ||
              (_isWidget(existing.path) && !_isWidget(d.path))) {
            _types[d.name] = d;
          }
        case DartDeclarationKind.extension:
          _extensions.putIfAbsent(d.onType!, () => []).add(d);
          _extensionsByName[d.name] = d;
        case DartDeclarationKind.topLevel:
          topLevel.addAll(d.members);
      }
    }
  }

  final Map<String, DartDeclaration> _types = {};
  final Map<String, List<DartDeclaration>> _extensions = {};
  final Map<String, DartDeclaration> _extensionsByName = {};
  final Set<String> topLevel = {};
  final Map<String, (Set<String>, Set<String>)> _cache = {};

  static bool _isWidget(String path) =>
      path.replaceAll(r'\', '/').contains('/widgets/');

  bool hasType(String name) => _types.containsKey(name);

  /// Whether [name] is a public type or a named extension, and [member] (if given) one of its members.
  bool hasDeclaration(String name, [String? member]) {
    if (hasType(name)) {
      return member == null || membersOf(name).contains(member);
    }
    final ext = _extensionsByName[name];
    return ext != null && (member == null || ext.members.contains(member));
  }

  /// All member names of [type] including inherited and extension members.
  Set<String> membersOf(String type) => _resolve(type).$1;

  /// The assignable subset of [membersOf].
  Set<String> writableOf(String type) => _resolve(type).$2;

  (Set<String>, Set<String>) _resolve(String type, [Set<String>? visiting]) {
    final cached = _cache[type];
    if (cached != null) return cached;
    visiting ??= {};
    final members = <String>{};
    final writable = <String>{};
    if (!visiting.add(type)) return (members, writable);
    final d = _types[type];
    if (d != null) {
      members.addAll(d.members);
      writable.addAll(d.writable);
      for (final s in d.supertypes) {
        final (m, w) = _resolve(s, visiting);
        members.addAll(m);
        writable.addAll(w);
      }
    }
    for (final e in _extensions[type] ?? const <DartDeclaration>[]) {
      members.addAll(e.members);
      writable.addAll(e.writable);
    }
    visiting.remove(type);
    return _cache[type] = (members, writable);
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Whitelist
// ---------------------------------------------------------------------------------------------------------------

/// tool/api_whitelist.yaml: `symbols:` = Kotlin symbols deliberately not ported (each with a one-sentence reason);
/// `additions:` = Dart-only public API with no MPChartLib.api counterpart (listed for review, never scored).
///
/// Only this YAML subset is read (no package:yaml dependency): top-level `symbols:` / `additions:` keys, entries
/// `  - symbol: <name>` followed by `    reason: <text>`, `#` comment lines. Values are plain scalars without `: ` or
/// ` #`, or are wrapped in double quotes.
class Whitelist {
  const Whitelist._(this.symbols, this.additions);

  /// Kotlin symbol (`Class` or `Class.member`, as printed by this tool) → reason.
  final Map<String, String> symbols;

  /// Dart symbol (`Type` or `Type.member`) → reason.
  final Map<String, String> additions;

  static const Whitelist empty = Whitelist._({}, {});

  factory Whitelist.parse(String text) {
    final sections = {
      'symbols': <String, String>{},
      'additions': <String, String>{},
    };
    Map<String, String>? section;
    String? pending;
    int? pendingLine;
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].replaceAll('\r', '').trimRight();
      final where = 'api_whitelist.yaml line ${i + 1}';
      if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
      final key = RegExp(r'^([a-z_]+):$').firstMatch(line);
      final symbol = RegExp(r'^  - symbol: (.+)$').firstMatch(line);
      final reason = RegExp(r'^    reason: (.+)$').firstMatch(line);
      if (key != null) {
        if (pending != null) {
          throw FormatException(
            'api_whitelist.yaml line $pendingLine: "$pending" has no reason',
          );
        }
        section = sections[key.group(1)];
        if (section == null) {
          throw FormatException('$where: unknown section "${key.group(1)}"');
        }
      } else if (symbol != null) {
        if (section == null) {
          throw FormatException('$where: entry outside a section');
        }
        if (pending != null) {
          throw FormatException(
            'api_whitelist.yaml line $pendingLine: "$pending" has no reason',
          );
        }
        pending = _scalar(symbol.group(1)!, where);
        pendingLine = i + 1;
        if (section.containsKey(pending)) {
          throw FormatException('$where: duplicate entry "$pending"');
        }
      } else if (reason != null) {
        if (pending == null || section == null) {
          throw FormatException('$where: reason without a symbol');
        }
        section[pending] = _scalar(reason.group(1)!, where);
        pending = null;
      } else {
        throw FormatException('$where: unexpected line', line);
      }
    }
    if (pending != null) {
      throw FormatException(
        'api_whitelist.yaml line $pendingLine: "$pending" has no reason',
      );
    }
    return Whitelist._(sections['symbols']!, sections['additions']!);
  }

  static String _scalar(String raw, String where) {
    final v = raw.trim();
    if (v.startsWith('"')) {
      if (v.length < 2 || !v.endsWith('"')) {
        throw FormatException('$where: unterminated quoted value', v);
      }
      return v
          .substring(1, v.length - 1)
          .replaceAll(r'\"', '"')
          .replaceAll(r'\\', r'\');
    }
    if (v.contains(': ') ||
        v.contains(' #') ||
        RegExp(r'''^[-?:,\[\]{}#&*!|>'%@`]''').hasMatch(v)) {
      throw FormatException(
        '$where: quote this value to keep the file valid YAML',
        v,
      );
    }
    return v;
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Parity
// ---------------------------------------------------------------------------------------------------------------

enum ParityStatus { present, whitelisted, missing }

/// One scored Kotlin symbol: a class (`member == null`) or a member (property or method; overloads collapsed).
class ParitySymbol {
  ParitySymbol._({
    required this.kotlinClass,
    required String? member,
    required this.kotlinFile,
    required this.dartType,
    required this.isProtected,
    required bool isProperty,
  }) : _member = member,
       _isProperty = isProperty;

  /// Kotlin class as written in Kotlin source (`Legend.LegendForm`); companion members belong to the outer class,
  /// top-level functions to their file facade (`EntryKt`).
  final String kotlinClass;

  /// Kotlin member name as printed (property `foo`, method `foo`); a method that shares its name with a property of
  /// the same class is `foo()`. Null for the class symbol.
  String? get member => _member;
  String? _member;

  /// Source file of the class below MPChartLib's package root, e.g. `components/Legend.kt` (Appendix A column 1).
  final String kotlinFile;

  /// Dart type the class maps to; empty for file facades (top-level functions).
  final String dartType;
  bool isProtected;

  final Set<String> _read = {};
  final Set<String> _write = {};
  final Set<String> _names = {};
  bool _hasGetter = false;
  bool _hasSetter = false;
  final bool _isProperty;

  late ParityStatus status;

  /// The matched Dart symbol (present only), e.g. `Chart.toImage`.
  String? dartName;

  /// Whitelist reason (whitelisted only).
  String? reason;

  String get key => member == null ? kotlinClass : '$kotlinClass.$member';
}

class ParityReport {
  ParityReport._(
    this.symbols,
    this.staleWhitelist,
    this.whitelistedButPresent,
    this.missingAdditions,
    this.unusedRenames,
    this.additions,
    this.missingRenameTargets,
    this.propertyMethodClashes,
  );

  /// Scored symbols in dump order.
  final List<ParitySymbol> symbols;

  /// Whitelist entries that name no Kotlin symbol of the dump.
  final List<String> staleWhitelist;

  /// Whitelist entries whose symbols are all present in Dart (the entry is unnecessary).
  final List<String> whitelistedButPresent;

  /// `additions:` entries that do not exist in Dart.
  final List<String> missingAdditions;

  /// [memberRenames] keys that name no Kotlin symbol of the dump.
  final List<String> unusedRenames;

  /// Dart-only additions from the whitelist (not scored).
  final Map<String, String> additions;

  /// [memberRenames] targets that do not exist in Dart, as `Class.member -> target`.
  final List<String> missingRenameTargets;

  /// Keys of the Kotlin methods that share their name with a Kotlin property of the same class (whole dump); they
  /// are scored apart from the property as `Class.name()`.
  final List<String> propertyMethodClashes;

  List<ParitySymbol> get present => [
    ...symbols.where((s) => s.status == ParityStatus.present),
  ];
  List<ParitySymbol> get whitelisted => [
    ...symbols.where((s) => s.status == ParityStatus.whitelisted),
  ];
  List<ParitySymbol> get missing => [
    ...symbols.where((s) => s.status == ParityStatus.missing),
  ];

  int get total => symbols.length;
  int get covered =>
      symbols.where((s) => s.status != ParityStatus.missing).length;

  /// The CLI's exit code under `--fail-on-missing` (without it the CLI exits 0).
  int get exitCode => missing.isEmpty ? 0 : 1;

  String get coverageLine => 'coverage: ${_ratio(symbols)}';

  /// [coverageLine] over the symbols whose [ParitySymbol.kotlinFile] is in [kotlinFiles].
  String coverageLineFor(Set<String> kotlinFiles) =>
      'coverage: ${_ratioFor(kotlinFiles)}';

  String _ratioFor(Set<String> kotlinFiles) =>
      _ratio(symbols.where((s) => kotlinFiles.contains(s.kotlinFile)));

  /// `<covered>/<total> (<pct>%)`; an empty set counts as fully covered.
  static String _ratio(Iterable<ParitySymbol> scored) {
    final total = scored.length;
    final covered = scored
        .where((s) => s.status != ParityStatus.missing)
        .length;
    final pct = total == 0 ? 100.0 : covered * 100 / total;
    return '$covered/$total (${pct.toStringAsFixed(1)}%)';
  }

  /// Hygiene warnings (stale or unnecessary whitelist entries, unknown renames, absent additions).
  List<String> get warnings => [
    for (final s in staleWhitelist)
      'whitelist entry matches no Kotlin symbol: $s',
    for (final s in whitelistedButPresent)
      'whitelist entry is unnecessary (present in Dart): $s',
    for (final s in missingAdditions) 'additions entry not found in Dart: $s',
    for (final s in unusedRenames) 'rename key matches no Kotlin symbol: $s',
    for (final s in missingRenameTargets) 'rename target not found in Dart: $s',
  ];

  /// Plain-text report: present / whitelisted / missing, last line [coverageLine]. A non-empty [byLane] (lane →
  /// Kotlin files, in print order) adds a `by lane:` section of `  <lane>: <covered>/<total> (<pct>%)` lines right
  /// before the last line.
  String format({String? header, Map<String, Set<String>>? byLane}) {
    final b = StringBuffer();
    if (header != null) b.writeln(header);
    final present = this.present;
    b.writeln('present (${present.length}):');
    for (final s in present) {
      b.writeln('  ${s.key}${s.dartName != s.key ? '  -> ${s.dartName}' : ''}');
    }
    final whitelisted = this.whitelisted;
    b.writeln('whitelisted (${whitelisted.length}):');
    for (final s in whitelisted) {
      b.writeln('  ${s.key}  -- ${s.reason}');
    }
    final missing = this.missing;
    b.writeln('missing (${missing.length}):');
    for (final s in missing) {
      b.writeln('  ${s.key}${s.isProtected ? '  (protected)' : ''}');
    }
    if (byLane != null && byLane.isNotEmpty) {
      b.writeln('by lane:');
      for (final e in byLane.entries) {
        b.writeln('  ${e.key}: ${_ratioFor(e.value)}');
      }
    }
    b.writeln(coverageLine);
    return b.toString();
  }

  /// Markdown report for docs/ (review artefact; spec §5.3 has the whitelist reviewed with it). A non-empty
  /// [byLane] adds a `## By lane` section (`- <lane>: <covered>/<total> (<pct>%)`) right before the last line.
  String markdown({
    required String title,
    required String command,
    required String scopeNote,
    Map<String, Set<String>>? byLane,
  }) {
    final b = StringBuffer()
      ..writeln('# $title')
      ..writeln()
      ..writeln(
        'Generated by `$command` — do not edit by hand, rerun the command instead.',
      )
      ..writeln()
      ..writeln(
        '- Kotlin side: `tool/MPChartLib.api`, the binary-compatibility dump of MPAndroidChart v4.0.1.',
      )
      ..writeln(
        '- Dart side: public declarations under `lib/src`, parsed with `package:analyzer`.',
      )
      ..writeln(
        '- Whitelist (deliberate omissions, one reason each): `tool/api_whitelist.yaml`.',
      )
      ..writeln('- Scope: $scopeNote')
      ..writeln()
      ..writeln(
        '**`$coverageLine`** — present ${present.length}, whitelisted ${whitelisted.length}, '
        'missing ${missing.length}.',
      )
      ..writeln()
      ..writeln('## Counting rules')
      ..writeln()
      ..writeln(
        '- One symbol per Kotlin class and one per member name: overloads collapse; a JVM getter/setter pair '
        '(`getFoo()`/`setFoo(x)`, `isFoo()`/`setFoo(x)`) is the Kotlin property `foo` / `isFoo`. An overloaded '
        '`getFoo()` is a property getter only next to a single `setFoo(x)` (ChartData `yMax` vs `getYMax(axis)`); '
        'otherwise it is one method symbol with its overloads (MPPointF `getInstance`). A property and a method '
        'of the same name in one class stay two symbols, the method keyed `name()`'
        '${propertyMethodClashes.isEmpty ? '' : ' (${propertyMethodClashes.map((k) => '`$k`').join(', ')})'}.',
      )
      ..writeln(
        '- JVM getters lose the case of the first letter: `getFoo()` prints as `foo` (all-caps names such as '
        '`COLORFUL_COLORS` stay), and `→` shows the Dart spelling where it differs (`Easing.easeInBack` → '
        '`Easing.EaseInBack`, the Kotlin name).',
      )
      ..writeln(
        '- A property is present when Dart can read it (field/getter `foo`, the capitalised `Foo`, or a '
        '`getFoo()` method) and, when Kotlin has a setter, write it (non-final field, setter, or `setFoo` method).',
      )
      ..writeln(
        '- Companion members count on the outer class; nested types use their top-level Dart name; '
        '`equals` is Dart `==`; members inherited in Dart (extends/implements/with) and members of named '
        'extensions count; `@internal` Dart members and unnamed (library-private) extensions do not.',
      )
      ..writeln(
        '- A member listed in the rename table (`memberRenames` in `tool/api_parity.dart`) is present only when '
        'every Dart name listed for it exists; `→` shows them joined with `/`, the Kotlin name included when Dart '
        'kept it for some overloads.',
      )
      ..writeln(
        '- Not scored: constructors (`<init>`), `synthetic` and `\$`-mangled members, `INSTANCE` / '
        '`Companion` fields, enum `values`/`valueOf`/`getEntries`, `DefaultImpls`, Kotlin top-level '
        'pseudo-constructors (`EntryKt.Entry`). `protected` members are scored (the port keeps them `@protected`).',
      )
      ..writeln();

    final byClass = <String, List<ParitySymbol>>{};
    for (final s in symbols) {
      byClass.putIfAbsent(s.kotlinClass, () => []).add(s);
    }
    b
      ..writeln('## Per class')
      ..writeln()
      ..writeln(
        '| Kotlin class | Kotlin file | Dart type | present | whitelisted | missing |',
      )
      ..writeln('|---|---|---|---:|---:|---:|');
    for (final e in byClass.entries) {
      int count(ParityStatus st) => e.value.where((s) => s.status == st).length;
      final dart = e.value.first.dartType;
      b.writeln(
        '| `${e.key}` | `${e.value.first.kotlinFile}` | ${dart.isEmpty ? '(top level)' : '`$dart`'} | '
        '${count(ParityStatus.present)} | ${count(ParityStatus.whitelisted)} | ${count(ParityStatus.missing)} |',
      );
    }

    final missingList = missing;
    b
      ..writeln()
      ..writeln('## Missing (${missingList.length})')
      ..writeln();
    if (missingList.isEmpty) b.writeln('None.');
    for (final s in missingList) {
      b.writeln('- `${s.key}`${s.isProtected ? ' (protected)' : ''}');
    }

    final whitelistedList = whitelisted;
    b
      ..writeln()
      ..writeln('## Whitelisted (${whitelistedList.length})')
      ..writeln()
      ..writeln('| Kotlin symbol | reason |')
      ..writeln('|---|---|');
    for (final s in whitelistedList) {
      b.writeln('| `${s.key}` | ${s.reason!.replaceAll('|', r'\|')} |');
    }

    b
      ..writeln()
      ..writeln('## Dart-only additions (${additions.length}, not scored)')
      ..writeln()
      ..writeln('| Dart symbol | reason |')
      ..writeln('|---|---|');
    for (final e in additions.entries) {
      b.writeln('| `${e.key}` | ${e.value.replaceAll('|', r'\|')} |');
    }

    final presentList = present;
    b
      ..writeln()
      ..writeln('## Present (${presentList.length})')
      ..writeln()
      ..writeln(
        '<details><summary>${presentList.length} symbols (Kotlin → Dart where the names differ)</summary>',
      )
      ..writeln();
    for (final s in presentList) {
      b.writeln(
        '- `${s.key}`${s.dartName != s.key ? ' → `${s.dartName}`' : ''}',
      );
    }
    b
      ..writeln()
      ..writeln('</details>');
    final warnings = this.warnings;
    if (warnings.isNotEmpty) {
      b
        ..writeln()
        ..writeln('## Warnings')
        ..writeln();
      for (final w in warnings) {
        b.writeln('- $w');
      }
    }
    if (byLane != null && byLane.isNotEmpty) {
      b
        ..writeln()
        ..writeln('## By lane')
        ..writeln();
      for (final e in byLane.entries) {
        b.writeln('- ${e.key}: ${_ratioFor(e.value)}');
      }
    }
    b
      ..writeln()
      ..writeln('`$coverageLine`');
    return b.toString();
  }
}

/// Compares [apiDump] (MPChartLib.api text) with [dart] declarations.
///
/// [scopeFiles] restricts scoring to classes whose Kotlin source file (e.g. `charts/Chart.kt`) is in the set;
/// whitelist hygiene ([ParityReport.staleWhitelist], [ParityReport.whitelistedButPresent]) is always judged over the
/// whole dump so that entries for out-of-scope classes are neither stale nor unnecessary.
ParityReport computeParity(
  String apiDump,
  Iterable<DartDeclaration> dart,
  Whitelist wl, {
  Set<String>? scopeFiles,
  Map<String, List<String>> renames = memberRenames,
  Map<String, String> nestedTypes = nestedTypeNames,
}) {
  final (symbols, clashes) = _buildSymbols(parseApiDump(apiDump), nestedTypes);
  final index = DartIndex(dart);
  final usedEntries = <String>{};
  for (final s in symbols.values) {
    _resolve(s, index, renames[s.key]);
    if (s.status == ParityStatus.present) continue;
    final entry = wl.symbols.containsKey(s.key)
        ? s.key
        : (wl.symbols.containsKey(s.kotlinClass) ? s.kotlinClass : null);
    if (entry != null) {
      s
        ..status = ParityStatus.whitelisted
        ..reason = wl.symbols[entry];
      usedEntries.add(entry);
    }
  }
  final classKeys = {for (final s in symbols.values) s.kotlinClass};
  bool known(String key) => symbols.containsKey(key) || classKeys.contains(key);
  return ParityReport._(
    [
      ...symbols.values.where(
        (s) => scopeFiles == null || scopeFiles.contains(s.kotlinFile),
      ),
    ],
    [...wl.symbols.keys.where((k) => !known(k))],
    [...wl.symbols.keys.where((k) => known(k) && !usedEntries.contains(k))],
    [
      ...wl.additions.keys.where((k) {
        final dot = k.indexOf('.');
        return dot < 0
            ? !index.hasDeclaration(k)
            : !index.hasDeclaration(k.substring(0, dot), k.substring(dot + 1));
      }),
    ],
    [...renames.keys.where((k) => !symbols.containsKey(k))],
    wl.additions,
    [
      for (final e in renames.entries)
        if (symbols[e.key] case final s?)
          for (final t in e.value)
            if (!_has(index, s.dartType, t)) '${e.key} -> $t',
    ],
    clashes,
  );
}

/// Whether Dart type [dartType] (top level when empty) has member [name], inherited and extension members included.
bool _has(DartIndex index, String dartType, String name) => dartType.isEmpty
    ? index.topLevel.contains(name)
    : index.hasType(dartType) && index.membersOf(dartType).contains(name);

/// Sets [ParitySymbol.status] / [ParitySymbol.dartName]. A symbol with a rename entry ([renamed]) is present only
/// when every listed Dart name exists (the Kotlin name itself counts only when the entry lists it), and a renamed
/// property with a Kotlin setter needs each name writable.
void _resolve(ParitySymbol s, DartIndex index, List<String>? renamed) {
  String? hit;
  if (s.member == null) {
    if (index.hasType(s.dartType)) hit = s.dartType;
  } else if (renamed != null) {
    final writable = s.dartType.isEmpty
        ? index.topLevel
        : index.writableOf(s.dartType);
    final ok = renamed.every(
      (n) =>
          _has(index, s.dartType, n) &&
          (!s._isProperty ||
              !s._hasSetter ||
              writable.contains(n) ||
              _has(index, s.dartType, 'set${_cap(n)}')),
    );
    if (ok) {
      hit = s.dartType.isEmpty
          ? renamed.join('/')
          : '${s.dartType}.${renamed.join('/')}';
    }
  } else if (s.dartType.isEmpty) {
    hit = s._names.where(index.topLevel.contains).firstOrNull;
  } else if (index.hasType(s.dartType)) {
    final members = index.membersOf(s.dartType);
    final writable = index.writableOf(s.dartType);
    if (!s._isProperty) {
      hit = s._names.where(members.contains).firstOrNull;
    } else {
      final read = s._read.where(members.contains).firstOrNull;
      final canWrite = s._write.any(
        (n) =>
            writable.contains(n) ||
            (n.startsWith('set') && members.contains(n)),
      );
      if ((!s._hasGetter || read != null) && (!s._hasSetter || canWrite)) {
        hit = read ?? s._write.firstWhere(members.contains);
      }
    }
    if (hit != null) hit = '${s.dartType}.$hit';
  }
  s
    ..status = hit == null ? ParityStatus.missing : ParityStatus.present
    ..dartName = hit;
}

/// Scored symbols by key, plus the keys of the methods split off a same-named property
/// ([ParityReport.propertyMethodClashes]).
(Map<String, ParitySymbol>, List<String>) _buildSymbols(
  List<KotlinClass> classes,
  Map<String, String> nestedTypes,
) {
  final byName = {for (final c in classes) c.qualifiedName: c};
  final simpleNames = {for (final c in classes) c.binaryName.split(r'$').last};
  // Keyed by kind and printed key: getter/setter/field folds (`p:`) never merge with methods (`m:`) of the same
  // name, e.g. YAxisRenderer's `getRenderLimitLines(): Path` and `renderLimitLines(Canvas)`.
  final out = <String, ParitySymbol>{};

  // Property identities (`P:Foo` for getFoo/fields, `is:isFoo`) visible in a class, including Kotlin supertypes.
  final propCache = <String, Set<String>>{};
  Set<String> props(KotlinClass c) => propCache[c.qualifiedName] ??= {
    for (final m in c.members)
      if (_skip(m, c))
        ...const <String>[]
      else if (_getterShape(m) case final raw?)
        'P:$raw'
      else if (_isGetterShape(m))
        'is:${m.name}'
      else if (m.isField)
        'P:${_cap(m.name)}',
    for (final s in c.supertypes)
      if (byName[s] case final sup?) ...props(sup),
  };

  String dartTypeOf(String binary) {
    if (!binary.contains(r'$')) return binary;
    return nestedTypes[binary] ?? binary.split(r'$').last;
  }

  for (final c in classes) {
    final binary = c.binaryName;
    if (binary.endsWith(r'$DefaultImpls')) {
      continue; // JVM copies of interface default bodies
    }
    final isCompanion = binary.endsWith(r'$Companion');
    final isFacade =
        !binary.contains(r'$') &&
        binary.endsWith('Kt') &&
        c.members.every((m) => m.isStatic);
    final owner = isCompanion
        ? binary.substring(0, binary.length - r'$Companion'.length)
        : binary;
    final ownerDisplay = owner.replaceAll(r'$', '.');
    final file =
        '${c.pkg}/${isFacade ? owner.substring(0, owner.length - 2) : owner.split(r'$').first}.kt';
    final dartType = isFacade ? '' : dartTypeOf(owner);

    ParitySymbol symbol(
      String? member,
      bool isProtected, {
      bool property = false,
    }) {
      final key =
          '${property ? 'p' : 'm'}:${member == null ? ownerDisplay : '$ownerDisplay.$member'}';
      final existing = out[key];
      if (existing != null) {
        existing.isProtected &= isProtected;
        return existing;
      }
      return out[key] = ParitySymbol._(
        kotlinClass: ownerDisplay,
        member: member,
        kotlinFile: file,
        dartType: dartType,
        isProtected: isProtected,
        isProperty: property,
      );
    }

    if (!isCompanion && !isFacade) symbol(null, c.isProtected);
    final classProps = props(c);
    final fieldNames = {
      for (final m in c.members)
        if (m.isField) _cap(m.name): m.name,
    };

    for (final m in c.members) {
      if (_skip(m, c)) continue;
      if (isFacade) {
        if (m.name == owner.substring(0, owner.length - 2) ||
            simpleNames.contains(m.name)) {
          continue;
        }
        symbol(m.name, m.isProtected)._names.add(m.name);
        continue;
      }
      final raw = _getterShape(m);
      final setterRaw = _isSetterShape(m) && !c.overloaded.contains(m.name)
          ? m.name.substring(3)
          : null;
      if (m.isField || (raw != null && _isAccessor(m, c, 'set$raw'))) {
        final r = raw ?? _cap(m.name);
        final s = symbol(
          fieldNames[r] ?? _propertyLabel(r),
          m.isProtected,
          property: true,
        ).._hasGetter = true;
        s._read.addAll([?fieldNames[r], _decap(r), r, if (!m.isField) m.name]);
        if (m.isField && !m.modifiers.contains('final')) {
          s
            .._hasSetter = true
            .._write.addAll([m.name, 'set$r']);
        }
      } else if (raw != null) {
        // An overloaded getFoo(): one method symbol with its other overloads; a Dart getter `foo` also matches.
        symbol(m.name, m.isProtected)._names.addAll([m.name, _decap(raw), raw]);
      } else if (_isGetterShape(m) &&
          _isAccessor(m, c, 'set${m.name.substring(2)}')) {
        (symbol(
          m.name,
          m.isProtected,
          property: true,
        ).._hasGetter = true)._read.add(m.name);
      } else if (setterRaw != null && classProps.contains('is:is$setterRaw')) {
        (symbol(
          'is$setterRaw',
          m.isProtected,
          property: true,
        ).._hasSetter = true)._write.addAll(['is$setterRaw', m.name]);
      } else if (setterRaw != null && classProps.contains('P:$setterRaw')) {
        final r = setterRaw;
        (symbol(
          fieldNames[r] ?? _propertyLabel(r),
          m.isProtected,
          property: true,
        ).._hasSetter = true)._write.addAll([
          ?fieldNames[r],
          _decap(r),
          r,
          m.name,
        ]);
      } else {
        symbol(
          m.name,
          m.isProtected,
        )._names.add(m.name == 'equals' ? '==' : m.name);
      }
    }
  }
  final result = <String, ParitySymbol>{};
  final clashes = <String>[];
  for (final s in out.values) {
    if (!s._isProperty &&
        s.member != null &&
        out.containsKey('p:${s.kotlinClass}.${s.member}')) {
      s._member = '${s.member}()';
      clashes.add(s.key);
    }
    result[s.key] = s;
  }
  return (result, clashes);
}

bool _skip(KotlinMember m, KotlinClass c) {
  final n = m.name;
  if (m.modifiers.contains('synthetic')) return true;
  if (n.startsWith('<') || n.contains(r'$') || n.contains('-')) {
    return true; // <init>, $default, access$, mangled
  }
  if (m.isField && m.isStatic && (n == 'INSTANCE' || n == 'Companion')) {
    return true;
  }
  if (!m.isField && RegExp(r'^component\d+$').hasMatch(n)) return true;
  if (c.isEnum &&
      m.isStatic &&
      !m.isField &&
      (n == 'values' || n == 'valueOf' || n == 'getEntries')) {
    return true;
  }
  return false;
}

/// `getFoo()`: no parameters and a result → `Foo`.
String? _getterShape(KotlinMember m) {
  final n = m.name;
  if (m.isField || m.params.isNotEmpty || m.returnType == 'V') return null;
  if (n.length > 3 && n.startsWith('get') && _isUpper(n.codeUnitAt(3))) {
    return n.substring(3);
  }
  return null;
}

/// `isFoo()` returning boolean.
bool _isGetterShape(KotlinMember m) =>
    !m.isField &&
    m.params.isEmpty &&
    m.returnType == 'Z' &&
    m.name.length > 2 &&
    m.name.startsWith('is') &&
    _isUpper(m.name.codeUnitAt(2));

/// `setFoo(x)` returning void.
bool _isSetterShape(KotlinMember m) =>
    !m.isField &&
    m.params.length == 1 &&
    m.returnType == 'V' &&
    m.name.length > 3 &&
    m.name.startsWith('set') &&
    _isUpper(m.name.codeUnitAt(3));

/// Whether a get/is-shaped [m] is a property getter. Not when the name is overloaded (MPPointF's `getInstance()` next
/// to `getInstance(x, y)` is a method), unless the class also declares a single `setFoo(x)` [setter] — Kotlin
/// `val foo` next to `fun getFoo(arg)`, e.g. ChartData's `yMax` and `getYMax(axis)`.
bool _isAccessor(KotlinMember m, KotlinClass c, String setter) =>
    !c.overloaded.contains(m.name) ||
    (!c.overloaded.contains(setter) &&
        c.members.any((o) => o.name == setter && _isSetterShape(o)));

bool _isUpper(int c) => c >= 0x41 && c <= 0x5A;
String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
String _decap(String s) => s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

/// Kotlin property name for the getter suffix [raw]: `XAxis` → `xAxis`; all-caps constants (`COLORFUL_COLORS`)
/// keep their spelling.
String _propertyLabel(String raw) =>
    raw.length > 1 && !raw.contains(RegExp('[a-z]')) ? raw : _decap(raw);

// ---------------------------------------------------------------------------------------------------------------
// Scope (spec Appendix A)
// ---------------------------------------------------------------------------------------------------------------

final RegExp _laneRow = RegExp(
  r'^\|\s*`([^`]+\.kt)`\s*\|\s*`[^`]*`\s*\|\s*\d+\s*\|\s*(P[0-9A-Z-]*)\s*\|\s*$',
);

/// Kotlin file (`charts/Chart.kt`) → lane (`P0`, `P1-A`, …) from the spec's Appendix A table.
Map<String, String> parseLanes(String spec) => {
  for (final line in spec.split('\n'))
    if (_laneRow.firstMatch(line.trimRight()) case final m?)
      m.group(1)!: m.group(2)!,
};

Set<String> filesInLane(Map<String, String> lanes, String lane) => {
  for (final e in lanes.entries)
    if (e.value == lane) e.key,
};

/// The Kotlin files of every lane in [laneNames] (union of [filesInLane]).
Set<String> filesInLanes(
  Map<String, String> lanes,
  Iterable<String> laneNames,
) {
  final wanted = laneNames.toSet();
  return {
    for (final e in lanes.entries)
      if (wanted.contains(e.value)) e.key,
  };
}

/// The lanes named by a `--scope=` value: split at `,`, trimmed, empty items and repeats dropped. `all` alone →
/// null (score the whole dump). Throws [FormatException] when no lane is left or `all` is combined with lanes.
List<String>? parseScopeArg(String value) {
  final lanes = {
    for (final l in value.split(','))
      if (l.trim().isNotEmpty) l.trim(),
  }.toList();
  if (lanes.isEmpty) {
    throw FormatException(
      '--scope="$value" names no lane (expected <lane>[,<lane>…] or all)',
    );
  }
  if (lanes.contains('all')) {
    if (lanes.length == 1) return null;
    throw FormatException(
      '--scope="$value": all cannot be combined with other lanes',
    );
  }
  return lanes;
}

// ---------------------------------------------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------------------------------------------

const String _specPath = 'tool/api_scope.md';
const String _phase0Markdown = 'docs/api-parity-phase0.md';
const String _notInAppendixA = '(not in Appendix A)';
const String _usage =
    'usage: dart run tool/api_parity.dart [--scope=<lane>[,<lane>…]|all] [--fail-on-missing] [--markdown[=<path>]]\n'
    '  --scope=P0         score only classes whose Kotlin file is in that lane of spec Appendix A\n'
    '  --scope=P1-A,P1-B  score the union of several lanes; prints a "by lane:" coverage section\n'
    '  --scope=all        score the whole dump; "by lane:" lists every Appendix A lane and the unmapped classes\n'
    '  --fail-on-missing  exit 1 when a symbol is missing (default: report only, exit 0)\n'
    '  --markdown[=path]  also write a Markdown report; without a path: $_phase0Markdown for P0,\n'
    '                     docs/api-parity-<lanes>.md for other lanes (lowercased, joined with -),\n'
    '                     docs/api-parity-all.md for all or no --scope\n';

/// The file a bare `--markdown` writes for the lanes of `--scope` ([laneNames]; null for `all` or no `--scope`):
/// [_phase0Markdown] for P0 alone, otherwise `docs/api-parity-<lanes>.md` with the lanes lowercased and joined with
/// `-` in the order given (repeats dropped), as the report lists them, and `docs/api-parity-all.md` for the whole
/// dump. Each scope gets its own file, so a report of another scope never overwrites the Phase 0 one.
String _defaultMarkdownPath(List<String>? laneNames) {
  if (laneNames == null) return 'docs/api-parity-all.md';
  if (laneNames.length == 1 && laneNames.single == 'P0') return _phase0Markdown;
  return 'docs/api-parity-${laneNames.map((l) => l.toLowerCase()).join('-')}.md';
}

void main(List<String> args) {
  exitCode = runParity(args, Directory.current);
}

/// CLI entry: returns the process exit code (0 report or `--help`, 1 missing symbols under `--fail-on-missing`, 2
/// usage or input error). Relative paths resolve against [root]; [out] / [err] default to stdout / stderr.
int runParity(
  List<String> args,
  Directory root, {
  StringSink? out,
  StringSink? err,
}) {
  out ??= stdout;
  err ??= stderr;
  String? scope; // the --scope value as given
  String? markdown; // the --markdown=<path> value
  var defaultMarkdown = false; // a bare --markdown: the scope's default path
  var failOnMissing = false;
  for (final a in args) {
    if (a.startsWith('--scope=')) {
      scope = a.substring('--scope='.length);
    } else if (a == '--fail-on-missing') {
      failOnMissing = true;
    } else if (a == '--markdown') {
      defaultMarkdown = true;
      markdown = null;
    } else if (a.startsWith('--markdown=')) {
      defaultMarkdown = false;
      markdown = a.substring('--markdown='.length);
    } else {
      if (a == '--help' || a == '-h') {
        out.write(_usage);
        return 0;
      }
      err.write('unknown argument: $a\n$_usage');
      return 2;
    }
  }
  // null with a scope = `all` (the whole dump, every lane listed).
  List<String>? laneNames;
  if (scope != null) {
    try {
      laneNames = parseScopeArg(scope);
    } on FormatException catch (e) {
      err.write('${e.message}\n$_usage');
      return 2;
    }
  }
  File file(String path) =>
      File(path).isAbsolute ? File(path) : File('${root.path}/$path');
  String ioError(FileSystemException e) =>
      '${e.osError?.message ?? e.message}: ${e.path ?? '?'} '
      '(run from the package root; needs tool/MPChartLib.api, tool/api_whitelist.yaml, lib/src and $_specPath)';
  var lanes = const <String, String>{};
  Set<String>? scopeFiles;
  final ParityReport report;
  try {
    if (scope != null) {
      lanes = parseLanes(file(_specPath).readAsStringSync());
      for (final lane in laneNames ?? const <String>[]) {
        if (filesInLane(lanes, lane).isEmpty) {
          err.writeln(
            'no Kotlin files in lane "$lane" of $_specPath (Appendix A)',
          );
          return 2;
        }
      }
      if (laneNames != null) scopeFiles = filesInLanes(lanes, laneNames);
    }
    report = computeParity(
      file('tool/MPChartLib.api').readAsStringSync(),
      collectDartDeclarations(Directory('${root.path}/lib/src')),
      Whitelist.parse(file('tool/api_whitelist.yaml').readAsStringSync()),
      scopeFiles: scopeFiles,
    );
  } on FileSystemException catch (e) {
    err.writeln(ioError(e));
    return 2;
  } on FormatException catch (e) {
    err.writeln(e);
    return 2;
  }
  // A lane list or `all` gets per-lane coverage; `all` lists every Appendix A lane (P0, P1-A, …, P2) and the dump
  // classes whose Kotlin file has no row.
  Map<String, Set<String>>? byLane;
  if (scope != null && (laneNames == null || laneNames.length > 1)) {
    final unmapped = laneNames != null
        ? const <String>{}
        : {
            for (final s in report.symbols) s.kotlinFile,
          }.difference(lanes.keys.toSet());
    byLane = {
      for (final lane in laneNames ?? (lanes.values.toSet().toList()..sort()))
        lane: filesInLane(lanes, lane),
      if (unmapped.isNotEmpty) _notInAppendixA: unmapped,
    };
  }
  final classes = report.symbols.map((s) => s.kotlinClass).toSet().length;
  final scopeNote = scope == null
      ? 'all $classes Kotlin classes of the dump'
      : laneNames == null
      ? 'all lanes of spec Appendix A (the whole dump, $classes Kotlin classes)'
      : '${laneNames.length == 1 ? 'lane' : 'lanes'} ${laneNames.join(', ')} of spec Appendix A '
            '(${scopeFiles!.length} Kotlin files, $classes classes in the dump)';
  out.write(
    report.format(
      header: 'API parity: tool/MPChartLib.api vs lib/src — $scopeNote',
      byLane: byLane,
    ),
  );
  for (final w in report.warnings) {
    err.writeln('warning: $w');
  }
  final defaultPath = _defaultMarkdownPath(laneNames);
  if (defaultMarkdown) markdown = defaultPath;
  if (markdown != null) {
    final target = file(markdown);
    try {
      target.parent.createSync(recursive: true);
      target.writeAsStringSync(
        report.markdown(
          title: scope == null
              ? 'API parity'
              : laneNames == null
              ? 'API parity — all lanes'
              : laneNames.length == 1 && laneNames.single == 'P0'
              ? 'API parity — P0 (LineChart core)'
              : 'API parity — ${laneNames.join(', ')}',
          command:
              'dart run tool/api_parity.dart${scope == null ? '' : ' --scope=$scope'} --markdown'
              '${markdown == defaultPath ? '' : '=$markdown'}',
          scopeNote: scopeNote,
          byLane: byLane,
        ),
      );
    } on FileSystemException catch (e) {
      err.writeln(ioError(e));
      return 2;
    }
    err.writeln('wrote ${target.path}');
  }
  return failOnMissing ? report.exitCode : 0;
}
