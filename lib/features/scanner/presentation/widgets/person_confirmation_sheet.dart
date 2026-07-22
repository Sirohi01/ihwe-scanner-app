import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/config/app_config.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../attendance/data/attendance_repository.dart';
import '../../../attendance/domain/attendance_categories.dart';
import '../../../attendance/domain/attendance_models.dart';

class PersonConfirmationSheet extends StatefulWidget {
  const PersonConfirmationSheet({
    super.key,
    required this.result,
    required this.raw,
    required this.repository,
    this.source = 'qr',
  });

  final ScanResult result;
  final String raw;
  final AttendanceRepository repository;
  final String source;

  @override
  State<PersonConfirmationSheet> createState() =>
      _PersonConfirmationSheetState();
}

class _PersonConfirmationSheetState extends State<PersonConfirmationSheet> {
  final selected = <String>{};
  bool loading = false;

  @override
  void initState() {
    super.initState();
    final open = widget.result.days
        .where((day) => !widget.result.attendedDays.contains(day))
        .toList();
    if (open.isNotEmpty) selected.add(open.first);
  }

  Future<void> mark() async {
    if (selected.isEmpty) return;
    setState(() => loading = true);
    try {
      final results = await widget.repository
          .mark(widget.raw, selected.toList(), source: widget.source);
      if (!mounted) return;
      final created = results.where((item) => item['created'] == true).length;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(created > 0
            ? 'Attendance marked for $created day(s).'
            : 'Attendance was already marked.'),
        backgroundColor: AppColors.emerald,
        behavior: SnackBarBehavior.floating,
      ));
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final person = widget.result.person;
    return FractionallySizedBox(
      heightFactor: .92,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 8),
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _identityCard(person),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      child: Column(children: [
                        _detail(Icons.badge_outlined, 'Registration ID',
                            person.registrationId),
                        _detail(Icons.category_outlined, 'Registration type',
                            attendanceLabel(person.subType)),
                        _detail(
                            Icons.mail_outline_rounded, 'Email', person.email),
                        _detail(Icons.phone_outlined, 'Mobile', person.mobile),
                        _detail(
                            Icons.public_rounded, 'Country', person.country),
                        _detail(
                            Icons.verified_outlined, 'Status', person.status),
                      ]),
                    ),
                  ),
                  if (widget.result.attendance.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: .18),
                          border: Border.all(color: AppColors.gold),
                          borderRadius: BorderRadius.circular(12)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(children: [
                              Icon(Icons.info_rounded,
                                  size: 17, color: AppColors.green),
                              SizedBox(width: 6),
                              Text('ALREADY MARKED',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.green))
                            ]),
                            const SizedBox(height: 5),
                            ...widget.result.attendance.map((record) {
                              final at = DateTime.tryParse(
                                  record['markedAt']?.toString() ?? '');
                              final when = at == null
                                  ? record['eventDay'].toString()
                                  : DateFormat('d MMM, h:mm a')
                                      .format(at.toLocal());
                              return Text(
                                  '$when • ${record['markedByName']?.toString().isNotEmpty == true ? record['markedByName'] : 'Unknown admin'}${record['gate']?.toString().isNotEmpty == true ? ' • ${record['gate']}' : ''}',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700));
                            }),
                          ]),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('ATTENDANCE DAYS',
                          style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.25,
                              fontWeight: FontWeight.w900,
                              color: Colors.black45)),
                      TextButton.icon(
                        onPressed: _selectAll,
                        style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8)),
                        icon: const Icon(Icons.done_all_rounded, size: 15),
                        label: const Text('SELECT ALL',
                            style: TextStyle(fontSize: 9)),
                      ),
                    ],
                  ),
                  ...widget.result.days.map(_dayTile),
                ],
              ),
            ),
          ),
          _fixedActionBar(),
        ]),
      ),
    );
  }

  Widget _identityCard(PersonProfile person) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient:
              LinearGradient(colors: [AppColors.navy, _typeColor(person.type)]),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
                color: Color(0x24071B33), blurRadius: 14, offset: Offset(0, 6))
          ],
        ),
        child: Row(children: [
          _photo(person),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    '${person.type.toUpperCase()} • ${attendanceLabel(person.subType).toUpperCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 8.5,
                        letterSpacing: .7),
                  ),
                ),
                const SizedBox(height: 8),
                Text(person.name.isEmpty ? person.registrationId : person.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        height: 1.08)),
                if (person.company.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(person.company,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 11,
                            fontWeight: FontWeight.w800)),
                  ),
                if (person.designation.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(person.designation,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 9)),
                  ),
              ],
            ),
          ),
        ]),
      );

  void _selectAll() => setState(() {
        selected
          ..clear()
          ..addAll(widget.result.days
              .where((day) => !widget.result.attendedDays.contains(day)));
      });

  Widget _dayTile(String day) {
    final done = widget.result.attendedDays.contains(day);
    final checked = selected.contains(day);
    return Card(
      margin: const EdgeInsets.only(bottom: 7),
      child: CheckboxListTile(
        dense: true,
        visualDensity: const VisualDensity(vertical: -2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
        value: done || checked,
        onChanged: done
            ? null
            : (value) => setState(
                () => value == true ? selected.add(day) : selected.remove(day)),
        activeColor: done ? Colors.grey : AppColors.green,
        secondary: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: (done ? AppColors.emerald : AppColors.green)
                .withValues(alpha: .1),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
              done ? Icons.check_circle_rounded : Icons.event_available_rounded,
              size: 19,
              color: done ? AppColors.emerald : AppColors.green),
        ),
        title: Text(DateFormat('EEEE, d MMMM').format(DateTime.parse(day)),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
        subtitle: Text(
          done
              ? 'Already marked'
              : checked
                  ? 'Selected for entry'
                  : 'Tap to select',
          style: TextStyle(
              fontSize: 9, color: done ? AppColors.emerald : Colors.black45),
        ),
      ),
    );
  }

  Widget _fixedActionBar() => Container(
        padding: EdgeInsets.fromLTRB(
            16, 11, 16, MediaQuery.paddingOf(context).bottom + 11),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE3E9E6))),
          boxShadow: [
            BoxShadow(
                color: Color(0x18000000), blurRadius: 16, offset: Offset(0, -5))
          ],
        ),
        child: SizedBox(
          height: 52,
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: loading || selected.isEmpty ? null : mark,
            icon: loading
                ? const SizedBox.square(
                    dimension: 19,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.how_to_reg_rounded, size: 20),
            label: Text(selected.isEmpty
                ? 'SELECT AN EVENT DAY'
                : 'MARK ATTENDANCE • ${selected.length} DAY${selected.length == 1 ? '' : 'S'}'),
          ),
        ),
      );

  Widget _photo(PersonProfile person) => Container(
        width: 82,
        height: 94,
        decoration: BoxDecoration(
          color: person.photoKind == 'logo' ? Colors.white : AppColors.navy,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: AppColors.gold, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: person.photoUrl.isNotEmpty
            ? Padding(
                padding: EdgeInsets.all(person.photoKind == 'logo' ? 7 : 0),
                child: Image.network(resolveApiAssetUrl(person.photoUrl),
                    fit: person.photoKind == 'logo'
                        ? BoxFit.contain
                        : BoxFit.cover,
                    errorBuilder: (_, __, ___) => _initial(person)),
              )
            : _initial(person),
      );

  Color _typeColor(String type) => type == 'visitor'
      ? const Color(0xFF176B87)
      : type == 'buyer'
          ? const Color(0xFF7A4EB2)
          : AppColors.green;

  Widget _initial(PersonProfile person) => Center(
        child: Text(
          (person.name.isNotEmpty ? person.name[0] : '?').toUpperCase(),
          style: const TextStyle(
              color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 36),
        ),
      );

  Widget _detail(IconData icon, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, size: 18, color: AppColors.green),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 8,
                      letterSpacing: .8,
                      color: Colors.black38,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 1),
              Text(value,
                  style: const TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ]),
    );
  }
}
