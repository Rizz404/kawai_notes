import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// QA-only workflow policy: `.github/workflows/qa.yml` may only verify a
/// `qa/herguri-*` branch and build one APK signed with the released key whose
/// certificate is checked fail-closed. It must have no publication path.
///
/// The workflow is parsed structurally (block YAML subset used by GitHub
/// workflows), and every rule is also checked against unsafe mutants.
void main() {
  const path = '.github/workflows/qa.yml';

  String read(String p) =>
      File(p).readAsStringSync().replaceAll('\r\n', '\n');

  test('the QA workflow exists', () {
    expect(File(path).existsSync(), isTrue, reason: '$path is missing');
  });

  test('the QA workflow satisfies the QA-only policy', () {
    expect(File(path).existsSync(), isTrue, reason: '$path is missing');
    expect(qaWorkflowViolations(read(path)), isEmpty);
  });

  test('the signed build regenerates a release plugin registrant first', () {
    expect(File(path).existsSync(), isTrue, reason: '$path is missing');
    final v = qaWorkflowViolations(read(path));
    expect(v.where((e) => e.startsWith('registrant:')), isEmpty);
  });

  test('a CRLF checkout of the QA workflow parses the same', () {
    expect(File(path).existsSync(), isTrue, reason: '$path is missing');
    final crlf = read(path).replaceAll('\n', '\r\n');
    expect(qaWorkflowViolations(crlf), isEmpty);
  });

  test('the QA pins match release.yml and the lockfile', () {
    expect(File(path).existsSync(), isTrue, reason: '$path is missing');
    final qa = asMap(parseWorkflow(read(path))['env']);
    final release = asMap(
      parseWorkflow(read('.github/workflows/release.yml'))['env'],
    );
    for (final k in ['FLUTTER_VERSION', 'OBX_C_VERSION', 'OBX_C_SHA256']) {
      expect(qa[k], release[k], reason: k);
    }
    final lock = read('pubspec.lock');
    final min = RegExp(r'\n  flutter: ">=([0-9.]+)').firstMatch(lock);
    expect(min, isNotNull);
    expect(
      compareVersions(qa['FLUTTER_VERSION']! as String, min!.group(1)!),
      greaterThanOrEqualTo(0),
    );
    final obx = RegExp(
      r'\n  objectbox:\n(?:    .*\n)*?    version: "([^"]+)"',
    ).firstMatch(lock);
    expect(qa['OBX_C_VERSION'], obx!.group(1));
  });

  group('the signer certificate parser', () {
    late RegExp leaf;
    setUpAll(() {
      final m = RegExp(r"^ *leaf='([^']*)'$", multiLine: true).firstMatch(read(path));
      expect(m, isNotNull, reason: 'no leaf digest pattern in $path');
      leaf = RegExp(m!.group(1)!);
    });

    // * the shell step: exit code, CR, `Number of signers: 1`, one digest line, one leaf digest, exact match
    String? verdict(String out, {int rc = 0}) {
      if (rc != 0) return 'apksigner exited $rc';
      if (out.contains('\r')) return 'CR line endings';
      final ls = out.split('\n');
      if (!ls.contains('Number of signers: 1')) return 'not one signer';
      final lines = ls.where(
        (l) => l.contains(' certificate SHA-256 digest: ') && !l.startsWith('Source Stamp Signer'),
      );
      if (lines.length != 1) return '${lines.length} digest lines';
      final digests = ls.map(leaf.firstMatch).whereType<RegExpMatch>().map((m) => m.group(5)!).toList();
      if (digests.length != 1) return '${digests.length} leaf digests';
      return digests.single == _expectedCert ? null : 'mismatch ${digests.single}';
    }

    String v2(String s) => s.replaceAll('Signer #1 ', 'V2 Signer: ');
    String two(String s, String second) {
      final blk = s.split('\n').where((l) => l.startsWith('Signer #1 ')).toList();
      final extra = blk.map((l) => l.replaceFirst('Signer #1 ', 'Signer #2 ')).join('\n').replaceAll(_expectedCert, second);
      return s
          .replaceFirst('Number of signers: 1', 'Number of signers: 2')
          .replaceFirst('${blk.last}\n', '${blk.last}\n$extra\n');
    }

    const other = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    String noLeaf(String s) =>
        s.split('\n').where((l) => !l.contains('certificate SHA-256 digest')).join('\n');

    test('real apksigner 0.9 (build-tools 36.0.0) output of the released APK passes', () {
      expect(verdict(_realPrintCerts), isNull);
    });

    test('the apksig android17 `V2 Signer:` grammar passes', () {
      expect(verdict(v2(_realPrintCerts)), isNull);
      expect(verdict(_realPrintCerts.replaceAll('Signer #1 ', 'V3.0 Signer: ')), isNull);
      expect(verdict(_realPrintCerts.replaceAll('Signer #1 ', 'Signer: ')), isNull);
      expect(verdict(v2(_realPrintCerts).trimRight()), isNull);
      expect(
        verdict(
          '${v2(_realPrintCerts)}Source Stamp Signer: certificate SHA-256 digest: ${'ab' * 32}\n',
        ),
        isNull,
      );
    });

    test('a wrong certificate fails', () {
      expect(verdict(_realPrintCerts.replaceAll(_expectedCert, other)), startsWith('mismatch'));
      expect(verdict(v2(_realPrintCerts).replaceAll(_expectedCert, other)), startsWith('mismatch'));
    });

    test('zero, multiple and repeated signers fail', () {
      expect(verdict(noLeaf(v2(_realPrintCerts))), isNotNull);
      for (final second in [other, _expectedCert]) {
        final t = two(_realPrintCerts, second);
        expect(verdict(t), isNotNull);
        expect(verdict(t.replaceAll('Number of signers: 2', 'Number of signers: 1')), '2 digest lines');
        final n = t.replaceAll('Signer #1 ', 'V2 Signer #1: ').replaceAll('Signer #2 ', 'V2 Signer #2: ');
        expect(verdict(n.replaceAll('Number of signers: 2', 'Number of signers: 1')), '2 digest lines');
      }
      final rot = v2(_realPrintCerts).replaceAll(
        'V2 Signer: ',
        'V3.1 Signer: (minSdkVersion=33, maxSdkVersion=2147483647): ',
      );
      expect(verdict(rot), isNotNull);
    });

    test('malformed digests and non-leaf hashes fail', () {
      final n = v2(_realPrintCerts);
      for (final bad in [
        _expectedCert.substring(1),
        '${_expectedCert}0',
        '${_expectedCert.substring(1)}g',
        _expectedCert.toUpperCase(),
        [for (var i = 0; i < 64; i += 2) _expectedCert.substring(i, i + 2)].join(':'),
        '\x1b[1m$_expectedCert\x1b[0m',
        '$_expectedCert ',
      ]) {
        expect(verdict(n.replaceAll('digest: $_expectedCert', 'digest: $bad')), isNotNull, reason: bad);
      }
      expect(verdict(n.replaceAll('V2 Signer: certificate SHA-256', ' V2 Signer: certificate SHA-256')), isNotNull);
      expect(
        verdict(noLeaf(n).replaceFirst('public key SHA-256 digest: ', 'public key SHA-256 digest: $_expectedCert x')),
        isNotNull,
      );
      expect(
        verdict(
          noLeaf(n).replaceFirst('certificate DN: CN=', 'certificate DN: CN=x certificate SHA-256 digest: $_expectedCert, CN='),
        ),
        isNotNull,
      );
      expect(verdict('Number of signers: 1\n\ufeffV2 Signer: certificate SHA-256 digest: $_expectedCert\n'), isNotNull);
    });

    test('a nonzero apksigner exit or CRLF output fails', () {
      expect(verdict(v2(_realPrintCerts), rc: 1), 'apksigner exited 1');
      expect(verdict('', rc: 2), 'apksigner exited 2');
      expect(verdict(v2(_realPrintCerts).replaceAll('\n', '\r\n')), 'CR line endings');
    });
  });

  group('unsafe mutants are rejected', () {
    late String valid;
    setUpAll(() => valid = read(path));

    String mutate(String from, String to) {
      expect(valid, contains(from), reason: 'mutant anchor missing: $from');
      return valid.replaceFirst(from, to);
    }

    void rejects(String mutant, String expectedRule) {
      final v = qaWorkflowViolations(mutant);
      expect(v, isNotEmpty);
      expect(v.join('\n'), contains(expectedRule));
    }

    test('a release job with contents: write', () {
      rejects(
        '$valid\n'
        '  release:\n'
        '    runs-on: ubuntu-latest\n'
        '    needs: [signed-apk]\n'
        '    permissions:\n'
        '      contents: write\n'
        '    steps:\n'
        '      - name: Create GitHub Release\n'
        '        run: gh release create "v0.0.0"\n',
        'jobs',
      );
    });

    test('workflow-level contents: write', () {
      rejects(
        mutate('permissions:\n  contents: read', 'permissions:\n  contents: write'),
        'permissions',
      );
    });

    test('a broad branch trigger', () {
      rejects(mutate("      - 'qa/herguri-*'", "      - '**'"), 'trigger');
    });

    test('a tag trigger', () {
      rejects(
        mutate("      - 'qa/herguri-*'\n", "      - 'qa/herguri-*'\n    tags:\n      - 'v*'\n"),
        'trigger',
      );
    });

    test('pull_request_target / workflow_run / manual triggers', () {
      for (final extra in [
        '  pull_request_target:\n',
        '  workflow_run:\n    workflows: [Release]\n',
        '  workflow_dispatch:\n',
      ]) {
        rejects(mutate('on:\n', 'on:\n$extra'), 'trigger');
      }
    });

    test('a plain pub get', () {
      rejects(
        mutate('run: flutter pub get --enforce-lockfile', 'run: flutter pub get'),
        'pub get',
      );
    });

    test('analyze/test/build without --no-pub', () {
      rejects(mutate('flutter test --no-pub', 'flutter test'), '--no-pub');
      rejects(
        mutate('flutter build apk --release --no-pub', 'flutter build apk --release'),
        '--no-pub',
      );
    });

    test('fatal infos', () {
      rejects(mutate('--no-fatal-infos', '--fatal-infos'), 'fatal-infos');
    });

    test('a wrong expected certificate', () {
      rejects(
        mutate(
          'c48112390477dbbdae99e54068eddccdc547ca7b8e18a7f2cea4a84fd98b6ccf',
          '0000000000000000000000000000000000000000000000000000000000000000',
        ),
        'certificate',
      );
    });

    test('no certificate comparison', () {
      rejects(
        mutate('if [ "\${digests[0]}" != "\$QA_EXPECTED_CERT_SHA256" ]; then', 'if false; then'),
        'certificate',
      );
    });

    test('a weakened signer certificate parser', () {
      const leafLine =
          r"leaf='^(Signer #[0-9]+|((V1|V2|V3\.0) )?Signer( #[0-9]+)?:) certificate SHA-256 digest: ([0-9a-f]{64})$'";
      rejects(mutate(leafLine, r"leaf='certificate SHA-256 digest: ([0-9a-fA-F:]+)'"), 'certificate');
      rejects(mutate('([0-9a-f]{64})\$', '([0-9a-fA-F:]+)\$'), 'certificate');
      rejects(mutate('> "\$certs" || rc=\$?', '> "\$certs" || true'), 'certificate');
      rejects(mutate('[ "\$rc" -eq 0 ] || {', 'true || {'), 'certificate');
      rejects(mutate("grep -qx 'Number of signers: 1' \"\$certs\" || {", 'true || {'), 'certificate');
      rejects(mutate('if [ "\${#lines[@]}" -ne 1 ]; then', 'if false; then'), 'certificate');
      rejects(mutate("[ \"\$(tr -dc '\\r' < \"\$certs\" | wc -c)\" -eq 0 ] || {", 'true || {'), 'certificate');
      rejects(mutate('          cat "\$certs"\n', ''), 'certificate');
    });

    test('missing fail-closed signing config check', () {
      rejects(mutate('          [ "\$missing" = 0 ] || exit 1\n', ''), 'fail-closed');
      rejects(
        mutate('[ -n "\$KEY_ALIAS" ] || { echo "::error::KEY_ALIAS secret is missing"; missing=1; }', 'true'),
        'fail-closed',
      );
    });

    test('signing material not always cleaned up', () {
      rejects(mutate('        if: always()\n', ''), 'cleanup');
    });

    test('a secret expanded inline in a script', () {
      rejects(
        mutate(
          'printf \'keyAlias=%s\\n\' "\$KEY_ALIAS"',
          r"printf 'keyAlias=%s\n' '${{ secrets.KEY_ALIAS }}'",
        ),
        'inline',
      );
    });

    test('secrets in the verify job', () {
      rejects(
        mutate(
          '      - name: Flutter pub get\n        run: flutter pub get --enforce-lockfile\n\n      - name: Install',
          '      - name: Flutter pub get\n        env:\n          K: \${{ secrets.KEYSTORE_BASE64 }}\n        run: flutter pub get --enforce-lockfile\n\n      - name: Install',
        ),
        'verify',
      );
    });

    test('an unpinned or unknown action', () {
      rejects(
        mutate('actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02', 'actions/upload-artifact@v4'),
        'pinned',
      );
      rejects(
        mutate('actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02', 'softprops/action-gh-release@ea165f8d65b6e75b540449e92b4886f43607fa02'),
        'allowed',
      );
    });

    test('publishing steps (push, tag, release, set -x)', () {
      for (final cmd in ['git push origin HEAD', 'git tag v9.9.9', 'gh release create v9', 'set -x']) {
        rejects(
          mutate('run: flutter build apk --release --no-pub', 'run: |\n          $cmd\n          flutter build apk --release --no-pub'),
          'forbidden',
        );
      }
    });

    test('uploading signing material or the build tree', () {
      rejects(
        mutate('            \${{ runner.temp }}/qa-out/qa-manifest.txt\n', '            \${{ runner.temp }}/qa-out/qa-manifest.txt\n            android/key.properties\n'),
        'upload',
      );
      rejects(
        mutate('            \${{ runner.temp }}/qa-out/qa-manifest.txt\n', '            \${{ runner.temp }}/qa-out/qa-manifest.txt\n            build/\n'),
        'upload',
      );
    });

    test('long artifact retention or non-QA artifact name', () {
      rejects(mutate('retention-days: 3', 'retention-days: 90'), 'retention');
      rejects(mutate('name: qa-only-kawai', 'name: kawai'), 'artifact name');
    });

    test('split APKs or versioning flags in the QA build', () {
      rejects(
        mutate('flutter build apk --release --no-pub', 'flutter build apk --release --no-pub --split-per-abi'),
        'universal',
      );
    });

    test('no release-mode plugin registrant before the --no-pub build', () {
      const step = '      - name: Generate release plugin registrant\n';
      final start = valid.indexOf(step);
      final end = valid.indexOf('      - name: Setup release signing', start);
      expect(start, greaterThan(0));
      final text = valid.substring(start, end);
      rejects(mutate(text, ''), 'registrant');
      // * the published CI failure: the regeneration step itself skips pub
      rejects(
        mutate('flutter build apk --release --config-only\n', 'flutter build apk --release --config-only --no-pub\n'),
        'registrant',
      );
      rejects(
        mutate('flutter build apk --release --config-only\n', 'flutter build apk --debug --config-only\n'),
        'registrant',
      );
      rejects(mutate('          sha256sum -c "\$RUNNER_TEMP/qa-pub-state.sha256"\n', ''), 'registrant');
      final moved = valid.replaceFirst(text, '').replaceFirst(
        '        run: flutter build apk --release --no-pub\n\n',
        '        run: flutter build apk --release --no-pub\n\n$text',
      );
      rejects(moved, 'registrant');
    });

    test('the signed build not gated on verify', () {
      rejects(mutate('    needs: [verify]\n', ''), 'needs');
    });
  });
}

// ---------------------------------------------------------------------------
// Policy
// ---------------------------------------------------------------------------

const _expectedCert =
    'c48112390477dbbdae99e54068eddccdc547ca7b8e18a7f2cea4a84fd98b6ccf';
// * leaf signer digest in the apksigner 0.9 `Signer #N` and apksig android17 `V2 Signer:` grammar
const _leafDigest =
    r"leaf='^(Signer #[0-9]+|((V1|V2|V3\.0) )?Signer( #[0-9]+)?:) certificate SHA-256 digest: ([0-9a-f]{64})$'";
// * real `apksigner verify --verbose --print-certs` stdout (build-tools 36.0.0) of the public v1.0.2 APK
const _realPrintCerts =
  'Verifies\n'
  'Verified using v1 scheme (JAR signing): false\n'
  'Verified using v2 scheme (APK Signature Scheme v2): true\n'
  'Verified using v3 scheme (APK Signature Scheme v3): false\n'
  'Verified using v3.1 scheme (APK Signature Scheme v3.1): false\n'
  'Verified using v4 scheme (APK Signature Scheme v4): false\n'
  'Verified for SourceStamp: false\n'
  'Number of signers: 1\n'
  'Signer #1 certificate DN: CN=Ikuyo Finance, OU=, O=, L=, ST=, C=ID\n'
  'Signer #1 certificate SHA-256 digest: c48112390477dbbdae99e54068eddccdc547ca7b8e18a7f2cea4a84fd98b6ccf\n'
  'Signer #1 certificate SHA-1 digest: 54b098748ca230cfad8b2a88ff77896e2331fd2f\n'
  'Signer #1 certificate MD5 digest: b2d70ea165bd8b4d4466774eb4394968\n'
  'Signer #1 key algorithm: RSA\n'
  'Signer #1 key size (bits): 2048\n'
  'Signer #1 public key SHA-256 digest: 6ebdd479c339e80196cfb19becb25bb6b05aa23b9a5fe22c8ee3a38e9c1b9d84\n'
  'Signer #1 public key SHA-1 digest: f3aa2595c99f0590a06d18625f756b0c54023559\n'
  'Signer #1 public key MD5 digest: 72e2051e529e5e4797f45144614302e2\n';
const _allowedActions = {
  'actions/checkout',
  'subosito/flutter-action',
  'actions/cache',
  'actions/setup-java',
  'actions/upload-artifact',
};
// * pub-enabled release config regenerates the registrant without dev plugins
const _releaseRegistrantPrep = 'flutter build apk --release --config-only';
const _signingSecrets = [
  'KEYSTORE_BASE64',
  'KEYSTORE_PASSWORD',
  'KEY_PASSWORD',
  'KEY_ALIAS',
];

List<String> qaWorkflowViolations(String source) {
  final v = <String>[];
  final Map<String, Object?> wf;
  try {
    wf = parseWorkflow(source);
  } on FormatException catch (e) {
    return ['parse: ${e.message}'];
  }

  // * trigger: push to qa/herguri-* branches only
  final on = asMap(wf['on']);
  if (on.keys.toList().join(',') != 'push') {
    v.add('trigger: only `push` is allowed, got ${on.keys.toList()}');
  }
  final push = asMap(on['push']);
  if (push.keys.toList().join(',') != 'branches') {
    v.add('trigger: push may only filter `branches`, got ${push.keys.toList()}');
  }
  final branches = asList(push['branches']);
  if (branches.length != 1 || branches.single != 'qa/herguri-*') {
    v.add('trigger: branches must be exactly [qa/herguri-*], got $branches');
  }

  if (!_readOnly(wf['permissions'])) {
    v.add('permissions: workflow default must be exactly contents: read');
  }
  if (RegExp(r':\s*write\b').hasMatch(source.replaceAll('\r\n', '\n'))) {
    v.add('permissions: no write permission may appear anywhere');
  }

  final env = asMap(wf['env']);
  if (env['FLUTTER_VERSION'] != '3.44.5') {
    v.add('flutter: FLUTTER_VERSION must be 3.44.5');
  }
  if (env['QA_EXPECTED_CERT_SHA256'] != _expectedCert) {
    v.add('certificate: QA_EXPECTED_CERT_SHA256 must be the released cert');
  }

  final jobs = asMap(wf['jobs']);
  if (jobs.keys.toList().join(',') != 'verify,signed-apk') {
    v.add('jobs: exactly [verify, signed-apk] are allowed, got ${jobs.keys.toList()}');
  }

  var uploads = 0;
  for (final entry in jobs.entries) {
    final id = entry.key;
    final job = asMap(entry.value);
    if (job['runs-on'] != 'ubuntu-latest') {
      v.add('jobs: $id must run on ubuntu-latest');
    }
    if (!_readOnly(job['permissions'])) {
      v.add('permissions: job $id must be exactly contents: read');
    }
    final steps = asList(job['steps']).map(asMap).toList();
    var pubGets = 0;
    var flutterSetups = 0;
    for (final step in steps) {
      final uses = step['uses'];
      if (uses is String) {
        final m = RegExp(r'^([\w.-]+/[\w.-]+)@([0-9a-f]{40})$').firstMatch(uses);
        if (m == null) {
          v.add('actions: $uses must be pinned to a full commit sha');
        } else if (!_allowedActions.contains(m.group(1))) {
          v.add('actions: ${m.group(1)} is not an allowed action');
        }
        if (uses.startsWith('subosito/flutter-action@')) {
          flutterSetups++;
          if (asMap(step['with'])['flutter-version'] !=
              r'${{ env.FLUTTER_VERSION }}') {
            v.add('flutter: $id must use the pinned FLUTTER_VERSION');
          }
        }
        if (uses.startsWith('actions/checkout@') &&
            asMap(step['with'])['persist-credentials'] != 'false') {
          v.add('actions: checkout in $id must not persist credentials');
        }
        if (uses.startsWith('actions/upload-artifact@')) {
          uploads++;
          v.addAll(_uploadViolations(asMap(step['with'])));
        }
      }
      for (final e in asMap(step['env']).entries) {
        final val = '${e.value}';
        if (!val.contains('secrets.')) continue;
        final m = RegExp(r'^\$\{\{\s*secrets\.([A-Z0-9_]+)\s*\}\}$').firstMatch(val);
        if (id != 'signed-apk' ||
            m == null ||
            m.group(1) != e.key ||
            !_signingSecrets.contains(e.key)) {
          v.add('secrets: ${e.key} in $id is not an allowed signing secret env');
        }
      }
      final run = step['run'];
      if (run is! String) continue;
      if (run.contains(r'${{')) {
        v.add('inline: expression expanded inline in a script in $id');
      }
      for (final bad in [
        RegExp(r'\bgit\s+(push|tag)\b'),
        RegExp(r'\bgh\s'),
        RegExp(r'\bset\s+-[a-wyz]*x'),
        RegExp(r'\bkeytool\b'),
        RegExp(r'curl[^\n]*\|\s*(ba)?sh'),
        RegExp(r'\bdeploy\b'),
      ]) {
        if (bad.hasMatch(run)) {
          v.add('forbidden: `${bad.pattern}` in a script in $id');
        }
      }
      for (final line in run.split('\n').map((l) => l.trim())) {
        if (RegExp(r'\b(flutter|dart) pub\b').hasMatch(line)) {
          pubGets++;
          if (line != 'flutter pub get --enforce-lockfile') {
            v.add('pub get: `$line` must be `flutter pub get --enforce-lockfile`');
          }
        }
        final cmd = RegExp(r'^flutter (analyze|test|build)\b').firstMatch(line);
        if (cmd != null &&
            !line.contains('--no-pub') &&
            line != _releaseRegistrantPrep) {
          v.add('--no-pub: `$line` must not re-resolve dependencies');
        }
        if (line.startsWith('flutter analyze') &&
            !line.contains('--no-fatal-infos')) {
          v.add('fatal-infos: analyze must keep --no-fatal-infos');
        }
      }
    }
    if (flutterSetups != 1 || pubGets != 1) {
      v.add('pub get: $id must set up Flutter and run pub get exactly once');
    }
  }
  if (uploads != 1) v.add('upload: exactly one artifact upload is allowed');

  v.addAll(_verifyJobViolations(asMap(jobs['verify'])));
  v.addAll(_signedJobViolations(asMap(jobs['signed-apk'])));
  return v;
}

bool _readOnly(Object? permissions) {
  final p = asMap(permissions);
  return p.length == 1 && p['contents'] == 'read';
}

String _scripts(Map<String, Object?> job) => asList(job['steps'])
    .map(asMap)
    .map((s) => s['run'])
    .whereType<String>()
    .join('\n');

List<String> _verifyJobViolations(Map<String, Object?> job) {
  final v = <String>[];
  final all = job.toString();
  if (all.contains('secrets.') || all.contains('KEYSTORE')) {
    v.add('verify: the verify job must be secrets-free');
  }
  final s = _scripts(job);
  for (final need in [
    'flutter analyze --no-pub --no-fatal-infos',
    'flutter test --no-pub',
    'objectbox-c/releases/download/v5.3.1/objectbox-linux-x64.tar.gz',
    r'echo "$OBX_C_SHA256  $RUNNER_TEMP/$archive" | sha256sum -c -',
  ]) {
    if (!s.contains(need)) v.add('verify: missing `$need`');
  }
  if (s.contains('flutter build')) v.add('verify: must not build');
  return v;
}

List<String> _signedJobViolations(Map<String, Object?> job) {
  final v = <String>[];
  final needs = job['needs'];
  final needList = needs is String ? [needs] : asList(needs);
  if (!needList.contains('verify')) {
    v.add('needs: signed-apk must depend on verify');
  }
  final steps = asList(job['steps']).map(asMap).toList();
  int at(bool Function(String run) f) => steps.indexWhere(
        (s) => s['run'] is String && f(s['run']! as String),
      );

  final signing = at((r) => r.contains('android/key.properties') && r.contains('base64 --decode'));
  final build = at(
    (r) => r.contains('flutter build apk') && !r.contains('--config-only'),
  );
  final pubGet = at((r) => r.trim() == 'flutter pub get --enforce-lockfile');
  final prep = at(
    (r) => r.split('\n').map((l) => l.trim()).contains(_releaseRegistrantPrep),
  );
  final cleanup = at((r) => r.trim().startsWith('rm -f') && r.contains('android/key.properties'));
  final certs = at((r) => r.contains('apksigner'));

  if (signing < 0) {
    v.add('fail-closed: no signing setup step');
  } else {
    final r = steps[signing]['run']! as String;
    for (final k in _signingSecrets) {
      if (!r.contains('[ -n "\$$k" ] || {') || !r.contains('$k secret is missing')) {
        v.add('fail-closed: $k is not checked before signing');
      }
    }
    if (!r.contains('[ "\$missing" = 0 ] || exit 1')) {
      v.add('fail-closed: missing secrets do not stop the job');
    }
    if (!r.startsWith('set -euo pipefail')) {
      v.add('fail-closed: signing script must start with set -euo pipefail');
    }
  }
  if (build < 0) {
    v.add('universal: no APK build step');
  } else {
    final r = (steps[build]['run']! as String).trim();
    if (r != 'flutter build apk --release --no-pub') {
      v.add('universal: build must be exactly `flutter build apk --release --no-pub`');
    }
  }
  if (prep < 0) {
    v.add('registrant: no `$_releaseRegistrantPrep` step regenerates the release plugin registrant');
  } else {
    final ls = (steps[prep]['run']! as String).split('\n').map((l) => l.trim()).toList();
    const hash =
        'sha256sum pubspec.lock .dart_tool/package_config.json > "\$RUNNER_TEMP/qa-pub-state.sha256"';
    const check = 'sha256sum -c "\$RUNNER_TEMP/qa-pub-state.sha256"';
    final i = ls.indexOf(_releaseRegistrantPrep);
    if (ls.first != 'set -euo pipefail' ||
        !ls.contains(hash) ||
        ls.indexOf(hash) > i ||
        ls.indexOf(check) < i) {
      v.add('registrant: the release registrant step must fail closed if the lock state changes');
    }
    if (pubGet < 0 || prep < pubGet || (signing >= 0 && prep > signing) || (build >= 0 && prep > build)) {
      v.add('registrant: must run after the locked pub get and before signing and the APK build');
    }
  }
  if (cleanup < 0 || steps[cleanup]['if'] != 'always()' || cleanup < build) {
    v.add('cleanup: signing material must be removed with if: always() after the build');
  } else if (!(steps[cleanup]['run']! as String).contains('kawai-qa-release.jks')) {
    v.add('cleanup: the generated keystore must be removed');
  }
  if (certs < 0 || certs < build) {
    v.add('certificate: no apksigner verification after the build');
  } else {
    final r = steps[certs]['run']! as String;
    final ls = r.split('\n').map((l) => l.trim()).toList();
    for (final need in [
      'set -euo pipefail',
      'rc=0',
      '"\$apksigner" verify --verbose --print-certs "\$apk" > "\$certs" || rc=\$?',
      'cat "\$certs"',
      '[ "\$rc" -eq 0 ] || { echo "::error::apksigner verify exited \$rc"; exit 1; }',
      "[ \"\$(tr -dc '\\r' < \"\$certs\" | wc -c)\" -eq 0 ] || "
          '{ echo "::error::apksigner output has CR line endings"; exit 1; }',
      "grep -qx 'Number of signers: 1' \"\$certs\" || "
          '{ echo "::error::apksigner did not report exactly one signer"; exit 1; }',
      _leafDigest,
      "mapfile -t lines < <(grep -F ' certificate SHA-256 digest: ' \"\$certs\" | grep -v '^Source Stamp Signer')",
      'mapfile -t digests < <(sed -nE "s/\$leaf/\\5/p" "\$certs")',
      'if [ "\${#lines[@]}" -ne 1 ]; then',
      'if [ "\${#digests[@]}" -ne 1 ]; then',
      'if [ "\${digests[0]}" != "\$QA_EXPECTED_CERT_SHA256" ]; then',
    ]) {
      if (!ls.contains(need)) v.add('certificate: missing `$need`');
    }
    final cat = ls.indexOf('cat "\$certs"');
    final firstCheck = ls.indexWhere((l) => l.startsWith('[ "\$rc" -eq 0 ]'));
    if (cat < 0 || firstCheck < 0 || cat > firstCheck) {
      v.add('certificate: the public apksigner output must be printed before any check');
    }
    if (RegExp(r'exit 1').allMatches(r).length < 8) {
      v.add('certificate: every check must exit 1');
    }
  }
  return v;
}

List<String> _uploadViolations(Map<String, Object?> w) {
  final v = <String>[];
  final name = '${w['name']}';
  if (!name.startsWith('qa-only-')) v.add('artifact name: must start with qa-only-');
  final days = int.tryParse('${w['retention-days']}') ?? 999;
  if (days > 7) v.add('retention: QA artifacts must expire within 7 days');
  if (w['if-no-files-found'] != 'error') {
    v.add('upload: must fail when the QA files are missing');
  }
  final paths = '${w['path']}'.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty);
  final allowed = RegExp(
    r'^\$\{\{ runner\.temp \}\}/qa-out/'
    r'(kawai-notes-qa-\*-universal\.apk|apksigner-print-certs\.txt|qa-manifest\.txt)$',
  );
  for (final p in paths) {
    if (!allowed.hasMatch(p)) v.add('upload: `$p` is not an allowed QA file');
  }
  return v;
}

int compareVersions(String a, String b) {
  final x = a.split('.').map(int.parse).toList();
  final y = b.split('.').map(int.parse).toList();
  for (var i = 0; i < 3; i++) {
    final c = x[i].compareTo(y[i]);
    if (c != 0) return c;
  }
  return 0;
}

// ---------------------------------------------------------------------------
// Minimal block-YAML parser (maps, sequences, block scalars, flow lists)
// ---------------------------------------------------------------------------

Map<String, Object?> asMap(Object? o) =>
    o is Map<String, Object?> ? o : <String, Object?>{};

List<Object?> asList(Object? o) => o is List<Object?> ? o : <Object?>[];

Map<String, Object?> parseWorkflow(String source) {
  final p = _Parser(source.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n'));
  final root = p.node(0);
  p.skip();
  if (p.i < p.lines.length) {
    throw FormatException('unexpected content at line ${p.i + 1}');
  }
  if (root is! Map<String, Object?>) {
    throw const FormatException('workflow root is not a mapping');
  }
  return root;
}

class _Parser {
  _Parser(this.lines);

  final List<String> lines;
  int i = 0;

  static int _indent(String l) => l.length - l.trimLeft().length;

  static bool _blank(String l) {
    final t = l.trim();
    return t.isEmpty || t.startsWith('#');
  }

  void skip() {
    while (i < lines.length && _blank(lines[i])) {
      i++;
    }
  }

  Object? node(int min) {
    skip();
    if (i >= lines.length) return null;
    final ind = _indent(lines[i]);
    if (ind < min) return null;
    if (lines[i].contains('\t')) throw FormatException('tab at line ${i + 1}');
    final t = lines[i].trimLeft();
    return t == '-' || t.startsWith('- ') ? seq(ind) : map(ind);
  }

  Map<String, Object?> map(int ind) {
    final out = <String, Object?>{};
    while (true) {
      skip();
      if (i >= lines.length) break;
      final line = lines[i];
      final li = _indent(line);
      if (li < ind) break;
      if (li > ind) throw FormatException('bad indentation at line ${i + 1}');
      final t = _stripComment(line.trimLeft());
      if (t.startsWith('- ')) break;
      final c = _keySplit(t);
      if (c < 0) throw FormatException('expected key at line ${i + 1}: $t');
      final key = _unquote(t.substring(0, c).trim());
      final rest = t.substring(c + 1).trim();
      if (out.containsKey(key)) {
        throw FormatException('duplicate key `$key` at line ${i + 1}');
      }
      i++;
      if (rest.isEmpty) {
        skip();
        if (i < lines.length &&
            _indent(lines[i]) == ind &&
            lines[i].trimLeft().startsWith('- ')) {
          out[key] = seq(ind);
        } else {
          out[key] = node(ind + 1);
        }
      } else if (RegExp(r'^[|>][-+]?$').hasMatch(rest)) {
        out[key] = _block(ind, rest.startsWith('>'));
      } else {
        out[key] = _scalar(rest);
      }
    }
    return out;
  }

  List<Object?> seq(int ind) {
    final out = <Object?>[];
    while (true) {
      skip();
      if (i >= lines.length) break;
      final line = lines[i];
      final li = _indent(line);
      final t = line.trimLeft();
      if (li != ind || !(t == '-' || t.startsWith('- '))) {
        if (li > ind) throw FormatException('bad indentation at line ${i + 1}');
        break;
      }
      final item = t == '-' ? '' : t.substring(2);
      final body = _stripComment(item).trim();
      if (body.isEmpty) {
        i++;
        out.add(node(ind + 1));
      } else if (_keySplit(body) >= 0 && !body.startsWith('[') && !body.startsWith('{')) {
        lines[i] = '${' ' * (ind + 2)}$item';
        out.add(map(ind + 2));
      } else {
        i++;
        out.add(_scalar(body));
      }
    }
    return out;
  }

  String _block(int parent, bool folded) {
    final buf = <String>[];
    int? ind;
    while (i < lines.length) {
      final l = lines[i];
      if (l.trim().isEmpty) {
        buf.add('');
        i++;
        continue;
      }
      final li = _indent(l);
      if (li <= parent) break;
      ind ??= li;
      if (li < ind) throw FormatException('bad block indentation at line ${i + 1}');
      buf.add(l.substring(ind));
      i++;
    }
    while (buf.isNotEmpty && buf.last.isEmpty) {
      buf.removeLast();
    }
    return buf.join(folded ? ' ' : '\n');
  }

  static int _keySplit(String t) {
    var q = '';
    for (var k = 0; k < t.length; k++) {
      final ch = t[k];
      if (q.isNotEmpty) {
        if (ch == q) q = '';
        continue;
      }
      if (ch == "'" || ch == '"') {
        if (k == 0) q = ch;
        continue;
      }
      if (ch == '{' && k + 1 < t.length && t[k + 1] == '{') return -1;
      if (ch == ':' && (k + 1 == t.length || t[k + 1] == ' ')) return k;
    }
    return -1;
  }

  static String _stripComment(String t) {
    var q = '';
    for (var k = 0; k < t.length; k++) {
      final ch = t[k];
      if (q.isNotEmpty) {
        if (ch == q) q = '';
      } else if (ch == "'" || ch == '"') {
        q = ch;
      } else if (ch == '#' && (k == 0 || t[k - 1] == ' ')) {
        return t.substring(0, k).trimRight();
      }
    }
    return t;
  }

  static String _unquote(String s) {
    if (s.length >= 2 &&
        ((s.startsWith("'") && s.endsWith("'")) ||
            (s.startsWith('"') && s.endsWith('"')))) {
      return s.substring(1, s.length - 1);
    }
    return s;
  }

  static Object? _scalar(String s) {
    if (s.startsWith('[') && s.endsWith(']')) {
      final inner = s.substring(1, s.length - 1).trim();
      if (inner.isEmpty) return <Object?>[];
      return inner.split(',').map((e) => _unquote(e.trim())).toList();
    }
    if (s.startsWith('{')) throw FormatException('flow mapping not supported: $s');
    return _unquote(s);
  }
}
