import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionStore extends ChangeNotifier {
  String? token;
  String username = '';
  String role = '';
  bool get isLoggedIn => token?.isNotEmpty == true;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('admin_token');
    username = prefs.getString('admin_username') ?? '';
    role = prefs.getString('admin_role') ?? '';
  }

  Future<void> save(
      {required String newToken,
      required String newUsername,
      required String newRole}) async {
    token = newToken;
    username = newUsername;
    role = newRole;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('admin_token', newToken);
    await prefs.setString('admin_username', newUsername);
    await prefs.setString('admin_role', newRole);
    notifyListeners();
  }

  Future<void> clear() async {
    token = null;
    username = '';
    role = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('admin_token');
    await prefs.remove('admin_username');
    await prefs.remove('admin_role');
    notifyListeners();
  }
}
