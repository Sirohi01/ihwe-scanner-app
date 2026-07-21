import '../../../core/network/api_client.dart';
import '../../../core/storage/session_store.dart';
import '../domain/attendance_models.dart';

class AttendanceRepository {
  AttendanceRepository(SessionStore session) : api = ApiClient(session);
  final ApiClient api;
  Future<ScanResult> resolve(String raw) async {
    final result = await api.post('/attendance/resolve', {'raw': raw});
    return ScanResult.fromJson(Map<String, dynamic>.from(result['data']));
  }

  Future<List<Map<String, dynamic>>> mark(String raw, List<String> days) async {
    final result = await api
        .post('/attendance/mark', {'raw': raw, 'days': days, 'source': 'qr'});
    return List<Map<String, dynamic>>.from(result['data']['results']);
  }

  Future<Map<String, dynamic>> dashboard(
          {String? day, String? type, String? subType}) async =>
      (await api.get('/attendance/dashboard', query: {
        if (day != null) 'day': day,
        if (type?.isNotEmpty == true) 'type': type!,
        if (subType?.isNotEmpty == true) 'subType': subType!,
      }))['data'];
  Future<List<Map<String, dynamic>>> records(
          {String? day,
          String? type,
          String? subType,
          String? search,
          int page = 1,
          int limit = 50}) async =>
      List<Map<String, dynamic>>.from(
          (await api.get('/attendance/records', query: {
        if (day?.isNotEmpty == true) 'day': day!,
        if (type?.isNotEmpty == true) 'type': type!,
        if (subType?.isNotEmpty == true) 'subType': subType!,
        if (search?.isNotEmpty == true) 'search': search!,
        'page': '$page',
        'limit': '$limit',
      }))['data']);

  Future<Map<String, dynamic>> companyDetail(String companyId) async =>
      Map<String, dynamic>.from(
          (await api.get('/attendance/companies/$companyId'))['data']);

  Future<Map<String, dynamic>> attendanceProfile(String attendanceId) async =>
      Map<String, dynamic>.from(
          (await api.get('/attendance/profile/$attendanceId'))['data']);
}
