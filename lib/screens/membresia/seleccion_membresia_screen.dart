import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:go_router/go_router.dart';

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
  String? _errorMensaje;

  Future<void> _onPagarPressed() async {
    if (_tipoSeleccionado == null) return;

    final quiereFactura = await _preguntarFactura();
    if (quiereFactura == null) return;

    if (!quiereFactura) {
      await _pagar(solicitaFactura: false);
      return;
    }

    Map<String, dynamic>? datosFiscales;
    try {
      datosFiscales = await _apiService.obtenerDatosFiscales();
    } catch (e) {
      datosFiscales = null;
    }
    if (!mounted) return;

    if (datosFiscales == null) {
      final guardado = await context.push<bool>('/membresia/datos-fiscales');
      if (guardado != true) return;
    } else {
      final razonSocial = datosFiscales['razon_social']?.toString() ?? '';
      final continuar = await _confirmarFacturacion(razonSocial);
      if (continuar == null) return;
      if (!continuar) {
        if (!mounted) return;
        final guardado = await context.push<bool>(
          '/membresia/datos-fiscales',
        );
        if (guardado != true) return;
      }
    }
    if (!mounted) return;

    await _pagar(solicitaFactura: true);
  }

  Future<bool?> _preguntarFactura() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          '¿Deseas factura por este pago?',
          style: CLODTextStyles.headingSmall.copyWith(
            color: CLODColors.carbon,
          ),
        ),
        content: Text(
          'Podrás usarla para tu contabilidad.',
          style: CLODTextStyles.bodyMedium.copyWith(
            color: CLODColors.carbon.withValues(alpha: 0.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'No',
              style: CLODTextStyles.bodyMedium.copyWith(
                color: CLODColors.carbon.withValues(alpha: 0.6),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Sí',
              style: CLODTextStyles.bodyMedium.copyWith(
                color: CLODColors.azulCLOD,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmarFacturacion(String razonSocial) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          'Facturación',
          style: CLODTextStyles.headingSmall.copyWith(
            color: CLODColors.carbon,
          ),
        ),
        content: Text(
          'Se facturará a $razonSocial',
          style: CLODTextStyles.bodyMedium.copyWith(
            color: CLODColors.carbon.withValues(alpha: 0.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Editar',
              style: CLODTextStyles.bodyMedium.copyWith(
                color: CLODColors.carbon.withValues(alpha: 0.6),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Confirmar',
              style: CLODTextStyles.bodyMedium.copyWith(
                color: CLODColors.azulCLOD,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarAvisoFactura() {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          '¡Pago exitoso!',
          style: CLODTextStyles.headingSmall.copyWith(
            color: CLODColors.carbon,
          ),
        ),
        content: Text(
          'Tu factura se generará en breve, la verás en tu historial de pagos',
          style: CLODTextStyles.bodyMedium.copyWith(
            color: CLODColors.carbon.withValues(alpha: 0.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Entendido',
              style: CLODTextStyles.bodyMedium.copyWith(
                color: CLODColors.azulCLOD,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pagar({required bool solicitaFactura}) async {
    final tipo = _tipoSeleccionado;
    if (tipo == null) return;

    setState(() {
      _cargando = true;
      _errorMensaje = null;
    });

    try {
      final clientSecret = await _apiService.crearPaymentIntent(
        tipo,
        solicitaFactura,
      );

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'CLOD',
        ),
      );
      await Stripe.instance.presentPaymentSheet();

      // El webhook de Stripe necesita un instante para procesar el pago del
      // lado del servidor antes de que la membresía quede reflejada.
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      final data = await _apiService.obtenerEstadoMembresia();
      if (!mounted) return;
      if (data['membresia_activa'] != null) {
        if (solicitaFactura) {
          await _mostrarAvisoFactura();
          if (!mounted) return;
        }
        context.go('/membresia-activa');
        return;
      }
      setState(() {
        _errorMensaje =
            'Tu pago se procesó, pero la membresía aún no se refleja. '
            'Intenta de nuevo en unos segundos.';
      });
    } on StripeException catch (e) {
      if (!mounted) return;
      final cancelado = e.error.code == FailureCode.Canceled;
      setState(() {
        _errorMensaje = cancelado
            ? null
            : (e.error.localizedMessage ?? 'No se pudo procesar el pago.');
      });
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
                  onTap: () => setState(() => _tipoSeleccionado = plan.tipo),
                ),
                const SizedBox(height: 16),
              ],
              if (_errorMensaje != null) ...[
                const SizedBox(height: 8),
                CLODErrorText(_errorMensaje!),
              ],
              const SizedBox(height: 16),
              CLODPrimaryButton(
                label: nombreSeleccionado != null
                    ? 'Pagar $nombreSeleccionado'
                    : 'Pagar',
                cargando: _cargando,
                habilitado: _tipoSeleccionado != null,
                onPressed: _onPagarPressed,
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
