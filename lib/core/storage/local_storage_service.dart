import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper over [SharedPreferences] for the small bits of local state
/// MediTrack persists: whether the user is subscribed/authenticated via
/// BD Apps OTP, and the phone number they used.
///
/// Other domains (medicines, prescriptions, buy list) persist through
/// Firestore, not SharedPreferences, so they don't appear here.
class LocalStorageService {
  static const _keyIsAuthenticated = 'is_authenticated';
  static const _keyPhoneNumber = 'phone_number';
  static const _keySubscriptionStatus = 'subscription_status';

  Future<bool> getIsAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsAuthenticated) ?? false;
  }

  Future<void> setAuthenticated({required String phoneNumber}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsAuthenticated, true);
    await prefs.setString(_keyPhoneNumber, phoneNumber);
  }

  Future<void> clearAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsAuthenticated);
    await prefs.remove(_keyPhoneNumber);
    await prefs.remove(_keySubscriptionStatus);
  }

  Future<String?> getPhoneNumber() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPhoneNumber);
  }

  /// Persists the last-known subscription status (e.g. `REGISTERED`) so the
  /// app can render the right home screen on cold start without a network
  /// round-trip.
  Future<void> setSubscriptionStatus(String status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySubscriptionStatus, status);
  }

  Future<String?> getSubscriptionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySubscriptionStatus);
  }
}
