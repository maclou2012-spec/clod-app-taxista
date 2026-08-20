import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../routes/app_router.dart';
import 'api_service.dart';

// Debe ser una función top-level (no un método de instancia) — así lo exige
// firebase_messaging, ya que se ejecuta en un isolate aparte cuando la app
// está completamente cerrada. El sistema operativo ya muestra la
// notificación nativa por su cuenta; aquí solo dejamos un rastro para
// depuración.
@pragma('vm:entry-point')
Future<void> manejarMensajeFcmSegundoPlano(RemoteMessage message) async {
  if (kDebugMode) {
    debugPrint('FcmService: mensaje en segundo plano ${message.data}');
  }
}

// Singleton: la suscripción a onTokenRefresh debe sobrevivir a la
// navegación entre pantallas mientras la app esté abierta.
class FcmService {
  FcmService._interno();

  static final FcmService _instancia = FcmService._interno();

  factory FcmService() => _instancia;

  final ApiService _apiService = ApiService();

  bool _inicializado = false;
  StreamSubscription<String>? _tokenRefreshSub;

  Future<void> inicializar() async {
    if (_inicializado) return;
    _inicializado = true;

    FirebaseMessaging.onBackgroundMessage(manejarMensajeFcmSegundoPlano);

    await FirebaseMessaging.instance.requestPermission();

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _registrarToken(token);

    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
      _registrarToken,
    );

    FirebaseMessaging.onMessage.listen(_onMensajePrimerPlano);
    FirebaseMessaging.onMessageOpenedApp.listen(_onNotificacionTocada);
  }

  Future<void> _registrarToken(String token) async {
    try {
      final plataforma = Platform.isIOS ? 'ios' : 'android';
      await _apiService.registrarTokenFcm(token, plataforma);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FcmService: no se pudo registrar el token: $e');
      }
    }
  }

  // Con la app en primer plano, el evento de socket 'nueva_solicitud' ya se
  // encarga de mostrar la hoja de la solicitud — evitamos duplicarla aquí,
  // solo lo dejamos registrado para depuración.
  void _onMensajePrimerPlano(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('FcmService: mensaje en primer plano ${message.data}');
    }
  }

  // El usuario tocó la notificación con la app en segundo plano — la
  // llevamos directo a la lista de solicitudes si es de ese tipo, o al
  // dashboard en cualquier otro caso.
  void _onNotificacionTocada(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('FcmService: notificación tocada ${message.data}');
    }
    if (message.data['tipo'] == 'nueva_solicitud') {
      appRouter.go('/solicitudes-pendientes');
      return;
    }
    appRouter.go('/dashboard');
  }

  Future<void> liberar() async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    _inicializado = false;
  }
}
