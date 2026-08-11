import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'socket_service.dart';

// Singleton: la posición debe seguir actualizándose (y transmitiéndose por
// socket) mientras el taxista esté disponible, sin importar qué pantalla
// esté visible — Dashboard y Viaje en curso comparten el mismo stream en
// vez de abrir cada uno su propio listener de GPS.
class LocationTrackingService {
  LocationTrackingService._interno();

  static final LocationTrackingService _instancia =
      LocationTrackingService._interno();

  factory LocationTrackingService() => _instancia;

  final SocketService _socketService = SocketService();

  StreamSubscription<Position>? _streamSub;

  final ValueNotifier<Position?> posicionActual = ValueNotifier(null);

  void iniciar() {
    if (_streamSub != null) return;

    final settings = defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 50,
            intervalDuration: const Duration(seconds: 12),
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 50,
          );

    _streamSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen((posicion) {
          posicionActual.value = posicion;
          _socketService.emitirUbicacion(posicion.latitude, posicion.longitude);
        });
  }

  void detener() {
    _streamSub?.cancel();
    _streamSub = null;
  }
}
