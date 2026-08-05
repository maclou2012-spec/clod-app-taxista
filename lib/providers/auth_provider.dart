import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/secure_storage_service.dart';

enum VerificacionResultado { exito, requiereRegistro, error }

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    AuthService? authService,
    ApiService? apiService,
    SecureStorageService? secureStorageService,
  })  : _authService = authService ?? AuthService(),
        _apiService = apiService ?? ApiService(),
        _secureStorageService =
            secureStorageService ?? SecureStorageService();

  final AuthService _authService;
  final ApiService _apiService;
  final SecureStorageService _secureStorageService;

  static const String _prefijoPais = '+52';

  bool cargando = false;
  String? errorMensaje;
  String? verificationId;
  String telefonoCompleto = '';
  String? idToken;

  Future<bool> enviarCodigo(String telefonoLocal) async {
    cargando = true;
    errorMensaje = null;
    notifyListeners();

    telefonoCompleto = '$_prefijoPais$telefonoLocal';

    // verifyPhoneNumber (dentro de AuthService) resuelve su Future casi de
    // inmediato, antes de que codeSent/verificationFailed lleguen — por eso
    // no podemos basar el resultado en ese await. Usamos un Completer que
    // solo se resuelve cuando el callback real dispara.
    final completer = Completer<bool>();

    try {
      await _authService.enviarCodigoOTP(
        telefonoCompleto,
        onCodigoEnviado: (id) {
          verificationId = id;
          cargando = false;
          notifyListeners();
          if (!completer.isCompleted) completer.complete(true);
        },
        onError: (error) {
          errorMensaje = error;
          cargando = false;
          notifyListeners();
          if (!completer.isCompleted) completer.complete(false);
        },
      );
    } catch (e) {
      errorMensaje = 'No se pudo enviar el código. Intenta de nuevo.';
      cargando = false;
      notifyListeners();
      if (!completer.isCompleted) completer.complete(false);
    }

    return completer.future;
  }

  Future<VerificacionResultado> verificarCodigo(String codigo) async {
    cargando = true;
    errorMensaje = null;
    notifyListeners();

    try {
      final idTokenObtenido = await _authService.verificarCodigoOTP(
        verificationId!,
        codigo,
      );

      if (idTokenObtenido == null) {
        errorMensaje = 'Código incorrecto, intenta de nuevo';
        cargando = false;
        notifyListeners();
        return VerificacionResultado.error;
      }

      idToken = idTokenObtenido;

      try {
        final respuesta = await _apiService.login(idToken: idTokenObtenido);
        final accessToken = respuesta['accessToken'] as String?;
        final refreshToken = respuesta['refreshToken'] as String?;
        if (accessToken != null && refreshToken != null) {
          await _secureStorageService.guardarTokens(accessToken, refreshToken);
        }
        cargando = false;
        notifyListeners();
        return VerificacionResultado.exito;
      } on RequiereRegistroException {
        cargando = false;
        notifyListeners();
        return VerificacionResultado.requiereRegistro;
      }
    } catch (e) {
      errorMensaje = 'Código incorrecto, intenta de nuevo';
      cargando = false;
      notifyListeners();
      return VerificacionResultado.error;
    }
  }

  Future<bool> completarRegistro({
    required String nombre,
    String? codigoReferido,
  }) async {
    if (idToken == null) {
      errorMensaje = 'Sesión expirada, intenta de nuevo desde el inicio.';
      notifyListeners();
      return false;
    }

    cargando = true;
    errorMensaje = null;
    notifyListeners();

    try {
      final respuesta = await _apiService.login(
        idToken: idToken!,
        nombre: nombre,
        rol: 'taxista',
        codigoReferido: codigoReferido,
      );
      final accessToken = respuesta['accessToken'] as String?;
      final refreshToken = respuesta['refreshToken'] as String?;
      if (accessToken != null && refreshToken != null) {
        await _secureStorageService.guardarTokens(accessToken, refreshToken);
      }
      cargando = false;
      notifyListeners();
      return true;
    } catch (e) {
      errorMensaje = 'No se pudo completar el registro. Intenta de nuevo.';
      cargando = false;
      notifyListeners();
      return false;
    }
  }
}
