import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/config/app_config.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/domain/attendance_categories.dart';
import '../../attendance/presentation/attendance_profile_screen.dart';
import '../../attendance/presentation/ai_summary_dialog.dart';
import 'company_resources_screen.dart';
import 'payment_information_screen.dart';

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
  Map<String, dynamic>? timelineData;
  Object? error;
  String selectedPassType = '';
  bool exporting = false;

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
      final values = await Future.wait([
        widget.repository.companyDetail(widget.companyId),
        widget.repository.companyTimeline(widget.companyId),
      ]);
      if (mounted) {
        setState(() {
          data = values[0];
          timelineData = values[1];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Exhibitor Profile'),
          actions: [
            IconButton(
              tooltip: 'AI company summary',
              onPressed: () => showAiSummaryDialog(context,
                  repository: widget.repository,
                  scope: 'company',
                  id: widget.companyId),
              icon: const Icon(Icons.auto_awesome_rounded,
                  color: AppColors.green),
            ),
            IconButton(
              tooltip: 'Export company Excel',
              onPressed: exporting ? null : _export,
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
        body: data == null
            ? Center(
                child: error == null
                    ? const AppProfileSkeleton()
                    : Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('$error'),
                        const SizedBox(height: 10),
                        FilledButton(
                            onPressed: load, child: const Text('Retry')),
                      ]))
            : RefreshIndicator(onRefresh: load, child: _content()),
      );

  Future<void> _export() async {
    setState(() => exporting = true);
    try {
      final path = await widget.repository
          .exportAttendance(companyId: widget.companyId, type: 'exhibitor');
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
      if (mounted) setState(() => exporting = false);
    }
  }

  Widget _content() {
    final company = Map<String, dynamic>.from(data!['company']);
    final companyAttendance =
        List<Map<String, dynamic>>.from(data!['companyAttendance'] ?? []);
    final allMemberAttendance = _groupMembers(
        List<Map<String, dynamic>>.from(data!['memberAttendance'] ?? []));
    final counts = <String, int>{
      for (final type in passLabels.keys)
        type:
            allMemberAttendance.where((item) => _passType(item) == type).length
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
            gradient:
                const LinearGradient(colors: [AppColors.navy, AppColors.green]),
            borderRadius: BorderRadius.circular(20),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                        label: Text(
                            DateFormat('d MMM').format(DateTime.parse(day))),
                      ))
                  .toList(),
            ),
          ]),
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 50,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            scrollDirection: Axis.horizontal,
            children: [
              _resourceButton(
                  'Free accessories',
                  Icons.redeem_rounded,
                  List<Map<String, dynamic>>.from(
                      data!['freeAccessories'] ?? []),
                  'free'),
              _resourceButton(
                  'Add-ons',
                  Icons.add_shopping_cart_rounded,
                  List<Map<String, dynamic>>.from(
                      data!['additionalAccessories'] ?? []),
                  'additional'),
              _paymentButton(),
              _resourceButton(
                  'Products',
                  Icons.inventory_2_outlined,
                  List<Map<String, dynamic>>.from(data!['products'] ?? []),
                  'product'),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        sliver: SliverToBoxAdapter(child: _companyInformation(company)),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 3, 16, 10),
        sliver: SliverToBoxAdapter(child: _arrivalTimeline()),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 3, 16, 5),
        sliver: SliverToBoxAdapter(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('PASS-WISE ARRIVALS',
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w900,
                      color: Colors.black45)),
              Text('${allMemberAttendance.length} Total',
                  style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.green,
                      fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 6),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: passLabels.keys
                    .map((type) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _passStat(type, counts[type] ?? 0)))
                    .toList(),
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
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('PRESENT TEAM MEMBERS',
                style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w900,
                    color: Colors.black45)),
            Text('${memberAttendance.length} Shown',
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
          sliver: memberAttendance.length <= 7
              ? SliverList(
                  delegate: SliverChildListDelegate(memberAttendance
                      .map(_memberCard)
                      .toList(growable: false)))
              : SliverFixedExtentList.builder(
                  itemExtent: 68,
                  itemCount: memberAttendance.length,
                  itemBuilder: (_, i) => _memberCard(memberAttendance[i]),
                ),
        ),
    ]);
  }

  Widget _companyInformation(Map<String, dynamic> company) {
    final stall = Map<String, dynamic>.from(
        company['stallInformation'] ?? <String, dynamic>{});
    final stallParts = <String>[
      if (stall['stallNo']?.toString().isNotEmpty == true)
        'Stall ${stall['stallNo']}',
      if (stall['stallSize'] != null) '${stall['stallSize']} sq. m.',
      if (stall['stallType']?.toString().isNotEmpty == true)
        stall['stallType'].toString(),
      if (stall['stallScheme']?.toString().isNotEmpty == true)
        stall['stallScheme'].toString(),
      if (stall['dimension']?.toString().isNotEmpty == true)
        stall['dimension'].toString(),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('COMPANY & STALL INFORMATION',
              style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.1,
                  color: Colors.black45,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 9),
          _companyInfoRow(Icons.person_outline_rounded, 'Contact person',
              company['contactPerson']),
          _companyInfoRow(
              Icons.phone_outlined, 'Mobile', company['contactMobile']),
          _companyInfoRow(
              Icons.email_outlined, 'Email', company['contactEmail']),
          _companyInfoRow(Icons.category_outlined, 'Exhibitor category',
              company['exhibitorCategory']),
          _companyInfoRow(Icons.factory_outlined, 'Industry / Sector',
              company['industrySector']),
          _companyInfoRow(Icons.store_mall_directory_outlined,
              'Stall information', stallParts.join(' • ')),
          _companyInfoRow(Icons.signpost_outlined, 'Stall category',
              stall['stallCategory']),
          _companyInfoRow(
              Icons.text_fields_rounded, 'Fascia name', stall['fasciaName']),
        ]),
      ),
    );
  }

  Widget _arrivalTimeline() {
    final events = List<Map<String, dynamic>>.from(
        timelineData?['timeline'] ?? <Map<String, dynamic>>[]);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE1E8E4))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.timeline_rounded, size: 18, color: AppColors.green),
          const SizedBox(width: 7),
          const Expanded(
              child: Text('COMPANY ARRIVAL TIMELINE',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .8))),
          Text('${events.length} Events',
              style: const TextStyle(
                  fontSize: 9,
                  color: AppColors.green,
                  fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 9),
        if (events.isEmpty)
          const Text('No company or team arrival recorded yet.',
              style: TextStyle(fontSize: 9.5, color: Colors.black45))
        else
          ...events.reversed.take(8).map((event) {
            final at = DateTime.tryParse(event['at']?.toString() ?? '');
            final companyEvent = event['kind'] == 'company';
            return IntrinsicHeight(
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Column(children: [
                  Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color:
                              companyEvent ? AppColors.gold : AppColors.green,
                          shape: BoxShape.circle)),
                  Container(
                      width: 1, height: 34, color: const Color(0xFFDCE5DF)),
                ]),
                const SizedBox(width: 9),
                Expanded(
                    child: Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event['title']?.toString() ?? 'Arrival',
                            style: const TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w900)),
                        Text(event['subtitle']?.toString() ?? '',
                            style: const TextStyle(fontSize: 8.5)),
                        Text(
                            '${at == null ? event['eventDay'] ?? '' : DateFormat('d MMM, h:mm a').format(at.toLocal())} • ${event['markedByName'] ?? 'Admin'}',
                            style: const TextStyle(
                                fontSize: 8, color: Colors.black45)),
                      ]),
                )),
              ]),
            );
          }),
      ]),
    );
  }

  Widget _companyInfoRow(IconData icon, String label, dynamic raw) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: AppColors.green),
        const SizedBox(width: 8),
        SizedBox(
          width: 105,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 9,
                  color: Colors.black45,
                  fontWeight: FontWeight.w800)),
        ),
        Expanded(
          child: Text(value,
              style:
                  const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }

  Widget _resourceButton(String label, IconData icon,
          List<Map<String, dynamic>> items, String kind) =>
      Padding(
        padding: const EdgeInsets.only(right: 7),
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              minimumSize: const Size(0, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3)),
              padding: const EdgeInsets.symmetric(horizontal: 10)),
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => CompanyResourcesScreen(
                      title: label, kind: kind, items: items))),
          icon: Icon(icon, size: 15, color: AppColors.green),
          label: Text('$label (${items.length})',
              style:
                  const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
        ),
      );

  Widget _paymentButton() => Padding(
        padding: const EdgeInsets.only(right: 7),
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              minimumSize: const Size(0, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3)),
              padding: const EdgeInsets.symmetric(horizontal: 10)),
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => PaymentInformationScreen(
                      data: Map<String, dynamic>.from(
                          data!['paymentInformation'] ?? {})))),
          icon: const Icon(Icons.account_balance_wallet_outlined,
              size: 15, color: AppColors.green),
          label: const Text('Stall Payment Information',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
        ),
      );

  List<Map<String, dynamic>> _groupMembers(List<Map<String, dynamic>> records) {
    final grouped = <String, Map<String, dynamic>>{};
    for (final record in records) {
      final key = record['subjectKey']?.toString() ??
          record['registrationId']?.toString() ??
          '';
      final current =
          grouped.putIfAbsent(key, () => {...record, 'days': <String>[]});
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
    final photo = resolveApiAssetUrl(company['logoUrl']);
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
              errorBuilder: (_, __, ___) => const Icon(Icons.storefront_rounded,
                  color: AppColors.green, size: 27))
          : const Icon(Icons.storefront_rounded,
              color: AppColors.gold, size: 27),
    );
  }

  Widget _passStat(String type, int count) => SizedBox(
        width: 104,
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            child: Row(children: [
              Container(
                width: 27,
                height: 27,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(7)),
                child: Text('$count',
                    style: const TextStyle(
                        color: AppColors.green,
                        fontSize: 13,
                        fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(passLabels[type]!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        height: 1.05,
                        fontSize: 9,
                        color: Colors.black54,
                        fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
        ),
      );

  Widget _filterChip(String type, String label) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          avatar: selectedPassType == type
              ? const Icon(Icons.check_circle_rounded,
                  size: 16, color: AppColors.gold)
              : null,
          label: Text(label),
          selected: selectedPassType == type,
          showCheckmark: false,
          selectedColor: AppColors.green,
          backgroundColor: Colors.white,
          side: BorderSide(
              color:
                  selectedPassType == type ? AppColors.green : Colors.black12),
          labelStyle: TextStyle(
              color: selectedPassType == type ? Colors.white : AppColors.ink,
              fontSize: 10,
              fontWeight: FontWeight.w700),
          onSelected: (_) => setState(() => selectedPassType = type),
        ),
      );

  Widget _memberCard(Map<String, dynamic> member) {
    final photo = resolveApiAssetUrl(member['photoUrl']);
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
        subtitle: Text(
            '${passLabels[_passType(member)] ?? attendanceLabel(member['subjectSubType'] ?? '')} Pass${member['designation']?.toString().isNotEmpty == true ? ' • ${member['designation']}' : ''}',
            style: const TextStyle(fontSize: 9)),
        trailing: Text(
            days.isEmpty
                ? '-'
                : days
                    .map((day) =>
                        DateFormat('d MMM').format(DateTime.parse(day)))
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
                errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded,
                    color: AppColors.green, size: 20))
            : const Icon(Icons.person_rounded,
                color: AppColors.green, size: 20),
      );
}
