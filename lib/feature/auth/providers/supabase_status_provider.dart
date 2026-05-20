import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kawai_notes/core/utils/logger.dart';
import 'package:kawai_notes/feature/auth/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum SupabaseAvailability {
  /// Supabase initialized and reachable (session may or may not exist)
  available,

  /// Network is offline or Supabase could not be reached
  unavailable,

  /// Supabase SDK was never initialized (missing env vars)
  notConfigured,
}

class SupabaseStatus {
  final SupabaseAvailability availability;
  final bool hasSession;

  const SupabaseStatus({
    required this.availability,
    required this.hasSession,
  });

  bool get isCloudEnabled =>
      availability == SupabaseAvailability.available && hasSession;

  bool get isConfigured =>
      availability != SupabaseAvailability.notConfigured;

  @override
  String toString() =>
      'SupabaseStatus(availability: $availability, hasSession: $hasSession)';
}

class SupabaseStatusNotifier extends Notifier<SupabaseStatus> {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<AuthState>? _authSub;

  @override
  SupabaseStatus build() {
    final client = ref.watch(supabaseClientProvider);

    ref.onDispose(() {
      _connectivitySub?.cancel();
      _authSub?.cancel();
    });

    if (client == null) {
      return const SupabaseStatus(
        availability: SupabaseAvailability.notConfigured,
        hasSession: false,
      );
    }

    // * Listen to auth state changes and mirror to this notifier
    _authSub?.cancel();
    _authSub = client.auth.onAuthStateChange.listen(
      (authState) {
        final hasSession = authState.session != null;
        if (state.availability == SupabaseAvailability.available &&
            state.hasSession != hasSession) {
          state = SupabaseStatus(
            availability: SupabaseAvailability.available,
            hasSession: hasSession,
          );
        }
      },
      onError: (Object e) {
        AppLogger.instance.error('Auth state stream error', e);
        state = SupabaseStatus(
          availability: SupabaseAvailability.unavailable,
          hasSession: state.hasSession,
        );
      },
    );

    // * Listen to connectivity changes
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen(
      (results) {
        final hasNetwork = results.any(
          (r) => r != ConnectivityResult.none,
        );
        if (!hasNetwork) {
          state = SupabaseStatus(
            availability: SupabaseAvailability.unavailable,
            hasSession: state.hasSession,
          );
        } else if (state.availability == SupabaseAvailability.unavailable) {
          // * Network restored — re-probe Supabase
          _probeSupabase(client);
        }
      },
    );

    final initialHasSession = client.auth.currentSession != null;
    return SupabaseStatus(
      availability: SupabaseAvailability.available,
      hasSession: initialHasSession,
    );
  }

  /// Wraps a Supabase call. On any exception, marks Supabase unavailable
  /// and returns null. Use this for cloud-optional operations.
  Future<T?> guard<T>(Future<T> Function() call) async {
    if (state.availability == SupabaseAvailability.notConfigured) {
      return null;
    }
    try {
      final result = await call();
      // * Successful call — restore available if it was degraded
      if (state.availability == SupabaseAvailability.unavailable) {
        state = SupabaseStatus(
          availability: SupabaseAvailability.available,
          hasSession: state.hasSession,
        );
      }
      return result;
    } catch (e, stack) {
      AppLogger.instance.error('Supabase call failed — degrading to offline', e, stack);
      state = SupabaseStatus(
        availability: SupabaseAvailability.unavailable,
        hasSession: state.hasSession,
      );
      return null;
    }
  }

  Future<void> _probeSupabase(SupabaseClient client) async {
    try {
      // * Probe: attempt a session refresh if a session exists,
      // * otherwise just confirm the client is accessible via currentSession.
      final currentSession = client.auth.currentSession;
      if (currentSession != null) {
        await client.auth.refreshSession();
      }
      final hasSession = client.auth.currentSession != null;
      state = SupabaseStatus(
        availability: SupabaseAvailability.available,
        hasSession: hasSession,
      );
      AppLogger.instance.info('Supabase back online');
    } catch (e) {
      AppLogger.instance.error('Supabase probe failed', e);
      state = SupabaseStatus(
        availability: SupabaseAvailability.unavailable,
        hasSession: state.hasSession,
      );
    }
  }

  /// Mark Supabase as unavailable immediately (e.g. after a failed auth call
  /// where statusCode == null, meaning no response was received).
  void markUnavailable() {
    state = SupabaseStatus(
      availability: SupabaseAvailability.unavailable,
      hasSession: state.hasSession,
    );
  }

  /// Manually trigger a re-probe (e.g., after user taps retry)
  Future<void> retry() async {
    final client = ref.read(supabaseClientProvider);
    if (client == null) return;
    await _probeSupabase(client);
  }
}

final supabaseStatusProvider =
    NotifierProvider<SupabaseStatusNotifier, SupabaseStatus>(
  SupabaseStatusNotifier.new,
);

/// Convenience provider — true when cloud features should be enabled
final isCloudEnabledProvider = Provider<bool>((ref) {
  return ref.watch(supabaseStatusProvider).isCloudEnabled;
});

/// Convenience provider — true when Supabase is configured at all
final isSupabaseConfiguredProvider = Provider<bool>((ref) {
  return ref.watch(supabaseStatusProvider).isConfigured;
});
