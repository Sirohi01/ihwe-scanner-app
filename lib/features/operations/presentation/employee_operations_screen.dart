import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/domain/attendance_categories.dart';
import '../../attendance/presentation/ai_summary_dialog.dart';

class EmployeeOperationsScreen extends StatefulWidget {
  const EmployeeOperationsScreen(
      {super.key, required this.userId, required this.repository});
  final String userId;
  final AttendanceRepository repository;
  @override
  State<EmployeeOperationsScreen> createState() =>
      _EmployeeOperationsScreenState();
}

class _EmployeeOperationsScreenState extends State<EmployeeOperationsScreen> {
  Map<String, dynamic>? data;
  Object? error;
  String day = '', source = '', action = '';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final result = await widget.repository.employeeOperations(widget.userId,
          day: day, source: source, action: action);
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
  Widget build(BuildContext context) {
    final user = Map<String, dynamic>.from(data?['user'] ?? {});
    final name = user['fullName']?.toString().isNotEmpty == true
        ? user['fullName'].toString()
        : user['username']?.toString() ?? 'Employee';
    return DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
              title: Text(name),
              actions: [
                IconButton(
                    onPressed: () => showAiSummaryDialog(context,
                        repository: widget.repository,
                        scope: 'employee',
                        id: widget.userId),
                    icon: const Icon(Icons.auto_awesome_rounded,
                        color: AppColors.green))
              ],
              bottom: const TabBar(tabs: [
                Tab(text: 'SUMMARY'),
                Tab(text: 'ACTIVITY'),
                Tab(text: 'PROFILE')
              ])),
          body: data == null
              ? Center(
                  child: error == null
                      ? const AppProfileSkeleton()
                      : FilledButton(
                          onPressed: load, child: Text('Retry: $error')))
              : TabBarView(children: [summary(), activity(), profile()]),
        ));
  }

  Widget header() {
    final user = Map<String, dynamic>.from(data!['user']);
    final photo = resolveApiAssetUrl(user['profileImage']);
    return Container(
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            gradient:
                const LinearGradient(colors: [AppColors.navy, AppColors.green]),
            borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white,
              backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
              child: photo.isEmpty
                  ? const Icon(Icons.person_rounded,
                      color: AppColors.green, size: 30)
                  : null),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    user['fullName']?.toString().isNotEmpty == true
                        ? user['fullName']
                        : user['username'] ?? 'Employee',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900)),
                Text('${user['designation'] ?? ''} • ${user['role'] ?? ''}',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 10)),
                Text(user['status'] ?? '',
                    style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 9,
                        fontWeight: FontWeight.w900))
              ]))
        ]));
  }

  Widget summary() {
    final s = Map<String, dynamic>.from(data!['summary'] ?? {});
    final days = List.from(data!['dayWise'] ?? []);
    final metrics = [
      ['Marked', s['marked'], Icons.how_to_reg_rounded],
      ['QR', s['qr'], Icons.qr_code_rounded],
      ['Manual', s['manual'], Icons.touch_app_rounded],
      ['Scans', s['scans'], Icons.document_scanner_rounded],
      ['Duplicate', s['duplicates'], Icons.copy_rounded],
      ['Invalid', s['invalid'], Icons.error_outline_rounded],
      ['Corrected', s['corrections'], Icons.edit_calendar_rounded],
      ['Removed', s['removals'], Icons.delete_outline_rounded]
    ];
    return ListView(padding: const EdgeInsets.only(bottom: 80), children: [
      header(),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              primary: false,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: .95,
              children: metrics
                  .map((m) => metric(m[0] as String, m[1], m[2] as IconData))
                  .toList())),
      const Padding(
          padding: EdgeInsets.fromLTRB(14, 16, 14, 7),
          child: Text('DAY-WISE WORK SUMMARY',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w900,
                  color: Colors.black45))),
      ...days.map(dayCard)
    ]);
  }

  Widget dayCard(dynamic raw) {
    final d = Map<String, dynamic>.from(raw);
    return Card(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 7),
        child: Padding(
            padding: const EdgeInsets.all(11),
            child: Column(children: [
              Row(children: [
                Expanded(
                    child: Text(
                        DateFormat('EEEE, d MMM')
                            .format(DateTime.parse(d['day'])),
                        style: const TextStyle(fontWeight: FontWeight.w900))),
                Text('${d['marked']} Marked',
                    style: const TextStyle(
                        color: AppColors.green, fontWeight: FontWeight.w900))
              ]),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                tiny('QR', d['qr']),
                tiny('Manual', d['manual']),
                tiny('Scans', d['scans']),
                tiny('Duplicate', d['duplicates']),
                tiny('Corrected', d['corrections'])
              ])
            ])));
  }

  Widget filters() {
    final days = List<String>.from(data!['days'] ?? []);
    return Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
        child: Column(children: [
          SizedBox(
              height: 34,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                chip('day', '', 'All days'),
                ...days.map((d) => chip(
                    'day', d, DateFormat('d MMM').format(DateTime.parse(d))))
              ])),
          const SizedBox(height: 5),
          SizedBox(
              height: 34,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                chip('source', '', 'All'),
                chip('source', 'qr', 'QR'),
                chip('source', 'manual', 'Manual'),
                chip('action', 'duplicate', 'Duplicate'),
                chip('action', 'invalid', 'Invalid'),
                chip('action', 'corrected', 'Corrected'),
                chip('action', 'removed', 'Removed')
              ]))
        ]));
  }

  Widget activity() {
    final f = Map<String, dynamic>.from(data!['filtered'] ?? {});
    final list = <Map<String, dynamic>>[];
    list.addAll(List<Map<String, dynamic>>.from(f['records'] ?? [])
        .map((e) => {...e, 'kind': 'attendance', 'when': e['markedAt']}));
    list.addAll(List<Map<String, dynamic>>.from(f['attempts'] ?? [])
        .map((e) => {...e, 'kind': 'scan', 'when': e['createdAt']}));
    list.addAll(List<Map<String, dynamic>>.from(f['audits'] ?? [])
        .map((e) => {...e, 'kind': 'audit', 'when': e['createdAt']}));
    list.sort((a, b) =>
        (b['when']?.toString() ?? '').compareTo(a['when']?.toString() ?? ''));
    return Column(children: [
      filters(),
      Expanded(
          child: list.isEmpty
              ? const Center(child: Text('No activity for selected filters.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 2, 14, 80),
                  itemCount: list.length,
                  itemExtent: list.length > 7 ? 76 : null,
                  itemBuilder: (_, i) => activityCard(list[i])))
    ]);
  }

  Widget activityCard(Map<String, dynamic> a) {
    final kind = a['kind'];
    final title = kind == 'attendance'
        ? 'Attendance marked'
        : kind == 'scan'
            ? '${a['result']} scan'
            : '${a['action']}';
    final detail = kind == 'attendance'
        ? '${a['name'] ?? ''} • ${a['registrationId'] ?? ''} • ${a['source'] ?? ''}'
        : kind == 'scan'
            ? '${a['registrationId'] ?? ''} • ${a['detail'] ?? ''}'
            : '${a['registrationId'] ?? ''} • ${a['reason'] ?? ''}';
    final at = DateTime.tryParse(a['when']?.toString() ?? '');
    return Card(
        margin: const EdgeInsets.only(bottom: 6),
        child: ListTile(
            dense: true,
            leading: Icon(
                kind == 'attendance'
                    ? Icons.check_circle_rounded
                    : kind == 'scan'
                        ? Icons.qr_code_scanner_rounded
                        : Icons.history_rounded,
                color: kind == 'audit' ? Colors.orange : AppColors.green),
            title: Text(title.toString().toUpperCase(),
                style:
                    const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
            subtitle:
                Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: Text(
                at == null
                    ? ''
                    : DateFormat('d MMM\nh:mm a').format(at.toLocal()),
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 8))));
  }

  Widget profile() {
    final user = Map<String, dynamic>.from(data!['user']);
    const imageKeys = ['hodImage', 'reportingToImage', 'signatureImage'];
    final fields = user.entries
        .where((e) =>
            ![
              '_id',
              'password',
              'profileImage',
              'createdBy',
              '__v',
              ...imageKeys
            ].contains(e.key) &&
            e.value.toString().isNotEmpty)
        .toList();
    final images = imageKeys
        .where((key) => user[key]?.toString().isNotEmpty == true)
        .toList();
    return ListView(padding: const EdgeInsets.only(bottom: 80), children: [
      header(),
      _deviceHealthSection(),
      const Padding(
        padding: EdgeInsets.fromLTRB(14, 0, 14, 7),
        child: Text('EMPLOYEE INFORMATION',
            style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.2,
                color: Colors.black45,
                fontWeight: FontWeight.w900)),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: GridView.builder(
          shrinkWrap: true,
          primary: false,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 0,
              crossAxisSpacing: 14,
              mainAxisExtent: 46),
          itemCount: fields.length,
          itemBuilder: (_, index) =>
              _profileField(fields[index].key, fields[index].value),
        ),
      ),
      if (images.isNotEmpty)
        const Padding(
          padding: EdgeInsets.fromLTRB(14, 14, 14, 7),
          child: Text('IMAGES & SIGNATURE',
              style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  color: Colors.black45,
                  fontWeight: FontWeight.w900)),
        ),
      if (images.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: GridView.builder(
            shrinkWrap: true,
            primary: false,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 7,
                crossAxisSpacing: 7,
                childAspectRatio: .95),
            itemCount: images.length,
            itemBuilder: (_, index) =>
                _profileImage(label(images[index]), user[images[index]]),
          ),
        ),
    ]);
  }

  Widget _deviceHealthSection() {
    final raw = data!['deviceHealth'];
    final health = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final reportedAt =
        DateTime.tryParse(health['lastReportedAt']?.toString() ?? '');
    final lastScan =
        DateTime.tryParse(health['lastSuccessfulScan']?.toString() ?? '');
    final hasReport = health.isNotEmpty;
    final deviceName =
        '${health['manufacturer'] ?? ''} ${health['model'] ?? ''}'.trim();
    final online = health['apiStatus'] == 'online' &&
        health['databaseStatus'] == 'online';

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F8F6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.green.withValues(alpha: .18)),
        ),
        child: hasReport
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: (online ? AppColors.emerald : Colors.orange)
                          .withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                        online
                            ? Icons.health_and_safety_rounded
                            : Icons.warning_amber_rounded,
                        color: online ? AppColors.emerald : Colors.orange,
                        size: 19),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('DEVICE HEALTH',
                              style: TextStyle(
                                  fontSize: 9,
                                  letterSpacing: 1,
                                  fontWeight: FontWeight.w900)),
                          Text(
                              reportedAt == null
                                  ? 'Last report unavailable'
                                  : 'Reported ${DateFormat('d MMM, h:mm a').format(reportedAt.toLocal())}',
                              style: const TextStyle(
                                  fontSize: 8, color: Colors.black45)),
                        ]),
                  ),
                  Text(online ? 'Healthy' : 'Attention',
                      style: TextStyle(
                          color: online ? AppColors.emerald : Colors.orange,
                          fontSize: 9,
                          fontWeight: FontWeight.w900)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: _healthValue('Device',
                          deviceName.isEmpty ? 'Unknown device' : deviceName)),
                  Expanded(
                      child: _healthValue('Android',
                          '${health['androidVersion'] ?? '-'} (SDK ${health['sdkInt'] ?? '-'})')),
                ]),
                const SizedBox(height: 7),
                Row(children: [
                  Expanded(
                      child: _healthValue(
                          'Camera',
                          health['cameraAvailable'] == true &&
                                  health['cameraPermissionGranted'] == true
                              ? 'Ready'
                              : 'Check required')),
                  Expanded(
                      child: _healthValue('API latency',
                          '${health['roundTripMs'] ?? '-'} ms')),
                ]),
                const SizedBox(height: 7),
                _healthValue(
                    'Last successful scan',
                    lastScan == null
                        ? 'No scan reported'
                        : DateFormat('d MMM yyyy, h:mm:ss a')
                            .format(lastScan.toLocal())),
              ])
            : const Row(children: [
                Icon(Icons.phonelink_erase_rounded,
                    color: Colors.black38, size: 22),
                SizedBox(width: 9),
                Expanded(
                    child: Text(
                        'DEVICE HEALTH\nNo device report yet. It will appear when this employee opens the attendance app.',
                        style: TextStyle(
                            fontSize: 8.5,
                            height: 1.35,
                            color: Colors.black54,
                            fontWeight: FontWeight.w700))),
              ]),
      ),
    );
  }

  Widget _healthValue(String title, String value) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                fontSize: 7,
                color: Colors.black45,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 1),
        Text(value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
      ]);

  Widget _profileField(String key, dynamic raw) {
    final value = _profileValue(key, raw);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label(key),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 7.5,
                color: Colors.black45,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  String _profileValue(String key, dynamic raw) {
    if (raw is List) {
      return raw.join(' • ');
    }
    if (raw is Map) {
      return raw.values.where((value) => '$value'.isNotEmpty).join(' • ');
    }
    final date = (key.toLowerCase().contains('date') ||
            key.toLowerCase().endsWith('at') ||
            key == 'lastLogin')
        ? DateTime.tryParse(raw.toString())
        : null;
    if (date != null) {
      return DateFormat('d MMM yyyy, h:mm a').format(date.toLocal());
    }
    if (['role', 'status', 'department', 'designation', 'title']
        .contains(key)) {
      return sentenceCase(raw);
    }
    return raw.toString();
  }

  Widget _profileImage(String title, dynamic raw) {
    final image = resolveApiAssetUrl(raw);
    return Card(
        margin: EdgeInsets.zero,
        child: Padding(
            padding: const EdgeInsets.all(10),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 9,
                      color: Colors.black45,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 7),
              Container(
                  height: 105,
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF7F9F8),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.black12)),
                  child: Image.network(image,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                Icon(Icons.broken_image_outlined,
                                    color: Colors.black26),
                                SizedBox(height: 5),
                                Text('Image could not be loaded',
                                    style: TextStyle(
                                        fontSize: 9, color: Colors.black38))
                              ]))))
            ])));
  }

  Widget metric(String l, dynamic v, IconData i) => Card(
      child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(i, size: 17, color: AppColors.green),
            const SizedBox(height: 3),
            Text('${v ?? 0}',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            Text(l,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 7,
                    color: Colors.black54,
                    fontWeight: FontWeight.w800))
          ])));
  Widget tiny(String l, dynamic v) => Column(children: [
        Text('${v ?? 0}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
        Text(l, style: const TextStyle(fontSize: 7, color: Colors.black45))
      ]);
  Widget chip(String group, String value, String text) {
    final selected = group == 'day'
        ? day == value
        : group == 'source'
            ? source == value
            : action == value;
    return Padding(
        padding: const EdgeInsets.only(right: 5),
        child: ChoiceChip(
            label: Text(text),
            selected: selected,
            onSelected: (_) {
              setState(() {
                if (group == 'day') {
                  day = value;
                } else if (group == 'source') {
                  source = value;
                  action = '';
                } else {
                  action = value;
                  source = '';
                }
                data = null;
              });
              load();
            }));
  }

  String label(String v) => v
      .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m[1]}')
      .replaceAll('_', ' ')
      .trim()
      .toUpperCase();
}
