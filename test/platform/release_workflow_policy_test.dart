import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
}
