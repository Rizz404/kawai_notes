import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// F12 / KEY-PORTABILITY config checks on the Android manifest and Gradle
/// signing (static source checks; device behaviour is verified separately).
void main() {
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();

  test('unused restricted permissions are not requested', () {
    for (final perm in [
      'android.permission.CAMERA',
      'android.permission.READ_MEDIA_VIDEO',
      'android.permission.READ_MEDIA_AUDIO',
    ]) {
      expect(manifest, isNot(contains('"$perm"')), reason: perm);
    }
  });

  test('OS backup excludes the secure-storage key prefs', () {
    expect(manifest, contains('android:dataExtractionRules="@xml/data_extraction_rules"'));
    expect(manifest, contains('android:fullBackupContent="@xml/backup_rules"'));
    for (final f in [
      'android/app/src/main/res/xml/data_extraction_rules.xml',
      'android/app/src/main/res/xml/backup_rules.xml',
    ]) {
      final xml = File(f).readAsStringSync();
      expect(xml, contains('FlutterSecureStorage.xml'), reason: f);
      expect(xml, contains('FlutterSecureKeyStorage.xml'), reason: f);
    }
  });

  test('release build refuses to fall back to debug signing', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('allowDebugSignedRelease'));
    expect(gradle, contains('GradleException'));
  });
}
