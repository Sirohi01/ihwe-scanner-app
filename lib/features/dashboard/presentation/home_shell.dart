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
      floatingActionButton: FloatingActionButton(
        onPressed: openScanner,
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.navy,
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.qr_code_scanner_rounded, size: 27),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        height: 66,
        color: AppColors.navy,
        elevation: 12,
        padding: EdgeInsets.zero,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(children: [
          Expanded(
              child: _navItem(0, 'Overview', Icons.grid_view_outlined,
                  Icons.grid_view_rounded)),
          const SizedBox(width: 72),
          Expanded(
              child: _navItem(1, 'Attendance', Icons.fact_check_outlined,
                  Icons.fact_check_rounded)),
        ]),
      ),
    );
  }

  Widget _navItem(
      int value, String label, IconData icon, IconData selectedIcon) {
    final selected = index == value;
    return InkWell(
      onTap: () => setState(() => index = value),
      child: SizedBox.expand(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(selected ? selectedIcon : icon,
              size: 21, color: selected ? AppColors.gold : Colors.white54),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                  color: selected ? AppColors.gold : Colors.white54,
                  fontSize: 9,
                  letterSpacing: .3,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w600)),
          const SizedBox(height: 3),
          AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: selected ? 18 : 0,
              height: 2,
              decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(2)))
        ]),
      ),
    );
  }
}
