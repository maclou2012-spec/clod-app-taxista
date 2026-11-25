import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/json.dart';

/// Nombre de esta app en el backend (`app` de GET /api/publico/config-app).
const String appConfig = 'taxista';

/// Respuesta de GET /api/publico/config-app (LANZAMIENTO_APPS.md §7).
class ConfigApp {
  const ConfigApp({
    required this.modo,
    this.stripePublishableKey,
    this.versionMinima,
    this.versionActual,
    this.urlDescarga,
    this.urlTienda,
    this.actualizacion,
  });

  factory ConfigApp.desdeJson(Map<String, dynamic> j) => ConfigApp(
    modo: aTexto(j['modo_servicios_externos']) ?? 'prueba',
    stripePublishableKey: aTexto(j['stripe_publishable_key']),
    versionMinima: aTexto(j['version_minima']),
    versionActual: aTexto(j['version_actual']),
    urlDescarga: aTexto(j['url_descarga']),
    urlTienda: aTexto(j['url_tienda']),
    actualizacion: aTexto(j['actualizacion']),
  );

  Map<String, dynamic> aJson() => {
    'modo_servicios_externos': modo,
    'stripe_publishable_key': stripePublishableKey,
    'version_minima': versionMinima,
    'version_actual': versionActual,
    'url_descarga': urlDescarga,
    'url_tienda': urlTienda,
    'actualizacion': actualizacion,
  };

  /// `prueba` o `produccion`.
  final String modo;

  /// `pk_test_…` o `pk_live_…`; null = no ofrecer pago con tarjeta.
  final String? stripePublishableKey;
  final String? versionMinima;
  final String? versionActual;
  final String? urlDescarga;
  final String? urlTienda;

  /// `obligatoria`, `disponible`, `ninguna` (o null si no se mandó versión).
  final String? actualizacion;

  bool get modoPrueba => modo != 'produccion';
  bool get actualizacionObligatoria => actualizacion == 'obligatoria';
  bool get actualizacionDisponible => actualizacion == 'disponible';

  /// La tienda tiene prioridad sobre el APK de clod.info.
  String? get urlActualizar => urlTienda ?? urlDescarga;
}

/// Pide la configuración al abrir la app y al volver de segundo plano si pasó
/// más de una hora. Sin respuesta se queda con la última guardada y nunca
/// bloquea la app.
class ConfigAppService {
  ConfigAppService._interno();

  static final ConfigAppService _instancia = ConfigAppService._interno();

  factory ConfigAppService() => _instancia;

  static const String _baseUrl = 'https://api.clod.info';
  static const String _claveCache = 'config_app';
  static const Duration _vigencia = Duration(hours: 1);

  final ValueNotifier<ConfigApp?> config = ValueNotifier(null);

  /// Versión instalada (`1.0.2+3`).
  String? version;
  DateTime? _ultimaConsulta;
  Future<void>? _enCurso;

  /// Pago con tarjeta: se permite mientras no sepamos lo contrario.
  bool get pagoConTarjetaDisponible {
    final c = config.value;
    return c == null || c.stripePublishableKey != null;
  }

  bool get modoPrueba => config.value?.modoPrueba ?? true;

  Future<void> inicializar() async {
    try {
      final info = await PackageInfo.fromPlatform();
      version = info.buildNumber.isEmpty
          ? info.version
          : '${info.version}+${info.buildNumber}';
    } catch (_) {
      // Sin versión el backend no calcula `actualizacion`; lo demás sirve.
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final guardada = prefs.getString(_claveCache);
      if (guardada != null) {
        config.value = ConfigApp.desdeJson(
          aMapa(jsonDecode(guardada)),
        );
      }
    } catch (_) {
      // Caché dañada: se ignora.
    }
    unawaited(refrescar());
  }

  /// Llamar cuando la app vuelve a primer plano.
  void alVolver() {
    final ultima = _ultimaConsulta;
    if (ultima == null || DateTime.now().difference(ultima) > _vigencia) {
      unawaited(refrescar());
    }
  }

  Future<void> refrescar() => _enCurso ??= _consultar().whenComplete(
    () => _enCurso = null,
  );

  Future<void> _consultar() async {
    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: _baseUrl,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      final r = await dio.get(
        '/api/publico/config-app',
        queryParameters: {
          'app': appConfig,
          'plataforma': defaultTargetPlatform == TargetPlatform.iOS
              ? 'ios'
              : 'android',
          'version': ?version,
        },
      );
      final nueva = ConfigApp.desdeJson(aMapa(r.data));
      _ultimaConsulta = DateTime.now();
      config.value = nueva;
      final prefs = await SharedPreferences.getInstance();
      // Sin `actualizacion`: la guardada se calculó para la versión de ese
      // momento y, sin red, nunca debe bloquear.
      await prefs.setString(
        _claveCache,
        jsonEncode({...nueva.aJson(), 'actualizacion': null}),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('ConfigAppService: sin respuesta ($e)');
    }
  }
}
