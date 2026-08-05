import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;

  Future<void> enviarCodigoOTP(
    String telefonoCompleto, {
    required Function(String verificationId) onCodigoEnviado,
    required Function(String error) onError,
  }) async {
    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: telefonoCompleto,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          // Auto-verificación de Android: el usuario queda autenticado
          // directamente, sin pasar por la pantalla de ingreso de código.
          await _firebaseAuth.signInWithCredential(credential);
        } on FirebaseAuthException catch (e) {
          onError(e.message ?? 'Error al verificar automáticamente');
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        onError(e.message ?? 'Error al enviar el código');
      },
      codeSent: (String verificationId, int? resendToken) {
        onCodigoEnviado(verificationId);
      },
      // Si el auto-llenado del SMS se agota (p.ej. Play Integrity/reCAPTCHA
      // no disponible en un emulador) sin que codeSent haya llegado a
      // disparar, igual dejamos pasar al usuario a ingresar el código
      // manualmente en vez de dejar la pantalla cargando indefinidamente.
      codeAutoRetrievalTimeout: (String verificationId) {
        onCodigoEnviado(verificationId);
      },
    );
  }

  Future<String?> verificarCodigoOTP(
    String verificationId,
    String codigo,
  ) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: codigo,
      );
      final userCredential =
          await _firebaseAuth.signInWithCredential(credential);
      return await userCredential.user?.getIdToken();
    } on FirebaseAuthException {
      return null;
    }
  }

  Future<String?> obtenerIdTokenActual() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    return user.getIdToken();
  }
}
