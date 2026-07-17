import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/feature/auth/providers/auth_provider.dart';

void main() {
  test(
    'supabaseClientProvider degrades to null instead of throwing when '
    'Supabase.initialize() was never called (offline/misconfigured mode)',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(() => container.read(supabaseClientProvider), returnsNormally);
      expect(container.read(supabaseClientProvider), isNull);
    },
  );

  test('currentUserProvider is null when there is no Supabase client', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(currentUserProvider), isNull);
  });
}
