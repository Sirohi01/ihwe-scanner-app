import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/config/app_config.dart';
import '../../../core/storage/session_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/domain/attendance_categories.dart';
import '../../attendance/presentation/attendance_profile_screen.dart';
import '../../attendance/presentation/ai_summary_dialog.dart';
import '../../operations/presentation/device_health_screen.dart';
import '../../communications/presentation/communication_inbox_screen.dart';
import 'company_detail_screen.dart';
import 'directory_screen.dart';
import '../../operations/presentation/operations_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen(
      {super.key,
      required this.repository,
      required this.session,
      required this.onScan});
  final AttendanceRepository repository;
  final SessionStore session;
  final VoidCallback onScan;
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? data;
  String? selectedDay;
  String selectedType = '';
  String selectedSubType = '';
  Object? error;
  bool exportingCompanies = false;

  @override
  void initState() {
    super.initState();
    load();
    widget.repository.syncDeviceHealth();
  }

  Future<void> load() async {
    try {
      final value = await widget.repository.dashboard(
          day: selectedDay, type: selectedType, subType: selectedSubType);
      if (mounted) {
        setState(() {
          data = value;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slivers = <Widget>[SliverToBoxAdapter(child: _hero())];
    if (data == null && error == null) {
      slivers.add(const SliverToBoxAdapter(child: DashboardSkeleton()));
    } else if (error != null) {
      slivers.add(SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.cloud_off_rounded, size: 48),
              const SizedBox(height: 12),
              Text('$error', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: load, child: const Text('TRY AGAIN')),
            ]),
          ),
        ),
      ));
    } else {
      slivers.addAll(_content());
    }
    return Scaffold(
        body: RefreshIndicator(
            onRefresh: load, child: CustomScrollView(slivers: slivers)));
  }

  Widget _hero() => Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.navy, AppColors.green]),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
        padding: EdgeInsets.fromLTRB(
            18, MediaQuery.paddingOf(context).top + 10, 18, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.gold, width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 3))
                    ]),
                clipBehavior: Clip.antiAlias,
                child: widget.session.profileImage.isNotEmpty
                    ? Transform.scale(
                        scale: 1.16,
                        child: Image.network(_adminPhotoUrl,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _adminInitials()),
                      )
                    : _adminInitials()),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('IHWE ACCESS',
                      style: TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.7,
                          fontSize: 9)),
                  Text('Welcome, ${widget.session.username}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15))
                ])),
            IconButton.filled(
                onPressed: widget.session.clear,
                tooltip: 'Logout',
                style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFD94141),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(34, 34),
                    maximumSize: const Size(34, 34),
                    padding: EdgeInsets.zero),
                icon: const Icon(Icons.logout_rounded, size: 18)),
          ]),
          const SizedBox(height: 11),
          Text(
              data?['event']?['name'] ?? 'International Health & Wellness Expo',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: .65), fontSize: 11)),
          if (data?['event']?['location']?.toString().isNotEmpty == true) ...[
            const SizedBox(height: 5),
            Row(children: [
              const Icon(Icons.location_on_outlined,
                  color: AppColors.gold, size: 13),
              const SizedBox(width: 4),
              Expanded(
                child: Text(data!['event']['location'],
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          ],
          const SizedBox(height: 11),
          Row(children: [
            FilledButton.icon(
                onPressed: widget.onScan,
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.navy,
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w900)),
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 17),
                label: const Text('SCAN QR')),
            const SizedBox(width: 8),
            IconButton.outlined(
              tooltip: 'AI summary',
              onPressed: () => showAiSummaryDialog(context,
                  repository: widget.repository, scope: 'exhibition'),
              style: IconButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white38),
                minimumSize: const Size(38, 38),
                maximumSize: const Size(38, 38),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.zero,
              ),
              icon: const Icon(Icons.auto_awesome_rounded,
                  color: AppColors.gold, size: 16),
            ),
            const SizedBox(width: 6),
            IconButton.outlined(
              tooltip: 'Messages',
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => CommunicationInboxScreen(
                          repository: widget.repository,
                          session: widget.session))),
              style: IconButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38),
                  minimumSize: const Size(38, 38),
                  maximumSize: const Size(38, 38),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero),
              icon: const Icon(Icons.forum_outlined, size: 18),
            ),
            const SizedBox(width: 6),
            IconButton.outlined(
              tooltip: 'Device health',
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          DeviceHealthScreen(repository: widget.repository))),
              style: IconButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38),
                  minimumSize: const Size(38, 38),
                  maximumSize: const Size(38, 38),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero),
              icon: const Icon(Icons.monitor_heart_rounded, size: 18),
            ),
            if (_isSuperAdministrator) ...[
              const SizedBox(width: 6),
              IconButton.outlined(
                tooltip: 'Operations centre',
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => OperationsScreen(
                            repository: widget.repository,
                            session: widget.session))),
                style: IconButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    side: const BorderSide(color: Colors.white38),
                    minimumSize: const Size(38, 38),
                    maximumSize: const Size(38, 38),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero),
                icon: const Icon(Icons.analytics_rounded, size: 18),
              ),
            ],
          ]),
        ]),
      );

  bool get _isSuperAdministrator =>
      widget.session.role
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-|-$'), '') ==
      'ihwe-super-administrator';

  Widget _adminInitials() {
    final parts = widget.session.username
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    final initials = parts.isEmpty
        ? 'A'
        : parts.take(2).map((part) => part[0].toUpperCase()).join();
    return Container(
      color: AppColors.gold.withValues(alpha: .2),
      alignment: Alignment.center,
      child: Text(initials,
          style: const TextStyle(
              color: AppColors.navy,
              fontSize: 14,
              fontWeight: FontWeight.w900)),
    );
  }

  String get _adminPhotoUrl {
    final path = widget.session.profileImage.trim();
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final api = Uri.parse(AppConfig.apiBaseUrl);
    return '${api.origin}/${path.replaceFirst(RegExp(r'^/+'), '')}';
  }

  List<Widget> _content() {
    final registered = Map<String, dynamic>.from(data!['registered']);
    final attended = Map<String, dynamic>.from(data!['attended']);
    final overallAttended = Map<String, dynamic>.from(
        data!['overallAttended'] ?? data!['attended']);
    final days = List<String>.from(data!['days']);
    final recent = List<Map<String, dynamic>>.from(data!['recent']);
    final companies = List<Map<String, dynamic>>.from(data!['companies'] ?? []);
    final registeredBySubType =
        Map<String, dynamic>.from(registered['bySubType'] ?? {});
    final attendedBySubType =
        Map<String, dynamic>.from(attended['bySubType'] ?? {});
    return [
      SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 0),
          sliver: SliverToBoxAdapter(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('EVENT DAYS',
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w900,
                        color: Colors.black45)),
                const SizedBox(height: 6),
                SizedBox(
                    height: 36,
                    child:
                        ListView(scrollDirection: Axis.horizontal, children: [
                      _dayChip(null, 'All days'),
                      ...days.map((day) => _dayChip(
                          day,
                          DateFormat('EEE, d MMM')
                              .format(DateTime.parse(day)))),
                    ])),
                const SizedBox(height: 9),
                const Text('REGISTRATION TYPE',
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w900,
                        color: Colors.black45)),
                const SizedBox(height: 6),
                SizedBox(
                    height: 34,
                    child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: attendanceTypes
                            .map((item) => _typeChip(item.value, item.label))
                            .toList())),
                if (selectedType.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  SizedBox(
                      height: 32,
                      child:
                          ListView(scrollDirection: Axis.horizontal, children: [
                        _subTypeChip(
                            '', 'All ${attendanceLabel(selectedType)}'),
                        ...subTypesFor(selectedType).map(
                            (item) => _subTypeChip(item.value, item.label)),
                      ])),
                ],
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: _metric('Present', '${attended['total']}',
                          Icons.how_to_reg_rounded, AppColors.emerald)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _metric('Not arrived', '${data!['notAttended']}',
                          Icons.person_off_outlined, const Color(0xFFE06A4E))),
                ]),
                const SizedBox(height: 8),
                _progress(attended['total'] ?? 0,
                    data!['scopeRegistered'] ?? registered['total'] ?? 0),
                const SizedBox(height: 11),
                const Text('ATTENDANCE BY CATEGORY',
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w900,
                        color: Colors.black45)),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                      child: _category(
                          'Visitors',
                          overallAttended['visitor'],
                          registered['visitor'],
                          Icons.groups_2_rounded,
                          const Color(0xFF176B87))),
                  const SizedBox(width: 7),
                  Expanded(
                      child: _category(
                          'Buyers',
                          overallAttended['buyer'],
                          registered['buyer'],
                          Icons.handshake_rounded,
                          const Color(0xFF7A4EB2))),
                  const SizedBox(width: 7),
                  Expanded(
                      child: _category(
                          'Exhibitors',
                          overallAttended['exhibitor'],
                          registered['exhibitor'],
                          Icons.storefront_rounded,
                          AppColors.green)),
                ]),
                const SizedBox(height: 10),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('REGISTRATION DIRECTORIES',
                          style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.4,
                              fontWeight: FontWeight.w900,
                              color: Colors.black45)),
                      Text('Present & total lists',
                          style: TextStyle(
                              fontSize: 9,
                              color: Colors.black.withValues(alpha: .4),
                              fontWeight: FontWeight.w700)),
                    ]),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                      child: _directoryButton('visitor', 'Visitors',
                          Icons.groups_2_rounded, const Color(0xFF176B87))),
                  const SizedBox(width: 7),
                  Expanded(
                      child: _directoryButton('buyer', 'Buyers',
                          Icons.handshake_rounded, const Color(0xFF7A4EB2))),
                  const SizedBox(width: 7),
                  Expanded(
                      child: _directoryButton('exhibitor', 'Exhibitors',
                          Icons.storefront_rounded, AppColors.green)),
                ]),
                const SizedBox(height: 10),
                const Text('DETAILED BREAKDOWN',
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w900,
                        color: Colors.black45)),
                const SizedBox(height: 5),
                GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    primary: false,
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 5,
                    crossAxisSpacing: 7,
                    childAspectRatio: 3.35,
                    children: attendanceSubTypes
                        .where((item) =>
                            selectedType.isEmpty || item.parent == selectedType)
                        .map((item) => _subTypeStat(
                            item.label,
                            attendedBySubType[item.value] ?? 0,
                            registeredBySubType[item.value] ?? 0,
                            item.parent))
                        .toList()),
                if (selectedType.isEmpty || selectedType == 'exhibitor') ...[
                  const SizedBox(height: 9),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('COMPANY-WISE ATTENDANCE',
                            style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w900,
                                color: Colors.black45)),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('${companies.length} present',
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.black38)),
                          const SizedBox(width: 5),
                          SizedBox(
                            width: 30,
                            height: 30,
                            child: IconButton.outlined(
                              tooltip: 'Download company-wise Excel',
                              onPressed:
                                  exportingCompanies ? null : _exportCompanies,
                              icon: exportingCompanies
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.file_download_outlined,
                                      size: 15),
                              style: IconButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(30, 30),
                                maximumSize: const Size(30, 30),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),
                        ])
                      ]),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 90,
                    child: companies.isEmpty
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: const Row(children: [
                              Icon(Icons.storefront_outlined,
                                  color: Colors.black38, size: 22),
                              SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  'No exhibitor company attendance yet. Scan a Stall Information or Exhibitor Pass QR.',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.black45,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ]),
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: companies.length,
                            itemBuilder: (_, i) => _companyStat(companies[i]),
                          ),
                  ),
                ],
                const SizedBox(height: 9),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('RECENT CHECK-INS',
                          style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.4,
                              fontWeight: FontWeight.w900,
                              color: Colors.black45)),
                      Text('${recent.length} Latest',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black38))
                    ]),
              ]))),
      SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 105),
          sliver: recent.length <= 7
              ? SliverList(
                  delegate: SliverChildListDelegate(
                      recent.map(_recent).toList(growable: false)))
              : SliverFixedExtentList.builder(
                  itemExtent: 63,
                  itemCount: recent.length,
                  itemBuilder: (_, i) => _recent(recent[i]))),
    ];
  }

  Widget _directoryButton(
          String type, String label, IconData icon, Color color) =>
      Material(
          color: color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => DirectoryScreen(
                          type: type, repository: widget.repository))),
              child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
                  child: Column(children: [
                    Icon(icon, size: 20, color: color),
                    const SizedBox(height: 4),
                    Text(label,
                        maxLines: 1,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: color)),
                    const Text('OPEN LIST',
                        style: TextStyle(
                            fontSize: 7,
                            fontWeight: FontWeight.w800,
                            color: Colors.black38))
                  ]))));

  Future<void> _exportCompanies() async {
    setState(() => exportingCompanies = true);
    try {
      final path = await widget.repository
          .exportAttendance(day: selectedDay, type: 'exhibitor');
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded,
              color: AppColors.emerald, size: 38),
          title: const Text('Company Excel ready'),
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $error')));
      }
    } finally {
      if (mounted) setState(() => exportingCompanies = false);
    }
  }

  Widget _dayChip(String? day, String label) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
          showCheckmark: true,
          checkmarkColor: Colors.white,
          visualDensity: const VisualDensity(horizontal: -1, vertical: -2),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          label: Text(label),
          selected: selectedDay == day,
          onSelected: (_) {
            setState(() {
              selectedDay = day;
              data = null;
            });
            load();
          },
          selectedColor: AppColors.green,
          labelStyle: TextStyle(
              color: selectedDay == day ? Colors.white : AppColors.ink,
              fontSize: 10,
              fontWeight: FontWeight.w700)));

  Widget _typeChip(String value, String label) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
          showCheckmark: true,
          checkmarkColor: Colors.white,
          visualDensity: const VisualDensity(horizontal: -1, vertical: -2),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          label: Text(label),
          selected: selectedType == value,
          onSelected: (_) {
            setState(() {
              selectedType = value;
              selectedSubType = '';
              data = null;
            });
            load();
          },
          selectedColor: AppColors.navy,
          labelStyle: TextStyle(
              color: selectedType == value ? Colors.white : AppColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 11)));

  Widget _subTypeChip(String value, String label) => Padding(
      padding: const EdgeInsets.only(right: 7),
      child: ChoiceChip(
          showCheckmark: true,
          checkmarkColor: Colors.white,
          visualDensity: const VisualDensity(horizontal: -1, vertical: -2),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          label: Text(label),
          selected: selectedSubType == value,
          onSelected: (_) {
            setState(() {
              selectedSubType = value;
              data = null;
            });
            load();
          },
          selectedColor: AppColors.green,
          labelStyle: TextStyle(
              color: selectedSubType == value ? Colors.white : AppColors.ink,
              fontWeight: FontWeight.w700,
              fontSize: 10)));

  Widget _subTypeStat(
          String label, dynamic attended, dynamic registered, String parent) =>
      Card(
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              child: Row(children: [
                Container(
                    width: 8,
                    height: 22,
                    decoration: BoxDecoration(
                        color: parent == 'visitor'
                            ? const Color(0xFF176B87)
                            : parent == 'buyer'
                                ? const Color(0xFF7A4EB2)
                                : AppColors.green,
                        borderRadius: BorderRadius.circular(8))),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 9.5, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('$attended/$registered',
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w900)),
                )
              ])));

  Widget _metric(String label, String value, IconData icon, Color color) =>
      Card(
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
              child: Row(children: [
                Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon, color: color, size: 19)),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(value,
                      style: const TextStyle(
                          fontSize: 21, fontWeight: FontWeight.w900)),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 9,
                          color: Colors.black45,
                          fontWeight: FontWeight.w700))
                ])
              ])));

  Widget _companyStat(Map<String, dynamic> item) => GestureDetector(
      onTap: () {
        final companyId = item['companyId']?.toString() ?? '';
        if (companyId.length != 24 || companyId == 'null') return;
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => CompanyDetailScreen(
                companyId: companyId, repository: widget.repository)));
      },
      child: Container(
          width: 190,
          margin: const EdgeInsets.only(right: 7),
          child: Card(
              child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['company']?.toString() ?? 'Company',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w900)),
                        const Spacer(),
                        Row(children: [
                          Icon(
                              item['companyAttendance'] == 1
                                  ? Icons.verified_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 14,
                              color: item['companyAttendance'] == 1
                                  ? AppColors.emerald
                                  : Colors.black26),
                          const SizedBox(width: 4),
                          Text('${item['passPeople'] ?? 0} pass arrivals',
                              style: const TextStyle(
                                  fontSize: 9, fontWeight: FontWeight.w700)),
                        ]),
                        const SizedBox(height: 3),
                        const Row(children: [
                          Text('VIEW PROFILE',
                              style: TextStyle(
                                  color: AppColors.green,
                                  fontSize: 8,
                                  letterSpacing: .7,
                                  fontWeight: FontWeight.w900)),
                          SizedBox(width: 2),
                          Icon(Icons.arrow_forward_rounded,
                              color: AppColors.green, size: 12),
                        ])
                      ])))));
  Widget _progress(num present, num total) {
    final ratio = total == 0 ? 0.0 : (present / total).clamp(0, 1).toDouble();
    return Card(
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Overall arrival rate',
                    style:
                        TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                Text('${(ratio * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AppColors.green))
              ]),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                  value: ratio,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(10),
                  backgroundColor: const Color(0xFFE8EFEB),
                  color: AppColors.emerald)
            ])));
  }

  Widget _category(String label, dynamic count, dynamic total, IconData icon,
          Color color) =>
      Card(
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
              child: Column(children: [
                Icon(icon, color: color, size: 19),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('${count ?? 0}/${total ?? 0}',
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.ink,
                          fontWeight: FontWeight.w900)),
                ),
                const SizedBox(height: 3),
                Text(label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w800))
              ])));
  Widget _recent(Map<String, dynamic> item) {
    final subjectType = item['subjectType']?.toString() ?? '';
    final company = item['company']?.toString() ?? '';
    final isPass = item['attendanceKind'] == 'pass';
    final isCompanyEntry = subjectType == 'exhibitor' && !isPass;
    final rawName = item['name']?.toString() ?? '';
    final baseName = isCompanyEntry && company.isNotEmpty
        ? company
        : (rawName.isNotEmpty
            ? rawName
            : item['registrationId']?.toString() ?? '-');
    final displayName =
        isPass && company.isNotEmpty ? '$baseName — $company' : baseName;
    final photoUrl = resolveApiAssetUrl(item['photoUrl']);
    return Card(
        margin: const EdgeInsets.only(bottom: 7),
        child: ListTile(
            onTap: () {
              final attendanceId = item['_id']?.toString() ?? '';
              final companyId = item['companyId']?.toString() ?? '';
              if (isCompanyEntry && companyId.length == 24) {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CompanyDetailScreen(
                        companyId: companyId, repository: widget.repository)));
              } else if (attendanceId.length == 24) {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AttendanceProfileScreen(
                        attendanceId: attendanceId,
                        repository: widget.repository)));
              }
            },
            dense: true,
            visualDensity: const VisualDensity(vertical: -2),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 11, vertical: 1),
            leading: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.green.withValues(alpha: .1),
                foregroundColor: AppColors.green,
                backgroundImage:
                    photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                child: photoUrl.isEmpty
                    ? Text((displayName.isNotEmpty ? displayName[0] : '?')
                        .toUpperCase())
                    : null),
            title: Text(displayName,
                maxLines: 1,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            subtitle: Text(
                '${sentenceCase(item['subjectType'])} • ${item['registrationId']}',
                maxLines: 1),
            trailing:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.emerald, size: 16),
              Text(item['eventDay'] ?? '', style: const TextStyle(fontSize: 8))
            ])));
  }
}
