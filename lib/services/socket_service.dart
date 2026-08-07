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
      });
  }

  void desconectar() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    estado.value = EstadoConexionSocket.desconectado;
  }

  void emitirDisponible() {
    _socket?.emit('taxista_disponible');
  }

  void emitirNoDisponible() {
    _socket?.emit('taxista_no_disponible');
  }

  void emitirUbicacion(double lat, double lng) {
    _socket?.emit('actualizar_ubicacion', {'lat': lat, 'lng': lng});
  }
}
