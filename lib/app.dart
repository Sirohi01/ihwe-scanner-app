import 'package:flutter/material.dart';
import 'core/storage/session_store.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/dashboard/presentation/home_shell.dart';

class IhweAttendanceApp extends StatefulWidget {
  const IhweAttendanceApp({super.key, required this.session});
  final SessionStore session;

  @override
  State<IhweAttendanceApp> createState() => _IhweAttendanceAppState();
}

class _IhweAttendanceAppState extends State<IhweAttendanceApp> {
  late final Future<void> startup = Future.wait<void>([
    widget.session.load(),
    Future<void>.delayed(const Duration(milliseconds: 1450)),
  ]);

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'IHWE Attendance',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: FutureBuilder<void>(
          future: startup,
          builder: (_, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _StartupScreen();
            }
            return ListenableBuilder(
              listenable: widget.session,
              builder: (_, __) => widget.session.isLoggedIn
                  ? HomeShell(session: widget.session)
                  : LoginScreen(session: widget.session),
            );
          },
        ),
      );
}

class _StartupScreen extends StatefulWidget {
  const _StartupScreen();
  @override
  State<_StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<_StartupScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF06182C), AppColors.navy, Color(0xFF193E27)],
              stops: [0, .54, 1],
            ),
          ),
          child: Stack(children: [
            Positioned(
              top: -90,
              right: -85,
              child: _glow(240, AppColors.gold.withValues(alpha: .08)),
            ),
            Positioned(
              bottom: -120,
              left: -95,
              child: _glow(280, AppColors.emerald.withValues(alpha: .09)),
            ),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 34),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: pulse,
                        builder: (_, child) => Transform.scale(
                          scale: .98 + (pulse.value * .025),
                          child: child,
                        ),
                        child: Container(
                          width: 224,
                          height: 132,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                                color: AppColors.gold.withValues(alpha: .75),
                                width: 1.4),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.gold.withValues(alpha: .16),
                                blurRadius: 34,
                                spreadRadius: 3,
                              ),
                              const BoxShadow(
                                color: Colors.black26,
                                blurRadius: 20,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Image(
                            image: AssetImage('assets/images/ngt_logo.png'),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 27),
                      const Text(
                        'IHWE GO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4.2,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'EXHIBITION ACCESS & ATTENDANCE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .55),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.35,
                        ),
                      ),
                      const SizedBox(height: 34),
                      SizedBox(
                        width: 118,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: const LinearProgressIndicator(
                            minHeight: 3,
                            backgroundColor: Colors.white12,
                            color: AppColors.gold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 11),
                      const Text(
                        'Preparing your workspace',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.paddingOf(context).bottom + 20,
              child: const Text(
                'INTERNATIONAL HEALTH & WELLNESS EXPO',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white30,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.15,
                ),
              ),
            ),
          ]),
        ),
      );

  Widget _glow(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
