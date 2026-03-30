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
  static const int _sessionDurationDays = 24;

  static Future<void> saveSession({
    required int orgId,
    required int userId,
    required String token,
    bool rememberMe = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyOrgId, orgId);
    await prefs.setInt(_keyUserId, userId);
    await prefs.setString(_keyToken, token);
    if (rememberMe) {
      await prefs.setInt(_keyLoginTime, DateTime.now().millisecondsSinceEpoch);
      await prefs.setBool(_keyRememberMe, true);
    } else {
      await prefs.remove(_keyLoginTime);
      await prefs.setBool(_keyRememberMe, false);
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

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
