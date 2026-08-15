import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

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
            final accessToken = await _secureStorageService
                .obtenerAccessToken();
            if (accessToken != null) {
              options.headers['Authorization'] = 'Bearer $accessToken';
            }
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final path = error.requestOptions.path;
          final esReintento =
              error.requestOptions.extra['reintentoRefresh'] == true;
          final esRutaAuth =
              path == '/api/auth/login' || path == '/api/auth/refresh';

          if (error.response?.statusCode == 401 &&
              !esReintento &&
              !esRutaAuth) {
            final nuevoAccessToken = await _refrescarToken();
            if (nuevoAccessToken != null) {
              // Un FormData ya se consume al enviarse una vez (multipart), así
              // que no se puede reintentar con la misma instancia. El nuevo
              // token ya quedó guardado: el usuario simplemente reintenta la
              // acción (ej. tomar la foto de nuevo) y esa petición lo usará.
              if (error.requestOptions.data is FormData) {
                return handler.next(error);
              }
              try {
                final requestOptions = error.requestOptions;
                requestOptions.headers['Authorization'] =
                    'Bearer $nuevoAccessToken';
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

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestHeader: true,
          requestBody: true,
          responseHeader: false,
          responseBody: true,
          error: true,
        ),
      );
    }
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

      await _secureStorageService.guardarTokens(
        nuevoAccessToken,
        nuevoRefreshToken,
      );
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

  Future<Map<String, dynamic>> actualizarPerfilTaxista({
    String? licenciaNumero,
    String? contactoEmergenciaNombre,
    String? contactoEmergenciaTelefono,
  }) async {
    final response = await _dio.put(
      '/api/taxistas/perfil',
      data: {
        'licencia_numero': ?licenciaNumero,
        'contacto_emergencia_nombre': ?contactoEmergenciaNombre,
        'contacto_emergencia_telefono': ?contactoEmergenciaTelefono,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> actualizarDatosPersonales({
    required String nombre,
    String? fechaNacimiento,
    String? curp,
    String? rfc,
    String? direccionCalle,
    String? direccionNumero,
    String? direccionColonia,
    String? direccionCp,
    String? direccionCiudad,
    String? contactoEmergenciaNombre,
    String? contactoEmergenciaTelefono,
  }) async {
    final response = await _dio.put(
      '/api/taxistas/perfil',
      data: {
        'nombre': nombre,
        'fecha_nacimiento': ?fechaNacimiento,
        'curp': ?curp,
        'rfc': ?rfc,
        'direccion_calle': ?direccionCalle,
        'direccion_numero': ?direccionNumero,
        'direccion_colonia': ?direccionColonia,
        'direccion_cp': ?direccionCp,
        'direccion_ciudad': ?direccionCiudad,
        'contacto_emergencia_nombre': ?contactoEmergenciaNombre,
        'contacto_emergencia_telefono': ?contactoEmergenciaTelefono,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> subirFotoReferencia(File foto) async {
    final formData = FormData.fromMap({
      'foto': await MultipartFile.fromFile(foto.path),
    });
    final response = await _dio.post(
      '/api/taxistas/verificacion-facial/referencia',
      data: formData,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verificarIdentidadFacial(
    File foto,
    String tipo,
  ) async {
    final formData = FormData.fromMap({
      'foto': await MultipartFile.fromFile(foto.path),
      'tipo': tipo,
    });
    final response = await _dio.post(
      '/api/taxistas/verificacion-facial/verificar',
      data: formData,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> registrarVehiculo({
    required String placas,
    String? marca,
    String? modelo,
    int? anio,
    String? color,
    String? numeroEconomico,
    File? foto,
  }) async {
    final formData = FormData.fromMap({
      'placas': placas,
      'marca': ?marca,
      'modelo': ?modelo,
      'anio': ?anio?.toString(),
      'color': ?color,
      'numero_economico': ?numeroEconomico,
      if (foto != null) 'foto': await MultipartFile.fromFile(foto.path),
    });
    final response = await _dio.post('/api/taxistas/vehiculo', data: formData);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> registrarDocumento({
    required String tipoDocumento,
    required String urlArchivo,
  }) async {
    final response = await _dio.post(
      '/api/taxistas/documentos',
      data: {'tipo_documento': tipoDocumento, 'url_archivo': urlArchivo},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> actualizarLicencia({
    String? licenciaNumero,
    String? licenciaVigencia,
  }) async {
    final response = await _dio.put(
      '/api/taxistas/perfil',
      data: {
        'licencia_numero': ?licenciaNumero,
        'licencia_vigencia': ?licenciaVigencia,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> obtenerClasesServicio() async {
    final response = await _dio.get('/api/catalogos/clases-servicio');
    final data = response.data as Map<String, dynamic>;
    return data['clases'] as List<dynamic>;
  }

  Future<List<dynamic>> obtenerCaracteristicasPlus() async {
    final response = await _dio.get('/api/catalogos/caracteristicas-plus');
    final data = response.data as Map<String, dynamic>;
    return data['caracteristicas'] as List<dynamic>;
  }

  Future<void> seleccionarClase(int claseId) async {
    await _dio.put('/api/taxistas/perfil', data: {'clase_id': claseId});
  }

  Future<void> agregarPlus(int caracteristicaId) async {
    await _dio.post(
      '/api/taxistas/caracteristicas',
      data: {'caracteristica_id': caracteristicaId},
    );
  }

  Future<void> quitarPlus(int caracteristicaId) async {
    await _dio.delete('/api/taxistas/caracteristicas/$caracteristicaId');
  }

  Future<void> actualizarObservacionesServicio(String observaciones) async {
    await _dio.put(
      '/api/taxistas/perfil',
      data: {'observaciones': observaciones},
    );
  }

  Future<Map<String, dynamic>> obtenerEstadoRegistro() async {
    final response = await _dio.get('/api/taxistas/estado-registro');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> obtenerMiPerfilTaxista() async {
    final response = await _dio.get('/api/taxistas/perfil');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> cambiarDisponibilidad(bool disponible) async {
    final response = await _dio.patch(
      '/api/taxistas/disponibilidad',
      data: {'disponible': disponible},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> obtenerEstadoMembresia() async {
    final response = await _dio.get('/api/membresias/estado');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> activarMembresia(String tipo) async {
    final response = await _dio.post(
      '/api/membresias/activar',
      data: {'tipo': tipo},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> aceptarSolicitud(int solicitudId) async {
    final response = await _dio.post('/api/solicitudes/$solicitudId/aceptar');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> completarViaje(int solicitudId) async {
    final response = await _dio.post('/api/solicitudes/$solicitudId/completar');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> obtenerVehiculo() async {
    try {
      final response = await _dio.get('/api/taxistas/vehiculo');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return (data['vehiculo'] as Map<String, dynamic>?) ?? data;
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<dynamic>> obtenerSolicitudesPendientes(
    double lat,
    double lng,
  ) async {
    final response = await _dio.get(
      '/api/solicitudes/',
      queryParameters: {'lat': lat, 'lng': lng},
    );
    final data = response.data as Map<String, dynamic>;
    return data['solicitudes'] as List<dynamic>;
  }

  Future<List<dynamic>> obtenerHistorialViajes() async {
    final response = await _dio.get('/api/solicitudes/historial');
    final data = response.data;
    if (data is List) return data;
    final map = data as Map<String, dynamic>;
    return (map['historial'] as List<dynamic>?) ??
        (map['solicitudes'] as List<dynamic>?) ??
        [];
  }

  Future<Map<String, dynamic>> obtenerMiCodigoReferido() async {
    final response = await _dio.get('/api/referidos/mi-codigo');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> obtenerProgresoReferidos() async {
    final response = await _dio.get('/api/referidos/progreso');
    final data = response.data as Map<String, dynamic>;
    return (data['progreso'] as Map<String, dynamic>?) ?? data;
  }

  Future<Map<String, dynamic>> solicitarPagoReferido(String clabe) async {
    final response = await _dio.post(
      '/api/referidos/solicitar-pago',
      data: {'clabe': clabe},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> obtenerListaReferidos({int pagina = 1}) async {
    final response = await _dio.get(
      '/api/referidos/',
      queryParameters: {'pagina': pagina},
    );
    final data = response.data as Map<String, dynamic>;
    final lista = (data['referidos'] as List<dynamic>?) ?? [];
    final totalRaw = data['total'] ?? data['total_referidos'] ?? lista.length;
    final total = totalRaw is int
        ? totalRaw
        : int.tryParse('$totalRaw') ?? lista.length;
    return {'referidos': lista, 'total': total};
  }

  Future<void> actualizarTarifa(
    double tarifaBase, {
    double? costoPorKm,
    double? costoPorMinuto,
  }) async {
    await _dio.put(
      '/api/taxistas/perfil',
      data: {
        'tarifa_base': tarifaBase,
        'costo_por_km': ?costoPorKm,
        'costo_por_minuto': ?costoPorMinuto,
      },
    );
  }
}
