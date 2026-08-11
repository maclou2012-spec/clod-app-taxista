import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/viaje_en_curso_args.dart';
import '../../services/api_service.dart';
import '../../services/location_tracking_service.dart';
import '../../services/socket_service.dart';
import '../../theme/clod_theme.dart';
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

  bool _completando = false;

  @override
  void initState() {
    super.initState();
    _socketService.unirseSolicitud(widget.args.solicitudId);
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
              child: ValueListenableBuilder<Position?>(
                valueListenable: _locationService.posicionActual,
                builder: (context, posicion, _) {
                  return GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: posicion != null
                          ? LatLng(posicion.latitude, posicion.longitude)
                          : const LatLng(19.1738, -96.1342),
                      zoom: 15,
                    ),
                    onMapCreated: (controller) {
                      final posicionConocida =
                          _locationService.posicionActual.value;
                      if (posicionConocida != null) {
                        controller.animateCamera(
                          CameraUpdate.newLatLng(
                            LatLng(
                              posicionConocida.latitude,
                              posicionConocida.longitude,
                            ),
                          ),
                        );
                      }
                    },
                    markers: posicion != null
                        ? {
                            Marker(
                              markerId: const MarkerId('mi_ubicacion'),
                              position: LatLng(
                                posicion.latitude,
                                posicion.longitude,
                              ),
                            ),
                          }
                        : {},
                  );
                },
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
