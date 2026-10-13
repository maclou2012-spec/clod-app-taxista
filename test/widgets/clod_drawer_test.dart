import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:taxiclod/providers/disponibilidad_provider.dart';
import 'package:taxiclod/providers/theme_provider.dart';
import 'package:taxiclod/services/api_service.dart';
import 'package:taxiclod/theme/clod_theme.dart';
import 'package:taxiclod/widgets/clod_drawer.dart';

// ClodDrawer y DisponibilidadProvider piden datos del taxista al montarse.
// Con el ApiService real (sin timeout configurado) esas llamadas intentan
// conectar de verdad y dejan un Timer pendiente al terminar el test —
// aquí se inyecta un ApiService con un Dio que falla casi al instante
// (host inválido + timeout de 1ms), así los catches de cada pantalla
// resuelven rápido y lo único que se pierde es el nombre/estado reales,
// que no son lo que este test verifica (el ORDEN del menú sí lo es).
ApiService _apiServiceQueFallaRapido() {
  return ApiService(
    dio: Dio(
      BaseOptions(
        baseUrl: 'http://10.255.255.1',
        connectTimeout: const Duration(milliseconds: 1),
        receiveTimeout: const Duration(milliseconds: 1),
      ),
    ),
  );
}

Widget _envolver() {
  final apiService = _apiServiceQueFallaRapido();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<DisponibilidadProvider>(
        create: (_) => DisponibilidadProvider(apiService: apiService),
      ),
    ],
    child: MaterialApp(
      theme: CLODTheme.dark,
      home: Scaffold(body: ClodDrawer(apiService: apiService)),
    ),
  );
}

// Con "Mi cuenta" expandido de entrada, el menú completo (encabezado +
// switch + los 8 hijos de Mi cuenta + los 4 ítems de primer nivel) no cabe
// en el viewport por defecto de flutter_test (800x600) — el ListView, al
// ser perezoso, ni siquiera construye lo que queda fuera. Un viewport más
// alto deja ver todo sin tener que scrollear.
Future<void> _agrandarViewport(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(400, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  testWidgets(
    'orden del menú: switch de disponibilidad debajo del encabezado, '
    '"Mi cuenta" primero y expandido, luego Historial/Referidos/Panel/Ayuda',
    (tester) async {
      await _agrandarViewport(tester);
      await tester.pumpWidget(_envolver());
      await tester.pump(const Duration(milliseconds: 100));

      // El switch de disponibilidad ya no está en el Dashboard — ahora
      // vive aquí, justo debajo del encabezado.
      expect(find.text('Disponibilidad voluntaria'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsOneWidget);

      expect(find.text('Mi cuenta'), findsOneWidget);
      expect(find.text('Historial de viajes'), findsOneWidget);
      expect(find.text('Mis referidos'), findsOneWidget);
      expect(find.text('Panel'), findsOneWidget);
      expect(find.text('Ayuda y soporte'), findsOneWidget);

      double dyDe(String texto) =>
          tester.getTopLeft(find.text(texto)).dy;

      final dySwitch = dyDe('Disponibilidad voluntaria');
      final dyMiCuenta = dyDe('Mi cuenta');
      final dyHistorial = dyDe('Historial de viajes');
      final dyReferidos = dyDe('Mis referidos');
      final dyPanel = dyDe('Panel');
      final dyAyuda = dyDe('Ayuda y soporte');

      expect(dySwitch, lessThan(dyMiCuenta));
      expect(dyMiCuenta, lessThan(dyHistorial));
      expect(dyHistorial, lessThan(dyReferidos));
      expect(dyReferidos, lessThan(dyPanel));
      expect(dyPanel, lessThan(dyAyuda));
    },
  );

  testWidgets(
    '"Mi cuenta" viene expandido de entrada, con todo lo que tenían Mi '
    'perfil y Configuración, en el orden pedido',
    (tester) async {
      await _agrandarViewport(tester);
      await tester.pumpWidget(_envolver());
      await tester.pump(const Duration(milliseconds: 100));

      final itemsEsperados = [
        'Mi vehículo',
        'Mi tarifa',
        'Mis documentos',
        'Mis pagos y facturas',
        'Contacto de emergencia',
        'Contrato de licenciatario',
        'Modo oscuro',
        'Cerrar sesión',
      ];
      for (final item in itemsEsperados) {
        expect(find.text(item), findsOneWidget, reason: 'falta "$item"');
      }

      double dyDe(String texto) => tester.getTopLeft(find.text(texto)).dy;
      for (var i = 0; i < itemsEsperados.length - 1; i++) {
        expect(
          dyDe(itemsEsperados[i]),
          lessThan(dyDe(itemsEsperados[i + 1])),
          reason:
              '"${itemsEsperados[i]}" debería ir antes que '
              '"${itemsEsperados[i + 1]}"',
        );
      }
    },
  );

  testWidgets(
    '"Mi perfil" y "Configuración" ya no existen como ítems del menú',
    (tester) async {
      await _agrandarViewport(tester);
      await tester.pumpWidget(_envolver());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Mi perfil'), findsNothing);
      expect(find.text('Configuración'), findsNothing);
    },
  );
}
