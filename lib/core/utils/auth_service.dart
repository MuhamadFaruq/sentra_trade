import 'package:local_auth/local_auth.dart';

class AuthService {
  static final _auth = LocalAuthentication();

  static Future<bool> authenticate() async {
    try {
      final isAvailable = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      
      if (!isAvailable || !isDeviceSupported) return true;

      // Untuk local_auth versi 3.x - tidak ada parameter options atau authMessages
      return await _auth.authenticate(
        localizedReason: 'Scan sidik jari untuk membuka SentraTrade',
      );
    } catch (e) {
      return false; 
    }
  }
}