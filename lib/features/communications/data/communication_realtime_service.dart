import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/config/app_config.dart';
import '../../../core/storage/session_store.dart';

class CommunicationRealtimeService {
  CommunicationRealtimeService._();
  static final instance = CommunicationRealtimeService._();

  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final _reads = StreamController<Map<String, dynamic>>.broadcast();
  final _presence = StreamController<Map<String, dynamic>>.broadcast();
  final _calls = StreamController<Map<String, dynamic>>.broadcast();
  final _notifications = FlutterLocalNotificationsPlugin();

  io.Socket? _socket;
  bool _notificationsReady = false;

  Stream<Map<String, dynamic>> get messages => _messages.stream;
  Stream<Map<String, dynamic>> get reads => _reads.stream;
  Stream<Map<String, dynamic>> get presence => _presence.stream;
  Stream<Map<String, dynamic>> get calls => _calls.stream;
  bool get connected => _socket?.connected == true;

  Future<void> connect(SessionStore session) async {
    if (session.token?.isNotEmpty != true) return;
    await _initializeNotifications();
    if (_socket != null) {
      if (!_socket!.connected) _socket!.connect();
      return;
    }
    final origin = Uri.parse(AppConfig.apiBaseUrl).origin;
    final socket = io.io(
      '$origin/communications',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': session.token})
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(20)
          .setReconnectionDelay(1000)
          .build(),
    );
    _socket = socket;
    socket.on('message:new', (raw) {
      final value = _map(raw);
      _messages.add(value);
      if (value['isMine'] != true) _showMessageNotification(value);
    });
    socket.on('message:updated',
        (raw) => _messages.add({..._map(raw), 'realtimeUpdated': true}));
    socket.on('messages:read', (raw) => _reads.add(_map(raw)));
    socket.on('presence:changed', (raw) => _presence.add(_map(raw)));
    socket.on('call:incoming', (raw) {
      final value = _map(raw);
      _calls.add({...value, 'event': 'incoming'});
      _showCallNotification(value);
    });
    socket.on(
        'call:signal', (raw) => _calls.add({..._map(raw), 'event': 'signal'}));
    socket.on('call:accepted', (raw) {
      final value = _map(raw);
      _cancelCallNotification(value);
      _calls.add({...value, 'event': 'accepted'});
    });
    socket.on('call:ended', (raw) {
      final value = _map(raw);
      _cancelCallNotification(value);
      _calls.add({...value, 'event': 'ended'});
    });
    socket.connect();
  }

  void emit(String event, Map<String, dynamic> payload) =>
      _socket?.emit(event, payload);

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  Map<String, dynamic> _map(dynamic raw) =>
      raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

  Future<void> _initializeNotifications() async {
    if (_notificationsReady) return;
    const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'));
    await _notifications.initialize(settings);
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _notificationsReady = true;
  }

  Future<void> _showMessageNotification(Map<String, dynamic> message) async {
    const android = AndroidNotificationDetails(
      'ihwe_messages',
      'IHWE Messages',
      channelDescription: 'Secure Super Administrator and employee messages',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.message,
    );
    final attachments = List.from(message['attachments'] ?? []);
    final body = message['text']?.toString().isNotEmpty == true
        ? message['text'].toString()
        : attachments.isNotEmpty
            ? 'Sent an attachment'
            : 'New secure message';
    await _notifications.show(
      message['_id']?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      message['senderName']?.toString() ?? 'IHWE Communication',
      body,
      const NotificationDetails(android: android),
      payload: message['conversationId']?.toString(),
    );
  }

  Future<void> _showCallNotification(Map<String, dynamic> call) async {
    const android = AndroidNotificationDetails(
      'ihwe_calls',
      'IHWE Calls',
      channelDescription: 'Incoming IHWE operations calls',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
      ongoing: true,
    );
    await _notifications.show(
      _callNotificationId(call),
      call['callerName']?.toString() ?? 'Incoming IHWE call',
      call['type'] == 'video' ? 'Incoming video call' : 'Incoming audio call',
      const NotificationDetails(android: android),
      payload: call['_id']?.toString(),
    );
  }

  int _callNotificationId(Map<String, dynamic> call) =>
      (call['_id'] ?? call['callId'])?.toString().hashCode ??
      DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);

  Future<void> _cancelCallNotification(Map<String, dynamic> call) =>
      _notifications.cancel(_callNotificationId(call));
}
