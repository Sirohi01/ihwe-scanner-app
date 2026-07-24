import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/storage/session_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../attendance/data/attendance_repository.dart';
import 'communication_thread_screen.dart';
import 'communication_tasks_screen.dart';

class CommunicationInboxScreen extends StatefulWidget {
  const CommunicationInboxScreen(
      {super.key, required this.repository, required this.session});

  final AttendanceRepository repository;
  final SessionStore session;

  @override
  State<CommunicationInboxScreen> createState() =>
      _CommunicationInboxScreenState();
}

class _CommunicationInboxScreenState extends State<CommunicationInboxScreen> {
  List<Map<String, dynamic>>? conversations;
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
      final value = await widget.repository.communicationConversations();
      if (mounted) {
        setState(() {
          conversations = value;
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
          title: const Text('Communication'),
          actions: [
            IconButton(
                tooltip: 'Operations tasks',
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => CommunicationTasksScreen(
                            repository: widget.repository,
                            session: widget.session))),
                icon: const Icon(Icons.task_alt_rounded)),
            if (isSuperAdmin)
              IconButton(
                  tooltip: 'Message employee',
                  onPressed: _chooseEmployee,
                  icon: const Icon(Icons.edit_square)),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'refresh') load();
                if (value == 'availability') _availability();
                if (value == 'announcement') _announcement();
                if (value == 'analytics') _analytics();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'refresh', child: Text('Refresh conversations')),
                if (isSuperAdmin)
                  const PopupMenuItem(
                      value: 'availability',
                      child: Text('Availability & AI assistant')),
                if (isSuperAdmin)
                  const PopupMenuItem(
                      value: 'announcement',
                      child: Text('Send team announcement')),
                if (isSuperAdmin)
                  const PopupMenuItem(
                      value: 'analytics',
                      child: Text('Communication analytics')),
              ],
            ),
          ],
        ),
        body: conversations == null
            ? Center(
                child: error == null
                    ? const AppListSkeleton(count: 7)
                    : FilledButton(
                        onPressed: load, child: Text('Retry: $error')))
            : RefreshIndicator(
                onRefresh: load,
                child: conversations!.isEmpty
                    ? ListView(children: [
                        SizedBox(
                            height: MediaQuery.sizeOf(context).height * .25),
                        const Icon(Icons.forum_outlined,
                            size: 52, color: Colors.black26),
                        const SizedBox(height: 10),
                        Text(
                            isSuperAdmin
                                ? 'Start a secure employee conversation.'
                                : 'Your Super Administrator conversation will appear here.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.black45)),
                      ])
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 90),
                        itemCount: conversations!.length,
                        itemBuilder: (_, index) =>
                            _conversation(conversations![index]),
                      ),
              ),
        floatingActionButton: isSuperAdmin
            ? FloatingActionButton.small(
                onPressed: _chooseEmployee,
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                child: const Icon(Icons.add_comment_rounded))
            : null,
      );

  Widget _conversation(Map<String, dynamic> item) {
    final person = Map<String, dynamic>.from(
        item[isSuperAdmin ? 'employeeId' : 'superAdminId'] ?? {});
    final name = person['fullName']?.toString().isNotEmpty == true
        ? person['fullName'].toString()
        : person['username']?.toString() ?? 'User';
    final photo = resolveApiAssetUrl(person['profileImage']);
    final unread = int.tryParse(
            '${item[isSuperAdmin ? 'superAdminUnread' : 'employeeUnread'] ?? 0}') ??
        0;
    return Card(
      margin: const EdgeInsets.only(bottom: 7),
      child: ListTile(
        onTap: () => _openThread(item['_id'].toString(), person),
        contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 3),
        leading: CircleAvatar(
          radius: 23,
          backgroundColor: AppColors.green.withValues(alpha: .1),
          backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
          child: photo.isEmpty
              ? Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                  style: const TextStyle(
                      color: AppColors.green, fontWeight: FontWeight.w900))
              : null,
        ),
        title: Row(children: [
          Expanded(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900))),
          if (unread > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(20)),
              child: Text('$unread',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w900)),
            )
        ]),
        subtitle: Text(
          item['lastMessage']?.toString().isNotEmpty == true
              ? item['lastMessage'].toString()
              : '${person['designation'] ?? person['role'] ?? ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 10,
              fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w500),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }

  Future<void> _chooseEmployee() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _EmployeePicker(
        repository: widget.repository,
        onSelected: (employee) async {
          Navigator.pop(sheetContext);
          final conversation = await widget.repository
              .openEmployeeConversation(employee['_id'].toString());
          if (!mounted) return;
          await _openThread(conversation['_id'].toString(), employee);
          await load();
        },
      ),
    );
  }

  Future<void> _openThread(
      String conversationId, Map<String, dynamic> person) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => CommunicationThreadScreen(
                  conversationId: conversationId,
                  person: person,
                  repository: widget.repository,
                  session: widget.session,
                )));
    await load();
  }

  Future<void> _availability() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _AvailabilityDialog(repository: widget.repository),
    );
  }

  Future<void> _announcement() async {
    final message = await showDialog<String>(
      context: context,
      builder: (_) => const _AnnouncementDialog(),
    );
    if (message?.isNotEmpty == true) {
      final sent =
          await widget.repository.sendCommunicationAnnouncement(message!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Announcement sent to $sent employees.')));
        await load();
      }
    }
  }

  Future<void> _analytics() async {
    final value = await widget.repository.communicationAnalytics();
    if (!mounted) return;
    final tasks = Map<String, dynamic>.from(value['tasksByStatus'] ?? {});
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('COMMUNICATION ANALYTICS',
                style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            Row(children: [
              _analyticsMetric('Conversations', value['conversations']),
              _analyticsMetric('Unread', value['unread']),
              _analyticsMetric('AI replies', value['aiReplies']),
            ]),
            const SizedBox(height: 12),
            Align(
                alignment: Alignment.centerLeft,
                child: Text(
                    'Tasks: ${tasks.entries.map((entry) => '${entry.key} ${entry.value}').join(' • ')}',
                    style: const TextStyle(fontSize: 10))),
          ]),
        ),
      ),
    );
  }

  Widget _analyticsMetric(String label, dynamic value) => Expanded(
        child: Column(children: [
          Text('${value ?? 0}',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          Text(label,
              style: const TextStyle(fontSize: 8, color: Colors.black45))
        ]),
      );
}

class _EmployeePicker extends StatefulWidget {
  const _EmployeePicker({required this.repository, required this.onSelected});
  final AttendanceRepository repository;
  final ValueChanged<Map<String, dynamic>> onSelected;

  @override
  State<_EmployeePicker> createState() => _EmployeePickerState();
}

class _EmployeePickerState extends State<_EmployeePicker> {
  List<Map<String, dynamic>>? users;
  String search = '';

  @override
  void initState() {
    super.initState();
    widget.repository.communicationEmployees().then((value) {
      if (mounted) setState(() => users = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = (users ?? []).where((user) {
      final haystack =
          '${user['fullName']} ${user['username']} ${user['designation']} ${user['department']}'
              .toLowerCase();
      return haystack.contains(search.toLowerCase());
    }).toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: Column(children: [
          const SizedBox(height: 9),
          Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(4))),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 13, 16, 8),
            child: Align(
                alignment: Alignment.centerLeft,
                child: Text('MESSAGE AN EMPLOYEE',
                    style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w900))),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TextField(
              onChanged: (value) => setState(() => search = value),
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Search employee, role or department'),
            ),
          ),
          const SizedBox(height: 7),
          Expanded(
            child: users == null
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, index) {
                      final user = filtered[index];
                      return ListTile(
                        onTap: () => widget.onSelected(user),
                        leading: const CircleAvatar(
                            child: Icon(Icons.person_rounded)),
                        title: Text(
                            user['fullName']?.toString().isNotEmpty == true
                                ? user['fullName']
                                : user['username'],
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(
                            '${user['designation'] ?? user['role'] ?? ''} • ${user['department'] ?? ''}'),
                        trailing: const Icon(Icons.chat_bubble_outline_rounded),
                      );
                    }),
          ),
        ]),
      ),
    );
  }
}

class _AvailabilityDialog extends StatefulWidget {
  const _AvailabilityDialog({required this.repository});

  final AttendanceRepository repository;

  @override
  State<_AvailabilityDialog> createState() => _AvailabilityDialogState();
}

class _AvailabilityDialogState extends State<_AvailabilityDialog> {
  String availability = 'available';
  bool aiEnabled = false;
  final statusController = TextEditingController();
  bool loading = true;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final current = await widget.repository.communicationAvailability();
      if (!mounted) return;
      setState(() {
        availability = current['availability']?.toString() ?? 'available';
        aiEnabled = current['aiAssistantEnabled'] == true;
        statusController.text = current['statusMessage']?.toString() ?? '';
        loading = false;
        error = null;
      });
    } catch (value) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Could not load current settings: $value';
      });
    }
  }

  Future<void> _save() async {
    if (saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.repository.updateCommunicationAvailability(
          availability, aiEnabled, statusController.text.trim());
      if (mounted) Navigator.pop(context);
    } catch (value) {
      if (!mounted) return;
      setState(() {
        saving = false;
        error = 'Could not save settings: $value';
      });
    }
  }

  @override
  void dispose() {
    statusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        title: const Text('Availability & AI assistant'),
        content: SizedBox(
          width: 360,
          child: loading
              ? const SizedBox(
                  height: 110,
                  child: Center(child: CircularProgressIndicator()))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (error != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 9),
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(error!,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 10)),
                      ),
                    DropdownButtonFormField<String>(
                      value: availability,
                      isExpanded: true,
                      decoration:
                          const InputDecoration(labelText: 'Availability'),
                      items: const [
                        DropdownMenuItem(
                            value: 'available', child: Text('Available')),
                        DropdownMenuItem(value: 'busy', child: Text('Busy')),
                        DropdownMenuItem(value: 'away', child: Text('Away')),
                        DropdownMenuItem(
                            value: 'offline', child: Text('Offline')),
                      ],
                      onChanged: (value) =>
                          setState(() => availability = value ?? 'available'),
                    ),
                    const SizedBox(height: 7),
                    SwitchListTile.adaptive(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Gemini assistant'),
                      subtitle: const Text(
                        'Replies while Away or Offline. Restricted actions are escalated.',
                        style: TextStyle(fontSize: 11),
                      ),
                      value: aiEnabled,
                      onChanged: (value) => setState(() => aiEnabled = value),
                    ),
                    const SizedBox(height: 3),
                    TextField(
                      controller: statusController,
                      maxLength: 250,
                      minLines: 1,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration:
                          const InputDecoration(labelText: 'Status message'),
                    ),
                  ],
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: loading || saving ? null : _save,
            child: saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      );
}

class _AnnouncementDialog extends StatefulWidget {
  const _AnnouncementDialog();

  @override
  State<_AnnouncementDialog> createState() => _AnnouncementDialogState();
}

class _AnnouncementDialogState extends State<_AnnouncementDialog> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        scrollable: true,
        title: const Text('Team announcement'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          maxLength: 10000,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
              hintText: 'This message will be sent to every active employee.'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isNotEmpty) Navigator.pop(context, value);
              },
              child: const Text('Send to all'))
        ],
      );
}
