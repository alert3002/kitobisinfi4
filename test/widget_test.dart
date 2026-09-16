import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitobho/screens/home_screen.dart';
import 'package:kitobho/theme/app_theme.dart';

void main() {
  testWidgets('Home shows grade 1 title', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();
    expect(find.text('Синфи 1'), findsWidgets);
  });

  test('Theme builds', () {
    expect(AppTheme.light.useMaterial3, isTrue);
  });
}
