import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../core/storage/session_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/domain/attendance_categories.dart';
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
  Map<String, dynamic>? alerts, insights, postEvent, operations;
  String? aiInsightSummary;
  Object? aiInsightError;
  Object? error;
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
        widget.repository.postEventIntelligence(),
        if (superAdmin) widget.repository.superAdminOperations()
      ]);
      if (mounted) {
        setState(() {
          alerts = values[0];
          insights = values[1];
          postEvent = values[2];
          if (superAdmin) operations = values[3];
          error = null;
        });
      }
      try {
        final summary = await widget.repository.aiSummary('exhibition');
        if (mounted) setState(() => aiInsightSummary = summary);
      } catch (value) {
        if (mounted) setState(() => aiInsightError = value);
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
      length: superAdmin ? 3 : 2,
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
                    if (superAdmin) const Tab(text: 'EMPLOYEES'),
                    const Tab(text: 'INSIGHTS')
                  ])),
          body: alerts == null
              ? Center(
                  child: error == null
                      ? const AppProfileSkeleton()
                      : FilledButton(
                          onPressed: load, child: Text('Retry: $error')))
              : TabBarView(children: [
                  _alerts(),
                  if (superAdmin) _employees(),
                  _insights()
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
                    Row(children: [
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  '${target['achieved'] ?? 0}/${target['target'] ?? 0}',
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900)),
                              Text(
                                  target['isEventDay'] == true
                                      ? 'Today • ${target['day'] ?? ''}'
                                      : 'Today is outside the exhibition dates',
                                  style: const TextStyle(
                                      fontSize: 9, color: Colors.black45)),
                            ]),
                      ),
                      Text('${target['percent'] ?? 0}%',
                          style: const TextStyle(
                              color: AppColors.green,
                              fontWeight: FontWeight.w900)),
                      IconButton(
                          tooltip: 'Set daily target',
                          onPressed: () => _editDailyTarget(
                              numberValue(target['target']).round()),
                          icon: const Icon(Icons.track_changes_rounded,
                              size: 19, color: AppColors.green))
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

  Future<void> _editDailyTarget(int current) async {
    var targetText = '$current';
    final value = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('Set daily target'),
        content: TextFormField(
          initialValue: targetText,
          autofocus: true,
          keyboardType: TextInputType.number,
          onChanged: (value) => targetText = value,
          decoration: const InputDecoration(
              labelText: 'Expected check-ins per day',
              prefixIcon: Icon(Icons.track_changes_rounded)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, int.tryParse(targetText.trim())),
              child: const Text('Save')),
        ],
      ),
    );
    if (value == null || value < 1) return;
    try {
      await widget.repository.updateDailyTarget(value);
      await load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Target update failed: $error')));
      }
    }
  }

  Widget _insights() {
    final countries = List.from(insights!['countries'] ?? []),
        types = List.from(insights!['buyerTypes'] ?? []),
        matches = List.from(insights!['visitorTypes'] ?? []),
        days = List.from(insights!['dayWise'] ?? []),
        categories = List.from(insights!['categoryWise'] ?? []),
        overview = Map<String, dynamic>.from(insights!['overview'] ?? {}),
        exhibitors = Map<String, dynamic>.from(insights!['exhibitors'] ?? {});
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.all(14), children: [
        _title('EXHIBITION OVERVIEW'),
        Row(children: [
          Expanded(
              child: _insightCard('Check-ins', overview['totalCheckIns'],
                  Icons.how_to_reg_rounded)),
          const SizedBox(width: 6),
          Expanded(
              child: _insightCard('Unique', overview['uniquePeople'],
                  Icons.people_alt_rounded)),
          const SizedBox(width: 6),
          Expanded(
              child: _insightCard('Companies', overview['exhibitorCompanies'],
                  Icons.storefront_rounded)),
        ]),
        _title('DAY-WISE ATTENDANCE'),
        _verticalBarChart(days, labelKey: 'day', valueKey: 'total'),
        const SizedBox(height: 14),
        _title('ATTENDANCE BY CATEGORY'),
        _donutChart(categories, labelKey: 'label', valueKey: 'count'),
        const SizedBox(height: 14),
        _title('BUYER MIX'),
        _donutChart(types, labelKey: 'label', valueKey: 'count'),
        const SizedBox(height: 14),
        _title('TOP COUNTRIES'),
        _chartCard(countries.take(8).toList(),
            labelKey: 'label', valueKey: 'count'),
        const SizedBox(height: 14),
        _title('VISITOR BREAKDOWN'),
        _visualTiles(matches, labelKey: 'label', valueKey: 'count'),
        const SizedBox(height: 14),
        _title('EXHIBITOR PERFORMANCE'),
        Row(children: [
          Expanded(
              child: _insightCard('Present', exhibitors['presentCompanies'],
                  Icons.storefront_rounded)),
          const SizedBox(width: 7),
          Expanded(
              child: _insightCard('Team entries', exhibitors['teamCheckIns'],
                  Icons.badge_rounded)),
          const SizedBox(width: 7),
          Expanded(
              child: _insightCard('Products', exhibitors['products'],
                  Icons.inventory_2_rounded))
        ]),
        const SizedBox(height: 8),
        _chartCard(List.from(exhibitors['topCompanies'] ?? []),
            labelKey: 'label', valueKey: 'checkIns', sentenceLabels: false),
        const SizedBox(height: 16),
        _postEventIntelligence(),
        const SizedBox(height: 16),
        _title('AI EXECUTIVE SUMMARY'),
        _aiSummaryCard(),
      ]),
    );
  }

  Widget _postEventIntelligence() {
    final overview = Map<String, dynamic>.from(postEvent?['overview'] ?? {});
    final participation =
        Map<String, dynamic>.from(postEvent?['participation'] ?? {});
    final buyerQuality =
        Map<String, dynamic>.from(postEvent?['buyerQuality'] ?? {});
    final peak = List.from(postEvent?['peakHours'] ?? []);
    final days = List.from(postEvent?['dayWise'] ?? []);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _title('POST-EVENT INTELLIGENCE'),
      Row(children: [
        Expanded(
            child: _insightCard(
                'No-shows', overview['noShows'], Icons.person_off_rounded)),
        const SizedBox(width: 6),
        Expanded(
            child: _insightCard('Returning', overview['returnVisitors'],
                Icons.replay_circle_filled_rounded)),
        const SizedBox(width: 6),
        Expanded(
            child: _insightCard('Total entries', overview['totalCheckIns'],
                Icons.login_rounded)),
      ]),
      const SizedBox(height: 10),
      _title('PARTICIPATION RATE'),
      _participationCard(participation),
      const SizedBox(height: 12),
      _title('PEAK ENTRY HOURS'),
      _chartCard(peak, labelKey: 'label', valueKey: 'count'),
      const SizedBox(height: 12),
      _title('DAY RETENTION'),
      _verticalBarChart(days, labelKey: 'day', valueKey: 'unique'),
      const SizedBox(height: 12),
      _title('BUYER QUALITY'),
      Row(children: [
        Expanded(
            child: _insightCard(
                'Attended', buyerQuality['total'], Icons.handshake_rounded)),
        const SizedBox(width: 6),
        Expanded(
            child: _insightCard('International', buyerQuality['international'],
                Icons.public_rounded)),
        const SizedBox(width: 6),
        Expanded(
            child: _insightCard('Returned', buyerQuality['returning'],
                Icons.workspace_premium_rounded)),
      ]),
    ]);
  }

  Widget _participationCard(Map<String, dynamic> data) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
              children: ['visitors', 'buyers', 'exhibitors'].map((key) {
            final item = Map<String, dynamic>.from(data[key] ?? {});
            final registered = numberValue(item['registered']);
            final attended = numberValue(item['attended']);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(children: [
                Row(children: [
                  Expanded(
                      child: Text(sentenceCase(key),
                          style: const TextStyle(
                              fontSize: 9.5, fontWeight: FontWeight.w800))),
                  Text('${attended.round()}/${registered.round()}',
                      style: const TextStyle(
                          fontSize: 9.5, fontWeight: FontWeight.w900)),
                ]),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                    value: registered == 0
                        ? 0
                        : (attended / registered).clamp(0, 1),
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(5)),
              ]),
            );
          }).toList()),
        ),
      );

  Widget _aiSummaryCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            AppColors.navy,
            AppColors.green.withValues(alpha: .94),
          ]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: Color(0x22071B33), blurRadius: 14, offset: Offset(0, 6))
          ],
        ),
        child: aiInsightSummary == null
            ? Row(children: [
                const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.gold)),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(
                        aiInsightError == null
                            ? 'AI is analysing the complete exhibition...'
                            : 'AI summary unavailable: $aiInsightError',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 10))),
                if (aiInsightError != null)
                  IconButton(
                      onPressed: load,
                      icon: const Icon(Icons.refresh_rounded,
                          color: Colors.white)),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.auto_awesome_rounded,
                      color: AppColors.gold, size: 18),
                  SizedBox(width: 7),
                  Text('LIVE AI ANALYSIS',
                      style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .8))
                ]),
                const SizedBox(height: 10),
                Text(aiInsightSummary!.replaceAll(RegExp(r'[#*]'), '').trim(),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 10.5, height: 1.48)),
              ]),
      );

  static const _chartColors = [
    AppColors.green,
    AppColors.gold,
    Color(0xFF3D7FC1),
    Color(0xFF9B59B6),
    Color(0xFFE67E22),
    Color(0xFF16A085),
  ];

  Widget _verticalBarChart(List<dynamic> items,
      {required String labelKey, required String valueKey}) {
    if (items.isEmpty) return _emptyChart();
    final values = items.map((item) => numberValue(item[valueKey])).toList();
    final maxValue = values.fold<double>(1, math.max);
    return Card(
      child: SizedBox(
        height: 176,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(items.length, (index) {
              final item = Map<String, dynamic>.from(items[index]);
              final value = values[index];
              final rawLabel = (item[labelKey] ?? '').toString();
              final label = rawLabel.length >= 10
                  ? rawLabel.substring(8).replaceFirst('-', ' Aug ')
                  : rawLabel;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('${value.round()}',
                            style: const TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 5),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 450),
                          height: math.max(8, 105 * value / maxValue),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [AppColors.green, Color(0xFF69A45B)]),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(9)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(label,
                            maxLines: 1,
                            style: const TextStyle(
                                fontSize: 8, fontWeight: FontWeight.w700)),
                      ]),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _donutChart(List<dynamic> items,
      {required String labelKey, required String valueKey}) {
    if (items.isEmpty) return _emptyChart();
    final visible =
        items.take(6).map((e) => Map<String, dynamic>.from(e)).toList();
    final values = visible.map((e) => numberValue(e[valueKey])).toList();
    final total = values.fold<double>(0, (sum, value) => sum + value);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          SizedBox.square(
            dimension: 118,
            child: Stack(alignment: Alignment.center, children: [
              CustomPaint(
                  size: const Size.square(118),
                  painter: _DonutPainter(values, _chartColors)),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${total.round()}',
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w900)),
                const Text('TOTAL',
                    style: TextStyle(
                        fontSize: 7,
                        color: Colors.black45,
                        fontWeight: FontWeight.w800)),
              ]),
            ]),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
                children: List.generate(visible.length, (index) {
              final label = sentenceCase(visible[index][labelKey] ?? 'Unknown');
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: _chartColors[index % _chartColors.length],
                          shape: BoxShape.circle)),
                  const SizedBox(width: 7),
                  Expanded(
                      child: Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 9))),
                  Text('${values[index].round()}',
                      style: const TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w900)),
                ]),
              );
            })),
          ),
        ]),
      ),
    );
  }

  Widget _visualTiles(List<dynamic> items,
      {required String labelKey, required String valueKey}) {
    if (items.isEmpty) return _emptyChart();
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: items.take(8).toList().asMap().entries.map((entry) {
        final item = Map<String, dynamic>.from(entry.value);
        final color = _chartColors[entry.key % _chartColors.length];
        return Container(
          width: (MediaQuery.sizeOf(context).width - 43) / 2,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          decoration: BoxDecoration(
              color: color.withValues(alpha: .09),
              border: Border.all(color: color.withValues(alpha: .25)),
              borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            CircleAvatar(
                radius: 15,
                backgroundColor: color.withValues(alpha: .16),
                child: Icon(Icons.groups_rounded, size: 15, color: color)),
            const SizedBox(width: 8),
            Expanded(
                child: Text(sentenceCase(item[labelKey] ?? 'Visitor'),
                    maxLines: 2,
                    style: const TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w700))),
            Text('${item[valueKey] ?? 0}',
                style: TextStyle(
                    color: color, fontSize: 14, fontWeight: FontWeight.w900)),
          ]),
        );
      }).toList(),
    );
  }

  Widget _emptyChart() => const Card(
      child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No data available yet.',
              style: TextStyle(color: Colors.black45))));

  Widget _chartCard(List<dynamic> items,
      {required String labelKey,
      required String valueKey,
      bool sentenceLabels = true}) {
    if (items.isEmpty) {
      return _emptyChart();
    }
    final maxValue = items
        .map((item) => numberValue(item[valueKey]))
        .fold<double>(1, (a, b) => a > b ? a : b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
            children: items.take(10).map((raw) {
          final item = Map<String, dynamic>.from(raw);
          final value = numberValue(item[valueKey]);
          final rawLabel = item[labelKey] ?? 'Unknown';
          final label = sentenceLabels ? sentenceCase(rawLabel) : '$rawLabel';
          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Column(children: [
              Row(children: [
                Expanded(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 9.5, fontWeight: FontWeight.w700))),
                Text('${value.round()}',
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w900)),
              ]),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                    value: (value / maxValue).clamp(0, 1),
                    minHeight: 7,
                    backgroundColor: AppColors.green.withValues(alpha: .08),
                    color: AppColors.green),
              ),
            ]),
          );
        }).toList()),
      ),
    );
  }

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
                              repository: widget.repository,
                              session: widget.session))),
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
                '${item['company'] ?? ''} • ${sentenceCase(item['subjectSubType'] ?? 'VIP')}'),
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

class _DonutPainter extends CustomPainter {
  const _DonutPainter(this.values, this.colors);

  final List<double> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (sum, value) => sum + value);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final background = Paint()
      ..color = const Color(0xFFE8EEEA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 17;
    canvas.drawCircle(center, radius, background);
    if (total <= 0) return;
    var start = -math.pi / 2;
    for (var index = 0; index < values.length; index++) {
      final sweep = (values[index] / total) * math.pi * 2;
      final paint = Paint()
        ..color = colors[index % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 17
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start, math.max(0, sweep - .025), false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.colors != colors;
}
