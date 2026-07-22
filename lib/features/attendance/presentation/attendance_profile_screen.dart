import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/config/app_config.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../data/attendance_repository.dart';
import '../domain/attendance_categories.dart';
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
  Object? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final value =
          await widget.repository.attendanceProfile(widget.attendanceId);
      if (mounted) setState(() => data = value);
    } catch (e) {
      if (mounted) setState(() => error = e);
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
            PopupMenuItem(value: 'correct', child: Text('Correct day / gate')),
            PopupMenuItem(value: 'remove', child: Text('Remove attendance')),
          ],
        ),
      ),
    );
  }

  Future<void> _correctAttendance(Map<String, dynamic> item) async {
    final reason = TextEditingController();
    final gate = TextEditingController(text: item['gate']?.toString() ?? '');
    final days = List<String>.from(data?['days'] ?? []);
    String selectedDay = item['eventDay']?.toString() ?? '';
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
                    TextField(
                        controller: gate,
                        decoration: const InputDecoration(labelText: 'Gate')),
                    const SizedBox(height: 9),
                    TextField(
                        controller: reason,
                        maxLines: 2,
                        decoration: const InputDecoration(
                            labelText: 'Correction reason *')),
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(
                            context, reason.text.trim().isNotEmpty),
                        child: const Text('Save correction'))
                  ],
                )));
    if (confirmed == true) {
      await widget.repository.correctAttendance(item['_id'].toString(),
          reason: reason.text.trim(), day: selectedDay, gate: gate.text);
      await load();
    }
    reason.dispose();
    gate.dispose();
  }

  Future<void> _removeAttendance(Map<String, dynamic> item) async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Remove attendance?'),
                content: TextField(
                    controller: reason,
                    maxLines: 2,
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
                          Navigator.pop(context, reason.text.trim().isNotEmpty),
                      child: const Text('Remove'))
                ]));
    if (confirmed == true) {
      await widget.repository
          .removeAttendance(item['_id'].toString(), reason.text.trim());
      await load();
    }
    reason.dispose();
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
