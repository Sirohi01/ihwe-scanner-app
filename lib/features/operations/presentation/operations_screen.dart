import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../core/storage/session_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/presentation/ai_summary_dialog.dart';
import 'employee_operations_screen.dart';

class OperationsScreen extends StatefulWidget {
  const OperationsScreen(
      {super.key, required this.repository, required this.session});
  final AttendanceRepository repository;
  final SessionStore session;
  @override
  State<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends State<OperationsScreen> {
  Map<String, dynamic>? alerts, insights, operations;
  Object? error;
  bool exporting = false;
  bool get superAdmin {
    final role = widget.session.role
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return role.contains('super-admin') || role.contains('super-administrator');
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final values = await Future.wait([
        widget.repository.notifications(),
        widget.repository.insights(),
        if (superAdmin) widget.repository.superAdminOperations()
      ]);
      if (mounted) {
        setState(() {
          alerts = values[0];
          insights = values[1];
          if (superAdmin) operations = values[2];
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
      length: superAdmin ? 4 : 3,
      child: Scaffold(
          appBar: AppBar(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              elevation: 0,
              flexibleSpace: const DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [AppColors.navy, AppColors.green]))),
              titleSpacing: 2,
              title: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('OPERATIONS',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w900)),
                    Text('Command Centre',
                        style: TextStyle(fontSize: 9, color: Colors.white60))
                  ]),
              actions: [
                IconButton(
                    onPressed: () => showAiSummaryDialog(context,
                        repository: widget.repository, scope: 'exhibition'),
                    icon: const Icon(Icons.auto_awesome_rounded,
                        color: AppColors.gold))
              ],
              bottom: TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  padding: const EdgeInsets.only(left: 8),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                  labelColor: AppColors.gold,
                  unselectedLabelColor: Colors.white60,
                  indicatorColor: AppColors.gold,
                  indicatorWeight: 3,
                  tabs: [
                    const Tab(text: 'ALERTS'),
                    const Tab(text: 'INSIGHTS'),
                    const Tab(text: 'REPORTS'),
                    if (superAdmin) const Tab(text: 'EMPLOYEES')
                  ])),
          body: alerts == null
              ? Center(
                  child: error == null
                      ? const AppProfileSkeleton()
                      : FilledButton(
                          onPressed: load, child: Text('Retry: $error')))
              : TabBarView(children: [
                  _alerts(),
                  _insights(),
                  _reports(),
                  if (superAdmin) _employees()
                ])));
  Widget _alerts() {
    final target = Map<String, dynamic>.from(alerts!['dailyTarget'] ?? {}),
        traffic = Map<String, dynamic>.from(alerts!['traffic'] ?? {}),
        special = List.from(alerts!['specialArrivals'] ?? []),
        suspicious = List.from(alerts!['suspicious'] ?? []);
    return RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.all(14), children: [
          _title('DAILY TARGET'),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              '${target['achieved'] ?? 0}/${target['target'] ?? 0}',
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w900)),
                          Text('${target['percent'] ?? 0}%',
                              style: const TextStyle(
                                  color: AppColors.green,
                                  fontWeight: FontWeight.w900))
                        ]),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                        value:
                            (numberValue(target['percent']) / 100).clamp(0, 1))
                  ]))),
          const SizedBox(height: 14),
          _title('LIVE TRAFFIC'),
          _notice(
              alerts!['highTraffic'] == true
                  ? 'High entry traffic detected'
                  : 'Traffic is normal',
              'Last 15 min: ${traffic['recent15Minutes'] ?? 0} • Previous: ${traffic['previous15Minutes'] ?? 0}',
              alerts!['highTraffic'] == true
                  ? Colors.orange
                  : AppColors.emerald),
          const SizedBox(height: 14),
          _title('SPECIAL ARRIVALS'),
          ...special.map(_arrival),
          if (special.isEmpty) const Text('No special arrival yet.'),
          const SizedBox(height: 14),
          _title('SUSPICIOUS REPEATED SCANS'),
          ...suspicious.map((e) => _notice(e['_id'] ?? 'Unknown QR',
              '${e['count']} duplicate attempts', Colors.red)),
          if (suspicious.isEmpty) const Text('No suspicious repeated scans.')
        ]));
  }

  double numberValue(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
  Widget _insights() {
    final countries = List.from(insights!['countries'] ?? []),
        types = List.from(insights!['buyerTypes'] ?? []),
        matches = List.from(insights!['visitorTypes'] ?? []),
        exhibitors = Map<String, dynamic>.from(insights!['exhibitors'] ?? {});
    return ListView(padding: const EdgeInsets.all(14), children: [
      _title('BUYER MIX'),
      Row(
          children: types
              .map((e) => Expanded(
                  child: Card(
                      child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(children: [
                            Text('${e['count']}',
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.w900)),
                            Text('${e['label']}',
                                style: const TextStyle(fontSize: 10))
                          ])))))
              .toList()),
      const SizedBox(height: 14),
      _title('TOP COUNTRIES'),
      ...countries.take(8).map((e) => ListTile(
          dense: true,
          title: Text(e['label']),
          trailing: Text('${e['count']}',
              style: const TextStyle(fontWeight: FontWeight.w900)))),
      const SizedBox(height: 12),
      _title('VISITOR INSIGHTS'),
      ...matches.map((e) => ListTile(
          dense: true,
          leading: const Icon(Icons.groups_rounded, color: AppColors.green),
          title:
              Text((e['label'] ?? 'Visitor').toString().replaceAll('-', ' ')),
          trailing: Text('${e['count'] ?? 0}',
              style: const TextStyle(fontWeight: FontWeight.w900)))),
      const SizedBox(height: 12),
      _title('EXHIBITOR INSIGHTS'),
      Row(children: [
        Expanded(
            child: _insightCard('Companies present',
                exhibitors['presentCompanies'], Icons.storefront_rounded)),
        const SizedBox(width: 7),
        Expanded(
            child: _insightCard('Team check-ins', exhibitors['teamCheckIns'],
                Icons.badge_rounded)),
        const SizedBox(width: 7),
        Expanded(
            child: _insightCard(
                'Products', exhibitors['products'], Icons.inventory_2_rounded))
      ]),
      const SizedBox(height: 8),
      ...List.from(exhibitors['topCompanies'] ?? []).map((e) => ListTile(
          dense: true,
          title: Text(e['label'] ?? 'Company',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('${e['members'] ?? 0} members'),
          trailing: Text('${e['checkIns'] ?? 0}',
              style: const TextStyle(fontWeight: FontWeight.w900))))
    ]);
  }

  Widget _reports() => ListView(padding: const EdgeInsets.all(14), children: [
        _title('EXPORT CENTRE'),
        const Text(
            'Overall, day-wise, category-wise and company-wise coloured Excel reports. PDF includes generated date/time and active filters.'),
        const SizedBox(height: 14),
        _exportButton('Overall Excel', Icons.table_view_rounded,
            () => widget.repository.exportAttendance()),
        _exportButton('Visitor Excel', Icons.groups_rounded,
            () => widget.repository.exportAttendance(type: 'visitor')),
        _exportButton('Buyer Excel', Icons.handshake_rounded,
            () => widget.repository.exportAttendance(type: 'buyer')),
        _exportButton('Company-wise Excel', Icons.storefront_rounded,
            () => widget.repository.exportAttendance(type: 'exhibitor')),
        _exportButton('Exhibition PDF Summary', Icons.picture_as_pdf_rounded,
            () => widget.repository.exportPdf())
      ]);
  Widget _employees() {
    final users = List.from(operations?['employees'] ?? []);
    return ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: users.length,
        itemExtent: users.length > 7 ? 84 : null,
        itemBuilder: (_, i) {
          final u = users[i], s = Map<String, dynamic>.from(u['stats'] ?? {});
          final photo = resolveApiAssetUrl(u['profileImage']);
          return Card(
              margin: const EdgeInsets.only(bottom: 7),
              child: ListTile(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => EmployeeOperationsScreen(
                              userId: u['_id'].toString(),
                              repository: widget.repository))),
                  leading: CircleAvatar(
                      backgroundColor: AppColors.green.withValues(alpha: .1),
                      backgroundImage:
                          photo.isNotEmpty ? NetworkImage(photo) : null,
                      child: photo.isEmpty
                          ? const Icon(Icons.person_rounded,
                              color: AppColors.green)
                          : null),
                  title: Text(
                      u['fullName']?.toString().isNotEmpty == true
                          ? u['fullName']
                          : u['username'],
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text(
                    'Marked ${s['total'] ?? 0} • QR ${s['qr'] ?? 0} • Manual ${s['manual'] ?? 0}\nScans ${s['scans'] ?? 0} • Duplicate ${s['duplicates'] ?? 0} • Corrections ${s['corrections'] ?? 0}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9.5, height: 1.25),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded)));
        });
  }

  Widget _exportButton(
          String label, IconData icon, Future<String> Function() action) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: FilledButton.icon(
              onPressed: exporting
                  ? null
                  : () async {
                      setState(() => exporting = true);
                      try {
                        final path = await action();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Saved: $path')));
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Export failed: $e')));
                        }
                      } finally {
                        if (mounted) setState(() => exporting = false);
                      }
                    },
              icon: Icon(icon),
              label: Text(label)));
  Widget _title(String value) => Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(value,
          style: const TextStyle(
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w900,
              color: Colors.black45)));
  Widget _notice(String title, String subtitle, Color color) => Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
          dense: true,
          leading: Icon(Icons.circle, size: 12, color: color),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: subtitle.isEmpty ? null : Text(subtitle)));
  Widget _arrival(dynamic raw) {
    final item = Map<String, dynamic>.from(raw),
        photo = resolveApiAssetUrl(item['photoUrl']);
    return Card(
        margin: const EdgeInsets.only(bottom: 6),
        child: ListTile(
            leading: CircleAvatar(
                backgroundColor: AppColors.gold.withValues(alpha: .2),
                backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                child: photo.isEmpty
                    ? const Icon(Icons.workspace_premium_rounded,
                        color: AppColors.green)
                    : null),
            title: Text(item['name'] ?? 'Special arrival',
                style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text(
                '${item['company'] ?? ''} • ${(item['subjectSubType'] ?? 'VIP').toString().replaceAll('-', ' ')}'),
            trailing: const Icon(Icons.star_rounded, color: AppColors.gold)));
  }

  Widget _insightCard(String label, dynamic value, IconData icon) => Card(
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
          child: Column(children: [
            Icon(icon, size: 18, color: AppColors.green),
            const SizedBox(height: 4),
            Text('${value ?? 0}',
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 8,
                    color: Colors.black54,
                    fontWeight: FontWeight.w700))
          ])));
}
