import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../../theme/clod_theme.dart';
import '../../widgets/clod_error_text.dart';
import '../../widgets/clod_primary_button.dart';

// TODO: Los montos de membresía están hardcodeados porque aún no existe un
// endpoint de consulta de precios. Conectar a configuracion_sistema cuando
// se construya esa parte del panel de administración.
class _PlanMembresia {
  const _PlanMembresia({
    required this.tipo,
    required this.nombre,
    required this.monto,
    this.promo = false,
  });

  final String tipo;
  final String nombre;
  final String monto;
  final bool promo;
}

const List<_PlanMembresia> _planes = [
  _PlanMembresia(
    tipo: 'mensual',
    nombre: 'Mensual',
    monto: '\$499 MXN',
    promo: true,
  ),
  _PlanMembresia(tipo: 'diaria', nombre: 'Diaria', monto: '\$39 MXN'),
];

class SeleccionMembresiaScreen extends StatefulWidget {
  const SeleccionMembresiaScreen({super.key});

  @override
  State<SeleccionMembresiaScreen> createState() =>
      _SeleccionMembresiaScreenState();
}

class _SeleccionMembresiaScreenState extends State<SeleccionMembresiaScreen> {
  final ApiService _apiService = ApiService();

  String? _tipoSeleccionado;
  bool _cargando = false;
  bool _verificando = false;
  bool _pagoIniciado = false;
  String? _errorMensaje;

  Future<void> _irAPagar() async {
    final tipo = _tipoSeleccionado;
    if (tipo == null) return;

    setState(() {
      _cargando = true;
      _errorMensaje = null;
    });

    try {
      final url = await _apiService.crearSesionPago(tipo);
      final exito = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!exito) throw Exception('No se pudo abrir el navegador');
      if (mounted) setState(() => _pagoIniciado = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMensaje = 'No se pudo iniciar el pago. Intenta de nuevo.';
        });
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _verificarPago() async {
    setState(() {
      _verificando = true;
      _errorMensaje = null;
    });

    try {
      final data = await _apiService.obtenerEstadoMembresia();
      if (!mounted) return;
      if (data['membresia_activa'] != null) {
        context.go('/membresia-activa');
        return;
      }
      setState(() {
        _errorMensaje =
            'Aún no detectamos tu pago. Espera unos segundos e inténtalo de nuevo.';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMensaje = 'No se pudo verificar tu membresía. Intenta de nuevo.';
        });
      }
    } finally {
      if (mounted) setState(() => _verificando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombreSeleccionado = _planes
        .where((plan) => plan.tipo == _tipoSeleccionado)
        .map((plan) => plan.nombre)
        .firstOrNull;

    return Scaffold(
      backgroundColor: CLODColors.grisClaro,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              Text(
                'Tu membresía',
                textAlign: TextAlign.center,
                style: CLODTextStyles.headingMedium.copyWith(
                  color: CLODColors.carbon,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Cuota fija, nunca comisión por viaje.',
                textAlign: TextAlign.center,
                style: CLODTextStyles.bodyMedium.copyWith(
                  color: CLODColors.carbon.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 32),
              for (final plan in _planes) ...[
                _TarjetaPlan(
                  plan: plan,
                  seleccionado: _tipoSeleccionado == plan.tipo,
                  onTap: _pagoIniciado
                      ? null
                      : () => setState(() => _tipoSeleccionado = plan.tipo),
                ),
                const SizedBox(height: 16),
              ],
              if (_errorMensaje != null) ...[
                const SizedBox(height: 8),
                CLODErrorText(_errorMensaje!),
              ],
              const SizedBox(height: 16),
              if (_pagoIniciado) ...[
                Text(
                  'Completa tu pago en el navegador, y vuelve a la app '
                  'cuando termines.',
                  textAlign: TextAlign.center,
                  style: CLODTextStyles.bodyMedium.copyWith(
                    color: CLODColors.carbon.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 16),
                CLODPrimaryButton(
                  label: 'Ya pagué, verificar',
                  cargando: _verificando,
                  onPressed: _verificarPago,
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: _verificando
                        ? null
                        : () => setState(() {
                              _pagoIniciado = false;
                              _errorMensaje = null;
                            }),
                    child: Text(
                      'Elegir otro plan',
                      style: CLODTextStyles.bodyMedium.copyWith(
                        color: CLODColors.carbon.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ] else
                CLODPrimaryButton(
                  label: nombreSeleccionado != null
                      ? 'Pagar $nombreSeleccionado'
                      : 'Pagar',
                  cargando: _cargando,
                  habilitado: _tipoSeleccionado != null,
                  onPressed: _irAPagar,
                ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaPlan extends StatelessWidget {
  const _TarjetaPlan({
    required this.plan,
    required this.seleccionado,
    required this.onTap,
  });

  final _PlanMembresia plan;
  final bool seleccionado;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seleccionado
                ? CLODColors.azulCLOD
                : const Color(0xFFD3D1C7),
            width: seleccionado ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        plan.nombre,
                        style: CLODTextStyles.headingSmall.copyWith(
                          color: CLODColors.carbon,
                        ),
                      ),
                      if (plan.promo) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: CLODColors.azulCLOD,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'PROMO',
                            style: CLODTextStyles.bodySmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plan.monto,
                    style: CLODTextStyles.bodyLarge.copyWith(
                      color: CLODColors.carbon.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              seleccionado
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: seleccionado
                  ? CLODColors.azulCLOD
                  : CLODColors.carbon.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}
