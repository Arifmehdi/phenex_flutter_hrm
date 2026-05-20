import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const String _keyOrgId = 'org_id';
  static const String _keyUserId = 'user_id';
  static const String _keyToken = 'token';
  static const String _keyLoginTime = 'login_time';
  static const String _keyRememberMe = 'remember_me';
  static const String _keyUserData = 'user_data';
  static const String _keyMenuData = 'menu_data';
  static const String _keyStoredPhone = 'stored_phone';
  static const String _keyStoredPassword = 'stored_password';
  static const int _sessionDurationDays = 24;

  static Future<void> saveSession({
    required int orgId,
    required int userId,
    required String token,
    bool rememberMe = false,
    String? phone,
    String? password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyOrgId, orgId);
    await prefs.setInt(_keyUserId, userId);
    await prefs.setString(_keyToken, token);
    await prefs.setBool(_keyRememberMe, rememberMe);

    if (rememberMe) {
      // For lifetime sessions, do NOT set loginTime (no expiration)
      // If previously existed, remove it to avoid time-based expiry
      await prefs.remove(_keyLoginTime);

      // Store credentials if provided
      if (phone != null && password != null) {
        await saveStoredCredentials(phone, password);
      }
    } else {
      // Non-remembered session: remove login time and stored credentials
      await prefs.remove(_keyLoginTime);
      await clearStoredCredentials();
    }
  }

  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserData, json.encode(userData));
  }

  static Future<void> saveMenuData(List<dynamic> menuData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMenuData, json.encode(menuData));
  }

  static Future<int?> getOrgId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyOrgId);
  }

  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyUserId);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  static Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyUserData);
    if (jsonString == null) return null;
    return json.decode(jsonString);
  }

  static Future<List<dynamic>?> getMenuData() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyMenuData);
    if (jsonString == null) return null;
    return json.decode(jsonString);
  }

  static Future<void> saveStoredCredentials(String phone, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStoredPhone, phone);
    await prefs.setString(_keyStoredPassword, password);
  }

  static Future<Map<String, String>?> getStoredCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString(_keyStoredPhone);
    final password = prefs.getString(_keyStoredPassword);
    if (phone != null && password != null) {
      return {'phone': phone, 'password': password};
    }
    return null;
  }

  static Future<void> clearStoredCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyStoredPhone);
    await prefs.remove(_keyStoredPassword);
  }

  static Future<Map<String, dynamic>> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'orgId': prefs.getInt(_keyOrgId),
      'userId': prefs.getInt(_keyUserId),
      'token': prefs.getString(_keyToken),
      'rememberMe': prefs.getBool(_keyRememberMe) ?? false,
    };
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyToken);
    final rememberMe = prefs.getBool(_keyRememberMe) ?? false;
    final loginTime = prefs.getInt(_keyLoginTime);

    if (token == null) {
      return false;
    }

    if (rememberMe && loginTime != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final sessionAge = now - loginTime;
      const maxSessionAge = _sessionDurationDays * 24 * 60 * 60 * 1000;

      if (sessionAge >= maxSessionAge) {
        await clearSession();
        return false;
      }
      return true;
    }

    return true;
  }

  static Future<void> clearSession({bool keepCredentials = false}) async {
    final prefs = await SharedPreferences.getInstance();

    if (keepCredentials) {
      // Preserve stored credentials but clear everything else
      final storedPhone = prefs.getString(_keyStoredPhone);
      final storedPassword = prefs.getString(_keyStoredPassword);
      final rememberMe = prefs.getBool(_keyRememberMe);

      await prefs.clear();

      // Restore credentials and remember me flag if they existed
      if (storedPhone != null) await prefs.setString(_keyStoredPhone, storedPhone);
      if (storedPassword != null) await prefs.setString(_keyStoredPassword, storedPassword);
      if (rememberMe == true) await prefs.setBool(_keyRememberMe, true);
    } else {
      await prefs.clear();
    }
  }
}
