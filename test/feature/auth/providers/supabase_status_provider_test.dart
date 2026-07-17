import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/feature/auth/providers/supabase_status_provider.dart';

void main() {
  group('SupabaseStatus', () {
    test('isCloudEnabled is true only when available and has a session', () {
      const status = SupabaseStatus(
        availability: SupabaseAvailability.available,
        hasSession: true,
      );

      expect(status.isCloudEnabled, isTrue);
    });

    test('isCloudEnabled is false when available but no session', () {
      const status = SupabaseStatus(
        availability: SupabaseAvailability.available,
        hasSession: false,
      );

      expect(status.isCloudEnabled, isFalse);
    });

    test('isCloudEnabled is false when unavailable even with a session', () {
      const status = SupabaseStatus(
        availability: SupabaseAvailability.unavailable,
        hasSession: true,
      );

      expect(status.isCloudEnabled, isFalse);
    });

    test('isConfigured is false only when notConfigured', () {
      const notConfigured = SupabaseStatus(
        availability: SupabaseAvailability.notConfigured,
        hasSession: false,
      );
      const unavailable = SupabaseStatus(
        availability: SupabaseAvailability.unavailable,
        hasSession: false,
      );
      const available = SupabaseStatus(
        availability: SupabaseAvailability.available,
        hasSession: false,
      );

      expect(notConfigured.isConfigured, isFalse);
      expect(unavailable.isConfigured, isTrue);
      expect(available.isConfigured, isTrue);
    });
  });
}
