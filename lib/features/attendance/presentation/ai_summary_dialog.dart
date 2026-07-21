import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../data/attendance_repository.dart';

Future<void> showAiSummaryDialog(
  BuildContext context, {
  required AttendanceRepository repository,
  required String scope,
  String? id,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _AiSummarySheet(
        repository: repository, scope: scope, id: id),
  );
}

class _AiSummarySheet extends StatefulWidget {
  const _AiSummarySheet(
      {required this.repository, required this.scope, this.id});

  final AttendanceRepository repository;
  final String scope;
  final String? id;

  @override
  State<_AiSummarySheet> createState() => _AiSummarySheetState();
}

class _AiSummarySheetState extends State<_AiSummarySheet> {
  String? summary;
  Object? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      summary = null;
      error = null;
    });
    try {
      final result =
          await widget.repository.aiSummary(widget.scope, id: widget.id);
      if (mounted) setState(() => summary = result);
    } catch (value) {
      if (mounted) setState(() => error = value);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .86),
        decoration: const BoxDecoration(
          color: Color(0xFFF5F7FA),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 10, 12),
            decoration: const BoxDecoration(
              gradient:
                  LinearGradient(colors: [AppColors.navy, AppColors.green]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: AppColors.gold),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('${widget.scope.toUpperCase()} AI SUMMARY',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .7)),
                  const Text('Generated from live attendance data',
                      style: TextStyle(color: Colors.white60, fontSize: 9)),
                ]),
              ),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white)),
            ]),
          ),
          Flexible(
            child: summary == null
                ? Padding(
                    padding: const EdgeInsets.all(38),
                    child: error == null
                        ? const AppSkeleton(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SkeletonBox(
                                      width: 190, height: 16, radius: 7),
                                  SizedBox(height: 14),
                                  SkeletonBox(height: 58, radius: 12),
                                  SizedBox(height: 9),
                                  SkeletonBox(height: 58, radius: 12),
                                  SizedBox(height: 12),
                                  Text('Analysing attendance data...')
                                ]),
                          )
                        : Column(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.error_outline_rounded,
                                color: Colors.redAccent, size: 38),
                            const SizedBox(height: 10),
                            Text('$error', textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                                onPressed: load,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Retry')),
                          ]),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                    child: _formattedSummary(summary!),
                  ),
          ),
        ]),
      );

  Widget _formattedSummary(String raw) {
    final lines = raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines.map(_summaryLine).toList(),
      ),
    );
  }

  Widget _summaryLine(String rawLine) {
    final markdownHeading = RegExp(r'^#{1,6}\s*(.+)$').firstMatch(rawLine);
    final boldHeading = RegExp(r'^\*\*(.+?)\*\*:?$').firstMatch(rawLine);
    final heading = markdownHeading?.group(1) ?? boldHeading?.group(1);
    if (heading != null) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 7, bottom: 7),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            AppColors.green.withValues(alpha: .13),
            AppColors.gold.withValues(alpha: .14),
          ]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.green.withValues(alpha: .22)),
        ),
        child: Row(children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(heading.replaceAll('**', '').trim(),
                style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .2)),
          ),
        ]),
      );
    }

    final isBullet = RegExp(r'^[-*•]\s+').hasMatch(rawLine);
    final line = rawLine.replaceFirst(RegExp(r'^[-*•]\s+'), '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 3, right: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: isBullet ? 7 : 4,
          height: isBullet ? 7 : 4,
          margin: const EdgeInsets.only(top: 7, right: 10),
          decoration: BoxDecoration(
            color: isBullet ? AppColors.gold : AppColors.green,
            shape: BoxShape.circle,
          ),
        ),
        Expanded(child: Text.rich(_inlineMarkdown(line))),
      ]),
    );
  }

  TextSpan _inlineMarkdown(String text) {
    final spans = <TextSpan>[];
    final boldPattern = RegExp(r'\*\*(.+?)\*\*', dotAll: true);
    var cursor = 0;
    for (final match in boldPattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: AppColors.navy,
          fontSize: 14,
        ),
      ));
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return TextSpan(
      style: const TextStyle(
        height: 1.48,
        fontSize: 12.5,
        color: Color(0xFF334E68),
        fontWeight: FontWeight.w600,
      ),
      children: spans,
    );
  }
}
