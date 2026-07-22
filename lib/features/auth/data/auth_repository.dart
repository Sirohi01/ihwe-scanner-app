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
    final token = result['token']?.toString() ?? '';
    if (token.isEmpty || admin.isEmpty) {
      throw ApiException('Unable to create a valid user session.', 401);
    }
    await session.save(
        newToken: token,
        newUsername: admin['fullName']?.toString().isNotEmpty == true
            ? admin['fullName']
            : admin['username'],
        newRole: role,
        newProfileImage: admin['profileImage']?.toString() ?? '');
  }
}
