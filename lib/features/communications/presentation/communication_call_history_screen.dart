import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/storage/session_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../attendance/data/attendance_repository.dart';

class CommunicationCallHistoryScreen extends StatefulWidget {
  const CommunicationCallHistoryScreen(
      {super.key, required this.repository, required this.session});
  final AttendanceRepository repository;
  final SessionStore session;

  @override
  State<CommunicationCallHistoryScreen> createState() =>
      _CommunicationCallHistoryScreenState();
}

class _CommunicationCallHistoryScreenState
    extends State<CommunicationCallHistoryScreen> {
  List<Map<String, dynamic>>? calls;
  Object? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final value = await widget.repository.communicationCallHistory();
      if (mounted) setState(() => calls = value);
    } catch (value) {
      if (mounted) setState(() => error = value);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Call History')),
        body: calls == null
            ? Center(
                child: error == null
                    ? const AppListSkeleton()
                    : FilledButton(
                        onPressed: load, child: Text('Retry: $error')))
            : RefreshIndicator(
                onRefresh: load,
                child: calls!.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 190),
                        Icon(Icons.phone_missed_outlined,
                            size: 50, color: Colors.black26),
                        SizedBox(height: 9),
                        Text('No call history yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black45))
                      ])
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 80),
                        itemCount: calls!.length,
                        itemBuilder: (_, index) => _call(calls![index]),
                      ),
              ),
      );

  Widget _call(Map<String, dynamic> call) {
    final caller =
        Map<String, dynamic>.from(call['callerId'] ?? <String, dynamic>{});
    final callee =
        Map<String, dynamic>.from(call['calleeId'] ?? <String, dynamic>{});
    final mine = call['isCaller'] == true;
    final person = mine ? callee : caller;
    final status = call['status']?.toString() ?? '';
    final statusLabel = status.isEmpty
        ? '-'
        : status
            .split('-')
            .map((word) => word.isEmpty
                ? word
                : '${word[0].toUpperCase()}${word.substring(1)}')
            .join(' ');
    final created =
        DateTime.tryParse(call['createdAt']?.toString() ?? '')?.toLocal();
    final color = status == 'accepted' || status == 'ended'
        ? AppColors.emerald
        : status == 'rejected' || status == 'missed' || status == 'failed'
            ? Colors.red
            : Colors.orange;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: .1),
          child: Icon(
              call['type'] == 'video'
                  ? Icons.videocam_outlined
                  : Icons.call_outlined,
              color: color),
        ),
        title: Text(
            person['fullName']?.toString().isNotEmpty == true
                ? person['fullName']
                : person['username'] ?? 'IHWE User',
            style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(
            '${mine ? 'Outgoing' : 'Incoming'} • $statusLabel • ${call['durationSeconds'] ?? 0}s',
            style: const TextStyle(fontSize: 9)),
        trailing: Text(
            created == null ? '' : DateFormat('d MMM\nh:mm a').format(created),
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 8, color: Colors.black45)),
      ),
    );
  }
}
