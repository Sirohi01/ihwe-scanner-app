import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/storage/session_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../attendance/data/attendance_repository.dart';

class CommunicationTasksScreen extends StatefulWidget {
  const CommunicationTasksScreen(
      {super.key, required this.repository, required this.session});
  final AttendanceRepository repository;
  final SessionStore session;

  @override
  State<CommunicationTasksScreen> createState() =>
      _CommunicationTasksScreenState();
}

class _CommunicationTasksScreenState extends State<CommunicationTasksScreen> {
  List<Map<String, dynamic>>? tasks;
  Object? error;

  bool get isSuperAdmin {
    final role = widget.session.role
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return const {
      'super-admin',
      'super-administrator',
      'ihwe-super-administrator'
    }.contains(role);
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final value = await widget.repository.communicationTasks();
      if (mounted) {
        setState(() {
          tasks = value;
          error = null;
        });
      }
    } catch (value) {
      if (mounted) setState(() => error = value);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Operations Tasks'),
          actions: [
            IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded))
          ],
        ),
        body: tasks == null
            ? Center(
                child: error == null
                    ? const AppListSkeleton()
                    : FilledButton(
                        onPressed: load, child: Text('Retry: $error')))
            : RefreshIndicator(
                onRefresh: load,
                child: tasks!.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 180),
                        Icon(Icons.task_alt_rounded,
                            size: 52, color: Colors.black26),
                        SizedBox(height: 9),
                        Text('No operations tasks yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black45))
                      ])
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 90),
                        itemCount: tasks!.length,
                        itemBuilder: (_, index) => _taskCard(tasks![index]),
                      ),
              ),
        floatingActionButton: isSuperAdmin
            ? FloatingActionButton.extended(
                onPressed: _createTask,
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add_task_rounded),
                label: const Text('ASSIGN TASK'))
            : null,
      );

  Widget _taskCard(Map<String, dynamic> task) {
    final assignedTo =
        Map<String, dynamic>.from(task['assignedTo'] ?? <String, dynamic>{});
    final status = task['status']?.toString() ?? 'assigned';
    final priority = task['priority']?.toString() ?? 'normal';
    final due = DateTime.tryParse(task['dueAt']?.toString() ?? '')?.toLocal();
    final statusColor = status == 'completed'
        ? AppColors.emerald
        : status == 'cancelled'
            ? Colors.red
            : status == 'in-progress'
                ? Colors.blue
                : Colors.orange;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                  color: (priority == 'urgent'
                          ? Colors.red
                          : priority == 'high'
                              ? Colors.orange
                              : AppColors.green)
                      .withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(7)),
              child: Text(priority.toUpperCase(),
                  style: TextStyle(
                      color: priority == 'urgent'
                          ? Colors.red
                          : priority == 'high'
                              ? Colors.orange
                              : AppColors.green,
                      fontSize: 7,
                      fontWeight: FontWeight.w900)),
            ),
            const Spacer(),
            Text(status.replaceAll('-', ' ').toUpperCase(),
                style: TextStyle(
                    color: statusColor,
                    fontSize: 8,
                    fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 7),
          Text(task['title']?.toString() ?? 'Task',
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
          if (task['description']?.toString().isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(task['description'].toString(),
                  style: const TextStyle(
                      fontSize: 10, color: Colors.black54, height: 1.3)),
            ),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 4, children: [
            if (isSuperAdmin)
              _meta(Icons.person_outline_rounded,
                  assignedTo['fullName'] ?? assignedTo['username'] ?? '-'),
            if (due != null)
              _meta(Icons.schedule_rounded,
                  'Due ${DateFormat('d MMM, h:mm a').format(due)}'),
            if (List.from(task['proofAttachments'] ?? []).isNotEmpty)
              _meta(Icons.attach_file_rounded,
                  '${List.from(task['proofAttachments']).length} Proof'),
          ]),
          if (!isSuperAdmin &&
              !['completed', 'cancelled'].contains(status)) ...[
            const SizedBox(height: 9),
            Row(children: [
              if (status == 'assigned')
                Expanded(
                    child: OutlinedButton(
                        onPressed: () => _changeStatus(task, 'accepted'),
                        child: const Text('ACCEPT'))),
              if (status == 'accepted') ...[
                Expanded(
                    child: OutlinedButton(
                        onPressed: () => _changeStatus(task, 'in-progress'),
                        child: const Text('START'))),
              ],
              if (['accepted', 'in-progress'].contains(status)) ...[
                const SizedBox(width: 7),
                Expanded(
                    child: FilledButton(
                        onPressed: () =>
                            _changeStatus(task, 'completed', proof: true),
                        child: const Text('COMPLETE'))),
              ],
            ]),
          ],
          if (isSuperAdmin && !['completed', 'cancelled'].contains(status)) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                  onPressed: () => _changeStatus(task, 'cancelled'),
                  icon: const Icon(Icons.cancel_outlined, size: 15),
                  label: const Text('CANCEL TASK')),
            )
          ]
        ]),
      ),
    );
  }

  Widget _meta(IconData icon, dynamic text) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: Colors.black38),
        const SizedBox(width: 4),
        Text('$text',
            style: const TextStyle(fontSize: 8.5, color: Colors.black45))
      ]);

  Future<void> _changeStatus(Map<String, dynamic> task, String status,
      {bool proof = false}) async {
    final attachments = <Map<String, dynamic>>[];
    if (proof) {
      final picked = await FilePicker.pickFiles(
          allowMultiple: true,
          type: FileType.custom,
          allowedExtensions: const [
            'jpg',
            'jpeg',
            'png',
            'webp',
            'pdf',
            'doc',
            'docx'
          ]);
      for (final path
          in (picked?.paths.whereType<String>() ?? const <String>[])) {
        attachments
            .add(await widget.repository.uploadCommunicationAttachment(path));
      }
    }
    await widget.repository.updateCommunicationTask(
        task['_id'].toString(), status,
        proofAttachments: attachments);
    await load();
  }

  Future<void> _createTask() async {
    final employees = await widget.repository.communicationEmployees();
    if (!mounted) return;
    String? employeeId;
    String priority = 'normal';
    DateTime? dueAt;
    final title = TextEditingController();
    final description = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('Assign operations task'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: employeeId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Employee *'),
                items: employees
                    .map((user) => DropdownMenuItem(
                        value: user['_id'].toString(),
                        child: Text(
                            user['fullName']?.toString().isNotEmpty == true
                                ? user['fullName']
                                : user['username'],
                            overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (value) => setDialogState(() => employeeId = value),
              ),
              const SizedBox(height: 9),
              TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Task title *')),
              const SizedBox(height: 9),
              TextField(
                  controller: description,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Instructions')),
              const SizedBox(height: 9),
              DropdownButtonFormField<String>(
                value: priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: const [
                  DropdownMenuItem(value: 'normal', child: Text('Normal')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                  DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                ],
                onChanged: (value) =>
                    setDialogState(() => priority = value ?? 'normal'),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(dueAt == null
                    ? 'Set due date'
                    : DateFormat('d MMM yyyy').format(dueAt!)),
                onTap: () async {
                  final value = await showDatePicker(
                      context: dialogContext,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate: dueAt ?? DateTime.now());
                  if (value != null) setDialogState(() => dueAt = value);
                },
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext,
                    employeeId != null && title.text.trim().isNotEmpty),
                child: const Text('Assign'))
          ],
        ),
      ),
    );
    if (created == true) {
      await widget.repository.createCommunicationTask(
          employeeId: employeeId!,
          title: title.text.trim(),
          description: description.text.trim(),
          priority: priority,
          dueAt: dueAt?.toIso8601String());
      await load();
    }
    title.dispose();
    description.dispose();
  }
}
