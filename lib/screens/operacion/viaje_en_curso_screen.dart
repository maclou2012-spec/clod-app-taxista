import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:url_launcher/url_launcher.dart';

import '../../models/calificar_pasajero_args.dart';
import '../../models/viaje_en_curso_args.dart';
import '../../services/api_service.dart';
import '../../services/location_tracking_service.dart';
import '../../services/socket_service.dart';
import '../../theme/clod_theme.dart';
import '../../utils/mapa_utils.dart';
import '../../widgets/clod_primary_button.dart';

enum _EstadoViajeTaxista { enCamino, llego, enCurso }

// La respuesta de completar puede traer el id del viaje anidado bajo
// 'viaje' o plano — si no viene ninguno, usamos el id de la solicitud como
// respaldo (algunos backends aún no distinguen solicitud_id de viaje_id).
int _extraerViajeId(Map<String, dynamic> data, int solicitudIdFallback) {
  final viaje = data['viaje'];
  final mapa = viaje is Map<String, dynamic> ? viaje : data;
  final valor = mapa['id'] ?? mapa['viaje_id'] ?? mapa['viajeId'];
  if (valor is int) return valor;
  if (valor is num) return valor.toInt();
  if (valor is String) return int.tryParse(valor) ?? solicitudIdFallback;
  return solicitudIdFallback;
}

_EstadoViajeTaxista _estadoInicialDesde(String estado) {
  switch (estado) {
    case 'en_espera':
      return _EstadoViajeTaxista.llego;
    case 'en_curso':
      return _EstadoViajeTaxista.enCurso;
    default:
      return _EstadoViajeTaxista.enCamino;
  }
}

class ViajeEnCursoScreen extends StatefulWidget {
  const ViajeEnCursoScreen({super.key, required this.args});

  final ViajeEnCursoArgs args;

  @override
  State<ViajeEnCursoScreen> createState() => _ViajeEnCursoScreenState();
}

class _ViajeEnCursoScreenState extends State<ViajeEnCursoScreen> {
  final ApiService _apiService = ApiService();
  final SocketService _socketService = SocketService();
  final LocationTrackingService _locationService = LocationTrackingService();

  mapbox.MapboxMap? _mapboxMap;
  mapbox.PointAnnotationManager? _pointAnnotationManager;
  mapbox.PointAnnotation? _miUbicacionAnnotation;
  Uint8List? _iconoUbicacion;

  late _EstadoViajeTaxista _estado = _estadoInicialDesde(widget.args.estado);
  bool _marcandoLlegada = false;
  bool _iniciando = false;
  bool _completando = false;

  static final mapbox.Point _centroVeracruz = mapbox.Point(
    coordinates: mapbox.Position(-96.1342, 19.1738),
  );

  @override
  void initState() {
    super.initState();
    _socketService.unirseSolicitud(widget.args.solicitudId);
    _locationService.posicionActual.addListener(_onPosicionActualizada);
  }

  @override
  void dispose() {
    _locationService.posicionActual.removeListener(_onPosicionActualizada);
    super.dispose();
  }

  mapbox.Point _puntoDesdePosicion(Position? posicion) {
    if (posicion == null) return _centroVeracruz;
    return mapbox.Point(
      coordinates: mapbox.Position(posicion.longitude, posicion.latitude),
    );
  }

  void _onPosicionActualizada() {
    final posicion = _locationService.posicionActual.value;
    if (posicion != null) {
      _sincronizarMapa(posicion);
    }
  }

  Future<void> _onMapaCreado(mapbox.MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _pointAnnotationManager = await mapboxMap.annotations
        .createPointAnnotationManager();
    _iconoUbicacion = await generarIconoUbicacion();
    final posicionConocida = _locationService.posicionActual.value;
    if (posicionConocida != null) {
      await _sincronizarMapa(posicionConocida);
    }
  }

  Future<void> _sincronizarMapa(Position posicion) async {
    final punto = _puntoDesdePosicion(posicion);

    _mapboxMap?.flyTo(
      mapbox.CameraOptions(center: punto),
      mapbox.MapAnimationOptions(duration: 500),
    );

    final manager = _pointAnnotationManager;
    final icono = _iconoUbicacion;
    if (manager == null || icono == null) return;

    final anotacionActual = _miUbicacionAnnotation;
    if (anotacionActual == null) {
      _miUbicacionAnnotation = await manager.create(
        mapbox.PointAnnotationOptions(geometry: punto, image: icono),
      );
    } else {
      anotacionActual.geometry = punto;
      await manager.update(anotacionActual);
    }
  }

  Future<void> _marcarLlegada() async {
    setState(() => _marcandoLlegada = true);

    try {
      await _apiService.marcarLlegada(widget.args.solicitudId);
      if (mounted) setState(() => _estado = _EstadoViajeTaxista.llego);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo marcar la llegada. Intenta de nuevo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _marcandoLlegada = false);
    }
  }

  Future<void> _iniciarViaje() async {
    setState(() => _iniciando = true);

    try {
      await _apiService.iniciarViaje(widget.args.solicitudId);
      if (mounted) setState(() => _estado = _EstadoViajeTaxista.enCurso);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo iniciar el viaje. Intenta de nuevo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _iniciando = false);
    }
  }

  Future<void> _completarViaje() async {
    setState(() => _completando = true);

    try {
      final respuesta = await _apiService.completarViaje(
        widget.args.solicitudId,
      );
      _socketService.salirSolicitud(widget.args.solicitudId);
      _socketService.marcarSolicitudActiva(null);
      if (mounted) {
        final viajeId = _extraerViajeId(respuesta, widget.args.solicitudId);
        context.go(
          '/calificar-pasajero',
          extra: CalificarPasajeroArgs(viajeId: viajeId, viajeArgs: widget.args),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo completar el viaje. Intenta de nuevo.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _completando = false);
      }
    }
  }

  String get _subtituloEstado {
    switch (_estado) {
      case _EstadoViajeTaxista.enCamino:
        return 'Yendo al punto de encuentro';
      case _EstadoViajeTaxista.llego:
        return 'Esperando al pasajero';
      case _EstadoViajeTaxista.enCurso:
        return 'Viaje en curso';
    }
  }

  String get _textoBotonEstado {
    switch (_estado) {
      case _EstadoViajeTaxista.enCamino:
        return 'He llegado';
      case _EstadoViajeTaxista.llego:
        return 'Iniciar viaje';
      case _EstadoViajeTaxista.enCurso:
        return 'Completar viaje';
    }
  }

  bool get _accionEnProgreso {
    switch (_estado) {
      case _EstadoViajeTaxista.enCamino:
        return _marcandoLlegada;
      case _EstadoViajeTaxista.llego:
        return _iniciando;
      case _EstadoViajeTaxista.enCurso:
        return _completando;
    }
  }

  VoidCallback get _accionEstado {
    switch (_estado) {
      case _EstadoViajeTaxista.enCamino:
        return _marcarLlegada;
      case _EstadoViajeTaxista.llego:
        return _iniciarViaje;
      case _EstadoViajeTaxista.enCurso:
        return _completarViaje;
    }
  }

  // Mientras el taxista va hacia el pasajero, navega al punto de recogida;
  // una vez que llegó (esperando o ya en viaje), navega al destino final.
  double? get _navLat => _estado == _EstadoViajeTaxista.enCamino
      ? widget.args.origenLat
      : widget.args.destinoLat;

  double? get _navLng => _estado == _EstadoViajeTaxista.enCamino
      ? widget.args.origenLng
      : widget.args.destinoLng;

  Future<void> _abrirNavegacionExterna() async {
    final lat = _navLat;
    final lng = _navLng;
    if (lat == null || lng == null) return;

    final uri = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
    final exito = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!exito && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir una app de navegación.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CLODColors.carbon,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: mapbox.MapWidget(
                viewport: mapbox.CameraViewportState(
                  center: _puntoDesdePosicion(
                    _locationService.posicionActual.value,
                  ),
                  zoom: 15,
                ),
                onMapCreated: _onMapaCreado,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: CLODColors.azulMarino.withValues(alpha: 0.2),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.args.pasajeroNombre,
                    style: CLODTextStyles.headingSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _subtituloEstado,
                    style: CLODTextStyles.bodyMedium.copyWith(
                      color: CLODColors.azulCLOD,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_navLat != null && _navLng != null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _abrirNavegacionExterna,
                        icon: Icon(
                          Icons.navigation_outlined,
                          color: CLODColors.azulCLOD,
                        ),
                        label: Text(
                          'Abrir en Waze o Google Maps',
                          style: CLODTextStyles.bodyLarge.copyWith(
                            color: CLODColors.azulCLOD,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: CLODColors.azulCLOD.withValues(alpha: 0.5),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  CLODPrimaryButton(
                    label: _textoBotonEstado,
                    cargando: _accionEnProgreso,
                    onPressed: _accionEstado,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
