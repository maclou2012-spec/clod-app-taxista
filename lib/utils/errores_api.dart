import 'package:dio/dio.dart';

/// Error del backend en el formato `{ status: 'error', mensaje, codigo? }`.
/// El `mensaje` ya viene en español para el usuario; `codigo` sirve para
/// reaccionar (p. ej. REPARTIDOR_NO_DISPONIBLE → recargar la lista).
class ErrorApi implements Exception {
  ErrorApi(this.mensaje, {this.codigo, this.status, this.datos = const {}});

  factory ErrorApi.desde(Object error, {String porDefecto = 'Algo salió mal. Intenta de nuevo.'}) {
    if (error is ErrorApi) return error;
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final mensaje = data['mensaje'] ?? data['message'];
        return ErrorApi(
          mensaje is String && mensaje.isNotEmpty ? mensaje : porDefecto,
          codigo: data['codigo'] as String?,
          status: error.response?.statusCode,
          datos: data,
        );
      }
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return ErrorApi('Sin conexión. Revisa tu internet e intenta de nuevo.');
      }
      return ErrorApi(porDefecto, status: error.response?.statusCode);
    }
    return ErrorApi(porDefecto);
  }

  final String mensaje;
  final String? codigo;
  final int? status;
  final Map<String, dynamic> datos;

  @override
  String toString() => mensaje;
}
