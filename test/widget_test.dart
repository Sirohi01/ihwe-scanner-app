import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ihwe_attendance/core/theme/app_theme.dart';

void main() {
  testWidgets('IHWE theme renders an app shell', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: Text('IHWE Attendance')),
    ));
    expect(find.text('IHWE Attendance'), findsOneWidget);
  });
}
