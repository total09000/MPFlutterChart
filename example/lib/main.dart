// Example app: a home list of sections and entries in the order and with the text of MPChartExample's MainActivity
// (notimportant/MainActivity.kt, MyAdapter.kt), each entry opening one page in the Nightfall style, and the `/design`
// deep link to the All chart types page.
import 'package:flutter/material.dart' hide Easing;

import 'design/nightfall.dart';
import 'pages.dart';
import 'pages/design_page.dart';

void main() => runApp(const ExampleApp());

/// The example app: the home list of [examplePages].
class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'mp_flutter_chart',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      colorSchemeSeed: Nightfall.accent,
      scaffoldBackgroundColor: Nightfall.stage,
    ),
    home: const _HomePage(),
    onGenerateRoute: _onGenerateRoute,
  );
}

/// The deep links: `/design?dark=…&only=…&from=…` opens the All chart types page with DesignActivity's intent extras
/// (`dark` defaults to true, `only` to -1, `from` to 0); any other route is unknown. Flutter's initial routes push the
/// home list below it.
///
/// `adb shell "am start -S -n com.example.mp_flutter_chart_example/.MainActivity --es route '/design?dark=true&only=1'"`
/// (`-S` cold-starts the app: a running FlutterActivity ignores the route extra).
Route<void>? _onGenerateRoute(RouteSettings settings) {
  final uri = Uri.tryParse(settings.name ?? '');
  if (uri == null || uri.path != '/design') return null;
  final q = uri.queryParameters;
  return MaterialPageRoute<void>(
    settings: settings,
    builder: (_) => DesignPage(
      dark: q['dark'] != 'false',
      only: int.tryParse(q['only'] ?? '') ?? -1,
      from: int.tryParse(q['from'] ?? '') ?? 0,
    ),
  );
}

/// The list of [examplePages]: a section is a centred header, an entry its name and description; tapping an entry
/// opens its page.
class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('mp_flutter_chart Example'),
      backgroundColor: Nightfall.card,
      foregroundColor: Nightfall.text,
    ),
    body: ListView.builder(
      itemCount: examplePages.length,
      itemBuilder: (context, index) => switch (examplePages[index]) {
        DemoSection(:final name) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Nightfall.accent, fontSize: 21),
          ),
        ),
        DemoEntry(:final name, :final description, :final builder) => ListTile(
          title: Text(name, style: const TextStyle(color: Nightfall.text)),
          subtitle: Text(
            description,
            style: const TextStyle(color: Nightfall.muted),
          ),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => builder())),
        ),
      },
    ),
  );
}
