import 'dart:async';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/storage/session_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../attendance/data/attendance_repository.dart';
import '../data/communication_realtime_service.dart';
import 'communication_call_screen.dart';

class CommunicationThreadScreen extends StatefulWidget {
  const CommunicationThreadScreen({
    super.key,
    required this.conversationId,
    required this.person,
    required this.repository,
    required this.session,
  });

  final String conversationId;
  final Map<String, dynamic> person;
  final AttendanceRepository repository;
  final SessionStore session;

  @override
  State<CommunicationThreadScreen> createState() =>
      _CommunicationThreadScreenState();
}

class _CommunicationThreadScreenState extends State<CommunicationThreadScreen> {
  final input = TextEditingController();
  final scroll = ScrollController();
  List<Map<String, dynamic>> messages = [];
  final List<Map<String, dynamic>> pendingAttachments = [];
  Timer? refreshTimer;
  StreamSubscription<Map<String, dynamic>>? messageSubscription;
  StreamSubscription<Map<String, dynamic>>? deliverySubscription;
  StreamSubscription<Map<String, dynamic>>? readSubscription;
  StreamSubscription<Map<String, dynamic>>? presenceSubscription;
  bool loading = true;
  bool sending = false;
  bool uploading = false;
  bool online = false;
  Object? error;

  String get name => widget.person['fullName']?.toString().isNotEmpty == true
      ? widget.person['fullName'].toString()
      : widget.person['username']?.toString() ?? 'User';

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
    load(scrollToBottom: true);
    refreshTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => load(silent: true));
    final realtime = CommunicationRealtimeService.instance;
    messageSubscription = realtime.messages.listen((message) {
      if (message['conversationId']?.toString() != widget.conversationId) {
        return;
      }
      final existing =
          messages.indexWhere((item) => item['_id'] == message['_id']);
      if (existing >= 0) {
        if (message['realtimeUpdated'] == true && mounted) {
          setState(() => messages[existing] = message);
        }
        return;
      }
      if (mounted) {
        setState(() => messages.add(message));
        if (message['isMine'] != true) {
          widget.repository.markCommunicationRead(widget.conversationId);
        }
        _scrollToBottom();
      }
    });
    readSubscription = realtime.reads.listen((event) {
      if (event['conversationId']?.toString() != widget.conversationId) return;
      if (mounted) {
        setState(() {
          for (final message in messages) {
            if (message['isMine'] == true && message['readAt'] == null) {
              message['readAt'] = event['readAt'];
            }
          }
        });
      }
    });
    deliverySubscription = realtime.deliveries.listen((event) {
      if (event['conversationId']?.toString() != widget.conversationId) return;
      final deliveredIds = List<dynamic>.from(event['messageIds'] ?? const [])
          .map((id) => id.toString())
          .toSet();
      if (!mounted || deliveredIds.isEmpty) return;
      setState(() {
        for (final message in messages) {
          if (message['isMine'] == true &&
              deliveredIds.contains(message['_id']?.toString())) {
            message['deliveredAt'] = event['deliveredAt'];
          }
        }
      });
    });
    presenceSubscription = realtime.presence.listen((event) {
      if (event['userId']?.toString() == widget.person['_id']?.toString() &&
          mounted) {
        setState(() => online = event['online'] == true);
      }
    });
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    messageSubscription?.cancel();
    deliverySubscription?.cancel();
    readSubscription?.cancel();
    presenceSubscription?.cancel();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> load({bool silent = false, bool scrollToBottom = false}) async {
    try {
      final value =
          await widget.repository.communicationMessages(widget.conversationId);
      await widget.repository.markCommunicationRead(widget.conversationId);
      if (!mounted) return;
      final changed = value.length != messages.length ||
          (value.isNotEmpty &&
              messages.isNotEmpty &&
              value.last['_id'] != messages.last['_id']);
      setState(() {
        messages = value;
        loading = false;
        error = null;
      });
      if (scrollToBottom || changed) _scrollToBottom();
    } catch (value) {
      if (mounted && !silent) {
        setState(() {
          error = value;
          loading = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.animateTo(scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      }
    });
  }

  Future<void> send() async {
    final text = input.text.trim();
    if ((text.isEmpty && pendingAttachments.isEmpty) || sending || uploading) {
      return;
    }
    final attachments = pendingAttachments
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    setState(() => sending = true);
    input.clear();
    setState(() => pendingAttachments.clear());
    try {
      final message = await widget.repository
          .sendCommunicationMessage(widget.conversationId, text, attachments);
      if (mounted) {
        if (!messages.any((item) => item['_id'] == message['_id'])) {
          setState(() => messages.add(message));
        }
        _scrollToBottom();
      }
    } catch (value) {
      input.text = text;
      pendingAttachments.addAll(attachments);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Message failed: $value')));
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = resolveApiAssetUrl(widget.person['profileImage']);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.green.withValues(alpha: .1),
              backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
              child: photo.isEmpty
                  ? Text(name.isEmpty ? '?' : name[0].toUpperCase())
                  : null),
          const SizedBox(width: 9),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w900)),
              Text(
                  online
                      ? 'Online'
                      : widget.person['designation']?.toString().isNotEmpty ==
                              true
                          ? widget.person['designation'].toString()
                          : widget.person['role']?.toString() ?? '',
                  style: TextStyle(
                      fontSize: 8,
                      color: online ? AppColors.emerald : Colors.black45,
                      fontWeight:
                          online ? FontWeight.w800 : FontWeight.normal)),
            ]),
          ),
        ]),
        actions: [
          IconButton(
              tooltip: 'Audio call',
              onPressed: () => _startCall(false),
              icon: const Icon(Icons.call_outlined)),
          IconButton(
              tooltip: 'Video call',
              onPressed: () => _startCall(true),
              icon: const Icon(Icons.videocam_outlined)),
          if (isSuperAdmin)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'audit') _showAudit();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'audit', child: Text('View audit history'))
              ],
            )
        ],
      ),
      body: Column(children: [
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
                  ? Center(
                      child: FilledButton(
                          onPressed: () => load(),
                          child: Text('Retry: $error')))
                  : messages.isEmpty
                      ? const Center(
                          child: Text(
                              'Secure conversation started.\nSend the first message.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black45)))
                      : ListView.builder(
                          controller: scroll,
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
                          itemCount: messages.length,
                          itemBuilder: (_, index) => _bubble(messages[index]),
                        ),
        ),
        _composer(),
      ]),
    );
  }

  Widget _bubble(Map<String, dynamic> message) {
    final mine = message['isMine'] == true;
    final created =
        DateTime.tryParse(message['createdAt']?.toString() ?? '')?.toLocal();
    final read = DateTime.tryParse(message['readAt']?.toString() ?? '') != null;
    final delivered =
        DateTime.tryParse(message['deliveredAt']?.toString() ?? '') != null;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: mine && message['deletedAt'] == null
            ? () => _messageActions(message)
            : null,
        child: Container(
          constraints:
              BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.fromLTRB(11, 8, 9, 6),
          decoration: BoxDecoration(
            color: mine ? AppColors.green : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(mine ? 14 : 3),
              bottomRight: Radius.circular(mine ? 3 : 14),
            ),
            border: mine ? null : Border.all(color: Colors.black12),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (message['aiGenerated'] == true || message['kind'] == 'ai')
              Container(
                margin: const EdgeInsets.only(bottom: 5),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(5)),
                child: const Text('GEMINI ASSISTANT',
                    style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 6.5,
                        letterSpacing: .6,
                        fontWeight: FontWeight.w900)),
              ),
            if (message['kind'] == 'task')
              Container(
                margin: const EdgeInsets.only(bottom: 5),
                child: const Text('OPERATIONS TASK',
                    style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 6.5,
                        letterSpacing: .6,
                        fontWeight: FontWeight.w900)),
              ),
            if (message['metadata']?['announcement'] == true)
              Container(
                margin: const EdgeInsets.only(bottom: 5),
                child: const Text('TEAM ANNOUNCEMENT',
                    style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 6.5,
                        letterSpacing: .6,
                        fontWeight: FontWeight.w900)),
              ),
            ...List<Map<String, dynamic>>.from(message['attachments'] ?? [])
                .map((attachment) => _attachmentTile(attachment, mine)),
            if (message['text']?.toString().isNotEmpty == true)
              Text(message['text']?.toString() ?? '',
                  style: TextStyle(
                      color: mine ? Colors.white : AppColors.navy,
                      fontSize: 12,
                      height: 1.3)),
            const SizedBox(height: 3),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(created == null ? '' : DateFormat('h:mm a').format(created),
                  style: TextStyle(
                      color: mine ? Colors.white60 : Colors.black38,
                      fontSize: 7)),
              if (mine) ...[
                const SizedBox(width: 3),
                Tooltip(
                  message: read
                      ? 'Read'
                      : delivered
                          ? 'Delivered'
                          : 'Sent',
                  child: Icon(
                      read || delivered
                          ? Icons.done_all_rounded
                          : Icons.done_rounded,
                      size: 12,
                      color: read ? AppColors.gold : Colors.white60),
                ),
              ]
            ])
          ]),
        ),
      ),
    );
  }

  Future<void> _messageActions(Map<String, dynamic> message) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(children: [
          if (message['text']?.toString().isNotEmpty == true)
            ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit message'),
                onTap: () => Navigator.pop(context, 'edit')),
          ListTile(
              leading:
                  const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: const Text('Delete message',
                  style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(context, 'delete')),
        ]),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      var editedText = message['text']?.toString() ?? '';
      final savedText = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          title: const Text('Edit message'),
          content: TextFormField(
            initialValue: editedText,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (value) => editedText = value,
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  final value = editedText.trim();
                  if (value.isNotEmpty) Navigator.pop(dialogContext, value);
                },
                child: const Text('Save'))
          ],
        ),
      );
      if (savedText != null) {
        final updated = await widget.repository
            .editCommunicationMessage(message['_id'].toString(), savedText);
        final index =
            messages.indexWhere((item) => item['_id'] == message['_id']);
        if (mounted && index >= 0) setState(() => messages[index] = updated);
      }
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete this message?'),
          content: const Text(
              'The message will disappear from chat. The action remains in the Super Administrator audit log.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Delete'))
          ],
        ),
      );
      if (confirmed == true) {
        final updated = await widget.repository
            .deleteCommunicationMessage(message['_id'].toString());
        final index =
            messages.indexWhere((item) => item['_id'] == message['_id']);
        if (mounted && index >= 0) setState(() => messages[index] = updated);
      }
    }
  }

  Widget _composer() => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(9, 7, 9, 8),
          decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.black12))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (pendingAttachments.isNotEmpty || uploading)
              SizedBox(
                height: 42,
                child: Row(children: [
                  if (uploading)
                    const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: SizedBox.square(
                            dimension: 17,
                            child: CircularProgressIndicator(strokeWidth: 2))),
                  Expanded(
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: pendingAttachments.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 5),
                      itemBuilder: (_, index) => InputChip(
                        visualDensity: const VisualDensity(vertical: -4),
                        label: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 110),
                            child: Text(
                                pendingAttachments[index]['originalName']
                                        ?.toString() ??
                                    'Attachment',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 8))),
                        onDeleted: () =>
                            setState(() => pendingAttachments.removeAt(index)),
                      ),
                    ),
                  ),
                ]),
              ),
            Row(children: [
              IconButton(
                  tooltip: 'Attach image, video or document',
                  onPressed: uploading || sending ? null : _pickAttachments,
                  icon: const Icon(Icons.attach_file_rounded)),
              Expanded(
                child: TextField(
                  controller: input,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => send(),
                  decoration: const InputDecoration(
                      hintText: 'Type a secure message...',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                tooltip: 'Send',
                onPressed: sending || uploading ? null : send,
                style: IconButton.styleFrom(backgroundColor: AppColors.green),
                icon: sending
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 19),
              )
            ]),
          ]),
        ),
      );

  Future<void> _pickAttachments() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const [
        'jpg',
        'jpeg',
        'png',
        'webp',
        'gif',
        'mp4',
        'mov',
        'm4v',
        'pdf',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'txt',
        'mp3',
        'm4a',
        'wav'
      ],
    );
    if (result == null) return;
    final paths = result.paths.whereType<String>().take(10).toList();
    if (paths.isEmpty) return;
    setState(() => uploading = true);
    try {
      for (final path in paths) {
        final attachment =
            await widget.repository.uploadCommunicationAttachment(path);
        if (mounted) setState(() => pendingAttachments.add(attachment));
      }
    } catch (value) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Attachment upload failed: $value')));
      }
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Widget _attachmentTile(Map<String, dynamic> attachment, bool mine) {
    final url = attachment['url']?.toString() ?? '';
    final type = attachment['mediaType']?.toString() ?? 'document';
    final name = attachment['originalName']?.toString() ?? 'Attachment';
    if (type == 'image' && url.isNotEmpty) {
      return GestureDetector(
        onTap: () => _openAttachment(url),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 230, maxHeight: 220),
          margin: const EdgeInsets.only(bottom: 6),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10), color: Colors.black12),
          child: Image.network(url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const SizedBox(height: 80, child: Icon(Icons.broken_image))),
        ),
      );
    }
    final icon = type == 'video'
        ? Icons.play_circle_outline_rounded
        : type == 'audio'
            ? Icons.graphic_eq_rounded
            : Icons.description_outlined;
    return InkWell(
      onTap: url.isEmpty ? null : () => _openAttachment(url),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: mine ? Colors.white12 : const Color(0xFFF3F6F8),
            borderRadius: BorderRadius.circular(9)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 22, color: mine ? AppColors.gold : AppColors.green),
          const SizedBox(width: 7),
          Flexible(
              child: Text(name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: mine ? Colors.white : AppColors.navy,
                      fontSize: 9,
                      fontWeight: FontWeight.w800))),
          const SizedBox(width: 5),
          Icon(Icons.open_in_new_rounded,
              size: 13, color: mine ? Colors.white60 : Colors.black38),
        ]),
      ),
    );
  }

  Future<void> _openAttachment(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open this attachment.')));
      }
    }
  }

  Future<void> _startCall(bool video) async {
    try {
      final call = await widget.repository
          .startCommunicationCall(widget.conversationId, video);
      if (!mounted) return;
      await Navigator.push(
          context,
          MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => CommunicationCallScreen(
                  call: call,
                  person: widget.person,
                  repository: widget.repository,
                  isCaller: true)));
    } catch (value) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Call failed: $value')));
      }
    }
  }

  Future<void> _showAudit() async {
    final rows =
        await widget.repository.communicationAudit(widget.conversationId);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: Column(children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('COMMUNICATION AUDIT HISTORY',
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w900)),
            ),
            Expanded(
              child: rows.isEmpty
                  ? const Center(child: Text('No audit entries.'))
                  : ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (_, index) {
                        final row = rows[index];
                        final at = DateTime.tryParse(
                                row['createdAt']?.toString() ?? '')
                            ?.toLocal();
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.history_rounded,
                              color: AppColors.green),
                          title: Text(
                              row['action']
                                      ?.toString()
                                      .replaceAll('-', ' ')
                                      .toUpperCase() ??
                                  'ACTION',
                              style: const TextStyle(
                                  fontSize: 9, fontWeight: FontWeight.w900)),
                          subtitle: Text(
                              '${row['actorName'] ?? '-'} • ${at == null ? '' : DateFormat('d MMM, h:mm a').format(at)}',
                              style: const TextStyle(fontSize: 8)),
                        );
                      }),
            )
          ]),
        ),
      ),
    );
  }
}
