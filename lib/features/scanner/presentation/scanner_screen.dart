import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../attendance/data/attendance_repository.dart';
import 'widgets/person_confirmation_sheet.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key, required this.repository});
  final AttendanceRepository repository;
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates);
  final manual = TextEditingController();
  bool busy = false;

  Future<void> process(String raw) async {
    if (busy || raw.trim().isEmpty) return;
    setState(() => busy = true);
    await controller.stop();
    try {
      final result = await widget.repository.resolve(raw);
      if (!mounted) return;
      final marked = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => PersonConfirmationSheet(
            result: result, raw: raw, repository: widget.repository),
      );
      if (marked == true && mounted) {
        Navigator.pop(context, true);
      } else {
        setState(() => busy = false);
        await controller.start();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.message),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade700));
        setState(() => busy = false);
        await controller.start();
      }
    }
  }

  @override
  void dispose() {
    controller.dispose();
    manual.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.navy,
        appBar: AppBar(
            backgroundColor: AppColors.navy,
            foregroundColor: Colors.white,
            title: const Text('Scan Entry QR',
                style: TextStyle(fontWeight: FontWeight.w900)),
            actions: [
              ValueListenableBuilder(
                  valueListenable: controller,
                  builder: (_, state, __) => IconButton(
                      onPressed: controller.toggleTorch,
                      icon: Icon(state.torchState == TorchState.on
                          ? Icons.flash_on_rounded
                          : Icons.flash_off_rounded)))
            ]),
        body: Column(children: [
          Expanded(
              child: Stack(fit: StackFit.expand, children: [
            MobileScanner(
                controller: controller,
                onDetect: (capture) {
                  final value = capture.barcodes.firstOrNull?.rawValue;
                  if (value != null) process(value);
                }),
            Container(
                decoration: ShapeDecoration(
                    shape: QrScannerOverlayShape(
                        borderColor: AppColors.gold,
                        borderRadius: 22,
                        borderLength: 38,
                        borderWidth: 5,
                        cutOutSize: MediaQuery.sizeOf(context).width * .70),
                    color: Colors.black.withValues(alpha: .55))),
            Positioned(
                left: 24,
                right: 24,
                bottom: 26,
                child: Column(children: [
                  if (busy)
                    const CircularProgressIndicator(color: AppColors.gold)
                  else
                    const Icon(Icons.qr_code_2_rounded,
                        color: AppColors.gold, size: 32),
                  const SizedBox(height: 10),
                  const Text('Align any IHWE QR inside the frame',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  const Text('Visitor • Buyer • Exhibitor',
                      style: TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                          letterSpacing: 1)),
                ])),
          ])),
          Container(
              color: AppColors.navy,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              child: Row(children: [
                Expanded(
                    child: TextField(
                        controller: manual,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                            hintText: 'Enter registration ID manually',
                            hintStyle: const TextStyle(color: Colors.white38),
                            fillColor: Colors.white.withValues(alpha: .08),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide:
                                    const BorderSide(color: Colors.white12))))),
                const SizedBox(width: 10),
                IconButton.filled(
                    onPressed: () => process(manual.text),
                    style: IconButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.navy,
                        minimumSize: const Size(54, 54)),
                    icon: const Icon(Icons.arrow_forward_rounded)),
              ])),
        ]),
      );
}

class QrScannerOverlayShape extends ShapeBorder {
  const QrScannerOverlayShape(
      {required this.borderColor,
      this.borderRadius = 16,
      this.borderLength = 30,
      this.borderWidth = 4,
      required this.cutOutSize});
  final Color borderColor;
  final double borderRadius, borderLength, borderWidth, cutOutSize;
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRect(rect);
  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    final cut = Rect.fromCenter(
        center: rect.center, width: cutOutSize, height: cutOutSize);
    return Path()
      ..addRRect(RRect.fromRectAndRadius(cut, Radius.circular(borderRadius)));
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final cut = Rect.fromCenter(
        center: rect.center, width: cutOutSize, height: cutOutSize);
    final p = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;
    final r = borderRadius, l = borderLength;
    for (final path in [
      Path()
        ..moveTo(cut.left, cut.top + l)
        ..lineTo(cut.left, cut.top + r)
        ..quadraticBezierTo(cut.left, cut.top, cut.left + r, cut.top)
        ..lineTo(cut.left + l, cut.top),
      Path()
        ..moveTo(cut.right - l, cut.top)
        ..lineTo(cut.right - r, cut.top)
        ..quadraticBezierTo(cut.right, cut.top, cut.right, cut.top + r)
        ..lineTo(cut.right, cut.top + l),
      Path()
        ..moveTo(cut.left, cut.bottom - l)
        ..lineTo(cut.left, cut.bottom - r)
        ..quadraticBezierTo(cut.left, cut.bottom, cut.left + r, cut.bottom)
        ..lineTo(cut.left + l, cut.bottom),
      Path()
        ..moveTo(cut.right - l, cut.bottom)
        ..lineTo(cut.right - r, cut.bottom)
        ..quadraticBezierTo(cut.right, cut.bottom, cut.right, cut.bottom - r)
        ..lineTo(cut.right, cut.bottom - l),
    ]) {
      canvas.drawPath(path, p);
    }
  }

  @override
  ShapeBorder scale(double t) => this;
}
