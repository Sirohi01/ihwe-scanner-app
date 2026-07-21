import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    scroll.addListener(_onScroll);
    load();
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
          SizedBox(
            height: 40,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              scrollDirection: Axis.horizontal,
              children: attendanceTypes
                  .map((item) => Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: ChoiceChip(
                          showCheckmark: true,
                          label: Text(item.label),
                          selected: type == item.value,
                          onSelected: (_) {
                            type = item.value;
                            subType = '';
                            load();
                          },
                        ),
                      ))
                  .toList(),
            ),
          ),
          if (type.isNotEmpty) ...[
            const SizedBox(height: 5),
            SizedBox(
              height: 36,
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

  Widget _body() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (records.isEmpty) {
      return const Center(child: Text('No attendance records found.'));
    }
    return RefreshIndicator(
      onRefresh: load,
      child: ListView.builder(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(18, 2, 18, 90),
        itemExtent: 76,
        cacheExtent: 380,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: records.length + (loadingMore ? 1 : 0),
        itemBuilder: (_, i) => i == records.length
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : _recordCard(records[i]),
      ),
    );
  }

  Widget _subTypeChip(String value, String label) => Padding(
        padding: const EdgeInsets.only(right: 7),
        child: ChoiceChip(
          showCheckmark: true,
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
