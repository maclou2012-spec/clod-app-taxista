import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:taxiclod/main.dart';
import 'package:taxiclod/providers/theme_provider.dart';

void main() {
  testWidgets('Splash screen shows TaxiCLOD branding', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MyApp(themeProvider: ThemeProvider()));

    expect(find.text('Taxi CLOD'), findsOneWidget);
    expect(
      find.text(
        'El directorio digital publicitario de servicio de Taxi hecho Sólo para Taxistas',
      ),
      findsOneWidget,
    );

    // Dispose the tree so the splash screen cancels its navigation timer,
    // instead of letting it fire and navigate to the Firebase-dependent
    // phone entry screen (Firebase isn't initialized in this test).
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
