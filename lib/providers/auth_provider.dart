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
    var enviado = false;

    try {
      await _authService.enviarCodigoOTP(
        telefonoCompleto,
        onCodigoEnviado: (id) {
          verificationId = id;
          cargando = false;
          enviado = true;
          notifyListeners();
        },
        onError: (error) {
          errorMensaje = error;
          cargando = false;
          notifyListeners();
        },
      );
    } catch (e) {
      errorMensaje = 'No se pudo enviar el código. Intenta de nuevo.';
      cargando = false;
      notifyListeners();
    }

    return enviado;
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
}
