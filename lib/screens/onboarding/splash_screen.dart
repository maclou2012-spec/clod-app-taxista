import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/viaje_en_curso_args.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../theme/clod_theme.dart';

dynamic _campo(Map<String, dynamic> mapa, List<String> llaves) {
  for (final llave in llaves) {
    final valor = mapa[llave];
    if (valor != null) return valor;
  }
  return null;
}

String? _campoTexto(Map<String, dynamic> mapa, List<String> llaves) {
  return _campo(mapa, llaves)?.toString();
}

int? _campoEntero(Map<String, dynamic> mapa, List<String> llaves) {
  final valor = _campo(mapa, llaves);
  if (valor is int) return valor;
  if (valor is num) return valor.toInt();
  if (valor is String) return int.tryParse(valor);
  return null;
}

double? _campoDecimal(Map<String, dynamic> mapa, List<String> llaves) {
  final valor = _campo(mapa, llaves);
  if (valor is num) return valor.toDouble();
  if (valor is String) return double.tryParse(valor);
  return null;
}

// Las coordenadas pueden venir anidadas (viaje['origen'] = {lat,lng}) o
// planas (viaje['origen_lat'], viaje['origen_lng']).
(double?, double?) _coordenadas(Map<String, dynamic> viaje, String prefijo) {
  final anidado = viaje[prefijo];
  final mapa = anidado is Map<String, dynamic> ? anidado : viaje;
  final lat = _campoDecimal(mapa, ['lat', 'latitud', 'latitude', '${prefijo}_lat']);
  final lng = _campoDecimal(mapa, [
    'lng',
    'lon',
    'longitud',
    'longitude',
    '${prefijo}_lng',
  ]);
  return (lat, lng);
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _navigationTimer;
  final ApiService _apiService = ApiService();
  final SocketService _socketService = SocketService();

  @override
  void initState() {
    super.initState();
    _navigationTimer = Timer(const Duration(seconds: 2), _decidirNavegacion);
  }

  Future<void> _decidirNavegacion() async {
    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();
    final sesionValida = await authProvider.intentarSesionExistente();
    if (!mounted) return;
    if (!sesionValida) {
      context.go('/telefono');
      return;
    }

    if (await _irAViajeActivo()) return;
    if (!mounted) return;
    context.go('/dashboard');
  }

  // Si el taxista ya tiene un viaje en curso (ej. cerró la app por completo
  // a media carrera), lo regresamos ahí en vez de mandarlo al dashboard.
  Future<bool> _irAViajeActivo() async {
    try {
      final viaje = await _apiService.obtenerMiViajeActivo();
      if (!mounted || viaje == null) return false;

      final estado = _campoTexto(viaje, ['estado']);
      // 'aceptado' (yendo al pasajero), 'en_espera' (ya llegó) y 'en_curso'
      // (viaje iniciado) son todos "viaje activo" — solo 'buscando' (una
      // solicitud que el taxista aún no ha aceptado) no aplica aquí.
      if (estado != 'aceptado' && estado != 'en_espera' && estado != 'en_curso') {
        return false;
      }

      final solicitudId = _campoEntero(viaje, [
        'solicitud_id',
        'solicitudId',
        'id',
      ]);
      if (solicitudId == null) return false;

      await _socketService.conectar();
      _socketService.unirseSolicitud(solicitudId);
      _socketService.marcarSolicitudActiva(solicitudId);
      if (!mounted) return false;

      final (origenLat, origenLng) = _coordenadas(viaje, 'origen');
      final (destinoLat, destinoLng) = _coordenadas(viaje, 'destino');

      final args = ViajeEnCursoArgs(
        solicitudId: solicitudId,
        pasajeroNombre:
            _campoTexto(viaje, ['pasajero_nombre', 'nombre_pasajero', 'nombre']) ??
            'Pasajero',
        origenDireccion:
            _campoTexto(viaje, ['origen_direccion', 'direccion_origen', 'origen']) ??
            '—',
        destinoDireccion:
            _campoTexto(viaje, ['destino_direccion', 'direccion_destino', 'destino']) ??
            '—',
        tarifa: _campoTexto(viaje, ['tarifa_ofrecida', 'tarifa']) ?? '—',
        horaInicio: DateTime.now(),
        origenLat: origenLat,
        origenLng: origenLng,
        destinoLat: destinoLat,
        destinoLng: destinoLng,
        estado: estado ?? 'aceptado',
      );
      context.go('/viaje-en-curso', extra: args);
      return true;
    } catch (e) {
      // Sin viaje activo (o falla la consulta) — seguimos el flujo normal.
      return false;
    }
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CLODColors.carbon,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/icono.png',
              width: 220,
            ),
            const SizedBox(height: 24),
            Text(
              'Taxi CLOD',
              style: CLODTextStyles.headingLarge,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'El directorio digital publicitario de servicio de Taxi hecho Sólo para Taxistas',
                textAlign: TextAlign.center,
                style: CLODTextStyles.bodySmall.copyWith(
                  color: CLODColors.grisClaro.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
