import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/viaje_en_curso_args.dart';
import '../../theme/clod_theme.dart';
import '../../widgets/clod_primary_button.dart';

class ResumenViajeScreen extends StatelessWidget {
  const ResumenViajeScreen({super.key, required this.args});

  final ViajeEnCursoArgs args;

  String _formatearDuracion() {
    final duracion = DateTime.now().difference(args.horaInicio);
    if (duracion.inMinutes < 1) return '${duracion.inSeconds} seg';
    return '${duracion.inMinutes} min';
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
        child: SingleChildScrollView(
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
                'Viaje completado',
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
                  border: Border.all(color: const Color(0xFFD3D1C7)),
                ),
                child: Column(
                  children: [
                    _filaResumen('Pasajero', args.pasajeroNombre),
                    const Divider(height: 1),
                    _filaResumen('Duración', _formatearDuracion()),
                    const Divider(height: 1),
                    _filaResumen('Acordado', '\$${args.tarifa} MXN'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Cobro directo con el pasajero',
                textAlign: TextAlign.center,
                style: CLODTextStyles.bodySmall.copyWith(
                  color: CLODColors.carbon.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 32),
              CLODPrimaryButton(
                label: 'Volver al panel',
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
