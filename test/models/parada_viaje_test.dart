import 'package:flutter_test/flutter_test.dart';
import 'package:taxiclod/models/parada_viaje.dart';

void main() {
  group('ParadaViaje.desdeJson', () {
    test('parada de servicio pendiente', () {
      final parada = ParadaViaje.desdeJson({
        'id': 1,
        'orden': 1,
        'tipo': 'servicio',
        'direccion': 'Av. Siempre Viva 123',
        'lat': '19.1',
        'lng': '-96.1',
        'nombre_contacto': 'Juan',
        'descripcion': 'Dejar paquete con el portero',
        'estado': 'pendiente',
      });
      expect(parada.esServicio, isTrue);
      expect(parada.pendiente, isTrue);
      expect(parada.llegada, isFalse);
      expect(parada.completadaUOmitida, isFalse);
      expect(parada.lat, 19.1);
      expect(parada.lng, -96.1);
      expect(parada.nombreContacto, 'Juan');
    });

    test('parada de recogida (colectivo) completada', () {
      final parada = ParadaViaje.desdeJson({
        'id': 2,
        'orden': 2,
        'tipo': 'recogida',
        'direccion': 'Calle Falsa 456',
        'estado': 'completada',
      });
      expect(parada.esServicio, isFalse);
      expect(parada.completadaUOmitida, isTrue);
    });

    test('parada omitida también cuenta como resuelta', () {
      final parada = ParadaViaje.desdeJson({
        'id': 3,
        'orden': 3,
        'tipo': 'servicio',
        'direccion': 'x',
        'estado': 'omitida',
      });
      expect(parada.completadaUOmitida, isTrue);
    });

    test('estado "llegada" — ni pendiente ni resuelta', () {
      final parada = ParadaViaje.desdeJson({
        'id': 4,
        'orden': 4,
        'tipo': 'servicio',
        'direccion': 'x',
        'estado': 'llegada',
      });
      expect(parada.llegada, isTrue);
      expect(parada.pendiente, isFalse);
      expect(parada.completadaUOmitida, isFalse);
    });
  });

  group('paradasDesdeMapa', () {
    test('ordena por "orden" aunque lleguen desordenadas', () {
      final paradas = paradasDesdeMapa({
        'paradas': [
          {'id': 2, 'orden': 2, 'tipo': 'servicio', 'direccion': 'B', 'estado': 'pendiente'},
          {'id': 1, 'orden': 1, 'tipo': 'servicio', 'direccion': 'A', 'estado': 'pendiente'},
        ],
      });
      expect(paradas.map((p) => p.direccion), ['A', 'B']);
    });

    test('sin la llave "paradas" -> lista vacía, no lanza', () {
      expect(paradasDesdeMapa({'estado': 'en_curso'}), isEmpty);
    });
  });

  group('tipoViajeDesdeMapa', () {
    test('normal por defecto si no viene el campo', () {
      expect(tipoViajeDesdeMapa({}), 'normal');
    });

    test('respeta el valor real', () {
      expect(
        tipoViajeDesdeMapa({'tipo_viaje': 'paradas_servicio'}),
        'paradas_servicio',
      );
      expect(tipoViajeDesdeMapa({'tipo_viaje': 'colectivo'}), 'colectivo');
    });
  });

  group('parsearMontoParada', () {
    test('vacío -> 0 (el sistema no sugiere montos)', () {
      expect(parsearMontoParada(''), 0);
      expect(parsearMontoParada('   '), 0);
    });

    test('número válido', () {
      expect(parsearMontoParada('25.50'), 25.5);
      expect(parsearMontoParada('100'), 100.0);
    });

    test('negativo -> null (inválido)', () {
      expect(parsearMontoParada('-5'), isNull);
    });

    test('texto no numérico -> null', () {
      expect(parsearMontoParada('abc'), isNull);
    });
  });

  group('montoParadaComoTexto', () {
    test('0 o null -> cadena vacía (sin sugerir un valor)', () {
      expect(montoParadaComoTexto(0), '');
      expect(montoParadaComoTexto(null), '');
      expect(montoParadaComoTexto('0'), '');
    });

    test('monto real -> 2 decimales', () {
      expect(montoParadaComoTexto(25), '25.00');
      expect(montoParadaComoTexto('30.5'), '30.50');
    });
  });

  group('direccionesParadasPendientesDesde', () {
    test('respuesta con objetos de parada', () {
      final direcciones = direccionesParadasPendientesDesde({
        'codigo': 'PARADAS_PENDIENTES',
        'paradas_pendientes': [
          {'id': 1, 'direccion': 'Calle A'},
          {'id': 2, 'direccion': 'Calle B'},
        ],
      });
      expect(direcciones, ['Calle A', 'Calle B']);
    });

    test('sin esa llave -> lista vacía, no lanza', () {
      expect(direccionesParadasPendientesDesde({'codigo': 'x'}), isEmpty);
      expect(direccionesParadasPendientesDesde('no es un mapa'), isEmpty);
    });
  });

  group('siguientePasoDesdeMapa', () {
    test('toma el valor tal cual si viene', () {
      expect(siguientePasoDesdeMapa({'siguiente_paso': 'parada'}), 'parada');
      expect(siguientePasoDesdeMapa({'siguiente_paso': 'destino'}), 'destino');
      expect(
        siguientePasoDesdeMapa({'siguiente_paso': 'completar'}),
        'completar',
      );
    });

    test('sin la llave -> null (backend sin desplegar todavía)', () {
      expect(siguientePasoDesdeMapa({}), isNull);
    });
  });

  group('paradaActualIdDesdeMapa', () {
    test('id plano', () {
      expect(paradaActualIdDesdeMapa({'parada_actual': 7}), 7);
    });

    test('objeto completo con id adentro', () {
      expect(
        paradaActualIdDesdeMapa({
          'parada_actual': {'id': 9, 'orden': 2},
        }),
        9,
      );
    });

    test('ausente -> null', () {
      expect(paradaActualIdDesdeMapa({}), isNull);
    });
  });

  group('pasoViajeEnCursoDesde', () {
    ParadaViaje parada(int id, String estado) => ParadaViaje(
      id: id,
      orden: id,
      tipo: 'servicio',
      direccion: 'Parada $id',
      estado: estado,
    );

    test('siguiente_paso del backend manda siempre, sin importar las paradas', () {
      expect(
        pasoViajeEnCursoDesde(
          siguientePaso: 'parada',
          paradas: const [],
          tipoViaje: 'normal',
        ),
        PasoViajeEnCurso.parada,
      );
      expect(
        pasoViajeEnCursoDesde(
          siguientePaso: 'destino',
          paradas: [parada(1, 'pendiente')],
          tipoViaje: 'paradas_servicio',
        ),
        PasoViajeEnCurso.destino,
      );
      expect(
        pasoViajeEnCursoDesde(
          siguientePaso: 'completar',
          paradas: [parada(1, 'pendiente')],
          tipoViaje: 'paradas_servicio',
        ),
        PasoViajeEnCurso.completar,
      );
    });

    test('un valor no reconocido -> inconsistente (nunca se adivina)', () {
      expect(
        pasoViajeEnCursoDesde(
          siguientePaso: 'algo_nuevo_que_no_existe_todavia',
          paradas: const [],
          tipoViaje: 'normal',
        ),
        PasoViajeEnCurso.inconsistente,
      );
    });

    group('sin siguiente_paso (backend viejo) — deriva localmente', () {
      test('viaje normal (0 paradas) -> destino', () {
        expect(
          pasoViajeEnCursoDesde(
            siguientePaso: null,
            paradas: const [],
            tipoViaje: 'normal',
          ),
          PasoViajeEnCurso.destino,
        );
      });

      test('1 parada pendiente -> parada', () {
        expect(
          pasoViajeEnCursoDesde(
            siguientePaso: null,
            paradas: [parada(1, 'pendiente')],
            tipoViaje: 'paradas_servicio',
          ),
          PasoViajeEnCurso.parada,
        );
      });

      test('1 parada ya completada -> destino', () {
        expect(
          pasoViajeEnCursoDesde(
            siguientePaso: null,
            paradas: [parada(1, 'completada')],
            tipoViaje: 'paradas_servicio',
          ),
          PasoViajeEnCurso.destino,
        );
      });

      test('2 paradas, la primera completada y la segunda pendiente -> parada', () {
        expect(
          pasoViajeEnCursoDesde(
            siguientePaso: null,
            paradas: [parada(1, 'completada'), parada(2, 'pendiente')],
            tipoViaje: 'colectivo',
          ),
          PasoViajeEnCurso.parada,
        );
      });

      test('2 paradas, ambas resueltas (una omitida) -> destino', () {
        expect(
          pasoViajeEnCursoDesde(
            siguientePaso: null,
            paradas: [parada(1, 'completada'), parada(2, 'omitida')],
            tipoViaje: 'colectivo',
          ),
          PasoViajeEnCurso.destino,
        );
      });

      test('3 paradas: solo la última pendiente -> parada', () {
        expect(
          pasoViajeEnCursoDesde(
            siguientePaso: null,
            paradas: [
              parada(1, 'completada'),
              parada(2, 'omitida'),
              parada(3, 'pendiente'),
            ],
            tipoViaje: 'colectivo',
          ),
          PasoViajeEnCurso.parada,
        );
      });

      test('3 paradas, las 3 resueltas -> destino', () {
        expect(
          pasoViajeEnCursoDesde(
            siguientePaso: null,
            paradas: [
              parada(1, 'completada'),
              parada(2, 'omitida'),
              parada(3, 'completada'),
            ],
            tipoViaje: 'colectivo',
          ),
          PasoViajeEnCurso.destino,
        );
      });
    });
  });
}
