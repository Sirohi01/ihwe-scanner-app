import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/domain/attendance_categories.dart';
import '../../attendance/presentation/attendance_profile_screen.dart';

class CompanyDetailScreen extends StatefulWidget {
  const CompanyDetailScreen({
    super.key,
    required this.companyId,
    required this.repository,
  });

  final String companyId;
  final AttendanceRepository repository;

  @override
  State<CompanyDetailScreen> createState() => _CompanyDetailScreenState();
}

class _CompanyDetailScreenState extends State<CompanyDetailScreen> {
  Map<String, dynamic>? data;
  Object? error;
  String selectedPassType = '';

  static const passLabels = <String, String>{
    'exhibitor': 'Exhibitor',
    'service': 'Service',
    'vehicle': 'Vehicle',
    'lunch': 'Lunch',
    'water': 'Water',
    'visitor': 'Visitor',
    'delegate': 'Delegate',
  };

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final value = await widget.repository.companyDetail(widget.companyId);
      if (mounted) setState(() => data = value);
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Company Attendance')),
        body: data == null
            ? Center(
                child: error == null
                    ? const CircularProgressIndicator()
                    : Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('$error'),
                        const SizedBox(height: 10),
                        FilledButton(onPressed: load, child: const Text('Retry')),
                      ]))
            : RefreshIndicator(onRefresh: load, child: _content()),
      );

  Widget _content() {
    final company = Map<String, dynamic>.from(data!['company']);
    final companyAttendance =
        List<Map<String, dynamic>>.from(data!['companyAttendance'] ?? []);
    final allMemberAttendance = _groupMembers(
        List<Map<String, dynamic>>.from(data!['memberAttendance'] ?? []));
    final counts = <String, int>{
      for (final type in passLabels.keys)
        type: allMemberAttendance.where((item) => _passType(item) == type).length
    };
    final memberAttendance = selectedPassType.isEmpty
        ? allMemberAttendance
        : allMemberAttendance
            .where((item) => _passType(item) == selectedPassType)
            .toList();
    final days = List<String>.from(data!['days'] ?? []);
    final companyDays = companyAttendance.map((e) => e['eventDay']).toSet();
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppColors.navy, AppColors.green]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _companyPhoto(company),
              const SizedBox(width: 10),
              Expanded(
                child: Text(company['name']?.toString() ?? 'Exhibitor',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900)),
              ),
            ]),
            const SizedBox(height: 7),
            Text(company['registrationId']?.toString() ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
            if (company['stallNo']?.toString().isNotEmpty == true)
              Text('Stall: ${company['stallNo']}',
                  style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
            if (company['contactPerson']?.toString().isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text('Contact: ${company['contactPerson']}',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 10)),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: days
                  .map((day) => Chip(
                        avatar: Icon(
                            companyDays.contains(day)
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 16,
                            color: companyDays.contains(day)
                                ? AppColors.emerald
                                : Colors.black38),
                        label: Text(DateFormat('d MMM')
                            .format(DateTime.parse(day))),
                      ))
                  .toList(),
            ),
          ]),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 3, 16, 5),
        sliver: SliverToBoxAdapter(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('PASS-WISE ARRIVALS',
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w900,
                      color: Colors.black45)),
              Text('${allMemberAttendance.length} total',
                  style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.green,
                      fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 6),
            SizedBox(
              height: 67,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: passLabels.length,
                itemBuilder: (_, index) {
                  final type = passLabels.keys.elementAt(index);
                  return _passStat(type, counts[type] ?? 0);
                },
              ),
            ),
            const SizedBox(height: 7),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _filterChip('', 'All'),
                  ...passLabels.entries
                      .where((entry) => (counts[entry.key] ?? 0) > 0)
                      .map((entry) => _filterChip(entry.key, entry.value)),
                ],
              ),
            ),
          ]),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
        sliver: SliverToBoxAdapter(
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('PRESENT TEAM MEMBERS',
                style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w900,
                    color: Colors.black45)),
            Text('${memberAttendance.length} shown',
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.green,
                    fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
      if (memberAttendance.isEmpty)
        const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('No team member checked in yet.')))
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
          sliver: SliverFixedExtentList.builder(
            itemExtent: 68,
            itemCount: memberAttendance.length,
            itemBuilder: (_, i) => _memberCard(memberAttendance[i]),
          ),
        ),
    ]);
  }

  List<Map<String, dynamic>> _groupMembers(
      List<Map<String, dynamic>> records) {
    final grouped = <String, Map<String, dynamic>>{};
    for (final record in records) {
      final key = record['subjectKey']?.toString() ??
          record['registrationId']?.toString() ??
          '';
      final current = grouped.putIfAbsent(key, () => {...record, 'days': <String>[]});
      final day = record['eventDay']?.toString() ?? '';
      if (day.isNotEmpty) (current['days'] as List<String>).add(day);
    }
    return grouped.values.toList();
  }

  String _passType(Map<String, dynamic> member) {
    final value = member['passType']?.toString() ?? '';
    if (value.isNotEmpty) return value;
    return (member['subjectSubType']?.toString() ?? '').replaceAll('-pass', '');
  }

  Widget _companyPhoto(Map<String, dynamic> company) {
    final photo = company['logoUrl']?.toString() ?? '';
    return Container(
      width: 50,
      height: 50,
      padding: EdgeInsets.all(photo.isNotEmpty ? 4 : 0),
      decoration: BoxDecoration(
        color: photo.isNotEmpty ? Colors.white : Colors.white12,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: photo.isNotEmpty
          ? Image.network(photo,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                  Icons.storefront_rounded,
                  color: AppColors.green,
                  size: 27))
          : const Icon(Icons.storefront_rounded,
              color: AppColors.gold, size: 27),
    );
  }

  Widget _passStat(String type, int count) => Container(
        width: 91,
        margin: const EdgeInsets.only(right: 6),
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$count',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  Text(passLabels[type]!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 9,
                          color: Colors.black54,
                          fontWeight: FontWeight.w800)),
                ]),
          ),
        ),
      );

  Widget _filterChip(String type, String label) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(label),
          selected: selectedPassType == type,
          showCheckmark: true,
          selectedColor: AppColors.green,
          labelStyle: TextStyle(
              color: selectedPassType == type ? Colors.white : AppColors.ink,
              fontSize: 10,
              fontWeight: FontWeight.w700),
          onSelected: (_) => setState(() => selectedPassType = type),
        ),
      );

  Widget _memberCard(Map<String, dynamic> member) {
    final photo = member['photoUrl']?.toString() ?? '';
    final days = List<String>.from(member['days'] ?? []);
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        onTap: () {
          final attendanceId = member['_id']?.toString() ?? '';
          if (attendanceId.length == 24) {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AttendanceProfileScreen(
                    attendanceId: attendanceId,
                    repository: widget.repository)));
          }
        },
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        leading: _memberPhoto(photo),
        title: Text(member['name']?.toString() ?? 'Team member',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
        subtitle: Text('${passLabels[_passType(member)] ?? attendanceLabel(member['subjectSubType'] ?? '')} Pass${member['designation']?.toString().isNotEmpty == true ? ' • ${member['designation']}' : ''}',
            style: const TextStyle(fontSize: 9)),
        trailing: Text(
            days.isEmpty
                ? '-'
                : days
                    .map((day) => DateFormat('d MMM').format(DateTime.parse(day)))
                    .join(', '),
            style: const TextStyle(
                color: AppColors.emerald,
                fontSize: 10,
                fontWeight: FontWeight.w900)),
      ),
    );
  }

  Widget _memberPhoto(String photo) => Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.green.withValues(alpha: .1),
        ),
        clipBehavior: Clip.antiAlias,
        child: photo.isNotEmpty
            ? Image.network(photo,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                    Icons.person_rounded,
                    color: AppColors.green,
                    size: 20))
            : const Icon(Icons.person_rounded,
                color: AppColors.green, size: 20),
      );
}
