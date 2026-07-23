import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/storage/session_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../history/presentation/history_screen.dart';
import '../../scanner/presentation/scanner_screen.dart';
import '../../communications/data/communication_realtime_service.dart';
import '../../communications/presentation/communication_call_screen.dart';
import 'dashboard_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.session});
  final SessionStore session;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int index = 0;
  int refreshKey = 0;
  late final repository = AttendanceRepository(widget.session);
  StreamSubscription<Map<String, dynamic>>? callSubscription;
  bool callPromptOpen = false;
  String? promptedCallId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CommunicationRealtimeService.instance.connect(widget.session);
    callSubscription =
        CommunicationRealtimeService.instance.calls.listen(_incomingCall);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    CommunicationRealtimeService.instance.disconnect();
    callSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      CommunicationRealtimeService.instance.connect(widget.session);
    }
  }

  Future<void> _incomingCall(Map<String, dynamic> event) async {
    final eventCallId = (event['_id'] ?? event['callId'])?.toString();
    if (event['event'] == 'ended' &&
        callPromptOpen &&
        eventCallId == promptedCallId &&
        mounted) {
      Navigator.of(context, rootNavigator: true).pop(false);
      return;
    }
    if (event['event'] != 'incoming' ||
        callPromptOpen ||
        !mounted ||
        eventCallId == null) {
      return;
    }
    callPromptOpen = true;
    promptedCallId = eventCallId;
    final video = event['type'] == 'video';
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(video ? Icons.videocam_rounded : Icons.call_rounded,
            color: AppColors.green, size: 36),
        title: Text(event['callerName']?.toString() ?? 'Incoming IHWE call'),
        content: Text(
            video ? 'Incoming secure video call' : 'Incoming secure audio call',
            textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, false),
            icon: const Icon(Icons.call_end_rounded),
            label: const Text('Reject'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.emerald),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.call_rounded),
            label: const Text('Accept'),
          ),
        ],
      ),
    );
    callPromptOpen = false;
    promptedCallId = null;
    if (!mounted) return;
    if (accepted == true) {
      await Navigator.push(
          context,
          MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => CommunicationCallScreen(
                  call: event,
                  person: {
                    '_id': event['callerId'],
                    'fullName': event['callerName'],
                    'profileImage': event['callerImage']
                  },
                  repository: repository,
                  isCaller: false)));
    } else {
      try {
        await repository.updateCommunicationCall(eventCallId, 'reject');
      } catch (_) {
        // The call may already be rejected, ended, or marked missed.
      }
    }
  }

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
      floatingActionButton: FloatingActionButton.small(
        onPressed: openScanner,
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.navy,
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: const Icon(Icons.qr_code_scanner_rounded, size: 23),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        height: 56,
        color: AppColors.navy,
        elevation: 12,
        padding: EdgeInsets.zero,
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        child: Row(children: [
          Expanded(
              child: _navItem(0, 'Overview', Icons.grid_view_outlined,
                  Icons.grid_view_rounded)),
          const SizedBox(width: 60),
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
              size: 19, color: selected ? AppColors.gold : Colors.white54),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: selected ? AppColors.gold : Colors.white54,
                  fontSize: 8.5,
                  letterSpacing: .3,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w600)),
          const SizedBox(height: 2),
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
