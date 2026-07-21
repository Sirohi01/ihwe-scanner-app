import 'package:flutter/material.dart';
import 'core/storage/session_store.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/dashboard/presentation/home_shell.dart';

class IhweAttendanceApp extends StatelessWidget {
  const IhweAttendanceApp({super.key, required this.session});
  final SessionStore session;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'IHWE Attendance',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: ListenableBuilder(
          listenable: session,
          builder: (_, __) => session.isLoggedIn
              ? HomeShell(session: session)
              : LoginScreen(session: session),
        ),
      );
}
