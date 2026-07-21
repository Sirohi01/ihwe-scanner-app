import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/domain/attendance_categories.dart';
import '../../attendance/presentation/attendance_profile_screen.dart';
import '../../dashboard/presentation/company_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.repository});
  final AttendanceRepository repository;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final search = TextEditingController();
  final scroll = ScrollController();
  List<Map<String, dynamic>> records = [];
  bool loading = true;
  bool loadingMore = false;
  bool hasMore = true;
  int page = 1;
  int requestVersion = 0;
  Timer? debounce;
  String type = '';
  String subType = '';
  String day = '';
  List<String> days = [];
  bool exporting = false;

  @override
  void initState() {
    super.initState();
    scroll.addListener(_onScroll);
    _loadDays();
    load();
  }

  Future<void> _loadDays() async {
    try {
      final dashboard = await widget.repository.dashboard();
      if (mounted) {
        setState(() => days = List<String>.from(dashboard['days'] ?? []));
      }
    } catch (_) {
      // Records remain usable when event metadata is temporarily unavailable.
    }
  }

  void _onScroll() {
    if (scroll.position.extentAfter < 360 &&
        hasMore &&
        !loading &&
        !loadingMore) {
      load(reset: false);
    }
  }

  void _onSearchChanged(String _) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 450), load);
  }

  Future<void> load({bool reset = true}) async {
    final version = reset ? ++requestVersion : requestVersion;
    final targetPage = reset ? 1 : page + 1;
    if (mounted) setState(() => reset ? loading = true : loadingMore = true);
    try {
      final next = await widget.repository.records(
        type: type,
        subType: subType,
        day: day,
        search: search.text.trim(),
        page: targetPage,
        limit: 50,
      );
      if (!mounted || version != requestVersion) return;
      setState(() {
        records = reset ? next : [...records, ...next];
        page = targetPage;
        hasMore = next.length == 50;
      });
    } finally {
      if (mounted && version == requestVersion) {
        setState(() {
          loading = false;
          loadingMore = false;
        });
      }
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    scroll.dispose();
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          toolbarHeight: 72,
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Attendance Log',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24)),
              Text('Verified entry records',
                  style: TextStyle(fontSize: 11, color: Colors.black45)),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Export filtered Excel',
              onPressed: exporting ? null : _exportExcel,
              icon: exporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.file_download_outlined,
                      color: AppColors.green),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 8),
            child: TextField(
              controller: search,
              onChanged: _onSearchChanged,
              onSubmitted: (_) => load(),
              decoration: InputDecoration(
                hintText: 'Search name, ID, company, mobile...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: search.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          search.clear();
                          load();
                        },
                        icon: const Icon(Icons.close_rounded)),
              ),
            ),
          ),
          if (days.isNotEmpty)
            SizedBox(
              height: 36,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                scrollDirection: Axis.horizontal,
                children: [
                  _dayChip('', 'All days'),
                  ...days.map((value) => _dayChip(
                      value,
                      DateFormat('EEE, d MMM')
                          .format(DateTime.parse(value)))),
                ],
              ),
            ),
          SizedBox(
            height: 34,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              scrollDirection: Axis.horizontal,
              children: attendanceTypes
                  .map((item) => _typeChip(item.value, item.label))
                  .toList(),
            ),
          ),
          if (type.isNotEmpty) ...[
            const SizedBox(height: 5),
            SizedBox(
              height: 32,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                scrollDirection: Axis.horizontal,
                children: [
                  _subTypeChip('', 'All ${attendanceLabel(type)}'),
                  ...subTypesFor(type)
                      .map((item) => _subTypeChip(item.value, item.label)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 7),
          Expanded(child: _body()),
        ]),
      );

  Widget _dayChip(String value, String label) => Padding(
        padding: const EdgeInsets.only(right: 7),
        child: ChoiceChip(
          showCheckmark: true,
          checkmarkColor: Colors.white,
          visualDensity: const VisualDensity(horizontal: -1, vertical: -2),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          label: Text(label),
          selected: day == value,
          onSelected: (_) {
            day = value;
            load();
          },
          selectedColor: AppColors.green,
          labelStyle: TextStyle(
              color: day == value ? Colors.white : AppColors.ink,
              fontSize: 10,
              fontWeight: FontWeight.w700),
        ),
      );

  Widget _typeChip(String value, String label) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          showCheckmark: true,
          checkmarkColor: Colors.white,
          visualDensity: const VisualDensity(horizontal: -1, vertical: -2),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          label: Text(label),
          selected: type == value,
          onSelected: (_) {
            type = value;
            subType = '';
            load();
          },
          selectedColor: AppColors.navy,
          labelStyle: TextStyle(
              color: type == value ? Colors.white : AppColors.ink,
              fontSize: 11,
              fontWeight: FontWeight.w800),
        ),
      );

  Future<void> _exportExcel() async {
    setState(() => exporting = true);
    try {
      final path = await widget.repository.exportAttendance(
        day: day,
        type: type,
        subType: subType,
        search: search.text.trim(),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded,
              color: AppColors.emerald, size: 38),
          title: const Text('Excel export ready'),
          content: SelectableText('Saved on this device:\n$path',
              textAlign: TextAlign.center),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'))
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Export failed: $error')));
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  Widget _body() {
    if (loading) return const AppListSkeleton(count: 7);
    if (records.isEmpty) {
      return const Center(child: Text('No attendance records found.'));
    }
    return RefreshIndicator(
      onRefresh: load,
      child: records.length <= 7
          ? ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 90),
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              children: records.map(_recordCard).toList(),
            )
          : ListView.builder(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 90),
              itemExtent: 76,
              cacheExtent: 380,
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: records.length + (loadingMore ? 1 : 0),
              itemBuilder: (_, i) => i == records.length
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : _recordCard(records[i]),
            ),
    );
  }

  Widget _subTypeChip(String value, String label) => Padding(
        padding: const EdgeInsets.only(right: 7),
        child: ChoiceChip(
          showCheckmark: true,
          checkmarkColor: Colors.white,
          visualDensity: const VisualDensity(horizontal: -1, vertical: -2),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          label: Text(label),
          selected: subType == value,
          selectedColor: AppColors.green,
          labelStyle: TextStyle(
            color: subType == value ? Colors.white : AppColors.ink,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
          onSelected: (_) {
            subType = value;
            load();
          },
        ),
      );

  Widget _recordCard(Map<String, dynamic> record) {
    final time = DateTime.tryParse(record['markedAt']?.toString() ?? '');
    final eventDay = DateTime.tryParse(record['eventDay']?.toString() ?? '');
    final subjectType = record['subjectType']?.toString() ?? '';
    final icon = subjectType == 'buyer'
        ? Icons.handshake_rounded
        : subjectType == 'exhibitor'
            ? Icons.storefront_rounded
            : Icons.person_rounded;
    final name = record['name']?.toString() ?? '';
    final company = record['company']?.toString() ?? '';
    final isCompanyEntry =
        subjectType == 'exhibitor' && record['attendanceKind'] != 'pass';
    final displayName = isCompanyEntry && company.isNotEmpty
        ? company
        : (name.isNotEmpty
            ? name
            : record['registrationId']?.toString() ?? '-');
    final detail = isCompanyEntry
        ? '${attendanceLabel(record['subjectSubType'] ?? '')} • ${record['registrationId'] ?? ''}'
        : '${company.isNotEmpty ? company : attendanceLabel(record['subjectSubType'] ?? '')} • ${attendanceLabel(record['subjectSubType'] ?? '')}';
    final photoUrl = record['photoUrl']?.toString() ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        onTap: () => _openProfile(record, isCompanyEntry),
        dense: true,
        visualDensity: const VisualDensity(vertical: -2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.green.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: photoUrl.isNotEmpty
              ? Image.network(photoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Icon(icon, color: AppColors.green))
              : Icon(icon, color: AppColors.green),
        ),
        title: Text(displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
        subtitle: Text(detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(eventDay == null ? '-' : DateFormat('d MMM').format(eventDay),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: AppColors.green)),
              if (isCompanyEntry) ...[
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right_rounded,
                    size: 15, color: AppColors.green),
              ]
            ]),
            if (time != null)
              Text(DateFormat('h:mm a').format(time.toLocal()),
                  style: const TextStyle(fontSize: 9, color: Colors.black38)),
          ],
        ),
      ),
    );
  }

  void _openProfile(Map<String, dynamic> record, bool isCompanyEntry) {
    final companyId = record['companyId']?.toString() ?? '';
    final attendanceId = record['_id']?.toString() ?? '';
    if (isCompanyEntry && companyId.length == 24) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CompanyDetailScreen(
              companyId: companyId, repository: widget.repository)));
    } else if (attendanceId.length == 24) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AttendanceProfileScreen(
              attendanceId: attendanceId, repository: widget.repository)));
    }
  }
}
