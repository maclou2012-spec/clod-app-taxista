import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
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

    // Mientras el taxista está disponible, su ubicación sigue enviándose
    // aunque cambie de app (navegación, llamadas): en Android como servicio
    // en primer plano de tipo "location" con notificación fija; en iOS con
    // el modo de fondo de ubicación. Se detiene al desconectarse.
    final LocationSettings settings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
        intervalDuration: const Duration(seconds: 12),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'TaxiCLOD',
          notificationText:
              'Estás disponible. Desconéctate en la app cuando quieras.',
          notificationChannelName: 'Ubicación mientras estás disponible',
          notificationIcon: AndroidResource(
            name: 'ic_notification',
            defType: 'drawable',
          ),
          color: Color(0xFF1CA3E3),
          setOngoing: true,
          enableWakeLock: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      settings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    } else {
      settings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
      );
    }

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
