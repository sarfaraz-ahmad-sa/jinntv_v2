import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/db_helper.dart';

class SessionManager {
  /// SAVE LOGIN
  static Future<void> saveLogin(String email) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('email', email);
    } else {
      await DBHelper.saveSession(email);
      await DBHelper.addLog("Login saved: $email");
    }
  }

  /// CHECK LOGIN
  static Future<bool> isLoggedIn() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey('email');
    } else {
      return DBHelper.isLoggedIn();
    }
  }

  /// LOGOUT
  static Future<void> logout() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } else {
      await DBHelper.logout();
    }
  }
}
