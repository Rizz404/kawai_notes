import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/core/utils/log_redaction.dart';
import 'package:kawai_notes/core/utils/logger.dart';
import 'package:kawai_notes/core/utils/talker_config.dart';

class _Secret {
  _Secret(this.body);
  final String body;
  @override
  String toString() => 'Note(content: $body)';
}

class _SecretNotifier extends Notifier<_Secret> {
  @override
  _Secret build() => _Secret('initial-plaintext');
  void set(String v) => state = _Secret(v);
}

final _secretProvider = NotifierProvider<_SecretNotifier, _Secret>(
  _SecretNotifier.new,
);

void main() {
  group('NEW-5 riverpod observer must not log full provider state', () {
    test('provider state content never reaches talker history', () async {
      AppLogger.instance.talker.cleanHistory();
      final container = ProviderContainer(
        observers: [TalkerConfig.riverpodObserver],
      );
      addTearDown(container.dispose);
      container.read(_secretProvider);
      container.read(_secretProvider.notifier).set('TOP-SECRET-HIDDEN-BODY');
      await Future<void>.delayed(Duration.zero);
      final dump = AppLogger.instance.talker.history
          .map((e) => e.generateTextMessage())
          .join('\n');
      expect(dump, isNot(contains('TOP-SECRET-HIDDEN-BODY')));
      expect(dump, isNot(contains('initial-plaintext')));
    });
  });

  group('F10 deep-link URIs are redacted before logging', () {
    test('query and fragment tokens are stripped', () {
      final uri = Uri.parse(
        'io.supabase.kawainotes://login-callback/?code=AUTHCODE123'
        '#access_token=ACCESS456&refresh_token=REFRESH789',
      );
      final out = redactUriForLog(uri);
      expect(out, isNot(contains('AUTHCODE123')));
      expect(out, isNot(contains('ACCESS456')));
      expect(out, isNot(contains('REFRESH789')));
      expect(out, contains('io.supabase.kawainotes'));
      expect(out, contains('login-callback'));
    });

    test('widget note ids are not logged', () {
      final uri = Uri.parse('kawainotes://widget/note?noteId=42&widgetId=7');
      final out = redactUriForLog(uri);
      expect(out, isNot(contains('42')));
      expect(out, contains('<redacted>'));
    });

    test('uri without query is unchanged', () {
      final uri = Uri.parse('kawainotes://open');
      expect(redactUriForLog(uri), 'kawainotes://open');
    });
  });
}
