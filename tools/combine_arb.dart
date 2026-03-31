// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

void main() async {
  final sourceDir = Directory('lib');
  final targetDir = Directory('lib/l10n');

  if (!await targetDir.exists()) {
    await targetDir.create(recursive: true);
  }

  // Semua locale yang didukung
  final locales = ['en', 'ja', 'id'];

  for (final locale in locales) {
    final combinedMap = <String, dynamic>{};
    combinedMap['@@locale'] = locale;

    // Cari semua file .arb untuk locale saat ini
    await _findAndCombineArbFiles(sourceDir, locale, combinedMap);

    // Tulis file gabungan
    final targetFile = File('${targetDir.path}/app_$locale.arb');
    const encoder = JsonEncoder.withIndent('  ');
    await targetFile.writeAsString(encoder.convert(combinedMap));
    print('✅ Successfully generated ${targetFile.path}');
  }
}

Future<void> _findAndCombineArbFiles(
  Directory dir,
  String locale,
  Map<String, dynamic> combinedMap,
) async {
  final files = dir.listSync(recursive: true);

  for (final file in files) {
    if (file is File && file.path.endsWith('_$locale.arb')) {
      // Skip file yang sudah ada di l10n_generated atau di lib/l10n (output directory)
      if (file.path.contains('l10n_generated') ||
          file.path.contains(r'lib\l10n')) {
        continue;
      }

      print('📁 Found: ${file.path}');

      try {
        final content = await file.readAsString();
        final Map<String, dynamic> json =
            jsonDecode(content) as Map<String, dynamic>;

        // Hapus @@locale dari individual files
        json.remove('@@locale');

        // Gabungkan dengan check duplikasi
        json.forEach((key, value) {
          if (combinedMap.containsKey(key)) {
            print('⚠️  Warning: Duplicate key "$key" found in ${file.path}');
          }
          combinedMap[key] = value;
        });
      } catch (e) {
        print('❌ Error decoding JSON from ${file.path}: $e');
      }
    }
  }
}
