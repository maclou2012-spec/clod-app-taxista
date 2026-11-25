import 'package:dio/dio.dart';

import '../models/foraneo_conductor.dart';
import '../utils/errores_api.dart';
import '../utils/json.dart';
import 'api_service.dart';

/// Viajes foráneos del lado del taxista (`/api/conductor-foraneo/*`,
/// docs/API_FORANEOS.md). Todos los métodos lanzan [ErrorApi].
class ForaneoConductorService {
  ForaneoConductorService({ApiService? api})
    : _dio = (api ?? ApiService()).cliente;

  final Dio _dio;

  static const String _base = '/api/conductor-foraneo';

  Future<T> _llamar<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      throw ErrorApi.desde(e);
    }
  }

  Future<PerfilForaneo> perfil() => _llamar(() async {
    final r = await _dio.get('$_base/perfil');
    return PerfilForaneo.desdeJson(aMapa(aMapa(r.data)['conductor']));
  });

  /// Pide que CLOD lo habilite; devuelve el estado (`pendiente`, …).
  Future<String> solicitarServicio() => _llamar(() async {
    final r = await _dio.post('$_base/solicitar-servicio');
    return aTexto(aMapa(r.data)['estado']) ?? 'pendiente';
  });

  Future<CotizacionForanea> cotizar({
    required LugarForaneo origen,
    required LugarForaneo destino,
    List<LugarForaneo> paradas = const [],
  }) => _llamar(() async {
    final r = await _dio.post(
      '$_base/cotizar',
      data: {
        'origen_lat': origen.lat,
        'origen_lng': origen.lng,
        'destino_lat': destino.lat,
        'destino_lng': destino.lng,
        if (paradas.isNotEmpty)
          'paradas': [
            for (final p in paradas) {'lat': p.lat, 'lng': p.lng},
          ],
      },
    );
    return CotizacionForanea.desdeJson(aMapa(aMapa(r.data)['cotizacion']));
  });

  /// Errores: FORANEOS_NO_HABILITADO, MEMBRESIA_NO_VIGENTE, SIN_VEHICULO,
  /// PRECIO_EXCEDE_TOPE, DISTANCIA_CORTA, VIAJE_TRASLAPADO, ASIENTOS_EXCEDEN.
  Future<int> publicar(Map<String, dynamic> datos) => _llamar(() async {
    final r = await _dio.post('$_base/viajes', data: datos);
    return aEntero(aMapa(r.data)['viaje_id']) ?? 0;
  });

  Future<List<ViajeConductor>> misViajes() => _llamar(() async {
    final r = await _dio.get('$_base/viajes');
    return aListaMapas(
      aMapa(r.data)['viajes'],
    ).map(ViajeConductor.desdeJson).toList();
  });

  Future<ViajeConductorDetalle> viaje(int id) => _llamar(() async {
    final r = await _dio.get('$_base/viajes/$id');
    return ViajeConductorDetalle.desdeJson(aMapa(aMapa(r.data)['viaje']));
  });

  Future<void> cancelarViaje(int id, {String? motivo}) => _llamar(() async {
    await _dio.post('$_base/viajes/$id/cancelar', data: {'motivo': ?motivo});
  });

  /// Desde una hora antes de la salida (`MUY_PRONTO`).
  Future<void> iniciar(int id) => _llamar(() async {
    await _dio.post('$_base/viajes/$id/iniciar');
  });

  Future<Map<String, dynamic>> finalizar(int id) => _llamar(() async {
    final r = await _dio.post('$_base/viajes/$id/finalizar');
    return aMapa(r.data);
  });

  Future<void> responderReserva(
    int reservaId, {
    required bool aprobar,
    String? mensaje,
  }) => _llamar(() async {
    await _dio.post(
      '$_base/reservas/$reservaId/${aprobar ? 'aprobar' : 'rechazar'}',
      data: {'mensaje': ?mensaje},
    );
  });

  /// Errores: CODIGO_INCORRECTO, PAGO_PENDIENTE.
  Future<void> abordar(int reservaId, String codigo) => _llamar(() async {
    await _dio.post(
      '$_base/reservas/$reservaId/abordar',
      data: {'codigo': codigo},
    );
  });

  Future<void> noSePresento(int reservaId) => _llamar(() async {
    await _dio.post('$_base/reservas/$reservaId/no-se-presento');
  });

  Future<void> calificarPasajero(
    int reservaId, {
    required int puntuacion,
    String? comentario,
  }) => _llamar(() async {
    await _dio.post(
      '$_base/reservas/$reservaId/calificar',
      data: {'puntuacion': puntuacion, 'comentario': ?comentario},
    );
  });

  Future<void> enviarUbicacion(double lat, double lng) => _llamar(() async {
    await _dio.post('$_base/ubicacion', data: {'lat': lat, 'lng': lng});
  });

  Future<BilleteraForanea> billetera() => _llamar(() async {
    final r = await _dio.get(
      '$_base/billetera',
      queryParameters: {'limite': 100},
    );
    return BilleteraForanea.desdeJson(aMapa(r.data));
  });

  /// Buscador de lugares (GET /api/geocoding/buscar) cerca de [lat], [lng].
  Future<List<LugarForaneo>> buscarLugares(
    String texto,
    double lat,
    double lng,
  ) => _llamar(() async {
    final r = await _dio.get(
      '/api/geocoding/buscar',
      queryParameters: {'q': texto, 'lat': lat, 'lng': lng},
    );
    return aListaMapas(aMapa(r.data)['resultados'])
        .map(
          (l) => LugarForaneo(
            direccion: aTexto(l['nombre']) ?? '',
            lat: aDecimal(l['lat']) ?? 0,
            lng: aDecimal(l['lng']) ?? 0,
          ),
        )
        .where((l) => l.direccion.isNotEmpty)
        .toList();
  });
}
