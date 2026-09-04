import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mchart/src/features/auth/login_screen.dart';
import 'package:mchart/src/theme/app_theme.dart';
import 'package:mchart/src/widgets/pills.dart';
import 'package:mchart/src/widgets/primitives.dart';

void main() {
  testWidgets('login screen renders its key fields', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light(), home: const LoginScreen()),
      ),
    );
    expect(find.text('Barua Pepe'), findsOneWidget);
    expect(find.text('Nenosiri'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Ingia Kazini'), findsOneWidget);
  });

  testWidgets('core widgets render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Column(
            children: [
              const AppCard(child: Text('card')),
              StatusPill.success('OK'),
              const TrendChip(delta: 8),
            ],
          ),
        ),
      ),
    );
    expect(find.text('card'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
  });
}
