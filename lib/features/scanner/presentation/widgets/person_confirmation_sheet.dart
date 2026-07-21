import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../attendance/data/attendance_repository.dart';
import '../../../attendance/domain/attendance_models.dart';
import '../../../attendance/domain/attendance_categories.dart';

class PersonConfirmationSheet extends StatefulWidget {
  const PersonConfirmationSheet(
      {super.key,
      required this.result,
      required this.raw,
      required this.repository});
  final ScanResult result;
  final String raw;
  final AttendanceRepository repository;
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
        .where((d) => !widget.result.attendedDays.contains(d))
        .toList();
    if (open.isNotEmpty) selected.add(open.first);
  }

  Future<void> mark() async {
    if (selected.isEmpty) return;
    setState(() => loading = true);
    try {
      final results =
          await widget.repository.mark(widget.raw, selected.toList());
      if (!mounted) return;
      final created = results.where((r) => r['created'] == true).length;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(created > 0
              ? 'Attendance marked for $created day(s).'
              : 'Attendance was already marked.'),
          backgroundColor: AppColors.emerald,
          behavior: SnackBarBehavior.floating));
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.result.person;
    return Container(
      decoration: const BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, MediaQuery.viewInsetsOf(context).bottom + 28),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
                child: Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(5)))),
            const SizedBox(height: 18),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _photo(p),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: _typeColor(p.type),
                            borderRadius: BorderRadius.circular(30)),
                        child: Text(
                            '${p.type.toUpperCase()} • ${attendanceLabel(p.subType).toUpperCase()}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                                letterSpacing: 1))),
                    const SizedBox(height: 9),
                    Text(p.name.isEmpty ? p.registrationId : p.name,
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            height: 1.05)),
                    if (p.designation.isNotEmpty)
                      Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(p.designation,
                              style: const TextStyle(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w600))),
                    if (p.company.isNotEmpty)
                      Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(p.company,
                              style: const TextStyle(
                                  color: AppColors.green,
                                  fontWeight: FontWeight.w800))),
                  ])),
            ]),
            const SizedBox(height: 18),
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      _detail(Icons.badge_outlined, 'Registration ID',
                          p.registrationId),
                      _detail(Icons.category_outlined, 'Registration type',
                          p.subType.replaceAll('-', ' ')),
                      _detail(Icons.mail_outline_rounded, 'Email', p.email),
                      _detail(Icons.phone_outlined, 'Mobile', p.mobile),
                      _detail(Icons.public_rounded, 'Country', p.country),
                      _detail(Icons.verified_outlined, 'Status', p.status),
                    ]))),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('SELECT ATTENDANCE DAYS',
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.3,
                      fontWeight: FontWeight.w900,
                      color: Colors.black45)),
              TextButton(
                  onPressed: () => setState(() {
                        selected.clear();
                        selected.addAll(widget.result.days.where(
                            (d) => !widget.result.attendedDays.contains(d)));
                      }),
                  child: const Text('SELECT ALL')),
            ]),
            ...widget.result.days.map((day) {
              final done = widget.result.attendedDays.contains(day);
              final checked = selected.contains(day);
              return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: CheckboxListTile(
                      value: done || checked,
                      onChanged: done
                          ? null
                          : (value) => setState(() => value == true
                              ? selected.add(day)
                              : selected.remove(day)),
                      activeColor: done ? Colors.grey : AppColors.green,
                      secondary: Icon(
                          done
                              ? Icons.check_circle_rounded
                              : Icons.calendar_today_rounded,
                          color: done ? AppColors.emerald : AppColors.green),
                      title: Text(
                          DateFormat('EEEE, d MMMM')
                              .format(DateTime.parse(day)),
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(
                          done
                              ? 'Attendance already marked'
                              : checked
                                  ? 'Will be marked now'
                                  : 'Not marked',
                          style: TextStyle(
                              color:
                                  done ? AppColors.emerald : Colors.black45))));
            }),
            const SizedBox(height: 14),
            FilledButton.icon(
                onPressed: loading || selected.isEmpty ? null : mark,
                icon: loading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.how_to_reg_rounded),
                label: Text(selected.isEmpty
                    ? 'SELECT A DAY'
                    : 'CONFIRM ${selected.length} DAY${selected.length == 1 ? '' : 'S'} ATTENDANCE')),
          ])),
    );
  }

  Widget _photo(PersonProfile p) => Container(
      width: 96,
      height: 112,
      decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.gold, width: 2)),
      clipBehavior: Clip.antiAlias,
      child: p.photoUrl.isNotEmpty
          ? Image.network(p.photoUrl,
              fit: BoxFit.cover, errorBuilder: (_, __, ___) => _initial(p))
          : _initial(p));

  Color _typeColor(String type) => type == 'visitor'
      ? const Color(0xFF176B87)
      : type == 'buyer'
          ? const Color(0xFF7A4EB2)
          : AppColors.green;
  Widget _initial(PersonProfile p) => Center(
      child: Text((p.name.isNotEmpty ? p.name[0] : '?').toUpperCase(),
          style: const TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.w900,
              fontSize: 42)));
  Widget _detail(IconData icon, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(icon, size: 19, color: AppColors.green),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 9,
                        letterSpacing: 1,
                        color: Colors.black38,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w700))
              ]))
        ]));
  }
}
