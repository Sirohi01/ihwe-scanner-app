import '../../../core/network/api_client.dart';
import '../../../core/storage/session_store.dart';

class AuthRepository {
  AuthRepository(this.session) : api = ApiClient(session);
  final SessionStore session;
  final ApiClient api;

  Future<void> login(String username, String password) async {
    final result = await api
        .post('/login', {'username': username.trim(), 'password': password});
    final admin = Map<String, dynamic>.from(result['admin'] ?? {});
    final role = admin['role']?.toString() ?? '';
    final normalized =
        role.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    const allowed = {
      'admin',
      'super-admin',
      'super-administrator',
      'ihwe-super-administrator'
    };
    if (!allowed.contains(normalized)) {
      throw ApiException(
          'Only an authorised IHWE administrator can use this app.', 403);
    }
    await session.save(
        newToken: result['token'],
        newUsername: admin['fullName']?.toString().isNotEmpty == true
            ? admin['fullName']
            : admin['username'],
        newRole: role);
  }
}
