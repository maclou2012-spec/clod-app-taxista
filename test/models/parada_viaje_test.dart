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
}
