import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../models/viaje_en_curso_args.dart';
import '../../services/api_service.dart';
import '../../services/location_tracking_service.dart';
import '../../services/socket_service.dart';
import '../../theme/clod_theme.dart';

dynamic _campo(Map<String, dynamic> mapa, List<String> llaves) {
  for (final llave in llaves) {
    final valor = mapa[llave];
    if (valor != null) return valor;
  }
  return null;
}

String? _campoTexto(Map<String, dynamic> mapa, List<String> llaves) {
  return _campo(mapa, llaves)?.toString();
}

double? _campoDecimal(Map<String, dynamic> mapa, List<String> llaves) {
  final valor = _campo(mapa, llaves);
  if (valor is num) return valor.toDouble();
  if (valor is String) return double.tryParse(valor);
  return null;
}

// Las coordenadas pueden venir anidadas (solicitud['origen'] = {lat,lng}) o
// planas (solicitud['origen_lat'], solicitud['origen_lng']).
(double?, double?) _coordenadas(Map<String, dynamic> solicitud, String prefijo) {
  final anidado = solicitud[prefijo];
  final mapa = anidado is Map<String, dynamic> ? anidado : solicitud;
  final lat = _campoDecimal(mapa, ['lat', 'latitud', 'latitude', '${prefijo}_lat']);
  final lng = _campoDecimal(mapa, [
    'lng',
    'lon',
    'longitud',
    'longitude',
    '${prefijo}_lng',
  ]);
  return (lat, lng);
}

String _formatearDistancia(double km) {
  if (km < 1) return '${(km * 1000).round()} m';
  return '${km.toStringAsFixed(1)} km';
}

class SolicitudesPendientesScreen extends StatefulWidget {
  const SolicitudesPendientesScreen({super.key});

  @override
  State<SolicitudesPendientesScreen> createState() =>
      _SolicitudesPendientesScreenState();
}

class _SolicitudesPendientesScreenState
    extends State<SolicitudesPendientesScreen> {
  final ApiService _apiService = ApiService();
  final SocketService _socketService = SocketService();
  final LocationTrackingService _locationService = LocationTrackingService();

  StreamSubscription<Map<String, dynamic>>? _nuevaSolicitudSub;

  bool _cargando = true;
  String? _errorMensaje;
  List<Map<String, dynamic>> _solicitudes = [];
  int? _aceptandoId;

  @override
  void initState() {
    super.initState();
    _cargar();
    _nuevaSolicitudSub = _socketService.nuevaSolicitud.listen(
      (_) => _cargar(),
    );
  }

  @override
  void dispose() {
    _nuevaSolicitudSub?.cancel();
    super.dispose();
  }

  Future<Position?> _obtenerPosicion() async {
    final conocida = _locationService.posicionActual.value;
    if (conocida != null) return conocida;
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() {
      _cargando = true;
      _errorMensaje = null;
    });

    final posicion = await _obtenerPosicion();
    if (!mounted) return;
    if (posicion == null) {
      setState(() {
        _cargando = false;
        _errorMensaje = 'No se pudo obtener tu ubicación.';
      });
      return;
    }

    try {
      final solicitudes = await _apiService.obtenerSolicitudesPendientes(
        posicion.latitude,
        posicion.longitude,
      );
      if (!mounted) return;
      setState(() {
        _solicitudes = solicitudes
            .cast<Map<String, dynamic>>()
            .toList(growable: false);
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorMensaje = 'No se pudieron cargar las solicitudes.';
      });
    }
  }

  Future<void> _aceptar(Map<String, dynamic> solicitud) async {
    final idRaw = solicitud['id'];
    final id = idRaw is int ? idRaw : int.tryParse('$idRaw');
    if (id == null) return;

    setState(() => _aceptandoId = id);

    try {
      await _apiService.aceptarSolicitud(id);
      if (!mounted) return;

      final (origenLat, origenLng) = _coordenadas(solicitud, 'origen');
      final (destinoLat, destinoLng) = _coordenadas(solicitud, 'destino');

      final args = ViajeEnCursoArgs(
        solicitudId: id,
        pasajeroNombre:
            _campoTexto(solicitud, [
              'pasajero_nombre',
              'nombre_pasajero',
              'nombre',
            ]) ??
            'Pasajero',
        origenDireccion:
            _campoTexto(solicitud, [
              'origen_direccion',
              'direccion_origen',
              'origen',
            ]) ??
            '—',
        destinoDireccion:
            _campoTexto(solicitud, [
              'destino_direccion',
              'direccion_destino',
              'destino',
            ]) ??
            '—',
        tarifa:
            _campoTexto(solicitud, ['tarifa_ofrecida', 'tarifa']) ?? '—',
        horaInicio: DateTime.now(),
        origenLat: origenLat,
        origenLng: origenLng,
        destinoLat: destinoLat,
        destinoLng: destinoLng,
      );

      _socketService.marcarSolicitudActiva(id);
      context.push('/viaje-en-curso', extra: args);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _aceptandoId = null);
      final mensaje = e.response?.statusCode == 409
          ? 'Otro taxista ya tomó esta solicitud.'
          : 'No se pudo aceptar la solicitud. Intenta de nuevo.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
      if (e.response?.statusCode == 409) _cargar();
    } catch (e) {
      if (!mounted) return;
      setState(() => _aceptandoId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo aceptar la solicitud. Intenta de nuevo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CLODColors.carbon,
      appBar: AppBar(
        backgroundColor: CLODColors.carbon,
        elevation: 0,
        title: Text('Solicitudes pendientes', style: CLODTextStyles.headingSmall),
      ),
      body: SafeArea(child: _cuerpo()),
    );
  }

  Widget _cuerpo() {
    if (_cargando && _solicitudes.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(CLODColors.azulCLOD),
        ),
      );
    }

    if (_errorMensaje != null && _solicitudes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMensaje!,
                textAlign: TextAlign.center,
                style: CLODTextStyles.bodyLarge,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _cargar,
                style: OutlinedButton.styleFrom(
                  foregroundColor: CLODColors.azulCLOD,
                  side: const BorderSide(color: CLODColors.azulCLOD),
                ),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      color: CLODColors.azulCLOD,
      backgroundColor: CLODColors.carbon,
      child: _solicitudes.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 120),
                Text(
                  'No hay solicitudes disponibles en tu zona por ahora.',
                  textAlign: TextAlign.center,
                  style: CLODTextStyles.bodyLarge.copyWith(
                    color: CLODColors.grisClaro.withValues(alpha: 0.6),
                  ),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: _solicitudes.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final solicitud = _solicitudes[index];
                final idRaw = solicitud['id'];
                final id = idRaw is int ? idRaw : int.tryParse('$idRaw');
                return _TarjetaSolicitudPendiente(
                  solicitud: solicitud,
                  aceptando: _aceptandoId != null && _aceptandoId == id,
                  deshabilitada: _aceptandoId != null,
                  onTap: () => _aceptar(solicitud),
                );
              },
            ),
    );
  }
}

class _TarjetaSolicitudPendiente extends StatelessWidget {
  const _TarjetaSolicitudPendiente({
    required this.solicitud,
    required this.aceptando,
    required this.deshabilitada,
    required this.onTap,
  });

  final Map<String, dynamic> solicitud;
  final bool aceptando;
  final bool deshabilitada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nombrePasajero =
        _campoTexto(solicitud, [
          'pasajero_nombre',
          'nombre_pasajero',
          'nombre',
        ]) ??
        'Pasajero';
    final origen =
        _campoTexto(solicitud, [
          'origen_direccion',
          'direccion_origen',
          'origen',
        ]) ??
        '—';
    final tarifa = _campoTexto(solicitud, ['tarifa_ofrecida', 'tarifa']);
    final distanciaKm = _campoDecimal(solicitud, ['distancia_km']);

    return Material(
      color: CLODColors.azulMarino.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: deshabilitada ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Opacity(
            opacity: deshabilitada && !aceptando ? 0.5 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        nombrePasajero,
                        style: CLODTextStyles.bodyLarge,
                      ),
                    ),
                    if (distanciaKm != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: CLODColors.azulCLOD.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _formatearDistancia(distanciaKm),
                          style: CLODTextStyles.bodyMedium.copyWith(
                            color: CLODColors.azulCLOD,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: CLODColors.grisClaro.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        origen,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CLODTextStyles.bodySmall.copyWith(
                          color: CLODColors.grisClaro.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (tarifa != null)
                      Text(
                        '\$$tarifa MXN',
                        style: CLODTextStyles.headingSmall.copyWith(
                          color: CLODColors.azulCLOD,
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    if (aceptando)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            CLODColors.azulCLOD,
                          ),
                        ),
                      )
                    else
                      Text(
                        'Toca para aceptar',
                        style: CLODTextStyles.bodySmall.copyWith(
                          color: CLODColors.grisClaro.withValues(alpha: 0.5),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
