import 'package:flutter/material.dart';
import 'app.dart';
import 'core/storage/session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = SessionStore();
  await session.load();
  runApp(IhweAttendanceApp(session: session));
}
