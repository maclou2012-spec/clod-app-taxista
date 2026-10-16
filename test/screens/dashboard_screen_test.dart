import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxiclod/screens/operacion/dashboard_screen.dart';
import 'package:taxiclod/services/socket_service.dart';
import 'package:taxiclod/theme/clod_theme.dart';

Widget _envolver(Widget child) {
  return MaterialApp(theme: CLODTheme.light, home: Scaffold(body: child));
}

void main() {
  group('CabeceraDashboard', () {
    testWidgets('muestra el saludo y, si hay resumen del día, los KPIs', (
      tester,
    ) async {
      await tester.pumpWidget(
        _envolver(
          CabeceraDashboard(
            nombre: 'Carlos',
            fotoPerfilUrl: null,
            socketService: SocketService(),
            resumenDia: const {
              'viajes_completados_hoy': 3,
              'ganancias_estimadas_hoy': 450.0,
            },
            onAbrirMenu: () {},
          ),
        ),
      );

      expect(find.text('Hola, Carlos'), findsOneWidget);
      expect(find.text('3 viajes hoy'), findsOneWidget);
      expect(find.text(r'$450 estimadas'), findsOneWidget);
    });

    testWidgets('sin resumen del día todavía, no muestra la fila de KPIs', (
      tester,
    ) async {
      await tester.pumpWidget(
        _envolver(
          CabeceraDashboard(
            nombre: 'Carlos',
            fotoPerfilUrl: null,
            socketService: SocketService(),
            resumenDia: null,
            onAbrirMenu: () {},
          ),
        ),
      );

      expect(find.textContaining('viajes hoy'), findsNothing);
      expect(find.textContaining('estimadas'), findsNothing);
    });

    testWidgets('un solo viaje usa el singular "viaje", no "viajes"', (
      tester,
    ) async {
      await tester.pumpWidget(
        _envolver(
          CabeceraDashboard(
            nombre: 'Carlos',
            fotoPerfilUrl: null,
            socketService: SocketService(),
            resumenDia: const {'viajes_completados_hoy': 1},
            onAbrirMenu: () {},
          ),
        ),
      );

      expect(find.text('1 viaje hoy'), findsOneWidget);
    });
  });

  group('IndicadorDisponibilidadDashboard', () {
    testWidgets('disponible=true muestra "Disponible"', (tester) async {
      await tester.pumpWidget(
        _envolver(
          IndicadorDisponibilidadDashboard(disponible: true, onTap: () {}),
        ),
      );
      expect(find.text('Disponible'), findsOneWidget);
      expect(find.text('No disponible'), findsNothing);
    });

    testWidgets('disponible=false muestra "No disponible" y abre el menú al tocar', (
      tester,
    ) async {
      var tocado = false;
      await tester.pumpWidget(
        _envolver(
          IndicadorDisponibilidadDashboard(
            disponible: false,
            onTap: () => tocado = true,
          ),
        ),
      );
      expect(find.text('No disponible'), findsOneWidget);

      await tester.tap(find.byType(IndicadorDisponibilidadDashboard));
      expect(tocado, isTrue);
    });

    testWidgets(
      'membresiaVigente=false muestra "Membresía no vigente" y el botón de renovar, no "Disponible"/"No disponible"',
      (tester) async {
        var renovado = false;
        await tester.pumpWidget(
          _envolver(
            IndicadorDisponibilidadDashboard(
              disponible: true,
              membresiaVigente: false,
              onTap: () {},
              onRenovar: () => renovado = true,
            ),
          ),
        );

        expect(find.text('Membresía no vigente'), findsOneWidget);
        expect(find.text('Disponible'), findsNothing);
        expect(find.text('No disponible'), findsNothing);

        await tester.tap(find.text('Renovar membresía'));
        expect(renovado, isTrue);
      },
    );

    testWidgets('membresiaVigente=true (por defecto) no muestra el botón de renovar', (
      tester,
    ) async {
      await tester.pumpWidget(
        _envolver(
          IndicadorDisponibilidadDashboard(disponible: true, onTap: () {}),
        ),
      );

      expect(find.text('Disponible'), findsOneWidget);
      expect(find.text('Renovar membresía'), findsNothing);
    });
  });

  group('AvisoVencimientoMembresiaDashboard', () {
    testWidgets('muestra el mensaje y llama a onRenovar al tocar "Renovar"', (
      tester,
    ) async {
      var renovado = false;
      await tester.pumpWidget(
        _envolver(
          AvisoVencimientoMembresiaDashboard(
            mensaje: 'Tu membresía vence el 20/03',
            onRenovar: () => renovado = true,
          ),
        ),
      );

      expect(find.text('Tu membresía vence el 20/03'), findsOneWidget);

      await tester.tap(find.text('Renovar'));
      expect(renovado, isTrue);
    });
  });

  group('ListaSolicitudesDashboard', () {
    testWidgets('vacía: estado compacto, sin ListView', (tester) async {
      await tester.pumpWidget(
        _envolver(ListaSolicitudesDashboard(solicitudes: const [], onTap: (_) {})),
      );

      expect(
        find.text('Sin solicitudes disponibles por ahora.'),
        findsOneWidget,
      );
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('muestra las solicitudes en el orden recibido (más reciente primero)', (
      tester,
    ) async {
      final solicitudes = [
        {'id': 3, 'origen_direccion': 'Solicitud C (más nueva)'},
        {'id': 2, 'origen_direccion': 'Solicitud B'},
        {'id': 1, 'origen_direccion': 'Solicitud A (más vieja)'},
      ];

      await tester.pumpWidget(
        _envolver(
          ListaSolicitudesDashboard(solicitudes: solicitudes, onTap: (_) {}),
        ),
      );

      expect(find.text('Solicitud C (más nueva)'), findsOneWidget);
      expect(find.text('Solicitud B'), findsOneWidget);
      expect(find.text('Solicitud A (más vieja)'), findsOneWidget);

      double dyDe(String texto) => tester.getTopLeft(find.text(texto)).dy;
      expect(
        dyDe('Solicitud C (más nueva)'),
        lessThan(dyDe('Solicitud B')),
      );
      expect(
        dyDe('Solicitud B'),
        lessThan(dyDe('Solicitud A (más vieja)')),
      );
    });

    testWidgets('tocar una fila llama a onTap con esa solicitud', (
      tester,
    ) async {
      Map<String, dynamic>? tocada;
      final solicitudes = [
        {'id': 1, 'origen_direccion': 'Av. Siempre Viva 123'},
      ];

      await tester.pumpWidget(
        _envolver(
          ListaSolicitudesDashboard(
            solicitudes: solicitudes,
            onTap: (s) => tocada = s,
          ),
        ),
      );

      await tester.tap(find.text('Av. Siempre Viva 123'));
      expect(tocada, isNotNull);
      expect(tocada!['id'], 1);
    });

    testWidgets('marca viajes con paradas o colectivos con su etiqueta', (
      tester,
    ) async {
      final solicitudes = [
        {
          'id': 1,
          'origen_direccion': 'Av. Paradas 100',
          'tipo_viaje': 'paradas_servicio',
        },
        {
          'id': 2,
          'origen_direccion': 'Calle Colectivos 200',
          'tipo_viaje': 'colectivo',
        },
        {'id': 3, 'origen_direccion': 'Calle Normal 300'},
      ];

      await tester.pumpWidget(
        _envolver(
          ListaSolicitudesDashboard(solicitudes: solicitudes, onTap: (_) {}),
        ),
      );

      expect(find.text('Paradas'), findsOneWidget);
      expect(find.text('Colectivo'), findsOneWidget);
    });
  });

  group('capa de demanda', () {
    test('celdasDemandaDesdeMapa descarta celdas sin lat/lng', () {
      final celdas = celdasDemandaDesdeMapa({
        'celdas': [
          {'lat': 19.17, 'lng': -96.13, 'intensidad': 0.8},
          {'lat': 19.18}, // sin lng -> se descarta
          {'intensidad': 0.5}, // sin coordenadas -> se descarta
        ],
      });

      expect(celdas, hasLength(1));
      expect(celdas.first.lat, 19.17);
      expect(celdas.first.lng, -96.13);
      expect(celdas.first.intensidad, 0.8);
    });

    test('celdasDemandaDesdeMapa sin la llave "celdas" -> lista vacía', () {
      expect(celdasDemandaDesdeMapa(null), isEmpty);
      expect(celdasDemandaDesdeMapa(const {}), isEmpty);
    });

    test('suficienteDatosDemandaDesdeMapa ausente -> true por defecto', () {
      expect(suficienteDatosDemandaDesdeMapa(null), isTrue);
      expect(suficienteDatosDemandaDesdeMapa(const {}), isTrue);
    });

    test('suficienteDatosDemandaDesdeMapa explícitamente false', () {
      expect(
        suficienteDatosDemandaDesdeMapa(const {'suficiente_datos': false}),
        isFalse,
      );
    });

    testWidgets('LeyendaCapaDemanda con datos muestra el texto histórico', (
      tester,
    ) async {
      await tester.pumpWidget(
        _envolver(const LeyendaCapaDemanda(suficienteDatos: true)),
      );
      expect(
        find.textContaining('Zonas con más solicitudes'),
        findsOneWidget,
      );
      expect(
        find.textContaining('recomendado'),
        findsNothing,
      );
    });

    testWidgets('LeyendaCapaDemanda sin datos suficientes avisa en vez de mostrar el histórico', (
      tester,
    ) async {
      await tester.pumpWidget(
        _envolver(const LeyendaCapaDemanda(suficienteDatos: false)),
      );
      expect(
        find.text('Aún no hay suficiente información de demanda'),
        findsOneWidget,
      );
      expect(find.textContaining('Zonas con más solicitudes'), findsNothing);
    });
  });

  group('conNuevaSolicitudAlFrente', () {
    test('agrega la nueva al principio de la lista', () {
      final actuales = [
        {'id': 1, 'x': 'vieja'},
      ];
      final resultado = conNuevaSolicitudAlFrente(actuales, {
        'id': 2,
        'x': 'nueva',
      });

      expect(resultado.first['id'], 2);
      expect(resultado.last['id'], 1);
      expect(resultado, hasLength(2));
    });

    test('no duplica si ya existía el mismo id', () {
      final actuales = [
        {'id': 1, 'x': 'vieja'},
        {'id': 2, 'x': 'otra'},
      ];
      final resultado = conNuevaSolicitudAlFrente(actuales, {
        'id': 1,
        'x': 'actualizada',
      });

      expect(resultado, hasLength(2));
      expect(resultado.first['x'], 'actualizada');
    });
  });
}
