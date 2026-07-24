import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/config/app_config.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../attendance/data/attendance_repository.dart';
import '../../../attendance/domain/attendance_categories.dart';
import '../../../attendance/domain/attendance_models.dart';
import '../../../dashboard/presentation/company_detail_screen.dart';

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
  bool changingStatus = false;
  int lunchQuantity = 1;
  late String buyerStatus;
  Map<String, dynamic>? concierge;
  Object? conciergeError;

  bool get isInternationalBuyer =>
      widget.result.person.subType == 'international-buyer';
  bool get canMark => !isInternationalBuyer || buyerStatus == 'Approved';
  bool get isLunch => widget.result.person.passType == 'lunch';
  int get allocatedLunch =>
      int.tryParse(widget.result.person.details['allocatedQuantity']?.toString() ?? '') ?? 1;
  int deliveredForDay(String day) {
    final record = widget.result.attendance.cast<Map<String, dynamic>?>().firstWhere(
        (item) => item?['eventDay']?.toString() == day,
        orElse: () => null);
    return int.tryParse(record?['deliveredQuantity']?.toString() ?? '') ?? 0;
  }
  int remainingForDay(String day) =>
      (allocatedLunch - deliveredForDay(day)).clamp(0, allocatedLunch);

  @override
  void initState() {
    super.initState();
    buyerStatus = widget.result.person.status.isEmpty
        ? 'Pending'
        : widget.result.person.status;
    final open = widget.result.days.where((day) =>
        isLunch ? remainingForDay(day) > 0 : !widget.result.attendedDays.contains(day)).toList();
    if (open.isNotEmpty && canMark) selected.add(open.first);
    if (widget.result.person.type == 'buyer') _loadConcierge();
  }

  Future<void> _loadConcierge() async {
    try {
      final value =
          await widget.repository.buyerConcierge(widget.result.person.id);
      if (mounted) setState(() => concierge = value);
    } catch (error) {
      if (mounted) setState(() => conciergeError = error);
    }
  }

  Future<void> changeBuyerStatus(String status) async {
    if (changingStatus || status == buyerStatus) return;
    setState(() => changingStatus = true);
    try {
      final updated = await widget.repository
          .updateBuyerStatus(widget.result.person.id, status);
      if (!mounted) return;
      setState(() {
        buyerStatus = updated;
        selected.clear();
        if (canMark) {
          final open = widget.result.days
              .where((day) => !widget.result.attendedDays.contains(day))
              .toList();
          if (open.isNotEmpty) selected.add(open.first);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Buyer status changed to $updated.'),
        backgroundColor:
            updated == 'Approved' ? AppColors.emerald : Colors.orange.shade800,
        behavior: SnackBarBehavior.floating,
      ));
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => changingStatus = false);
    }
  }

  Future<void> mark() async {
    if (!canMark || selected.isEmpty) return;
    setState(() => loading = true);
    try {
      final results = await widget.repository
          .mark(widget.raw, selected.toList(), source: widget.source,
              quantity: isLunch ? lunchQuantity : null);
      if (!mounted) return;
      final created = results.where((item) =>
          item['created'] == true || item['deliveryRecorded'] == true).length;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(created > 0
            ? isLunch
                ? '$lunchQuantity lunch item(s) recorded for $created day(s).'
                : 'Attendance marked for $created day(s).'
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
                        _detail(Icons.verified_outlined, 'Status',
                            isInternationalBuyer ? buyerStatus : person.status),
                      ]),
                    ),
                  ),
                  if (isInternationalBuyer) ...[
                    const SizedBox(height: 10),
                    _buyerApprovalPanel(),
                  ],
                  if (person.type == 'buyer') ...[
                    const SizedBox(height: 10),
                    _conciergePanel(),
                  ],
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
                              Text('PREVIOUS ACTIVITY',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.green))
                            ]),
                            const SizedBox(height: 5),
                            Builder(builder: (context) {
                              final latest = widget.result.attendance.first;
                              final status =
                                  latest['acknowledgementStatus']?.toString() ??
                                      'pending';
                              final label = status == 'confirmed'
                                  ? 'CONFIRMED BY EXHIBITOR'
                                  : status == 'disputed'
                                      ? 'ISSUE REPORTED BY EXHIBITOR'
                                      : 'AWAITING EXHIBITOR CONFIRMATION';
                              final color = status == 'confirmed'
                                  ? AppColors.emerald
                                  : status == 'disputed'
                                      ? Colors.red.shade700
                                      : Colors.orange.shade800;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(children: [
                                  Icon(
                                      status == 'confirmed'
                                          ? Icons.verified_rounded
                                          : status == 'disputed'
                                              ? Icons.warning_rounded
                                              : Icons.hourglass_top_rounded,
                                      size: 15,
                                      color: color),
                                  const SizedBox(width: 5),
                                  Text(label,
                                      style: TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w900,
                                          color: color)),
                                ]),
                              );
                            }),
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
                  if (isLunch) ...[
                    _lunchQuantitySelector(),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          person.passType.isNotEmpty
                              ? 'PASS ACTIVITY DAYS'
                              : 'ATTENDANCE DAYS',
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
        if (!canMark) return;
        selected
          ..clear()
          ..addAll(widget.result.days.where((day) => isLunch
              ? remainingForDay(day) > 0
              : !widget.result.attendedDays.contains(day)));
      });

  Widget _dayTile(String day) {
    final delivered = deliveredForDay(day);
    final remaining = remainingForDay(day);
    final done = isLunch ? remaining == 0 : widget.result.attendedDays.contains(day);
    final checked = selected.contains(day);
    return Card(
      margin: const EdgeInsets.only(bottom: 7),
      child: CheckboxListTile(
        dense: true,
        visualDensity: const VisualDensity(vertical: -2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
        value: done || checked,
        onChanged: done || !canMark
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
          isLunch
              ? '$delivered of $allocatedLunch delivered • $remaining remaining'
              : done
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

  Widget _lunchQuantitySelector() {
    final selectedRemaining = selected.isEmpty
        ? allocatedLunch
        : selected.map(remainingForDay).reduce((a, b) => a < b ? a : b);
    if (lunchQuantity > selectedRemaining && selectedRemaining > 0) {
      lunchQuantity = selectedRemaining;
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('LUNCH DELIVERY QUANTITY',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
              SizedBox(height: 3),
              Text('Enter how many lunches are being handed over now.',
                  style: TextStyle(fontSize: 9, color: Colors.black54)),
            ]),
          ),
          IconButton(
            onPressed: lunchQuantity > 1
                ? () => setState(() => lunchQuantity--)
                : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text('$lunchQuantity',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          IconButton(
            onPressed: lunchQuantity < selectedRemaining
                ? () => setState(() => lunchQuantity++)
                : null,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ]),
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
            onPressed: loading || !canMark || selected.isEmpty ? null : mark,
            icon: loading
                ? const SizedBox.square(
                    dimension: 19,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.how_to_reg_rounded, size: 20),
            label: Text(!canMark
                ? 'APPROVE BUYER TO MARK ATTENDANCE'
                : selected.isEmpty
                    ? 'SELECT AN EVENT DAY'
                    : widget.result.person.passType.isNotEmpty
                        ? 'RECORD ${widget.result.person.passType.toUpperCase()} ACTIVITY'
                        : 'MARK ATTENDANCE | ${selected.length} DAY${selected.length == 1 ? '' : 'S'}'),
          ),
        ),
      );

  Widget _buyerApprovalPanel() {
    final approved = buyerStatus == 'Approved';
    final rejected = buyerStatus == 'Rejected';
    final color = approved
        ? AppColors.emerald
        : rejected
            ? Colors.red.shade700
            : Colors.orange.shade800;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        border: Border.all(color: color.withValues(alpha: .45)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(
              approved
                  ? Icons.verified_rounded
                  : rejected
                      ? Icons.cancel_rounded
                      : Icons.pending_rounded,
              size: 19,
              color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Text('BUYER IS ${buyerStatus.toUpperCase()}',
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w900)),
          ),
          if (changingStatus)
            SizedBox.square(
                dimension: 17,
                child: CircularProgressIndicator(strokeWidth: 2, color: color)),
        ]),
        if (!approved) ...[
          const SizedBox(height: 5),
          const Text(
              'Attendance is blocked until this buyer is approved. Verify the buyer and update the status here.',
              style: TextStyle(fontSize: 9.5, height: 1.35)),
        ],
        const SizedBox(height: 9),
        Row(children: [
          _statusButton('Approved', Icons.check_rounded, AppColors.emerald),
          const SizedBox(width: 6),
          _statusButton('Pending', Icons.schedule_rounded, Colors.orange),
          const SizedBox(width: 6),
          _statusButton('Rejected', Icons.close_rounded, Colors.red),
        ]),
      ]),
    );
  }

  Widget _conciergePanel() {
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
        if (concierge == null && conciergeError == null)
          const Row(children: [
            SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 8),
            Text('Matching buyer interests with exhibitors...',
                style: TextStyle(fontSize: 9.5)),
          ])
        else if (conciergeError != null)
          TextButton.icon(
              onPressed: _loadConcierge,
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
    return InkWell(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => CompanyDetailScreen(
                  companyId: item['companyId'].toString(),
                  repository: widget.repository))),
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

  Widget _statusButton(String status, IconData icon, Color color) => Expanded(
        child: OutlinedButton.icon(
          onPressed: changingStatus || buyerStatus == status
              ? null
              : () => changeBuyerStatus(status),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            foregroundColor: color,
            side: BorderSide(color: color.withValues(alpha: .45)),
          ),
          icon: Icon(icon, size: 14),
          label: Text(status,
              style:
                  const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900)),
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
