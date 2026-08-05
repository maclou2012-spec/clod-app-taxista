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

    // Flush the splash screen's navigation timer before the test ends.
    await tester.pump(const Duration(seconds: 3));
  });
}
