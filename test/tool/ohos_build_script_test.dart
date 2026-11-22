// Tests scripts/ohos_build.sh, the HarmonyOS build/install helper (lane D plan Task 1), against
// fake `flutter` and `hdc` executables. No Kotlin counterpart.
//
// Every run is hermetic: the real DevEco Studio, OpenHarmony SDK and ohos flutter on this machine are never seen
// (all paths are set explicitly, the parent environment is not inherited). The script under test is a copy placed in
// `<tmp>/with space/repo/scripts/`, next to a minimal `example/`, so nothing is ever written into the real `example/`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _bundleName = 'com.example.fixture_app';
const _signedHap = 'build/ohos/hap/entry-default-signed.hap';
const _unsignedHap =
    'ohos/entry/build/default/outputs/default/entry-default-unsigned.hap';

void main() {
  // Symlinks resolved (/var -> /private/var on macOS) so expected paths match what the script's `pwd` prints.
  late Directory tmp;
  late Directory elsewhere; // an unrelated working directory
  late String base; // '<tmp>/with space'
  late String
  repo; // '<base>/repo': scripts/ohos_build.sh (copied) + a minimal example/
  late String script;
  late String flutter;
  late String
  sdk; // fake OHOS_SDK_ROOT: api 12 and 20 with hdc, 15 without, 'licenses' not an api
  late String emptySdk;
  late String
  deveco; // fake DEVECO_HOME: sdk/default (api 26) with hdc, tools/{node,ohpm,hvigor}/bin
  late String noDeveco; // an empty DEVECO_HOME
  late File log;

  String calls() => log.existsSync() ? log.readAsStringSync() : '';

  void writeExecutable(String path, String content) {
    File(path)
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
    final chmod = Process.runSync('chmod', ['+x', path]);
    expect(chmod.exitCode, 0, reason: '${chmod.stderr}');
  }

  void writeFile(String path, String content) => File(path)
    ..createSync(recursive: true)
    ..writeAsStringSync(content);

  /// Runs the copied script with `bash`. [env] overrides the base environment; a `null` value removes the variable.
  ProcessResult run(
    List<String> args, {
    Map<String, String?> env = const {},
    String? cwd,
    String? scriptArg,
  }) {
    final environment = <String, String>{
      'PATH': '/usr/bin:/bin:/usr/sbin:/sbin',
      'HOME': '$base/home',
      'OHOS_FLUTTER': flutter,
      'OHOS_SDK_ROOT': sdk,
      'DEVECO_HOME': noDeveco,
    };
    env.forEach(
      (k, v) => v == null ? environment.remove(k) : environment[k] = v,
    );
    return Process.runSync(
      '/bin/bash',
      [scriptArg ?? script, ...args],
      workingDirectory: cwd ?? elsewhere.path,
      environment: environment,
      includeParentEnvironment: false,
    );
  }

  List<String> lines(Object? out) => (out as String).split('\n');

  List<String> toolchainLines(ProcessResult r) => [
    for (final l in lines(r.stdout))
      if (l.startsWith('toolchains: ')) l,
  ];

  String describe(ProcessResult r) =>
      'exit ${r.exitCode}\n--- stdout\n${r.stdout}--- stderr\n${r.stderr}--- calls\n${calls()}';

  setUp(() {
    tmp = Directory(
      Directory.systemTemp
          .createTempSync('ohos_script_test')
          .resolveSymbolicLinksSync(),
    );
    elsewhere = Directory(
      Directory.systemTemp
          .createTempSync('ohos_script_cwd')
          .resolveSymbolicLinksSync(),
    );
    base = '${tmp.path}/with space';
    repo = '$base/repo';
    script = '$repo/scripts/ohos_build.sh';
    flutter = '$base/bin/flutter';
    sdk = '$base/sdk';
    emptySdk = '$base/empty sdk';
    deveco = '$base/deveco';
    noDeveco = '$base/no deveco';
    log = File('$base/calls.log');

    // Throws while scripts/ohos_build.sh does not exist (the RED state of this file).
    Directory('$repo/scripts').createSync(recursive: true);
    File('scripts/ohos_build.sh').copySync(script);

    writeFile('$repo/example/ohos/AppScope/app.json5', '''
{
  "app": {
    "bundleName": "$_bundleName",
    "vendor": "example",
    "versionCode": 1000000
  }
}
''');
    writeFile('$repo/example/ohos/entry/src/main/module.json5', '''
{
  "module": {
    "name": "entry",
    "type": "entry",
    "mainElement": "EntryAbility",
    "abilities": [
      {
        "name": "EntryAbility"
      }
    ]
  }
}
''');

    final fakeHdc =
        '''
#!/bin/bash
echo "hdc \$*" >> '${log.path}'
case "\$*" in
  "list targets") printf '%s\\n' "\${FAKE_TARGETS:-[Empty]}" ;;
  *" install -r "*) if [ "\${FAKE_INSTALL_FAIL:-}" = 1 ]; then echo "[Fail][E005005] install failed"; fi ;;
esac
exit 0
''';
    writeExecutable('$sdk/12/toolchains/hdc', fakeHdc);
    writeExecutable('$sdk/20/toolchains/hdc', fakeHdc);
    Directory('$sdk/15/toolchains').createSync(recursive: true); // no hdc
    writeExecutable(
      '$sdk/licenses/toolchains/hdc',
      fakeHdc,
    ); // not an api number
    Directory(emptySdk).createSync(recursive: true);

    writeExecutable('$deveco/sdk/default/openharmony/toolchains/hdc', fakeHdc);
    writeFile('$deveco/sdk/default/sdk-pkg.json', '''
{
    "meta": {
        "version": "1.0.0"
    },
    "data": {
        "apiVersion": "26",
        "displayName": "HarmonyOS 26.0.0"
    }
}
''');
    for (final tool in ['node', 'ohpm', 'hvigor']) {
      Directory('$deveco/tools/$tool/bin').createSync(recursive: true);
    }
    Directory(noDeveco).createSync(recursive: true);

    // FAKE_HAPS: ':'-separated paths relative to the build directory (example/), written in order.
    writeExecutable(flutter, '''
#!/bin/bash
echo "flutter \$* @ \$PWD" >> '${log.path}'
case "\${1:-}" in
  --version)
    echo "Flutter 3.41.10-ohos-1.0.1 - channel oh-3.41.9-release"
    echo "Tools - Dart 3.11.5"
    ;;
  devices)
    echo "Found 1 connected device: fake (desktop) - macos - darwin-arm64"
    ;;
  build)
    echo "  env DEVECO_SDK_HOME=\${DEVECO_SDK_HOME:-<unset>}" >> '${log.path}'
    echo "  env PATH=\$PATH" >> '${log.path}'
    old_ifs=\$IFS
    IFS=:
    for h in \${FAKE_HAPS:-}; do
      mkdir -p "\$(dirname "\$h")"
      echo hap > "\$h"
    done
    IFS=\$old_ifs
    if [ "\${FAKE_BUILD_FAIL:-}" = 1 ]; then
      echo "fake build failed" >&2
      exit 1
    fi
    ;;
esac
exit 0
''');
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
    elsewhere.deleteSync(recursive: true);
  });

  group('ohos_build.sh', skip: Platform.isWindows, () {
    test('--env lists toolchains highest api first and resolves hdc', () {
      final r = run(['--env']);

      expect(r.exitCode, 0, reason: describe(r));
      final out = lines(r.stdout);
      expect(out, contains('flutter:    $flutter'));
      expect(toolchainLines(r), [
        'toolchains: $sdk/20/toolchains (api 20)',
        'toolchains: $sdk/12/toolchains (api 12)',
      ]); // 15 has no hdc; 'licenses' is not an api number
      expect(out, contains('hdc:        $sdk/20/toolchains/hdc'));
      expect(calls(), isEmpty); // --env runs neither flutter nor hdc
    });

    test('the DevEco SDK toolchains count with their apiVersion', () {
      final r = run(['--env'], env: {'DEVECO_HOME': deveco});

      expect(r.exitCode, 0, reason: describe(r));
      final devecoToolchains = '$deveco/sdk/default/openharmony/toolchains';
      expect(toolchainLines(r), [
        'toolchains: $devecoToolchains (api 26)',
        'toolchains: $sdk/20/toolchains (api 20)',
        'toolchains: $sdk/12/toolchains (api 12)',
      ]);
      final out = lines(r.stdout);
      expect(out, contains('hdc:        $devecoToolchains/hdc'));
      for (final tool in ['node', 'ohpm', 'hvigor']) {
        expect(out, contains('tools:      $deveco/tools/$tool/bin'));
      }
    });

    test('OHOS_API pins one toolchains directory', () {
      final r = run(['--env'], env: {'DEVECO_HOME': deveco, 'OHOS_API': '12'});

      expect(r.exitCode, 0, reason: describe(r));
      expect(toolchainLines(r), ['toolchains: $sdk/12/toolchains (api 12)']);
      expect(lines(r.stdout), contains('hdc:        $sdk/12/toolchains/hdc'));

      final missing = run(['--env'], env: {'OHOS_API': '99'});
      expect(missing.exitCode, 3, reason: describe(missing));
      expect(missing.stderr, contains('OHOS_API'));
    });

    test('a missing flutter exits 3 and names OHOS_FLUTTER', () {
      final r = run([], env: {'OHOS_FLUTTER': '$base/nowhere/flutter'});

      expect(r.exitCode, 3, reason: describe(r));
      expect(r.stderr, contains('OHOS_FLUTTER'));
      expect(calls(), isEmpty);
    });

    test('no hdc anywhere exits 3 with an install hint', () {
      final r = run([], env: {'OHOS_SDK_ROOT': emptySdk});

      expect(r.exitCode, 3, reason: describe(r));
      expect(r.stderr, contains('OpenHarmony SDK'));
      expect(r.stderr, contains('OHOS_SDK_ROOT'));
      expect(toolchainLines(r), isEmpty);
      expect(calls(), isNot(contains('flutter build')));
    });

    test('--no-build lists devices and targets but does not build', () {
      final r = run(['--no-build'], env: {'DEVECO_HOME': deveco});

      expect(r.exitCode, 0, reason: describe(r));
      expect(calls(), contains('flutter devices @'));
      expect(calls(), contains('hdc list targets'));
      expect(calls(), isNot(contains('flutter build')));
      expect(r.stdout, contains('no HarmonyOS device'));
    });

    test('the default run builds a debug hap inside example/ from any cwd', () {
      final invocations = <(String, String)>[
        (repo, 'scripts/ohos_build.sh'), // from the repo root
        ('$repo/scripts', 'ohos_build.sh'), // from scripts/
        (elsewhere.path, script), // from an unrelated directory
      ];
      for (final (cwd, scriptArg) in invocations) {
        if (log.existsSync()) log.deleteSync();

        final r = run(
          [],
          env: {'DEVECO_HOME': deveco},
          cwd: cwd,
          scriptArg: scriptArg,
        );

        expect(r.exitCode, 0, reason: 'cwd $cwd\n${describe(r)}');
        expect(
          calls(),
          contains('flutter build hap --debug @ $repo/example\n'),
        );
        expect(r.stdout, contains('version:    Flutter 3.41.10-ohos-1.0.1'));
        expect(r.stdout, contains('no HarmonyOS device')); // a warning only
        expect(calls(), contains('  env DEVECO_SDK_HOME=$deveco/sdk\n'));
        expect(
          calls(),
          contains(
            '  env PATH=$deveco/sdk/default/openharmony/toolchains:$sdk/20/toolchains:$sdk/12/toolchains:',
          ),
        );
        for (final tool in ['node', 'ohpm', 'hvigor']) {
          expect(calls(), contains('$deveco/tools/$tool/bin:'));
        }
      }
    });

    test('a failed build exits 4 with readable hints', () {
      // A hap from an earlier run must not count as the output of this one.
      final stale = File('$repo/example/$_unsignedHap')
        ..createSync(recursive: true)
        ..writeAsStringSync('old hap');
      stale.setLastModifiedSync(DateTime(2020));

      final r = run([], env: {'DEVECO_HOME': deveco, 'FAKE_BUILD_FAIL': '1'});

      expect(r.exitCode, 4, reason: describe(r));
      expect(r.stderr, contains('signing'));
      expect(r.stderr, contains('ohpm'));
      expect(r.stderr, contains('DEVECO_SDK_HOME'));
      expect(r.stderr, contains('hvigorw --stop-daemon'));
    });

    test(
      'a successful build that wrote no hap warns and uses the earlier one',
      () {
        final stale = File('$repo/example/$_unsignedHap')
          ..createSync(recursive: true)
          ..writeAsStringSync('old hap');
        stale.setLastModifiedSync(DateTime(2020));

        // FAKE_HAPS unset: the fake build exits 0 and writes nothing.
        final r = run([], env: {'DEVECO_HOME': deveco});

        expect(r.exitCode, 0, reason: describe(r));
        final hap = '$repo/example/$_unsignedHap';
        expect(
          r.stderr,
          contains(
            'warning: no hap newer than this build; using $hap from an earlier build.',
          ),
        );
        expect(lines(r.stdout), contains('hap:        $hap'));
      },
    );

    test(
      '--install installs the newest hap and starts the main ability on OHOS_DEVICE',
      () {
        // An older signed hap from an earlier build must lose to the one this build writes.
        File(
            '$repo/example/ohos/entry/build/default/outputs/default/entry-default-signed.hap',
          )
          ..createSync(recursive: true)
          ..writeAsStringSync('old hap')
          ..setLastModifiedSync(DateTime(2020));

        final r = run(
          ['--install'],
          env: {
            'DEVECO_HOME': deveco,
            'OHOS_DEVICE': '127.0.0.1:5557',
            'FAKE_HAPS': _signedHap,
          },
        );

        expect(r.exitCode, 0, reason: describe(r));
        final hap = '$repo/example/$_signedHap';
        final history = calls();
        final install = history.indexOf(
          'hdc -t 127.0.0.1:5557 install -r $hap\n',
        );
        final start = history.indexOf(
          'hdc -t 127.0.0.1:5557 shell aa start -a EntryAbility -b $_bundleName\n',
        );
        expect(install, isNonNegative, reason: describe(r));
        expect(start, greaterThan(install), reason: describe(r));
        final out = lines(r.stdout);
        expect(out, contains('hap:        $hap'));
        expect(out, contains('device:     127.0.0.1:5557'));
        expect(out, contains('bundle:     $_bundleName'));
      },
    );

    test('--install without a device exits 5', () {
      final r = run(
        ['--install'],
        env: {'DEVECO_HOME': deveco, 'FAKE_HAPS': _signedHap},
      );

      expect(r.exitCode, 5, reason: describe(r));
      expect(r.stderr, contains('no HarmonyOS device'));
      expect(
        calls(),
        isNot(contains('flutter build')),
      ); // fails before the build
      expect(calls(), isNot(contains('install -r')));
    });

    test('unknown arguments exit 2 with usage', () {
      final r = run(['--bogus']);

      expect(r.exitCode, 2, reason: describe(r));
      expect(r.stderr, contains('--bogus'));
      expect(r.stderr, contains('usage:'));

      final conflicting = run(['--env', '--install']);
      expect(conflicting.exitCode, 2, reason: describe(conflicting));
      expect(conflicting.stderr, contains('usage:'));

      final help = run(['--help']);
      expect(help.exitCode, 0, reason: describe(help));
      expect(help.stdout, contains('usage:'));
      expect(help.stdout, contains('OHOS_DEVICE'));
      expect(calls(), isEmpty);
    });

    test('DEVECO_SDK_HOME defaults to the sdk directory of DEVECO_HOME', () {
      final r = run(['--env'], env: {'DEVECO_HOME': deveco});

      expect(r.exitCode, 0, reason: describe(r));
      expect(lines(r.stdout), contains('sdk home:   $deveco/sdk'));
    });

    test('a caller-provided DEVECO_SDK_HOME is kept and exported', () {
      final mySdk = '$base/my sdk';
      Directory(mySdk).createSync(recursive: true);
      final env = {'DEVECO_HOME': deveco, 'DEVECO_SDK_HOME': mySdk};

      final r = run(['--env'], env: env);
      expect(r.exitCode, 0, reason: describe(r));
      expect(lines(r.stdout), contains('sdk home:   $mySdk'));

      final build = run([], env: env);
      expect(build.exitCode, 0, reason: describe(build));
      expect(calls(), contains('  env DEVECO_SDK_HOME=$mySdk\n'));
    });

    test('a missing DEVECO_SDK_HOME directory exits 3 and names it', () {
      // Set by the caller: an error in every mode.
      final given = run(
        ['--env'],
        env: {'DEVECO_HOME': deveco, 'DEVECO_SDK_HOME': '$base/no such sdk'},
      );
      expect(given.exitCode, 3, reason: describe(given));
      expect(given.stderr, contains('DEVECO_SDK_HOME'));

      // Derived from a DEVECO_HOME without sdk/: a warning for --env, an error before a build.
      final envOnly = run(['--env']);
      expect(envOnly.exitCode, 0, reason: describe(envOnly));
      expect(envOnly.stderr, contains('DEVECO_SDK_HOME'));

      final build = run([]);
      expect(build.exitCode, 3, reason: describe(build));
      expect(build.stderr, contains('DEVECO_SDK_HOME'));
      expect(calls(), isNot(contains('flutter build')));
    });

    test(
      'a failed build that still wrote a fresh unsigned hap warns and exits 0',
      () {
        final r = run(
          [],
          env: {
            'DEVECO_HOME': deveco,
            'FAKE_BUILD_FAIL': '1',
            'FAKE_HAPS': _unsignedHap,
          },
        );

        expect(r.exitCode, 0, reason: describe(r));
        expect(r.stderr, contains('unsigned'));
        expect(r.stderr, contains('Signing Configs'));
        expect(
          lines(r.stdout),
          contains('hap:        $repo/example/$_unsignedHap'),
        );
      },
    );

    test(
      '--install installs a fresh unsigned hap when signing is not configured',
      () {
        final r = run(
          ['--install'],
          env: {
            'DEVECO_HOME': deveco,
            'OHOS_DEVICE': '127.0.0.1:5557',
            'FAKE_BUILD_FAIL': '1',
            'FAKE_HAPS': _unsignedHap,
          },
        );

        expect(r.exitCode, 0, reason: describe(r));
        expect(r.stderr, contains('unsigned'));
        expect(
          calls(),
          contains(
            'hdc -t 127.0.0.1:5557 install -r $repo/example/$_unsignedHap\n',
          ),
        );
        expect(
          calls(),
          contains(
            'hdc -t 127.0.0.1:5557 shell aa start -a EntryAbility -b $_bundleName\n',
          ),
        );
      },
    );

    test('--install prefers a signed hap over a newer unsigned one', () {
      // The unsigned hap sits in example/build, which is searched first, and is the newer one.
      const signed =
          'ohos/entry/build/default/outputs/default/entry-default-signed.hap';
      const unsigned = 'build/ohos/hap/entry-default-unsigned.hap';
      final env = {'DEVECO_HOME': deveco, 'OHOS_DEVICE': '127.0.0.1:5557'};

      // Both written by this build, unsigned last.
      final fresh = run(
        ['--install'],
        env: {...env, 'FAKE_HAPS': '$signed:$unsigned'},
      );
      expect(fresh.exitCode, 0, reason: describe(fresh));
      expect(calls(), contains('install -r $repo/example/$signed\n'));
      expect(calls(), isNot(contains('install -r $repo/example/$unsigned')));

      // Neither written by this (successful) build: the newest earlier hap is used, signed still first.
      log.deleteSync();
      File('$repo/example/$signed').setLastModifiedSync(DateTime(2020));
      File('$repo/example/$unsigned').setLastModifiedSync(DateTime(2021));
      final stale = run(['--install'], env: env);
      expect(stale.exitCode, 0, reason: describe(stale));
      expect(calls(), contains('install -r $repo/example/$signed\n'));
      expect(calls(), isNot(contains('install -r $repo/example/$unsigned')));
    });

    test('--install without OHOS_DEVICE uses the first hdc target', () {
      final r = run(
        ['--install'],
        env: {
          'DEVECO_HOME': deveco,
          'FAKE_TARGETS': 'emulator-a\nemulator-b',
          'FAKE_HAPS': _signedHap,
        },
      );

      expect(r.exitCode, 0, reason: describe(r));
      expect(lines(r.stdout), contains('device:     emulator-a'));
      expect(calls(), contains('hdc -t emulator-a install -r '));
      expect(calls(), contains('hdc -t emulator-a shell aa start '));
    });

    test('an hdc install failure exits 5', () {
      final r = run(
        ['--install'],
        env: {
          'DEVECO_HOME': deveco,
          'OHOS_DEVICE': '127.0.0.1:5557',
          'FAKE_HAPS': _signedHap,
          'FAKE_INSTALL_FAIL': '1', // hdc prints [Fail] and still exits 0
        },
      );

      expect(r.exitCode, 5, reason: describe(r));
      expect(calls(), contains('install -r'));
      expect(calls(), isNot(contains('aa start')));
    });
  });
}
