import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../attendance/data/attendance_repository.dart';
import 'widgets/person_confirmation_sheet.dart';

class ManualLookupScreen extends StatefulWidget {
  const ManualLookupScreen({super.key, required this.repository});
  final AttendanceRepository repository;
  @override
  State<ManualLookupScreen> createState() => _ManualLookupScreenState();
}

class _ManualLookupScreenState extends State<ManualLookupScreen> {
  final search = TextEditingController();
  Timer? debounce;
  List<Map<String, dynamic>> items = [];
  bool loading = false;
  Object? error;

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  Future<void> load(String value) async {
    if (value.trim().length < 2) {
      setState(() => items = []);
      return;
    }
    setState(() => loading = true);
    try {
      final result = await widget.repository.manualSearch(value.trim());
      if (mounted) {
        setState(() {
          items = result;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> open(Map<String, dynamic> item) async {
    final id = item['registrationId']?.toString() ?? '';
    final result = await widget.repository.resolve(id, source: 'manual');
    if (!mounted) return;
    final marked = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => PersonConfirmationSheet(
            result: result,
            raw: id,
            repository: widget.repository,
            source: 'manual'));
    if (marked == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Manual Lookup')),
        body: Column(children: [
          Padding(
              padding: const EdgeInsets.all(14),
              child: TextField(
                controller: search,
                autofocus: true,
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.manage_search_rounded),
                    hintText: 'Name, mobile, email or registration ID'),
                onChanged: (value) {
                  debounce?.cancel();
                  debounce = Timer(
                      const Duration(milliseconds: 450), () => load(value));
                },
              )),
          Expanded(
              child: loading
                  ? const AppListSkeleton()
                  : items.isEmpty
                      ? Center(
                          child: Text(error?.toString() ??
                              (search.text.length < 2
                                  ? 'Type at least 2 characters'
                                  : 'No registration found.')))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 80),
                          itemCount: items.length,
                          itemExtent: items.length > 7 ? 72 : null,
                          itemBuilder: (_, index) {
                            final item = items[index];
                            final photo = resolveApiAssetUrl(item['photoUrl']);
                            final rawName = item['name']?.toString() ?? '';
                            return Card(
                                margin: const EdgeInsets.only(bottom: 6),
                                child: ListTile(
                                  dense: true,
                                  onTap: () => open(item),
                                  leading: CircleAvatar(
                                      backgroundImage: photo.isNotEmpty
                                          ? NetworkImage(photo)
                                          : null,
                                      child: photo.isEmpty
                                          ? const Icon(Icons.person_rounded)
                                          : null),
                                  title: Text(
                                      rawName.isNotEmpty
                                          ? rawName
                                          : item['company']?.toString() ??
                                              'Registration',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w900)),
                                  subtitle: Text(
                                      '${item['registrationId'] ?? ''} • ${item['type'] ?? ''}'),
                                  trailing: const Icon(Icons.how_to_reg_rounded,
                                      color: AppColors.green),
                                ));
                          },
                        )),
        ]),
      );
}
