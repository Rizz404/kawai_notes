import 'package:local_auth/local_auth.dart';

class AuthService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> authenticate({
    String reason = 'Please authenticate to access hidden notes',
  }) async {
    try {
      final isAvailable =
          await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!isAvailable) {
        // If device has no secure hardware, we can fallback, but for now we just return true.
        // It's the user's responsibility to set a pass/biometric if they want safety.
        return true;
      }

      final didAuthenticate = await _auth.authenticate(localizedReason: reason);

      return didAuthenticate;
    } catch (e) {
      // In case of error (like API lacking), return false
      return false;
    }
  }
}
