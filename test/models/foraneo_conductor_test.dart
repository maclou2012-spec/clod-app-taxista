import 'package:flutter_test/flutter_test.dart';
import 'package:taxiclod/models/foraneo_conductor.dart';

void main() {
  test('perfil del conductor foráneo', () {
    final p = PerfilForaneo.desdeJson({
      'viajes_foraneos': 'habilitado',
      'saldo': '120.50',
      'vehiculo': {'marca': 'Nissan', 'modelo': 'Versa', 'placas': 'PRUEBA-TX1', 'num_asientos': 5},
      'membresia': {'membresia_vigente': true},
      'calificacion_foraneos': '4.70',
      'resenas_foraneos': 3,
      'precio_max_km': '2.5',
    });
    expect(p.habilitado, isTrue);
    expect(p.asientosMaximos, 4, reason: 'los del vehículo menos el del taxista');
    expect(p.vehiculo, 'Nissan · Versa · PRUEBA-TX1');
    expect(p.calificacion, 4.7);
  });

  test('sin solicitar y sin vehículo', () {
    final p = PerfilForaneo.desdeJson({'viajes_foraneos': null, 'vehiculo': null});
    expect(p.servicio, 'sin_solicitar');
    expect(p.habilitado, isFalse);
    expect(p.asientosMaximos, 4);
  });

  test('la cotización solo expone el tope, no un precio sugerido', () {
    final c = CotizacionForanea.desdeJson({
      'distancia_km': '210.4',
      'duracion_min': 170,
      'precio_max_asiento': 526,
      'precio_sugerido': 315,
      'tarifa_servicio_cliente': '15',
    });
    expect(c.precioMaxAsiento, 526);
    expect(c.tarifaServicioCliente, 15);
  });

  test('detalle con paradas y reservas', () {
    final d = ViajeConductorDetalle.desdeJson({
      'id': 4,
      'estado': 'en_curso',
      'origen_ciudad': 'Colima',
      'origen_punto': 'Jardín Libertad',
      'destino_ciudad': 'Guadalajara',
      'destino_punto': 'Minerva',
      'salida_en': '2026-11-26T14:00:00.000Z',
      'precio_asiento': '350.00',
      'asientos_totales': 3,
      'paradas': [
        {'id': 10, 'ciudad': 'Ciudad Guzmán', 'punto': 'Centro', 'precio_desde_origen': '150.00'},
      ],
      'reservas': [
        {
          'id': 1,
          'estado': 'confirmada',
          'asientos': 2,
          'sube_parada_id': null,
          'baja_parada_id': 10,
          'metodo_pago': 'tarjeta',
          'pagado': 0,
          'pasajero': 'Ana',
          'pasajero_telefono': '3120000101',
        },
      ],
    });
    expect(d.enCurso, isTrue);
    expect(d.puedeIniciar, isFalse);
    expect(d.viaje.salida, isNotNull);
    final r = d.reservas.single;
    expect(d.ciudadDe(r.subeParadaId, esSubida: true), 'Colima');
    expect(d.ciudadDe(r.bajaParadaId, esSubida: false), 'Ciudad Guzmán');
    expect(r.esperandoPago, isTrue);
  });

  test('textos de estado sin lenguaje de asignación', () {
    expect(textoEstadoReserva('solicitada'), 'Por aprobar');
    expect(textoEstadoReserva('rechazada'), 'No aprobada');
    expect(textoEstadoViaje('completo'), 'Lleno');
  });

  test('parada nueva al publicar', () {
    final p = ParadaNueva(
      ciudad: 'Tecomán',
      lugar: const LugarForaneo(direccion: 'Centro', lat: 18.9, lng: -103.8),
    );
    expect(p.aJson(), {'ciudad': 'Tecomán', 'punto': 'Centro', 'lat': 18.9, 'lng': -103.8});
  });
}
