import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/domain/attendance_categories.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.repository});
  final AttendanceRepository repository;
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final search = TextEditingController();
  List<Map<String, dynamic>> records = [];
  bool loading = true;
  String type = '';
  String subType = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      records = await widget.repository
          .records(type: type, subType: subType, search: search.text);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          toolbarHeight: 80,
          title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Attendance Log',
                    style:
                        TextStyle(fontWeight: FontWeight.w900, fontSize: 26)),
                Text('Verified entry records',
                    style: TextStyle(fontSize: 12, color: Colors.black45)),
              ]),
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
            child: TextField(
              controller: search,
              onSubmitted: (_) => load(),
              decoration: InputDecoration(
                hintText: 'Search name, ID, company, mobile...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                    onPressed: load,
                    icon: const Icon(Icons.arrow_forward_rounded)),
              ),
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              scrollDirection: Axis.horizontal,
              children: attendanceTypes
                  .map((item) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(item.label),
                          selected: type == item.value,
                          onSelected: (_) {
                            type = item.value;
                            subType = '';
                            load();
                          },
                        ),
                      ))
                  .toList(),
            ),
          ),
          if (type.isNotEmpty) ...[
            const SizedBox(height: 7),
            SizedBox(
              height: 38,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                scrollDirection: Axis.horizontal,
                children: [
                  _subTypeChip('', 'All ${attendanceLabel(type)}'),
                  ...subTypesFor(type)
                      .map((item) => _subTypeChip(item.value, item.label)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Expanded(child: _body()),
        ]),
      );

  Widget _body() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (records.isEmpty) {
      return const Center(child: Text('No attendance records found.'));
    }
    return RefreshIndicator(
      onRefresh: load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 110),
        itemCount: records.length,
        itemBuilder: (_, i) => _recordCard(records[i]),
      ),
    );
  }

  Widget _subTypeChip(String value, String label) => Padding(
        padding: const EdgeInsets.only(right: 7),
        child: ChoiceChip(
          label: Text(label),
          selected: subType == value,
          selectedColor: AppColors.green,
          labelStyle: TextStyle(
              color: subType == value ? Colors.white : AppColors.ink,
              fontSize: 10,
              fontWeight: FontWeight.w700),
          onSelected: (_) {
            subType = value;
            load();
          },
        ),
      );

  Widget _recordCard(Map<String, dynamic> record) {
    final time = DateTime.tryParse(record['markedAt']?.toString() ?? '');
    final subjectType = record['subjectType']?.toString();
    final icon = subjectType == 'buyer'
        ? Icons.handshake_rounded
        : subjectType == 'exhibitor'
            ? Icons.storefront_rounded
            : Icons.person_rounded;
    final name = record['name']?.toString() ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: AppColors.green),
        ),
        title: Text(
            name.isNotEmpty
                ? name
                : record['registrationId']?.toString() ?? '-',
            maxLines: 1,
            style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(
            '${attendanceLabel(record['subjectSubType'] ?? subjectType ?? '')} • ${record['registrationId'] ?? ''}\n${record['company'] ?? ''}',
            maxLines: 2),
        isThreeLine: true,
        trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                  DateFormat('d MMM')
                      .format(DateTime.parse(record['eventDay'])),
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, color: AppColors.green)),
              if (time != null)
                Text(DateFormat('h:mm a').format(time.toLocal()),
                    style:
                        const TextStyle(fontSize: 10, color: Colors.black38)),
            ]),
      ),
    );
  }
}
