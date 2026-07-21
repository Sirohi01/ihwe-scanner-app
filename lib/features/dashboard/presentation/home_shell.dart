import 'package:flutter/material.dart';
import '../../../core/storage/session_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../history/presentation/history_screen.dart';
import '../../scanner/presentation/scanner_screen.dart';
import 'dashboard_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.session});
  final SessionStore session;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  int refreshKey = 0;
  late final repository = AttendanceRepository(widget.session);

  void openScanner() => Navigator.of(context)
          .push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ScannerScreen(repository: repository),
      ))
          .then((marked) {
        if (marked == true) setState(() => refreshKey++);
      });

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(
          key: ValueKey(refreshKey),
          repository: repository,
          session: widget.session,
          onScan: openScanner),
      HistoryScreen(
          key: ValueKey('history-$refreshKey'), repository: repository),
    ];
    return Scaffold(
      body: IndexedStack(index: index, children: screens),
      floatingActionButton: FloatingActionButton.large(
        onPressed: openScanner,
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.navy,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: const Icon(Icons.qr_code_scanner_rounded, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: NavigationBar(
        height: 74,
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              selectedIcon: Icon(Icons.space_dashboard_rounded),
              label: 'Overview'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Attendance'),
        ],
      ),
    );
  }
}
