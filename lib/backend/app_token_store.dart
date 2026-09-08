import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the long-lived Discord-login app token (Android Keystore-backed via
/// flutter_secure_storage) — unlike PS5 IP / backend URL, this is a real credential,
/// not a convenience value, so it doesn't belong in shared_preferences.
class AppTokenStore {
  static const _keyToken = 'app_token';
  static const _keyDriverName = 'app_driver_name';
  static const _keyDriverId = 'app_driver_id';

  final _storage = const FlutterSecureStorage();

  Future<void> save({required String token, required String driverName, required int driverId}) async {
    await _storage.write(key: _keyToken, value: token);
    await _storage.write(key: _keyDriverName, value: driverName);
    await _storage.write(key: _keyDriverId, value: driverId.toString());
  }

  Future<String?> readToken() => _storage.read(key: _keyToken);

  Future<String?> readDriverName() => _storage.read(key: _keyDriverName);

  Future<void> clear() async {
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyDriverName);
    await _storage.delete(key: _keyDriverId);
  }
}
