import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../attendance/data/attendance_repository.dart';

class DeviceHealthScreen extends StatefulWidget {
  const DeviceHealthScreen({super.key, required this.repository});

  final AttendanceRepository repository;

  @override
  State<DeviceHealthScreen> createState() => _DeviceHealthScreenState();
}

class _DeviceHealthScreenState extends State<DeviceHealthScreen> {
  Map<String, dynamic>? server;
  Map<String, dynamic>? device;
  String? lastScan;
  Object? error;
  int roundTripMs = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => error = null);
    final watch = Stopwatch()..start();
    try {
      final values = await Future.wait([
        widget.repository.deviceHealth(),
        widget.repository.localDeviceHealth(),
        widget.repository.lastSuccessfulScan(),
      ]);
      watch.stop();
      if (!mounted) return;
      setState(() {
        server = Map<String, dynamic>.from(values[0] as Map);
        device = Map<String, dynamic>.from(values[1] as Map);
        lastScan = values[2] as String?;
        roundTripMs = watch.elapsedMilliseconds;
      });
    } catch (value) {
      watch.stop();
      if (mounted) setState(() => error = value);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Device Health Centre'),
          actions: [
            IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded))
          ],
        ),
        body: server == null
            ? Center(
                child: error == null
                    ? const AppProfileSkeleton()
                    : Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.cloud_off_rounded,
                            color: Colors.red, size: 42),
                        const SizedBox(height: 10),
                        Text('$error', textAlign: TextAlign.center),
                        FilledButton(
                            onPressed: load, child: const Text('Retry checks'))
                      ]))
            : RefreshIndicator(
                onRefresh: load,
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [AppColors.navy, AppColors.green]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(children: [
                      Icon(Icons.health_and_safety_rounded,
                          color: AppColors.gold, size: 34),
                      SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('SYSTEM READY',
                                style: TextStyle(
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.1)),
                            Text('Live hardware and service diagnostics',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 10)),
                          ]))
                    ]),
                  ),
                  const SizedBox(height: 14),
                  _section('CONNECTIVITY', [
                    _check('API connectivity', server!['api'] == 'online',
                        '$roundTripMs ms round trip'),
                    _check('Database', server!['database'] == 'online',
                        '${server!['backendLatencyMs'] ?? 0} ms backend'),
                    _check(
                        'Event configuration',
                        server!['eventId']?.toString().isNotEmpty == true,
                        server!['eventName']?.toString() ?? ''),
                  ]),
                  const SizedBox(height: 12),
                  _section('CAMERA & DEVICE', [
                    _check(
                        'Camera hardware',
                        device?['cameraAvailable'] == true,
                        device?['cameraAvailable'] == true
                            ? 'Available'
                            : 'Not detected'),
                    _check(
                        'Camera permission',
                        device?['cameraPermissionGranted'] == true,
                        device?['cameraPermissionGranted'] == true
                            ? 'Granted'
                            : 'Open scanner once to grant permission'),
                    _check('Android device', true,
                        '${device?['manufacturer'] ?? ''} ${device?['model'] ?? ''} • Android ${device?['androidVersion'] ?? ''}'),
                  ]),
                  const SizedBox(height: 12),
                  _section('SCANNER ACTIVITY', [
                    _check(
                        'Last successful scan',
                        lastScan != null,
                        lastScan == null
                            ? 'No successful scan recorded on this device'
                            : DateFormat('d MMM yyyy, h:mm:ss a')
                                .format(DateTime.parse(lastScan!).toLocal())),
                  ]),
                ]),
              ),
      );

  Widget _section(String title, List<Widget> children) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFFE1E8E4))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.black45,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1)),
          const SizedBox(height: 7),
          ...children,
        ]),
      );

  Widget _check(String label, bool healthy, String detail) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: (healthy ? AppColors.emerald : Colors.orange)
                    .withValues(alpha: .11),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(
                healthy
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,
                color: healthy ? AppColors.emerald : Colors.orange,
                size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10.5, fontWeight: FontWeight.w900)),
                Text(detail,
                    style:
                        const TextStyle(fontSize: 8.5, color: Colors.black45)),
              ])),
        ]),
      );
}
