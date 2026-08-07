import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';
import '../../theme/clod_theme.dart';
import '../../widgets/clod_error_text.dart';
import '../../widgets/clod_primary_button.dart';

class MembresiaActivaScreen extends StatefulWidget {
  const MembresiaActivaScreen({super.key});

  @override
  State<MembresiaActivaScreen> createState() => _MembresiaActivaScreenState();
}

class _MembresiaActivaScreenState extends State<MembresiaActivaScreen> {
  final ApiService _apiService = ApiService();

  bool _cargando = true;
  String? _errorMensaje;
  String? _tipo;
  String? _fechaFin;
  num? _monto;

  @override
  void initState() {
    super.initState();
    _cargarEstado();
  }

  Future<void> _cargarEstado() async {
    try {
      final data = await _apiService.obtenerEstadoMembresia();
      final membresia = data['membresia_activa'] as Map<String, dynamic>?;
      final montoRaw = membresia?['monto'];
      if (mounted) {
        setState(() {
          _tipo = membresia?['tipo'] as String?;
          _fechaFin = membresia?['fecha_fin'] as String?;
          _monto = montoRaw is String
              ? double.tryParse(montoRaw)
              : montoRaw as num?;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMensaje = 'No se pudo cargar el estado de tu membresía.';
          _cargando = false;
        });
      }
    }
  }

  String _formatearFecha(String? fechaIso) {
    if (fechaIso == null) return '—';
    final fecha = DateTime.tryParse(fechaIso);
    if (fecha == null) return '—';
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
  }

  String _formatearPlan(String? tipo) {
    return switch (tipo) {
      'mensual' => 'Mensual',
      'diaria' => 'Diaria',
      _ => '—',
    };
  }

  String _formatearMonto(num? monto) {
    if (monto == null) return '—';
    return '\$${monto.toStringAsFixed(2)} MXN';
  }

  Widget _filaResumen(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            etiqueta,
            style: CLODTextStyles.bodyMedium.copyWith(
              color: CLODColors.carbon.withValues(alpha: 0.6),
            ),
          ),
          Text(
            valor,
            style: CLODTextStyles.bodyLarge.copyWith(
              color: CLODColors.carbon,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CLODColors.grisClaro,
      body: SafeArea(
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
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 64),
                        Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F7FC),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check_circle,
                              size: 36,
                              color: CLODColors.azulCLOD,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Membresía activa',
                          textAlign: TextAlign.center,
                          style: CLODTextStyles.headingMedium.copyWith(
                            color: CLODColors.carbon,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFD3D1C7),
                            ),
                          ),
                          child: Column(
                            children: [
                              _filaResumen('Plan', _formatearPlan(_tipo)),
                              const Divider(height: 1),
                              _filaResumen('Vence', _formatearFecha(_fechaFin)),
                              const Divider(height: 1),
                              _filaResumen('Monto', _formatearMonto(_monto)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Ya puedes activar tu disponibilidad',
                          textAlign: TextAlign.center,
                          style: CLODTextStyles.bodyMedium.copyWith(
                            color: CLODColors.carbon.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 32),
                        CLODPrimaryButton(
                          label: 'Ir a mi panel',
                          onPressed: () => context.go('/dashboard'),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
      ),
    );
  }
}
