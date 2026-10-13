import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxiclod/models/parada_viaje.dart';
import 'package:taxiclod/screens/operacion/viaje_en_curso_screen.dart';
import 'package:taxiclod/theme/clod_theme.dart';

// SeccionViajeEnCursoConParadas no depende de Mapbox/geolocalización (a
// diferencia de ViajeEnCursoScreen completa) — se puede pumpear con un árbol
// de widgets real. Cubre exactamente lo pedido: 0/1/2/3 paradas, omitiendo
// una, y el estado "inconsistente" que corresponde al caso donde
// completarViaje devolvería un 409 que el backend no supo explicar con
// ninguno de los tres siguiente_paso esperados — siempre debe quedar
// exactamente una acción disponible.

ParadaViaje _parada(int id, String estado, {String tipo = 'servicio'}) {
  return ParadaViaje(
    id: id,
    orden: id,
    tipo: tipo,
    direccion: 'Parada $id',
    estado: estado,
  );
}

Widget _envolver(Widget child) {
  return MaterialApp(
    theme: CLODTheme.dark,
    home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
  );
}

void main() {
  group('SeccionViajeEnCursoConParadas — paso "parada"', () {
    testWidgets('0 paradas: no hay fila de parada, solo el título de la lista', (
      tester,
    ) async {
      await tester.pumpWidget(
        _envolver(
          SeccionViajeEnCursoConParadas(
            paso: PasoViajeEnCurso.parada,
            paradas: const [],
            paradaActualId: null,
            accionEnCursoId: null,
            paradasPendientesConCoordenadas: const [],
            completando: false,
            onLlegue: (_) {},
            onCompletarParada: (_) {},
            onOmitir: (_) {},
            onAbrirGoogleMaps: () {},
            onLlegarDestino: () {},
            onCompletarViaje: () {},
            onActualizar: () {},
          ),
        ),
      );

      expect(find.text('Paradas de este viaje'), findsOneWidget);
      expect(find.text('Llegué a la parada'), findsNothing);
    });

    testWidgets(
      '1 parada pendiente y actual: muestra "Llegué a la parada" y la '
      'dispara al tocarla',
      (tester) async {
        var tocada = false;
        await tester.pumpWidget(
          _envolver(
            SeccionViajeEnCursoConParadas(
              paso: PasoViajeEnCurso.parada,
              paradas: [_parada(1, 'pendiente')],
              paradaActualId: 1,
              accionEnCursoId: null,
              paradasPendientesConCoordenadas: const [],
              completando: false,
              onLlegue: (p) => tocada = p.id == 1,
              onCompletarParada: (_) {},
              onOmitir: (_) {},
              onAbrirGoogleMaps: () {},
              onLlegarDestino: () {},
              onCompletarViaje: () {},
              onActualizar: () {},
            ),
          ),
        );

        expect(find.text('Llegué a la parada'), findsOneWidget);
        await tester.tap(find.text('Llegué a la parada'));
        expect(tocada, isTrue);
      },
    );

    testWidgets(
      '2 paradas: la ya completada no tiene botones, la pendiente (actual) '
      'sí',
      (tester) async {
        await tester.pumpWidget(
          _envolver(
            SeccionViajeEnCursoConParadas(
              paso: PasoViajeEnCurso.parada,
              paradas: [_parada(1, 'completada'), _parada(2, 'pendiente')],
              paradaActualId: 2,
              accionEnCursoId: null,
              paradasPendientesConCoordenadas: const [],
              completando: false,
              onLlegue: (_) {},
              onCompletarParada: (_) {},
              onOmitir: (_) {},
              onAbrirGoogleMaps: () {},
              onLlegarDestino: () {},
              onCompletarViaje: () {},
              onActualizar: () {},
            ),
          ),
        );

        expect(find.text('Llegué a la parada'), findsOneWidget);
        expect(find.text('Completada'), findsOneWidget);
      },
    );

    testWidgets(
      '3 paradas, la actual ya en estado "llegada": muestra "Parada '
      'completada" y "Omitir parada", y dispara onOmitir al confirmar',
      (tester) async {
        ParadaViaje? omitida;
        await tester.pumpWidget(
          _envolver(
            SeccionViajeEnCursoConParadas(
              paso: PasoViajeEnCurso.parada,
              paradas: [
                _parada(1, 'completada'),
                _parada(2, 'omitida'),
                _parada(3, 'llegada'),
              ],
              paradaActualId: 3,
              accionEnCursoId: null,
              paradasPendientesConCoordenadas: const [],
              completando: false,
              onLlegue: (_) {},
              onCompletarParada: (_) {},
              onOmitir: (p) => omitida = p,
              onAbrirGoogleMaps: () {},
              onLlegarDestino: () {},
              onCompletarViaje: () {},
              onActualizar: () {},
            ),
          ),
        );

        expect(find.text('Parada completada'), findsOneWidget);
        expect(find.text('Omitir parada'), findsOneWidget);

        await tester.tap(find.text('Omitir parada'));
        expect(omitida?.id, 3);
      },
    );

    testWidgets(
      'con paradas pendientes con coordenadas: muestra el botón de Google '
      'Maps y la nota de Waze',
      (tester) async {
        await tester.pumpWidget(
          _envolver(
            SeccionViajeEnCursoConParadas(
              paso: PasoViajeEnCurso.parada,
              paradas: [_parada(1, 'pendiente')],
              paradaActualId: 1,
              accionEnCursoId: null,
              paradasPendientesConCoordenadas: [_parada(1, 'pendiente')],
              completando: false,
              onLlegue: (_) {},
              onCompletarParada: (_) {},
              onOmitir: (_) {},
              onAbrirGoogleMaps: () {},
              onLlegarDestino: () {},
              onCompletarViaje: () {},
              onActualizar: () {},
            ),
          ),
        );

        expect(find.text('Abrir en Google Maps (con paradas)'), findsOneWidget);
        expect(
          find.textContaining('Waze no admite varias paradas'),
          findsOneWidget,
        );
      },
    );
  });

  group('SeccionViajeEnCursoConParadas — pasos "destino"/"completar"/"inconsistente"', () {
    testWidgets('"destino": un solo botón "Llegué al destino"', (tester) async {
      var tocado = false;
      await tester.pumpWidget(
        _envolver(
          SeccionViajeEnCursoConParadas(
            paso: PasoViajeEnCurso.destino,
            paradas: const [],
            paradaActualId: null,
            accionEnCursoId: null,
            paradasPendientesConCoordenadas: const [],
            completando: false,
            onLlegue: (_) {},
            onCompletarParada: (_) {},
            onOmitir: (_) {},
            onAbrirGoogleMaps: () {},
            onLlegarDestino: () => tocado = true,
            onCompletarViaje: () {},
            onActualizar: () {},
          ),
        ),
      );

      expect(find.text('Llegué al destino'), findsOneWidget);
      expect(find.text('Completar viaje'), findsNothing);
      await tester.tap(find.text('Llegué al destino'));
      expect(tocado, isTrue);
    });

    testWidgets('"completar": un solo botón "Completar viaje"', (tester) async {
      var tocado = false;
      await tester.pumpWidget(
        _envolver(
          SeccionViajeEnCursoConParadas(
            paso: PasoViajeEnCurso.completar,
            paradas: const [],
            paradaActualId: null,
            accionEnCursoId: null,
            paradasPendientesConCoordenadas: const [],
            completando: false,
            onLlegue: (_) {},
            onCompletarParada: (_) {},
            onOmitir: (_) {},
            onAbrirGoogleMaps: () {},
            onLlegarDestino: () {},
            onCompletarViaje: () => tocado = true,
            onActualizar: () {},
          ),
        ),
      );

      expect(find.text('Completar viaje'), findsOneWidget);
      expect(find.text('Llegué al destino'), findsNothing);
      await tester.tap(find.text('Completar viaje'));
      expect(tocado, isTrue);
    });

    testWidgets(
      '"inconsistente": siempre hay una acción disponible ("Actualizar"), '
      'nunca se queda sin botón',
      (tester) async {
        var actualizado = false;
        await tester.pumpWidget(
          _envolver(
            SeccionViajeEnCursoConParadas(
              paso: PasoViajeEnCurso.inconsistente,
              paradas: const [],
              paradaActualId: null,
              accionEnCursoId: null,
              paradasPendientesConCoordenadas: const [],
              completando: false,
              onLlegue: (_) {},
              onCompletarParada: (_) {},
              onOmitir: (_) {},
              onAbrirGoogleMaps: () {},
              onLlegarDestino: () {},
              onCompletarViaje: () {},
              onActualizar: () => actualizado = true,
            ),
          ),
        );

        expect(find.text('Actualizar'), findsOneWidget);
        await tester.tap(find.text('Actualizar'));
        expect(actualizado, isTrue);
      },
    );
  });
}
