import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'secure_storage_service.dart';

enum EstadoConexionSocket { desconectado, reconectando, conectado }

// Singleton: el socket debe sobrevivir a la navegación entre pantallas
// mientras la app esté abierta, no reiniciarse con cada State.
class SocketService {
  SocketService._interno();

  static final SocketService _instancia = SocketService._interno();

  factory SocketService() => _instancia;

  static const String _baseUrl = 'https://api.clod.info';

  final SecureStorageService _secureStorageService = SecureStorageService();

  io.Socket? _socket;

  final ValueNotifier<EstadoConexionSocket> estado = ValueNotifier(
    EstadoConexionSocket.desconectado,
  );

  final StreamController<Map<String, dynamic>> _nuevaSolicitudController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get nuevaSolicitud =>
      _nuevaSolicitudController.stream;

  final StreamController<Map<String, dynamic>> _viajeCanceladoController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get viajeCancelado =>
      _viajeCanceladoController.stream;

  // Solicitud del viaje en curso, si hay uno — se incluye automáticamente en
  // cada emisión de ubicación para que el backend también transmita a la
  // sala de esa solicitud específica.
  int? _solicitudActivaId;

  void marcarSolicitudActiva(int? solicitudId) {
    _solicitudActivaId = solicitudId;
  }

  // Refleja la última activación exitosa de disponibilidad. Vive aquí (no en
  // DashboardScreen) porque el socket es el singleton que persiste entre
  // pantallas y reconexiones — una reconexión puede ocurrir mientras
  // DashboardScreen ni siquiera está montado.
  bool _disponible = false;

  Future<void> conectar() async {
    if (_socket != null) return;

    final accessToken = await _secureStorageService.obtenerAccessToken();
    if (accessToken == null) return;

    estado.value = EstadoConexionSocket.reconectando;

    _socket = io.io(
      _baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': accessToken})
          .enableReconnection()
          .build(),
    );

    _socket!
      ..onConnect((_) {
        estado.value = EstadoConexionSocket.conectado;
        if (kDebugMode) debugPrint('SocketService: conectado');
        // Cada conexión es una sala nueva en el backend — si el taxista
        // seguía marcado disponible antes del corte, hay que re-unirlo sin
        // que tenga que tocar el switch de nuevo.
        if (_disponible) {
          _socket?.emit('taxista_disponible');
          if (kDebugMode) {
            debugPrint(
              'SocketService: reconexión con disponibilidad activa, '
              're-emitiendo taxista_disponible',
            );
          }
        }
      })
      ..onDisconnect((_) {
        estado.value = EstadoConexionSocket.reconectando;
        if (kDebugMode) {
          debugPrint('SocketService: desconectado, reintentando...');
        }
      })
      ..onConnectError((error) {
        if (kDebugMode) debugPrint('SocketService: error de conexión: $error');
      })
      ..on('nueva_solicitud', (data) {
        if (kDebugMode) debugPrint('SocketService: nueva_solicitud $data');
        if (data is Map) {
          _nuevaSolicitudController.add(Map<String, dynamic>.from(data));
        }
      })
      ..on('viaje_cancelado', (data) {
        if (kDebugMode) debugPrint('SocketService: viaje_cancelado $data');
        if (data is Map) {
          _viajeCanceladoController.add(Map<String, dynamic>.from(data));
        }
      });
  }

  void desconectar() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _disponible = false;
    estado.value = EstadoConexionSocket.desconectado;
  }

  void emitirDisponible() {
    _disponible = true;
    _socket?.emit('taxista_disponible');
  }

  void emitirNoDisponible() {
    _disponible = false;
    _socket?.emit('taxista_no_disponible');
  }

  void emitirUbicacion(double lat, double lng) {
    _socket?.emit('actualizar_ubicacion', {
      'lat': lat,
      'lng': lng,
      if (_solicitudActivaId != null) 'solicitudId': _solicitudActivaId,
    });
  }

  void unirseSolicitud(int solicitudId) {
    _socket?.emit('unirse_solicitud', solicitudId);
  }

  void salirSolicitud(int solicitudId) {
    _socket?.emit('salir_solicitud', solicitudId);
  }
}
