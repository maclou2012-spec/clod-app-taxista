import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:taxiclod/main.dart';

void main() {
  testWidgets('Splash screen shows TaxiCLOD branding', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

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
