import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const String _keyOrgId = 'org_id';
  static const String _keyUserId = 'user_id';
  static const String _keyToken = 'token';

  static Future<void> saveSession({
    required int orgId,
    required int userId,
    required String token,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyOrgId, orgId);
    await prefs.setInt(_keyUserId, userId);
    await prefs.setString(_keyToken, token);
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

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
