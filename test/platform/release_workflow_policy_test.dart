import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'qa_workflow_policy_test.dart' as qa;

/// F1: the release workflow must verify what it downloads, keep secrets out
/// of the analyze/test job, and never expand secrets or inputs inline in
/// shell scripts (static checks on the workflow source).
void main() {
  // * normalise CRLF so the line-based parsing also holds on Windows checkouts
  final workflow = File('.github/workflows/release.yml')
      .readAsStringSync()
      .replaceAll('\r\n', '\n');

  /// Top-level job blocks keyed by job id.
  Map<String, String> jobs() {
    final body = workflow.substring(workflow.indexOf('\njobs:\n') + 7);
    final result = <String, String>{};
    final starts = RegExp(r'^  ([A-Za-z0-9_-]+):\s*$', multiLine: true)
        .allMatches(body)
        .toList();
    for (var i = 0; i < starts.length; i++) {
      final end = i + 1 < starts.length ? starts[i + 1].start : body.length;
      result[starts[i].group(1)!] = body.substring(starts[i].start, end);
    }
    return result;
  }

  /// Bodies of every `run:` step (single-line or block scalar).
  List<String> runScripts() {
    final lines = workflow.split('\n');
    final scripts = <String>[];
    for (var i = 0; i < lines.length; i++) {
      final m = RegExp(r'^(\s*)(- )?run:\s*(.*)$').firstMatch(lines[i]);
      if (m == null) continue;
      final inline = m.group(3)!.trim();
      if (inline.isNotEmpty && inline != '|' && inline != '>') {
        scripts.add(inline);
        continue;
      }
      final indent = m.group(1)!.length + (m.group(2) == null ? 0 : 2);
      final buf = StringBuffer();
      for (var j = i + 1; j < lines.length; j++) {
        final l = lines[j];
        if (l.trim().isEmpty) {
          buf.writeln();
          continue;
        }
        final lead = l.length - l.trimLeft().length;
        if (lead <= indent) break;
        buf.writeln(l);
      }
      scripts.add(buf.toString());
    }
    return scripts;
  }

  test('no unpinned remote script is piped into a shell', () {
    expect(workflow, isNot(contains('/main/install.sh')));
    expect(workflow, isNot(contains('/main/download.sh')));
    expect(workflow, isNot(matches(RegExp(r'curl[^\n]*\|\s*(ba)?sh'))));
    expect(workflow, isNot(matches(RegExp(r'(ba)?sh\s+<\(\s*curl'))));
  });

  test('the ObjectBox library download is pinned and checksum-verified', () {
    expect(
      workflow,
      contains(
        'https://github.com/objectbox/objectbox-c/releases/download/'
        'v5.3.1/objectbox-linux-x64.tar.gz',
      ),
    );
    // * digest published by GitHub for the v5.3.1 release asset
    expect(
      workflow,
      contains(
        'd1a22f5a43e8aa438c987524c2ef97f5d179acb991b0f63ab03a30c33b882368',
      ),
    );
    expect(workflow, contains('sha256sum -c'));
  });

  test('the pinned ObjectBox C version matches pubspec.lock', () {
    final lock =
        File('pubspec.lock').readAsStringSync().replaceAll('\r\n', '\n');
    final m = RegExp(
      r'\n  objectbox:\n(?:    .*\n)*?    version: "([^"]+)"',
    ).firstMatch(lock);
    expect(m, isNotNull);
    expect(workflow, contains('objectbox-c/releases/download/v${m!.group(1)}/'));
  });

  test('analyze and test run in a secrets-free job that gates the build', () {
    final all = jobs();
    final verify = all['verify'];
    expect(verify, isNotNull, reason: 'a dedicated verify job');
    expect(verify, contains('flutter analyze'));
    expect(verify, contains('flutter test'));
    expect(verify, isNot(contains('secrets.')));
    expect(verify, isNot(contains('KEYSTORE')));
    expect(verify, contains('contents: read'));

    final build = all['build']!;
    expect(build, matches(RegExp(r'needs:\s*\[?\s*verify')));
    expect(build, isNot(contains('flutter test')));
    expect(build, isNot(contains('flutter analyze')));
  });

  test('no secret, input or event value is expanded inline in a script', () {
    for (final script in runScripts()) {
      expect(
        script,
        isNot(contains(r'${{')),
        reason: 'use env: and "\$VAR" instead:\n$script',
      );
    }
  });

  test('CI pins the tested Flutter release that satisfies pubspec.lock', () {
    // * the toolchain the host and device suites were verified with
    const tested = '3.44.5';
    final pin = RegExp(r"^  FLUTTER_VERSION: '([^']+)'", multiLine: true)
        .firstMatch(workflow);
    expect(pin, isNotNull);
    expect(pin!.group(1), tested);

    final lock =
        File('pubspec.lock').readAsStringSync().replaceAll('\r\n', '\n');
    final min = RegExp(r'\n  flutter: ">=([0-9.]+)').firstMatch(lock);
    expect(min, isNotNull);
    List<int> parts(String v) => v.split('.').map(int.parse).toList();
    final p = parts(tested);
    final m = parts(min!.group(1)!);
    var cmp = 0;
    for (var i = 0; i < 3 && cmp == 0; i++) {
      cmp = p[i].compareTo(m[i]);
    }
    expect(cmp, greaterThanOrEqualTo(0), reason: 'lock needs >=${min.group(1)}');

    for (final id in ['verify', 'build']) {
      expect(
        jobs()[id],
        contains(r'flutter-version: ${{ env.FLUTTER_VERSION }}'),
        reason: '$id must use the pinned version',
      );
    }
  });

  test('every pub get enforces the committed lockfile', () {
    final gets = runScripts()
        .expand((s) => s.split('\n'))
        .where((l) => RegExp(r'\b(flutter|dart) pub (get|upgrade)\b').hasMatch(l))
        .toList();
    expect(gets, isNotEmpty);
    for (final l in gets) {
      expect(l.trim(), 'flutter pub get --enforce-lockfile');
    }
    for (final id in ['verify', 'build']) {
      expect(jobs()[id], contains('run: flutter pub get --enforce-lockfile'));
    }
  });

  test('workflow token defaults to read-only', () {
    expect(
      workflow,
      matches(RegExp(r'^permissions:\s*\n\s+contents: read', multiLine: true)),
    );
  });

  group('release prerequisites', () {
    final wf = qa.parseWorkflow(workflow);
    final qaEnv = qa.asMap(
      qa.parseWorkflow(
        File('.github/workflows/qa.yml')
            .readAsStringSync()
            .replaceAll('\r\n', '\n'),
      )['env'],
    );
    final env = qa.asMap(wf['env']);
    Map<String, Object?> job(String id) => qa.asMap(qa.asMap(wf['jobs'])[id]);
    List<Map<String, Object?>> steps(String id) =>
        qa.asList(job(id)['steps']).map(qa.asMap).toList();
    Map<String, Object?> step(String id, String name) =>
        steps(id).firstWhere((s) => s['name'] == name, orElse: () => {});
    int at(String id, String name) =>
        steps(id).indexWhere((s) => s['name'] == name);
    String run(String id, String name) => '${step(id, name)['run'] ?? ''}';
    List<String> lines(String id, String name) =>
        run(id, name).split('\n').map((l) => l.trim()).toList();

    test('pubspec carries the next patch version and build number', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final v = RegExp(r'^version: (.+?)\s*$', multiLine: true)
          .allMatches(pubspec)
          .map((m) => m.group(1))
          .toList();
      expect(v, ['1.0.3+4']);
    });

    test('host tests use a synthetic backend config, never real secrets', () {
      final s = run('verify', 'Synthetic loopback .env');
      expect(s, contains("'http://127.0.0.1:54321' > .env"));
      expect(s, contains("'qa-synthetic-not-a-real-key' >> .env"));
      expect(at('verify', 'Synthetic loopback .env'),
          lessThan(at('verify', 'Flutter pub get')));
      expect(job('verify').toString(), isNot(contains('secrets.')));
      expect(at('verify', 'Install ObjectBox native library (host tests)'),
          lessThan(at('verify', 'Test')));
      expect(run('verify', 'Analyze'),
          'flutter analyze --no-pub --no-fatal-infos');
      expect(run('verify', 'Test'), 'flutter test --no-pub');
    });

    test('secrets are confined to the build and release jobs', () {
      const allowed = {
        'build': {
          'SUPABASE_URL',
          'SUPABASE_ANON_KEY',
          'KEYSTORE_BASE64',
          'KEYSTORE_PASSWORD',
          'KEY_PASSWORD',
          'KEY_ALIAS',
        },
        'release': {'GITHUB_TOKEN'},
      };
      for (final id in qa.asMap(wf['jobs']).keys) {
        for (final s in steps(id)) {
          for (final e in qa.asMap(s['env']).entries) {
            final m = RegExp(r'secrets\.([A-Z0-9_]+)').firstMatch('${e.value}');
            if (m == null) continue;
            expect(allowed[id], contains(m.group(1)), reason: '$id ${e.key}');
            expect('${e.value}', r'${{ secrets.' '${m.group(1)} }}');
          }
        }
      }
    });

    test('the build bakes in a real https backend config, fail closed', () {
      final s = lines('build', 'Create .env');
      expect(s.first, 'set -euo pipefail');
      for (final k in ['SUPABASE_URL', 'SUPABASE_ANON_KEY']) {
        expect(s, contains('[ -n "\$$k" ] || { echo "::error::$k secret is missing"; missing=1; }'));
      }
      expect(s, contains('[ "\$missing" = 0 ] || exit 1'));
      expect(s, contains('https://*) ;;'));
      expect(at('build', 'Create .env'), lessThan(at('build', 'Flutter pub get')));
    });

    test('all actions are pinned to the commits qa.yml tested', () {
      final pins = <String>{};
      for (final id in qa.asMap(wf['jobs']).keys) {
        for (final s in steps(id)) {
          final uses = s['uses'];
          if (uses is! String) continue;
          expect(uses, matches(RegExp(r'^[\w.-]+/[\w.-]+@[0-9a-f]{40}$')));
          pins.add(uses);
          if (uses.startsWith('actions/checkout@')) {
            expect(qa.asMap(s['with'])['persist-credentials'], 'false');
            expect('${qa.asMap(s['with'])['ref']}', startsWith('refs/tags/'));
          }
        }
      }
      final qaPins = RegExp(r'uses: (\S+)')
          .allMatches(File('.github/workflows/qa.yml').readAsStringSync())
          .map((m) => m.group(1)!)
          .toSet();
      expect(
        pins.difference(qaPins),
        {'actions/download-artifact@d3f86a106a0bac45b974a628896c90dbdf5c8093'},
      );
    });

    test('the version is resolved strictly from the tag and pubspec', () {
      final s = lines('build', 'Resolve version');
      expect(s.first, 'set -euo pipefail');
      expect(s, contains(r"""if ! printf '%s' "$VERSION" | grep -Eqx 'v[0-9]+\.[0-9]+\.[0-9]+'; then"""));
      expect(s, contains(r'if [ "$HEAD_SHA" != "$TAG_SHA" ]; then'));
      expect(run('build', 'Resolve version'),
          contains(r'"${PUB_NAME:-}" != "$BUILD_NAME"'));
      expect(s, contains(r'if [ -z "${PREV_NUMBER:-}" ] || [ "$BUILD_NUMBER" -le "$PREV_NUMBER" ]; then'));
      for (final b in ['Build universal APK', 'Build ABI-split APKs']) {
        expect(run('build', b), contains(r'--build-name="$BUILD_NAME"'));
        expect(run('build', b), contains(r'--build-number="$BUILD_NUMBER"'));
        expect(run('build', b), contains('flutter build apk --release --no-pub'));
      }
    });

    test('the release plugin registrant is regenerated with the lock unchanged', () {
      final s = lines('build', 'Generate release plugin registrant');
      expect(s, [
        'set -euo pipefail',
        'sha256sum pubspec.lock .dart_tool/package_config.json > "\$RUNNER_TEMP/release-pub-state.sha256"',
        'flutter build apk --release --config-only',
        'sha256sum -c "\$RUNNER_TEMP/release-pub-state.sha256"',
      ]);
      final i = at('build', 'Generate release plugin registrant');
      expect(i, greaterThan(at('build', 'Flutter pub get')));
      expect(i, lessThan(at('build', 'Setup release signing')));
      expect(i, lessThan(at('build', 'Build universal APK')));
    });

    test('signing is fail closed and its material is always removed', () {
      final s = lines('build', 'Setup release signing');
      expect(s.first, 'set -euo pipefail');
      for (final k in ['KEYSTORE_BASE64', 'KEYSTORE_PASSWORD', 'KEY_PASSWORD', 'KEY_ALIAS']) {
        expect(s, contains('[ -n "\$$k" ] || { echo "::error::$k secret is missing"; missing=1; }'));
      }
      expect(s, contains('[ "\$missing" = 0 ] || exit 1'));
      expect(s, contains('printf \'%s\' "\$KEYSTORE_BASE64" | base64 --decode > "\$RUNNER_TEMP/kawai-release.jks"'));
      final clean = step('build', 'Remove signing material');
      expect(clean['if'], 'always()');
      expect(clean['run'], 'rm -f android/key.properties "\$RUNNER_TEMP/kawai-release.jks" .env');
      expect(at('build', 'Remove signing material'),
          greaterThan(at('build', 'Build ABI-split APKs')));
      expect(workflow, isNot(contains('android/kawai-release.jks')));
    });

    test('every APK must carry the historical certificate, fail closed', () {
      expect(env['RELEASE_EXPECTED_CERT_SHA256'], qaEnv['QA_EXPECTED_CERT_SHA256']);
      expect(env['RELEASE_EXPECTED_CERT_SHA256'],
          'c48112390477dbbdae99e54068eddccdc547ca7b8e18a7f2cea4a84fd98b6ccf');
      final qaLeaf = RegExp(r"^ *(leaf='[^']*')$", multiLine: true)
          .firstMatch(File('.github/workflows/qa.yml').readAsStringSync())!
          .group(1);
      final s = lines('build', 'Verify APKs (fail closed)');
      expect(s.first, 'set -euo pipefail');
      for (final need in [
        qaLeaf,
        '"\$apksigner" verify --verbose --print-certs "\$apk" > "\$certs" || rc=\$?',
        'cat "\$certs"',
        '[ "\$rc" -eq 0 ] || { echo "::error::apksigner verify of \$name exited \$rc"; exit 1; }',
        "[ \"\$(tr -dc '\\r' < \"\$certs\" | wc -c)\" -eq 0 ] || { echo \"::error::apksigner output has CR line endings\"; exit 1; }",
        "grep -qx 'Number of signers: 1' \"\$certs\" || { echo \"::error::\$name does not have exactly one signer\"; exit 1; }",
        'if [ "\${#lines[@]}" -ne 1 ]; then',
        'if [ "\${#digests[@]}" -ne 1 ]; then',
        'if [ "\${digests[0]}" != "\$RELEASE_EXPECTED_CERT_SHA256" ]; then',
      ]) {
        expect(s, contains(need));
      }
      final v = at('build', 'Verify APKs (fail closed)');
      expect(v, greaterThan(at('build', 'Remove signing material')));
      expect(v, lessThan(at('build', 'Upload APK artifacts')));
    });

    test('every APK must have the exact package, version and minSdk', () {
      expect(env['RELEASE_PACKAGE'], 'com.rizz.kawainotes');
      expect(env['RELEASE_MIN_SDK'], '24');
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle, contains('applicationId = "com.rizz.kawainotes"'));
      expect(gradle, contains('minSdk = flutter.minSdkVersion'));
      final r = run('build', 'Verify APKs (fail closed)');
      for (final spec in [
        '"universal:0:native-code: \'arm64-v8a\' \'armeabi-v7a\' \'x86_64\'"',
        '"armeabi-v7a:1:native-code: \'armeabi-v7a\'"',
        '"arm64-v8a:2:native-code: \'arm64-v8a\'"',
        '"x86_64:4:native-code: \'x86_64\'"',
      ]) {
        expect(r, contains(spec));
      }
      final s = lines('build', 'Verify APKs (fail closed)');
      expect(s, contains(r'code=$((mult * 1000 + BUILD_NUMBER))'));
      expect(s, contains(r'''want="package: name='$RELEASE_PACKAGE' versionCode='$code' versionName='$BUILD_NAME' "'''));
      expect(s, contains(r'''grep -qxF "minSdkVersion:'$RELEASE_MIN_SDK'" "$badging" || { echo "::error::$name: minSdkVersion is not $RELEASE_MIN_SDK"; exit 1; }'''));
      expect(s, contains(r"grep -q '^SUPABASE_URL=https://' " '"\$appenv" || ok=0'));
      expect(s, contains(r'( cd "$out" && sha256sum --binary kawai-notes-*.apk > SHA256SUMS )'));
    });

    test('only verified files are uploaded', () {
      final w = qa.asMap(step('build', 'Upload APK artifacts')['with']);
      expect(w['if-no-files-found'], 'error');
      final paths = '${w['path']}'.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty);
      for (final p in paths) {
        expect(p, startsWith(r'${{ runner.temp }}/release-out/'));
      }
    });

    test('the release is created as a draft and never replaces one', () {
      final s = run('release', 'Create draft GitHub Release');
      expect(s, contains('ARGS="--draft --verify-tag"'));
      expect(s, isNot(contains('--latest')));
      expect(s, isNot(contains('--clobber')));
      expect(s, contains('refusing to replace it'));
      expect(s.indexOf('gh release view'), lessThan(s.indexOf('gh release create')));
      expect(s, contains('"apks/SHA256SUMS"'));
      expect(workflow, isNot(matches(RegExp(r'gh release (edit|upload|delete)'))));
      expect(workflow, isNot(contains('--draft=false')));
      expect(at('release', 'Check artifact hashes'),
          lessThan(at('release', 'Create draft GitHub Release')));
      expect(run('release', 'Check artifact hashes'), contains('sha256sum -c SHA256SUMS'));
      expect(run('release', 'Check artifact hashes'),
          contains(r'^[0-9a-f]{64} \*kawai-notes-${VERSION}-${abi}\.apk$'));
    });

    test('release notes state the actual minimum Android version', () {
      final s = run('release', 'Generate release notes');
      expect(s, contains(r'Android 7.0 (API ${RELEASE_MIN_SDK}) or higher'));
      expect(workflow, isNot(contains('API 23')));
    });
  });
}
