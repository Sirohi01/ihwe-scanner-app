import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/config/app_config.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../data/attendance_repository.dart';
import '../domain/attendance_categories.dart';
import '../../dashboard/presentation/company_detail_screen.dart';
import 'ai_summary_dialog.dart';

class AttendanceProfileScreen extends StatefulWidget {
  const AttendanceProfileScreen({
    super.key,
    required this.attendanceId,
    required this.repository,
  });

  final String attendanceId;
  final AttendanceRepository repository;

  @override
  State<AttendanceProfileScreen> createState() =>
      _AttendanceProfileScreenState();
}

class _AttendanceProfileScreenState extends State<AttendanceProfileScreen> {
  Map<String, dynamic>? data;
  Map<String, dynamic>? concierge;
  Object? error;
  Object? conciergeError;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final value =
          await widget.repository.attendanceProfile(widget.attendanceId);
      final profile = Map<String, dynamic>.from(value['profile'] ?? {});
      final buyer = _isBuyer(profile);
      final buyerId = profile['subjectId']?.toString() ?? '';
      if (mounted) {
        setState(() {
          data = value;
          error = null;
          concierge = null;
          conciergeError = null;
        });
      }
      if (buyer && buyerId.isNotEmpty) {
        await _loadConcierge(buyerId);
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  bool _isBuyer(Map<String, dynamic> profile) =>
      profile['subjectType']?.toString().toLowerCase() == 'buyer' ||
      profile['subjectSubType']?.toString().toLowerCase().contains('buyer') ==
          true;

  Future<void> _loadConcierge(String buyerId) async {
    try {
      final value = await widget.repository.buyerConcierge(buyerId);
      if (mounted) {
        setState(() {
          concierge = value;
          conciergeError = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => conciergeError = e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Attendance Profile'),
          actions: [
            IconButton(
              tooltip: 'AI profile summary',
              onPressed: () => showAiSummaryDialog(context,
                  repository: widget.repository,
                  scope: 'person',
                  id: widget.attendanceId),
              icon: const Icon(Icons.auto_awesome_rounded,
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
                        Text('$error', textAlign: TextAlign.center),
                        const SizedBox(height: 10),
                        FilledButton(
                            onPressed: load, child: const Text('Retry')),
                      ]))
            : RefreshIndicator(onRefresh: load, child: _content()),
      );

  Widget _content() {
    final profile = Map<String, dynamic>.from(data!['profile']);
    final attendance =
        List<Map<String, dynamic>>.from(data!['attendance'] ?? []);
    final photo = resolveApiAssetUrl(profile['photoUrl']);
    final isLogo = profile['photoKind']?.toString() == 'logo';
    final name = profile['name']?.toString().isNotEmpty == true
        ? profile['name'].toString()
        : profile['registrationId']?.toString() ?? 'Attendee';
    final type = attendanceLabel(
        profile['subjectSubType'] ?? profile['subjectType'] ?? '');
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 90),
      children: [
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            gradient:
                const LinearGradient(colors: [AppColors.navy, AppColors.green]),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(children: [
            Container(
              width: 74,
              height: 80,
              decoration: BoxDecoration(
                color: isLogo ? Colors.white : Colors.white12,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: AppColors.gold, width: 1.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: photo.isNotEmpty
                  ? Padding(
                      padding: EdgeInsets.all(isLogo ? 7 : 0),
                      child: Image.network(photo,
                          fit: isLogo ? BoxFit.contain : BoxFit.cover,
                          errorBuilder: (_, __, ___) => _initial(name)))
                  : _initial(name),
            ),
            const SizedBox(height: 8),
            Text(name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900)),
            if (profile['company']?.toString().isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(profile['company'].toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(20)),
              child: Text(type.toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w900)),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(children: [
              _detail(Icons.badge_outlined, 'Registration ID',
                  profile['registrationId']),
              _detail(Icons.work_outline_rounded, 'Designation',
                  profile['designation']),
              _detail(Icons.email_outlined, 'Email', profile['email']),
              _detail(Icons.phone_outlined, 'Mobile', profile['mobile']),
              _detail(Icons.public_rounded, 'Country', profile['country']),
              _detail(Icons.verified_outlined, 'Status',
                  sentenceCase(profile['status'])),
              _detail(Icons.confirmation_number_outlined, 'Pass type',
                  sentenceCase(profile['passType'])),
            ]),
          ),
        ),
        if (_isBuyer(profile)) ...[
          const SizedBox(height: 10),
          _conciergePanel(profile['subjectId']?.toString() ?? ''),
        ],
        const SizedBox(height: 13),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('ATTENDANCE DAYS',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w900,
                  color: Colors.black45)),
          Text('${attendance.length} Marked',
              style: const TextStyle(
                  color: AppColors.green,
                  fontSize: 10,
                  fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 6),
        ...attendance.map(_attendanceDay),
        ..._detailSections(profile['details']),
      ],
    );
  }

  Widget _conciergePanel(String buyerId) {
    final recommendations =
        List<Map<String, dynamic>>.from(concierge?['recommendations'] ?? []);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF5FF),
        border: Border.all(color: const Color(0xFFBED3EC)),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.connect_without_contact_rounded,
              color: Color(0xFF225D9C), size: 18),
          SizedBox(width: 7),
          Expanded(
            child: Text('MEETING CONCIERGE',
                style: TextStyle(
                    color: Color(0xFF225D9C),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8)),
          ),
        ]),
        const SizedBox(height: 8),
        if (buyerId.isEmpty)
          const Text('Buyer identity is unavailable for recommendations.',
              style: TextStyle(fontSize: 9.5))
        else if (concierge == null && conciergeError == null)
          const Row(children: [
            SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 8),
            Expanded(
                child: Text('Matching buyer interests with exhibitors...',
                    style: TextStyle(fontSize: 9.5))),
          ])
        else if (conciergeError != null)
          TextButton.icon(
              onPressed: buyerId.isEmpty
                  ? null
                  : () {
                      setState(() => conciergeError = null);
                      _loadConcierge(buyerId);
                    },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry recommendations'))
        else if (recommendations.isEmpty)
          const Text('No strong exhibitor match found yet.',
              style: TextStyle(fontSize: 9.5))
        else
          ...recommendations.take(4).map(_recommendationCard),
      ]),
    );
  }

  Widget _recommendationCard(Map<String, dynamic> item) {
    final products = List.from(item['products'] ?? []);
    final reasons = List.from(item['reasons'] ?? []);
    final logo = resolveApiAssetUrl(item['logo']);
    final companyId = item['companyId']?.toString() ?? '';
    return InkWell(
      onTap: companyId.isEmpty
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => CompanyDetailScreen(
                      companyId: companyId, repository: widget.repository))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD8E4F0))),
        child: Row(children: [
          CircleAvatar(
              radius: 21,
              backgroundColor: Colors.white,
              backgroundImage: logo.isNotEmpty ? NetworkImage(logo) : null,
              child: logo.isEmpty
                  ? const Icon(Icons.storefront_rounded, color: AppColors.green)
                  : null),
          const SizedBox(width: 9),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(item['company']?.toString() ?? 'Exhibitor',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 10.5, fontWeight: FontWeight.w900))),
                Text('${item['matchPercent'] ?? 0}% match',
                    style: const TextStyle(
                        color: AppColors.green,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900)),
              ]),
              Text(
                  item['stallNumber']?.toString().isNotEmpty == true
                      ? 'Stall ${item['stallNumber']}'
                      : 'Ask help desk for stall',
                  style: const TextStyle(
                      color: Color(0xFF225D9C),
                      fontSize: 9,
                      fontWeight: FontWeight.w800)),
              if (products.isNotEmpty || reasons.isNotEmpty)
                Text(
                    products.isNotEmpty
                        ? products
                            .take(2)
                            .map((product) => product['name'])
                            .join(' • ')
                        : 'Matched: ${reasons.take(3).join(', ')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 8.5)),
              Text(item['navigation']?.toString() ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 8, color: Colors.black45)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, size: 17),
        ]),
      ),
    );
  }

  Widget _initial(String name) => Center(
        child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
            style: const TextStyle(
                color: AppColors.gold,
                fontSize: 38,
                fontWeight: FontWeight.w900)),
      );

  Widget _detail(IconData icon, String label, dynamic raw) {
    final value = raw?.toString() ?? '';
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, color: AppColors.green, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label.toUpperCase(),
                style: const TextStyle(
                    color: Colors.black38,
                    fontSize: 8,
                    letterSpacing: .8,
                    fontWeight: FontWeight.w800)),
            Text(value,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }

  Widget _attendanceDay(Map<String, dynamic> item) {
    final day = DateTime.tryParse(item['eventDay']?.toString() ?? '');
    final marked = DateTime.tryParse(item['markedAt']?.toString() ?? '');
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading:
            const Icon(Icons.check_circle_rounded, color: AppColors.emerald),
        title: Text(day == null ? '-' : DateFormat('EEEE, d MMMM').format(day),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        subtitle: marked == null
            ? null
            : Text(DateFormat('h:mm a').format(marked.toLocal()),
                style: const TextStyle(fontSize: 9)),
        trailing: PopupMenuButton<String>(
          tooltip: 'Correct attendance',
          onSelected: (value) => value == 'remove'
              ? _removeAttendance(item)
              : _correctAttendance(item),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'correct', child: Text('Correct event day')),
            PopupMenuItem(value: 'remove', child: Text('Remove attendance')),
          ],
        ),
      ),
    );
  }

  Future<void> _correctAttendance(Map<String, dynamic> item) async {
    final days = List<String>.from(data?['days'] ?? []);
    String selectedDay = item['eventDay']?.toString() ?? '';
    String reason = '';
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title: const Text('Correct attendance'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    DropdownButtonFormField<String>(
                        value: days.contains(selectedDay) ? selectedDay : null,
                        decoration: const InputDecoration(
                            labelText: 'Correct event day'),
                        items: days
                            .map((day) => DropdownMenuItem(
                                value: day,
                                child: Text(DateFormat('d MMM yyyy')
                                    .format(DateTime.parse(day)))))
                            .toList(),
                        onChanged: (value) => setDialogState(
                            () => selectedDay = value ?? selectedDay)),
                    const SizedBox(height: 9),
                    TextFormField(
                        maxLines: 2,
                        onChanged: (value) => reason = value,
                        decoration: const InputDecoration(
                            labelText: 'Correction reason *')),
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () =>
                            Navigator.pop(context, reason.trim().isNotEmpty),
                        child: const Text('Save correction'))
                  ],
                )));
    if (confirmed == true) {
      await widget.repository.correctAttendance(item['_id'].toString(),
          reason: reason.trim(), day: selectedDay);
      await load();
    }
  }

  Future<void> _removeAttendance(Map<String, dynamic> item) async {
    String reason = '';
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Remove attendance?'),
                scrollable: true,
                content: TextFormField(
                    maxLines: 2,
                    onChanged: (value) => reason = value,
                    decoration:
                        const InputDecoration(labelText: 'Removal reason *')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      style:
                          FilledButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () =>
                          Navigator.pop(context, reason.trim().isNotEmpty),
                      child: const Text('Remove'))
                ]));
    if (confirmed == true) {
      await widget.repository
          .removeAttendance(item['_id'].toString(), reason.trim());
      await load();
    }
  }

  List<Widget> _detailSections(dynamic raw) {
    if (raw is! Map) return const [];
    final details = Map<String, dynamic>.from(raw);
    final groups = <String, List<String>>{
      'Personal details': [
        'title',
        'gender',
        'dateOfBirth',
        'alternateNo',
        'alternateNumber',
        'alternateMobile',
        'whatsappNumber'
      ],
      'Location': [
        'address',
        'registeredAddress',
        'residenceAddress',
        'state',
        'city',
        'pinCode',
        'pincode',
        'postalCode'
      ],
      'Business profile': [
        'registrationFor',
        'companyWebsite',
        'website',
        'industrySector',
        'companySize',
        'businessType',
        'typeOfBusiness',
        'natureOfBusiness',
        'buyerIndustry',
        'annualTurnover',
        'yearOfEstablishment',
        'legalEntityType',
        'countryOfRegistration',
        'groupSize'
      ],
      'Interests & preferences': [
        'purposeOfVisit',
        'areaOfInterest',
        'specificRequirement',
        'primaryProductInterest',
        'primaryProductCategory',
        'secondaryProductCategories',
        'productCategories',
        'targetMarket',
        'purchaseTimeline',
        'roleInPurchaseDecision',
        'b2bMeeting',
        'b2bMeetInterest',
        'b2bInterest',
        'preferredDate',
        'preferredTimeSlot',
        'specificHealthConcerns'
      ],
      'Registration & pass': [
        'registrationCategory',
        'registrationSource',
        'buyerTag',
        'sellerTag',
        'vehicleType',
        'vehicleNumber',
        'sessions',
        'specialPasses'
      ],
    };
    final used = <String>{};
    final widgets = <Widget>[];
    for (final group in groups.entries) {
      final values = group.value
          .where((key) => _displayValue(details[key]).isNotEmpty)
          .toList();
      if (values.isEmpty) continue;
      used.addAll(values);
      widgets.add(const SizedBox(height: 6));
      widgets.add(_detailsCard(group.key, values, details));
    }
    final remaining = details.keys
        .where((key) =>
            !used.contains(key) && _displayValue(details[key]).isNotEmpty)
        .toList();
    if (remaining.isNotEmpty) {
      widgets.add(const SizedBox(height: 6));
      widgets.add(_detailsCard('Additional details', remaining, details));
    }
    return widgets;
  }

  Widget _detailsCard(
      String title, List<String> keys, Map<String, dynamic> details) {
    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 7),
        visualDensity: const VisualDensity(vertical: -3),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(Icons.info_outline_rounded,
            color: AppColors.green, size: 17),
        title: Text(title,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: AppColors.navy)),
        subtitle: Text('${keys.length} Details',
            style: const TextStyle(fontSize: 8, color: Colors.black38)),
        children: keys
            .map((key) => _detail(_detailIcon(key), _fieldLabel(key),
                _displayValue(details[key], key: key)))
            .toList(),
      ),
    );
  }

  String _displayValue(dynamic value, {String key = ''}) {
    if (value == null) return '';
    if (value is List) {
      return value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .join(' • ');
    }
    if (value is Map) {
      return value.values
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .join(' • ');
    }
    final text = value.toString().trim();
    if (text == 'null' || text == '[]' || text == '{}') return '';
    const caseFields = {
      'gender',
      'status',
      'passType',
      'registrationFor',
      'businessType',
      'natureOfBusiness',
      'registrationCategory',
      'buyerTag',
      'sellerTag',
      'roleInPurchaseDecision',
      'typeOfBusiness',
      'legalEntityType'
    };
    return caseFields.contains(key) ? sentenceCase(text) : text;
  }

  String _fieldLabel(String key) {
    final spaced = key.replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'), (match) => '${match[1]} ${match[2]}');
    return spaced.isEmpty
        ? key
        : '${spaced[0].toUpperCase()}${spaced.substring(1)}';
  }

  IconData _detailIcon(String key) {
    final value = key.toLowerCase();
    if (value.contains('address') ||
        value.contains('city') ||
        value.contains('state') ||
        value.contains('pin')) {
      return Icons.location_on_outlined;
    }
    if (value.contains('website')) return Icons.language_rounded;
    if (value.contains('product') || value.contains('interest')) {
      return Icons.interests_outlined;
    }
    if (value.contains('vehicle')) return Icons.directions_car_outlined;
    if (value.contains('date') || value.contains('time')) {
      return Icons.event_outlined;
    }
    if (value.contains('business') || value.contains('industry')) {
      return Icons.business_center_outlined;
    }
    return Icons.info_outline_rounded;
  }
}
