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

enum IniciarViajeResultado {
  exito,
  codigoIncorrecto,
  bloqueado,
  // El backend responde 409 cuando el estado de la solicitud ya no admite
  // "iniciar" (ej. otro dispositivo del mismo taxista ya lo inició, o el
  // pasajero canceló mientras se escribía el código).
  estadoInvalido,
  otroError,
}

// Resultado tipado de POST /solicitudes/:id/iniciar — nunca lanza, así la
// pantalla no necesita un try/catch para distinguir "código incorrecto" de
// "bloqueado" de un error de red genérico.
class IniciarViajeRespuesta {
  const IniciarViajeRespuesta._(
    this.resultado, {
    this.intentosRestantes,
    this.segundosRestantes,
  });

  final IniciarViajeResultado resultado;
  final int? intentosRestantes;
  final int? segundosRestantes;

  factory IniciarViajeRespuesta.exito() =>
      const IniciarViajeRespuesta._(IniciarViajeResultado.exito);

  factory IniciarViajeRespuesta.codigoIncorrecto(int? intentosRestantes) =>
      IniciarViajeRespuesta._(
        IniciarViajeResultado.codigoIncorrecto,
        intentosRestantes: intentosRestantes,
      );

  factory IniciarViajeRespuesta.bloqueado(int? segundosRestantes) =>
      IniciarViajeRespuesta._(
        IniciarViajeResultado.bloqueado,
        segundosRestantes: segundosRestantes,
      );

  factory IniciarViajeRespuesta.estadoInvalido() =>
      const IniciarViajeRespuesta._(IniciarViajeResultado.estadoInvalido);

  factory IniciarViajeRespuesta.otroError() =>
      const IniciarViajeRespuesta._(IniciarViajeResultado.otroError);
}

int? _comoEntero(dynamic valor) {
  if (valor is int) return valor;
  if (valor is num) return valor.toInt();
  if (valor is String) return int.tryParse(valor);
  return null;
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
    int? localidadId,
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
        'localidad_id': ?localidadId,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> obtenerLocalidades() async {
    final response = await _dio.get('/api/catalogos/localidades');
    final data = response.data;
    if (data is List) return data;
    if (data is Map<String, dynamic>) {
      final localidades = data['localidades'];
      if (localidades is List) return localidades;
    }
    return const [];
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

  Future<String> subirFotoPerfil(File foto) async {
    final formData = FormData.fromMap({
      'foto': await MultipartFile.fromFile(foto.path),
    });
    final response = await _dio.post('/api/perfil/foto', data: formData);
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final url = data['foto_perfil_url'];
      if (url is String) return url;
    }
    throw Exception('Respuesta inesperada al subir la foto de perfil');
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

  Future<Map<String, dynamic>> subirDocumento({
    required File foto,
    required String tipoDocumento,
  }) async {
    final formData = FormData.fromMap({
      'foto': await MultipartFile.fromFile(foto.path),
      'tipo_documento': tipoDocumento,
    });
    final response = await _dio.post(
      '/api/taxistas/documentos',
      data: formData,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> actualizarLicencia({
    String? licenciaNumero,
    String? licenciaVigencia,
    int? localidadId,
  }) async {
    final response = await _dio.put(
      '/api/taxistas/perfil',
      data: {
        'licencia_numero': ?licenciaNumero,
        'licencia_vigencia': ?licenciaVigencia,
        'localidad_id': ?localidadId,
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

  Future<List<dynamic>> obtenerRegimenesFiscales() async {
    final response = await _dio.get('/api/catalogos/regimenes-fiscales');
    final data = response.data as Map<String, dynamic>;
    return data['regimenes'] as List<dynamic>;
  }

  Future<Map<String, dynamic>?> obtenerDatosFiscales() async {
    try {
      final response = await _dio.get('/api/taxistas/datos-fiscales');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return (data['datos_fiscales'] as Map<String, dynamic>?) ?? data;
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<dynamic>> obtenerHistorialMembresias() async {
    final response = await _dio.get('/api/membresias/historial');
    final data = response.data;
    if (data is List) return data;
    final map = data as Map<String, dynamic>;
    return (map['historial'] as List<dynamic>?) ??
        (map['membresias'] as List<dynamic>?) ??
        (map['pagos'] as List<dynamic>?) ??
        [];
  }

  /// Devuelve true si la solicitud quedó en revisión (202), false si la
  /// factura se generó de inmediato.
  Future<bool> solicitarFacturaTardia(int membresiaId) async {
    final response = await _dio.post(
      '/api/membresias/$membresiaId/solicitar-factura-tardia',
    );
    return response.statusCode == 202;
  }

  Future<void> guardarDatosFiscales({
    required String rfc,
    required String razonSocial,
    required String regimenFiscal,
    required String codigoPostalFiscal,
    required String usoCfdi,
    required String emailFiscal,
  }) async {
    await _dio.put(
      '/api/taxistas/datos-fiscales',
      data: {
        'rfc': rfc,
        'razon_social': razonSocial,
        'regimen_fiscal': regimenFiscal,
        'codigo_postal_fiscal': codigoPostalFiscal,
        'uso_cfdi': usoCfdi,
        'email_fiscal': emailFiscal,
      },
    );
  }

  Future<String> crearPaymentIntent(String tipo, bool solicitaFactura) async {
    final response = await _dio.post(
      '/api/stripe/crear-payment-intent',
      data: {'tipo': tipo, 'solicita_factura': solicitaFactura},
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final clientSecret = data['clientSecret'];
      if (clientSecret is String) return clientSecret;
    }
    throw Exception('Respuesta inesperada al crear el intento de pago');
  }

  Future<Map<String, dynamic>> aceptarSolicitud(int solicitudId) async {
    final response = await _dio.post('/api/solicitudes/$solicitudId/aceptar');
    return response.data as Map<String, dynamic>;
  }

  Future<void> marcarLlegada(int solicitudId) async {
    await _dio.post('/api/solicitudes/$solicitudId/llegada');
  }

  // No imprime ni guarda el código en ningún lado. Usa un Dio aparte, sin
  // el LogInterceptor de depuración que el constructor le agrega a _dio
  // (requestBody: true imprimiría el código tal cual) — mismo patrón de
  // "dio limpio" que ya usa _refrescarToken para otra llamada sensible.
  Future<IniciarViajeRespuesta> iniciarViaje(
    int solicitudId,
    String codigo,
  ) async {
    try {
      final accessToken = await _secureStorageService.obtenerAccessToken();
      final dioSinLog = Dio(BaseOptions(baseUrl: baseUrl));
      if (accessToken != null) {
        dioSinLog.options.headers['Authorization'] = 'Bearer $accessToken';
      }
      await dioSinLog.post(
        '/api/solicitudes/$solicitudId/iniciar',
        data: {'codigo': codigo},
      );
      return IniciarViajeRespuesta.exito();
    } on DioException catch (e) {
      final data = e.response?.data;
      final codigoError = data is Map<String, dynamic>
          ? data['codigo'] as String?
          : null;
      final statusCode = e.response?.statusCode;

      if (statusCode == 403 && codigoError == 'CODIGO_INCORRECTO') {
        return IniciarViajeRespuesta.codigoIncorrecto(
          data is Map<String, dynamic>
              ? _comoEntero(data['intentos_restantes'])
              : null,
        );
      }
      if (statusCode == 423 && codigoError == 'CODIGO_BLOQUEADO') {
        return IniciarViajeRespuesta.bloqueado(
          data is Map<String, dynamic>
              ? _comoEntero(data['segundos_restantes'])
              : null,
        );
      }
      if (statusCode == 409) {
        return IniciarViajeRespuesta.estadoInvalido();
      }
      return IniciarViajeRespuesta.otroError();
    } catch (e) {
      return IniciarViajeRespuesta.otroError();
    }
  }

  Future<Map<String, dynamic>> completarViaje(int solicitudId) async {
    final response = await _dio.post('/api/solicitudes/$solicitudId/completar');
    return response.data as Map<String, dynamic>;
  }

  Future<void> calificarViaje(
    int viajeId,
    int puntuacion,
    String? comentario,
  ) async {
    await _dio.post(
      '/api/calificaciones',
      data: {
        'viaje_id': viajeId,
        'puntuacion': puntuacion,
        'comentario': ?comentario,
      },
    );
  }

  Future<void> registrarTokenFcm(String token, String plataforma) async {
    await _dio.post(
      '/api/fcm-tokens/registrar',
      data: {'token': token, 'plataforma': plataforma},
    );
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

  Future<Map<String, dynamic>?> obtenerMiViajeActivo() async {
    final response = await _dio.get('/api/solicitudes/mi-viaje-activo');
    final data = response.data;
    if (data is! Map<String, dynamic>) return null;
    final viaje = data['viaje'] ?? data['solicitud'];
    if (viaje is Map<String, dynamic>) return viaje;
    if (data['status'] == 'ok' || data.containsKey('estado')) return data;
    return null;
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
