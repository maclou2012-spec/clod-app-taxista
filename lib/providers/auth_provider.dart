import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? authService, ApiService? apiService})
      : _authService = authService ?? AuthService(),
        _apiService = apiService ?? ApiService();

  final AuthService _authService;
  // Se usará en verificarCodigo() cuando conectemos el login contra el backend.
  // ignore: unused_field
  final ApiService _apiService;

  static const String _prefijoPais = '+52';

  bool cargando = false;
  String? errorMensaje;
  String? verificationId;
  String telefonoCompleto = '';

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

  // TODO: implementar en el paso de la pantalla de OTP.
  Future<bool> verificarCodigo(String codigo) async {
    throw UnimplementedError('verificarCodigo se implementa en el siguiente paso');
  }
}
