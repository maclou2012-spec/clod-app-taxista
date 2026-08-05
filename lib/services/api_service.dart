import 'package:dio/dio.dart';

class RequiereRegistroException implements Exception {
  RequiereRegistroException(this.data);

  final Map<String, dynamic> data;

  @override
  String toString() => 'RequiereRegistroException: $data';
}

class ApiService {
  ApiService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(baseUrl: baseUrl),
            );

  static const String baseUrl = 'https://api.clod.info';

  final Dio _dio;

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
}
