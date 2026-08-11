import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/clod_theme.dart';
import '../../widgets/clod_error_text.dart';

String? _campoViaje(Map<String, dynamic> viaje, List<String> llaves) {
  for (final llave in llaves) {
    final valor = viaje[llave];
    if (valor != null) return valor.toString();
  }
  return null;
}

DateTime? _fechaViaje(Map<String, dynamic> viaje) {
  const llaves = [
    'completado_en',
    'fecha_completado',
    'actualizado_en',
    'updated_at',
    'creado_en',
    'created_at',
  ];
  for (final llave in llaves) {
    final valor = viaje[llave];
    if (valor is String) {
      final fecha = DateTime.tryParse(valor);
      if (fecha != null) return fecha.toLocal();
    }
  }
  return null;
}

String _formatearFecha(DateTime fecha) {
  final ahora = DateTime.now();
  final hoy = DateTime(ahora.year, ahora.month, ahora.day);
  final fechaDia = DateTime(fecha.year, fecha.month, fecha.day);
  final diferenciaDias = hoy.difference(fechaDia).inDays;

  final hora12 = fecha.hour % 12 == 0 ? 12 : fecha.hour % 12;
  final minuto = fecha.minute.toString().padLeft(2, '0');
  final ampm = fecha.hour < 12 ? 'am' : 'pm';
  final horaTexto = '$hora12:$minuto $ampm';

  if (diferenciaDias == 0) return 'Hoy, $horaTexto';
  if (diferenciaDias == 1) return 'Ayer, $horaTexto';

  final dia = fecha.day.toString().padLeft(2, '0');
  final mes = fecha.month.toString().padLeft(2, '0');
  return '$dia/$mes/${fecha.year}, $horaTexto';
}

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  final ApiService _apiService = ApiService();

  bool _cargando = true;
  String? _errorMensaje;
  List<Map<String, dynamic>> _viajes = [];

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  Future<void> _cargarHistorial() async {
    try {
      final datos = await _apiService.obtenerHistorialViajes();
      final viajes = datos.cast<Map<String, dynamic>>()
        ..sort((a, b) {
          final fechaA = _fechaViaje(a);
          final fechaB = _fechaViaje(b);
          if (fechaA == null || fechaB == null) return 0;
          return fechaB.compareTo(fechaA);
        });
      if (mounted) {
        setState(() {
          _viajes = viajes;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMensaje = 'No se pudo cargar tu historial.';
          _cargando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CLODColors.grisClaro,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 48),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Historial',
                style: CLODTextStyles.headingMedium.copyWith(
                  color: CLODColors.carbon,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _cargando
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          CLODColors.azulCLOD,
                        ),
                      ),
                    )
                  : _errorMensaje != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: CLODErrorText(_errorMensaje!),
                          ),
                        )
                      : _viajes.isEmpty
                          ? const _EstadoVacio()
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              itemCount: _viajes.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) =>
                                  _TarjetaViaje(viaje: _viajes[index]),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history,
              size: 48,
              color: CLODColors.carbon.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Aún no tienes viajes completados',
              textAlign: TextAlign.center,
              style: CLODTextStyles.bodyMedium.copyWith(
                color: CLODColors.carbon.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaViaje extends StatelessWidget {
  const _TarjetaViaje({required this.viaje});

  final Map<String, dynamic> viaje;

  @override
  Widget build(BuildContext context) {
    final nombre =
        _campoViaje(viaje, [
          'pasajero_nombre',
          'nombre_pasajero',
          'nombre',
        ]) ??
        'Pasajero';
    final tarifa = _campoViaje(viaje, [
      'tarifa_ofrecida',
      'tarifa_acordada',
      'tarifa',
    ]);
    final fecha = _fechaViaje(viaje);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD3D1C7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  nombre,
                  style: CLODTextStyles.bodyLarge.copyWith(
                    color: CLODColors.carbon,
                  ),
                ),
              ),
              if (tarifa != null)
                Text(
                  '\$$tarifa',
                  style: CLODTextStyles.bodyLarge.copyWith(
                    color: CLODColors.azulCLOD,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            fecha != null ? _formatearFecha(fecha) : '—',
            style: CLODTextStyles.bodySmall.copyWith(
              color: CLODColors.carbon.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
