import 'package:dio/dio.dart';

import 'secure_storage_service.dart';

class RequiereRegistroException implements Exception {
  RequiereRegistroException(this.data);

  final Map<String, dynamic> data;

  @override
  String toString() => 'RequiereRegistroException: $data';
}

class ApiService {
  ApiService({Dio? dio, SecureStorageService? secureStorageService})
      : _secureStorageService = secureStorageService ?? SecureStorageService(),
        _dio = dio ?? Dio(BaseOptions(baseUrl: baseUrl)) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.path != '/api/auth/login') {
            final accessToken = await _secureStorageService.obtenerAccessToken();
            if (accessToken != null) {
              options.headers['Authorization'] = 'Bearer $accessToken';
            }
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final path = error.requestOptions.path;
          final esReintento = error.requestOptions.extra['reintentoRefresh'] == true;
          final esRutaAuth = path == '/api/auth/login' || path == '/api/auth/refresh';

          if (error.response?.statusCode == 401 && !esReintento && !esRutaAuth) {
            final nuevoAccessToken = await _refrescarToken();
            if (nuevoAccessToken != null) {
              try {
                final requestOptions = error.requestOptions;
                requestOptions.headers['Authorization'] = 'Bearer $nuevoAccessToken';
                requestOptions.extra['reintentoRefresh'] = true;
                final respuesta = await _dio.fetch(requestOptions);
                return handler.resolve(respuesta);
              } on DioException catch (e) {
                return handler.next(e);
              }
            } else {
              await _secureStorageService.borrarTokens();
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  static const String baseUrl = 'https://api.clod.info';

  final Dio _dio;
  final SecureStorageService _secureStorageService;

  Future<String?> _refrescarToken() async {
    try {
      final refreshToken = await _secureStorageService.obtenerRefreshToken();
      if (refreshToken == null) return null;

      // Dio "limpio", sin los interceptores de esta instancia, para evitar
      // que un 401 en /api/auth/refresh dispare este mismo flujo de nuevo.
      final dioSinInterceptores = Dio(BaseOptions(baseUrl: baseUrl));
      final respuesta = await dioSinInterceptores.post(
        '/api/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      final data = respuesta.data as Map<String, dynamic>;
      final nuevoAccessToken = data['accessToken'] as String?;
      final nuevoRefreshToken = data['refreshToken'] as String?;
      if (nuevoAccessToken == null || nuevoRefreshToken == null) return null;

      await _secureStorageService.guardarTokens(nuevoAccessToken, nuevoRefreshToken);
      return nuevoAccessToken;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> login({
    required String idToken,
    String? nombre,
    String? rol,
    String? codigoReferido,
  }) async {
    try {
      final response = await _dio.post(
        '/api/auth/login',
        data: {
          'idToken': idToken,
          'nombre': ?nombre,
          'rol': ?rol,
          'codigoReferido': ?codigoReferido,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (e.response?.statusCode == 400 &&
          data is Map<String, dynamic> &&
          data['status'] == 'requiere_registro') {
        throw RequiereRegistroException(data);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> obtenerUsuarioActual() async {
    final response = await _dio.get('/api/auth/me');
    return response.data as Map<String, dynamic>;
  }
}
