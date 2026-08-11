import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;

import '../../models/viaje_en_curso_args.dart';
import '../../services/api_service.dart';
import '../../services/location_tracking_service.dart';
import '../../services/socket_service.dart';
import '../../theme/clod_theme.dart';
import '../../utils/mapa_utils.dart';
import '../../widgets/clod_primary_button.dart';

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

  Future<void> _completarViaje() async {
    setState(() => _completando = true);

    try {
      await _apiService.completarViaje(widget.args.solicitudId);
      _socketService.salirSolicitud(widget.args.solicitudId);
      _socketService.marcarSolicitudActiva(null);
      if (mounted) {
        context.go('/resumen-viaje', extra: widget.args);
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
                    'Viaje en curso',
                    style: CLODTextStyles.bodyMedium.copyWith(
                      color: CLODColors.azulCLOD,
                    ),
                  ),
                  const SizedBox(height: 20),
                  CLODPrimaryButton(
                    label: 'Completar viaje',
                    cargando: _completando,
                    onPressed: _completarViaje,
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
