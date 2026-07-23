import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/session_store.dart';
import '../domain/attendance_models.dart';

class AttendanceRepository {
  AttendanceRepository(SessionStore session) : api = ApiClient(session);
  final ApiClient api;
  static const _files = MethodChannel('ihwe_attendance/files');
  Future<ScanResult> resolve(String raw, {String source = 'qr'}) async {
    final result =
        await api.post('/attendance/resolve', {'raw': raw, 'source': source});
    return ScanResult.fromJson(Map<String, dynamic>.from(result['data']));
  }

  Future<List<Map<String, dynamic>>> manualSearch(String search) async =>
      List<Map<String, dynamic>>.from((await api.get(
          '/attendance/manual-search',
          query: {'search': search}))['data']);

  Future<Map<String, dynamic>> insights() async => Map<String, dynamic>.from(
      (await api.get('/attendance/insights'))['data']);

  Future<Map<String, dynamic>> notifications() async =>
      Map<String, dynamic>.from(
          (await api.get('/attendance/notifications'))['data']);

  Future<int> updateDailyTarget(int target) async {
    final result =
        await api.patch('/attendance/daily-target', {'target': target});
    return int.tryParse(result['data']['target'].toString()) ?? target;
  }

  Future<Map<String, dynamic>> superAdminOperations() async =>
      Map<String, dynamic>.from(
          (await api.get('/attendance/super-admin/operations'))['data']);

  Future<Map<String, dynamic>> employeeOperations(String userId,
          {String? day, String? source, String? action}) async =>
      Map<String, dynamic>.from(
          (await api.get('/attendance/super-admin/operations/$userId', query: {
        if (day?.isNotEmpty == true) 'day': day!,
        if (source?.isNotEmpty == true) 'source': source!,
        if (action?.isNotEmpty == true) 'action': action!,
      }))['data']);

  Future<Map<String, dynamic>> correctAttendance(String id,
          {required String reason, String? day, String? gate}) async =>
      Map<String, dynamic>.from((await api.patch('/attendance/records/$id', {
        'reason': reason,
        if (day?.isNotEmpty == true) 'eventDay': day,
        if (gate != null) 'gate': gate,
      }))['data']);

  Future<void> removeAttendance(String id, String reason) async =>
      api.delete('/attendance/$id', body: {'reason': reason});

  Future<List<Map<String, dynamic>>> mark(String raw, List<String> days,
      {String source = 'qr'}) async {
    final result = await api
        .post('/attendance/mark', {'raw': raw, 'days': days, 'source': source});
    final created = List<Map<String, dynamic>>.from(result['data']['results'])
        .any((item) => item['created'] == true);
    if (created) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
          'last_successful_scan', DateTime.now().toIso8601String());
      syncDeviceHealth();
    }
    return List<Map<String, dynamic>>.from(result['data']['results']);
  }

  Future<Map<String, dynamic>> buyerConcierge(String buyerId) async =>
      Map<String, dynamic>.from(
          (await api.get('/attendance/buyer-concierge/$buyerId'))['data']);

  Future<Map<String, dynamic>> companyTimeline(String companyId) async =>
      Map<String, dynamic>.from(
          (await api.get('/attendance/companies/$companyId/timeline'))['data']);

  Future<Map<String, dynamic>> deviceHealth() async =>
      Map<String, dynamic>.from(
          (await api.get('/attendance/device-health'))['data']);

  Future<Map<String, dynamic>> postEventIntelligence() async =>
      Map<String, dynamic>.from(
          (await api.get('/attendance/post-event-intelligence'))['data']);

  Future<List<Map<String, dynamic>>> communicationConversations() async =>
      List<Map<String, dynamic>>.from(
          (await api.get('/communications/conversations'))['data']);

  Future<List<Map<String, dynamic>>> communicationEmployees() async =>
      List<Map<String, dynamic>>.from(
          (await api.get('/communications/employees'))['data']);

  Future<Map<String, dynamic>> openEmployeeConversation(
          String employeeId) async =>
      Map<String, dynamic>.from((await api.post(
          '/communications/conversations/$employeeId', const {}))['data']);

  Future<List<Map<String, dynamic>>> communicationMessages(
          String conversationId) async =>
      List<Map<String, dynamic>>.from((await api.get(
          '/communications/conversations/$conversationId/messages'))['data']);

  Future<Map<String, dynamic>> sendCommunicationMessage(String conversationId,
          String text, List<Map<String, dynamic>> attachments) async =>
      Map<String, dynamic>.from((await api.post(
          '/communications/conversations/$conversationId/messages',
          {'text': text, 'attachments': attachments}))['data']);

  Future<Map<String, dynamic>> uploadCommunicationAttachment(
          String filePath) async =>
      Map<String, dynamic>.from((await api.uploadFile(
          '/communications/attachments', 'file', filePath))['data']);

  Future<void> markCommunicationRead(String conversationId) async =>
      api.patch('/communications/conversations/$conversationId/read', const {});

  Future<Map<String, dynamic>> editCommunicationMessage(
          String messageId, String text) async =>
      Map<String, dynamic>.from(
          (await api.patch('/communications/messages/$messageId', {
        'text': text,
      }))['data']);

  Future<Map<String, dynamic>> deleteCommunicationMessage(
          String messageId) async =>
      Map<String, dynamic>.from(
          (await api.delete('/communications/messages/$messageId'))['data']);

  Future<List<Map<String, dynamic>>> communicationAudit(
          String conversationId) async =>
      List<Map<String, dynamic>>.from((await api
          .get('/communications/conversations/$conversationId/audit'))['data']);

  Future<Map<String, dynamic>> communicationAvailability() async =>
      Map<String, dynamic>.from(
          (await api.get('/communications/availability'))['data']);

  Future<Map<String, dynamic>> updateCommunicationAvailability(
          String availability, bool aiEnabled, String statusMessage) async =>
      Map<String, dynamic>.from(
          (await api.patch('/communications/availability', {
        'availability': availability,
        'aiAssistantEnabled': aiEnabled,
        'statusMessage': statusMessage,
      }))['data']);

  Future<List<Map<String, dynamic>>> communicationTasks() async =>
      List<Map<String, dynamic>>.from(
          (await api.get('/communications/tasks'))['data']);

  Future<Map<String, dynamic>> createCommunicationTask(
          {required String employeeId,
          required String title,
          required String description,
          required String priority,
          String? dueAt}) async =>
      Map<String, dynamic>.from((await api.post('/communications/tasks', {
        'employeeId': employeeId,
        'title': title,
        'description': description,
        'priority': priority,
        if (dueAt != null) 'dueAt': dueAt,
      }))['data']);

  Future<Map<String, dynamic>> updateCommunicationTask(
          String taskId, String status,
          {List<Map<String, dynamic>> proofAttachments = const []}) async =>
      Map<String, dynamic>.from(
          (await api.patch('/communications/tasks/$taskId/status', {
        'status': status,
        'proofAttachments': proofAttachments,
      }))['data']);

  Future<int> sendCommunicationAnnouncement(String text) async =>
      int.tryParse((await api.post(
              '/communications/announcements', {'text': text}))['data']['sent']
          .toString()) ??
      0;

  Future<Map<String, dynamic>> communicationAnalytics() async =>
      Map<String, dynamic>.from(
          (await api.get('/communications/analytics'))['data']);

  Future<Map<String, dynamic>> communicationIceConfig() async =>
      Map<String, dynamic>.from(
          (await api.get('/communications/calls/ice-config'))['data']);

  Future<Map<String, dynamic>> startCommunicationCall(
          String conversationId, bool video) async =>
      Map<String, dynamic>.from((await api.post('/communications/calls', {
        'conversationId': conversationId,
        'type': video ? 'video' : 'audio',
      }))['data']);

  Future<Map<String, dynamic>> updateCommunicationCall(
          String callId, String action, {String reason = ''}) async =>
      Map<String, dynamic>.from(
          (await api.patch('/communications/calls/$callId', {
        'action': action,
        'reason': reason,
      }))['data']);

  Future<List<Map<String, dynamic>>> communicationCallHistory() async =>
      List<Map<String, dynamic>>.from(
          (await api.get('/communications/calls'))['data']);

  Future<String?> lastSuccessfulScan() async =>
      (await SharedPreferences.getInstance()).getString('last_successful_scan');

  Future<Map<String, dynamic>> localDeviceHealth() async =>
      Map<String, dynamic>.from(
          await _files.invokeMethod('deviceHealth') ?? <String, dynamic>{});

  Future<void> syncDeviceHealth() async {
    try {
      final watch = Stopwatch()..start();
      final values = await Future.wait([
        deviceHealth(),
        localDeviceHealth(),
        lastSuccessfulScan(),
      ]);
      watch.stop();
      await api.post('/attendance/device-health/snapshot', {
        'server': values[0],
        'local': values[1],
        'lastSuccessfulScan': values[2],
        'roundTripMs': watch.elapsedMilliseconds,
      });
    } catch (_) {
      // Health reporting must never block normal attendance operations.
    }
  }

  Future<String> updateBuyerStatus(String buyerId, String status) async {
    final result = await api
        .patch('/attendance/buyers/$buyerId/status', {'status': status});
    return result['data']['status']?.toString() ?? status;
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

  Future<Map<String, dynamic>> directory(String type,
          {String view = 'present',
          String? day,
          String? subType,
          String? search,
          int page = 1}) async =>
      Map<String, dynamic>.from(
          (await api.get('/attendance/directory/$type', query: {
        'view': view,
        if (day?.isNotEmpty == true) 'day': day!,
        if (subType?.isNotEmpty == true) 'subType': subType!,
        if (search?.isNotEmpty == true) 'search': search!,
        'page': '$page',
        'limit': '500',
      }))['data']);

  Future<
      Map<String,
          dynamic>> directoryProfile(String registrationId) async => Map<String,
      dynamic>.from((await api.get(
          '/attendance/directory-profile/${Uri.encodeComponent(registrationId)}'))[
      'data']);

  Future<String> exportAttendance(
      {String? day,
      String? type,
      String? subType,
      String? search,
      String? companyId}) async {
    final response = await api.download('/attendance/export', query: {
      if (day?.isNotEmpty == true) 'day': day!,
      if (type?.isNotEmpty == true) 'type': type!,
      if (subType?.isNotEmpty == true) 'subType': subType!,
      if (search?.isNotEmpty == true) 'search': search!,
      if (companyId?.isNotEmpty == true) 'companyId': companyId!,
    });
    final disposition = response.headers['content-disposition'] ?? '';
    final match = RegExp(r'filename="?([^";]+)').firstMatch(disposition);
    final filename = match?.group(1) ??
        'IHWE-attendance-${DateTime.now().millisecondsSinceEpoch}.xlsx';
    if (response.bodyBytes.isEmpty) {
      throw ApiException('The server returned an empty Excel file.');
    }
    if (!_isXlsx(response.bodyBytes)) {
      throw ApiException(
          'The server did not return a valid Excel file. Please restart the backend and try again.');
    }
    final savedPath = await _files.invokeMethod<String>('saveToDownloads', {
      'filename': filename,
      'bytes': response.bodyBytes,
      'mimeType':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    });
    if (savedPath?.isNotEmpty != true) {
      throw ApiException('Android could not save the Excel file.');
    }
    return savedPath!;
  }

  Future<String> exportPdf({String? day, String? type, String? subType}) async {
    final response = await api.download('/attendance/export/pdf', query: {
      if (day?.isNotEmpty == true) 'day': day!,
      if (type?.isNotEmpty == true) 'type': type!,
      if (subType?.isNotEmpty == true) 'subType': subType!,
    });
    final disposition = response.headers['content-disposition'] ?? '';
    final filename =
        RegExp(r'filename="?([^";]+)').firstMatch(disposition)?.group(1) ??
            'IHWE-summary.pdf';
    if (!_isPdf(response.bodyBytes)) {
      throw ApiException(
          'The server did not return a valid PDF file. Please restart the backend and try again.');
    }
    final saved = await _files.invokeMethod<String>('saveToDownloads', {
      'filename':
          filename.toLowerCase().endsWith('.pdf') ? filename : '$filename.pdf',
      'bytes': response.bodyBytes,
      'mimeType': 'application/pdf',
    });
    if (saved?.isNotEmpty != true) throw ApiException('Could not save PDF.');
    return saved!;
  }

  bool _isPdf(List<int> bytes) =>
      bytes.length >= 5 &&
      bytes[0] == 0x25 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x44 &&
      bytes[3] == 0x46 &&
      bytes[4] == 0x2D;

  bool _isXlsx(List<int> bytes) =>
      bytes.length >= 4 &&
      bytes[0] == 0x50 &&
      bytes[1] == 0x4B &&
      bytes[2] == 0x03 &&
      bytes[3] == 0x04;

  Future<String> aiSummary(String scope, {String? id}) async {
    final result = await api.post('/attendance/ai-summary', {
      'scope': scope,
      if (id?.isNotEmpty == true) 'id': id,
    });
    return result['data']?['summary']?.toString() ?? '';
  }
}
