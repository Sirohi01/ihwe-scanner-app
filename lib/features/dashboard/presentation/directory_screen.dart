import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/domain/attendance_categories.dart';
import '../../attendance/presentation/attendance_profile_screen.dart';
import '../../attendance/presentation/ai_summary_dialog.dart';
import 'company_detail_screen.dart';

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen(
      {super.key, required this.type, required this.repository});
  final String type;
  final AttendanceRepository repository;
  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  Map<String, dynamic>? data;
  Object? error;
  String view = 'present', subType = '';
  String? day;
  Timer? debounce;
  String get title =>
      '${widget.type[0].toUpperCase()}${widget.type.substring(1)} Directory';
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  Future<void> load([String search = '']) async {
    try {
      final result = await widget.repository.directory(widget.type,
          view: view, day: day, subType: subType, search: search);
      if (mounted) {
        setState(() {
          data = result;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(title), actions: [
        IconButton(
            tooltip: 'AI summary',
            onPressed: () => showAiSummaryDialog(context,
                repository: widget.repository, scope: 'exhibition'),
            icon:
                const Icon(Icons.auto_awesome_rounded, color: AppColors.green))
      ]),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
            child: Column(children: [
              SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'present',
                        label: Text('Present'),
                        icon: Icon(Icons.how_to_reg_rounded)),
                    ButtonSegment(
                        value: 'all',
                        label: Text('All registered'),
                        icon: Icon(Icons.groups_rounded))
                  ],
                  selected: {
                    view
                  },
                  showSelectedIcon: false,
                  onSelectionChanged: (v) {
                    setState(() {
                      view = v.first;
                      data = null;
                    });
                    load();
                  }),
              const SizedBox(height: 8),
              TextField(
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Search name, company, ID, email or mobile',
                      isDense: true),
                  onChanged: (v) {
                    debounce?.cancel();
                    debounce =
                        Timer(const Duration(milliseconds: 450), () => load(v));
                  }),
              if (view == 'present' && data != null) ...[
                const SizedBox(height: 7),
                SizedBox(
                    height: 34,
                    child:
                        ListView(scrollDirection: Axis.horizontal, children: [
                      _day(null, 'All days'),
                      ...List<String>.from(data!['days'] ?? []).map((d) => _day(
                          d, DateFormat('d MMM').format(DateTime.parse(d))))
                    ]))
              ],
              const SizedBox(height: 7),
              SizedBox(
                  height: 34,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    _typeChip('', 'All'),
                    ...subTypesFor(widget.type)
                        .map((c) => _typeChip(c.value, c.label))
                  ]))
            ])),
        Expanded(
            child: data == null
                ? Center(
                    child: error == null
                        ? const AppListSkeleton()
                        : FilledButton(
                            onPressed: () => load(),
                            child: Text('Retry: $error')))
                : RefreshIndicator(onRefresh: () => load(), child: _list()))
      ]));
  Widget _day(String? key, String label) => Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
          label: Text(label),
          selected: day == key,
          onSelected: (_) {
            setState(() {
              day = key;
              data = null;
            });
            load();
          }));
  Widget _typeChip(String key, String label) => Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
          label: Text(label),
          selected: subType == key,
          onSelected: (_) {
            setState(() {
              subType = key;
              data = null;
            });
            load();
          }));
  Widget _list() {
    final items = List<Map<String, dynamic>>.from(data!['items'] ?? []);
    final total = data!['pagination']?['total'] ?? items.length;
    if (items.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 120),
        Icon(Icons.person_search_rounded, size: 52, color: Colors.black26),
        const SizedBox(height: 10),
        Text(
            view == 'present'
                ? 'No check-ins in this selection.'
                : 'No registrations found.',
            textAlign: TextAlign.center)
      ]);
    }
    return CustomScrollView(slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(14, 2, 14, 7),
        sliver: SliverToBoxAdapter(
          child: Text('$total ${view == 'present' ? 'present' : 'registered'}',
              style: const TextStyle(
                  fontWeight: FontWeight.w900, color: AppColors.green)),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 90),
        sliver: items.length > 7
            ? SliverFixedExtentList.builder(
                itemExtent: 76,
                itemCount: items.length,
                itemBuilder: (_, i) => _card(items[i]),
              )
            : SliverList.builder(
                itemCount: items.length,
                itemBuilder: (_, i) => _card(items[i]),
              ),
      ),
    ]);
  }

  Widget _card(Map<String, dynamic> item) {
    final photo = resolveApiAssetUrl(item['photoUrl']);
    final name = (widget.type == 'exhibitor' ? item['company'] : item['name'])
            ?.toString() ??
        'Profile';
    return Card(
        margin: const EdgeInsets.only(bottom: 7),
        child: ListTile(
            dense: true,
            onTap: () => _open(item),
            leading: CircleAvatar(
                backgroundColor: AppColors.green.withValues(alpha: .1),
                backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                child: photo.isEmpty
                    ? Icon(
                        widget.type == 'exhibitor'
                            ? Icons.storefront_rounded
                            : Icons.person_rounded,
                        color: AppColors.green)
                    : null),
            title: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text(
                [
                  if (widget.type != 'exhibitor' &&
                      (item['company']?.toString().isNotEmpty ?? false))
                    item['company'],
                  item['registrationId']
                ]
                    .where((e) => e != null && e.toString().isNotEmpty)
                    .join(' • '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.chevron_right_rounded)));
  }

  void _open(Map<String, dynamic> item) {
    if (widget.type == 'exhibitor' &&
        (item['companyId']?.toString().length ?? 0) == 24) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => CompanyDetailScreen(
                  companyId: item['companyId'],
                  repository: widget.repository)));
      return;
    }
    final attendanceId = item['attendanceId']?.toString() ?? '';
    if (attendanceId.isNotEmpty) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => AttendanceProfileScreen(
                  attendanceId: attendanceId, repository: widget.repository)));
    } else {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => DirectoryProfileScreen(
                  registrationId: item['registrationId'],
                  repository: widget.repository)));
    }
  }
}

class DirectoryProfileScreen extends StatefulWidget {
  const DirectoryProfileScreen(
      {super.key, required this.registrationId, required this.repository});
  final String registrationId;
  final AttendanceRepository repository;
  @override
  State<DirectoryProfileScreen> createState() => _DirectoryProfileScreenState();
}

class _DirectoryProfileScreenState extends State<DirectoryProfileScreen> {
  Map<String, dynamic>? data;
  Object? error;
  @override
  void initState() {
    super.initState();
    widget.repository.directoryProfile(widget.registrationId).then((v) {
      if (mounted) setState(() => data = v);
    }).catchError((e) {
      if (mounted) setState(() => error = e);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = data == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(data!['profile'] ?? {});
    final photo = resolveApiAssetUrl(p['photoUrl']);
    return Scaffold(
        appBar: AppBar(title: const Text('Registered Profile'), actions: [
          IconButton(
              onPressed: () => showAiSummaryDialog(context,
                  repository: widget.repository,
                  scope: 'person',
                  id: widget.registrationId),
              icon: const Icon(Icons.auto_awesome_rounded,
                  color: AppColors.green))
        ]),
        body: data == null
            ? Center(
                child:
                    error == null ? const AppProfileSkeleton() : Text('$error'))
            : ListView(padding: const EdgeInsets.all(16), children: [
                CircleAvatar(
                    radius: 38,
                    backgroundColor: AppColors.green.withValues(alpha: .1),
                    backgroundImage:
                        photo.isNotEmpty ? NetworkImage(photo) : null,
                    child: photo.isEmpty
                        ? const Icon(Icons.person_rounded,
                            size: 38, color: AppColors.green)
                        : null),
                const SizedBox(height: 12),
                Text(p['name']?.toString() ?? 'Profile',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w900)),
                Text(p['registrationId']?.toString() ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.green, fontWeight: FontWeight.w800)),
                const SizedBox(height: 18),
                ...p.entries
                    .where((e) =>
                        !['details', 'subjectId', 'subjectKey', 'photoUrl']
                            .contains(e.key) &&
                        e.value.toString().isNotEmpty)
                    .map((e) => ListTile(
                        dense: true,
                        title: Text(_label(e.key)),
                        subtitle: Text(e.value.toString()))),
                ...Map<String, dynamic>.from(p['details'] ?? {})
                    .entries
                    .where((e) => e.value.toString().isNotEmpty)
                    .map((e) => ListTile(
                        dense: true,
                        title: Text(_label(e.key)),
                        subtitle: Text(e.value is List
                            ? (e.value as List).join(', ')
                            : e.value.toString())))
              ]));
  }

  String _label(String v) => v
      .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m[1]}')
      .replaceAll('_', ' ')
      .trim();
}
