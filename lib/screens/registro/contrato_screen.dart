import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/clod_theme.dart';
import '../../widgets/clod_primary_button.dart';

class ContratoScreen extends StatefulWidget {
  const ContratoScreen({super.key, this.soloLectura = false});

  // En modo solo lectura (acceso desde Configuración) se oculta el checkbox
  // y el botón de aceptar — solo se puede consultar el texto.
  final bool soloLectura;

  @override
  State<ContratoScreen> createState() => _ContratoScreenState();
}

class _ContratoScreenState extends State<ContratoScreen> {
  bool _aceptado = false;

  void _onAceptarYContinuar() {
    context.go('/registro-basico-taxista');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CLODColors.grisClaro,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Text(
                'Contrato de licenciatario',
                textAlign: TextAlign.center,
                style: CLODTextStyles.headingMedium.copyWith(
                  color: CLODColors.carbon,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Versión vigente — léelo con calma',
                textAlign: TextAlign.center,
                style: CLODTextStyles.bodyMedium.copyWith(
                  color: CLODColors.carbon.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: CLODColors.carbon.withValues(alpha: 0.15),
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _seccionContrato(
                          '1. Naturaleza del servicio',
                          'CLOD opera como un directorio digital y servicio de licencia de '
                              'marca para taxistas independientes. CLOD no presta servicios de '
                              'transporte ni actúa como empleador del licenciatario en ningún '
                              'momento.\n\n'
                              'El licenciatario reconoce que utiliza la marca CLOD en su '
                              'calidad de empresario independiente, conservando el control '
                              'total sobre su actividad económica.',
                        ),
                        _seccionContrato(
                          '2. Independencia comercial',
                          'El licenciatario no mantiene relación laboral alguna con CLOD. No '
                              'existe subordinación, horario impuesto ni exclusividad de '
                              'ningún tipo.\n\n'
                              'El licenciatario es libre de fijar su propia tarifa y de operar '
                              'de forma simultánea bajo cualquier otro medio o servicio que '
                              'considere conveniente.',
                        ),
                        _seccionContrato(
                          '3. Disponibilidad voluntaria',
                          'La conexión y desconexión del licenciatario en la aplicación es '
                              'completamente voluntaria. El licenciatario puede ignorar '
                              'cualquier solicitud de viaje sin consecuencia ni penalización '
                              'alguna.\n\n'
                              'CLOD no impone horarios ni jornadas de disponibilidad '
                              'obligatoria.',
                        ),
                        _seccionContrato(
                          '4. Terminación',
                          'Cualquiera de las partes puede dar por terminada esta licencia en '
                              'cualquier momento, sin necesidad de justificar causa.\n\n'
                              'La terminación no genera derecho a indemnización, prestación '
                              'laboral ni compensación de ningún tipo, dada la naturaleza de '
                              'licencia comercial independiente de este acuerdo.',
                          ultimaSeccion: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!widget.soloLectura) ...[
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => setState(() => _aceptado = !_aceptado),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _aceptado,
                        activeColor: CLODColors.azulCLOD,
                        onChanged: (valor) =>
                            setState(() => _aceptado = valor ?? false),
                      ),
                      Expanded(
                        child: Text(
                          'He leído y acepto los términos',
                          style: CLODTextStyles.bodyMedium.copyWith(
                            color: CLODColors.carbon,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                CLODPrimaryButton(
                  label: 'Aceptar y continuar',
                  habilitado: _aceptado,
                  onPressed: _onAceptarYContinuar,
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _seccionContrato(
    String titulo,
    String texto, {
    bool ultimaSeccion = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: ultimaSeccion ? 0 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: CLODTextStyles.headingSmall.copyWith(
              color: CLODColors.carbon,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            texto,
            style: CLODTextStyles.bodyMedium.copyWith(
              color: CLODColors.carbon.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '[TEXTO PENDIENTE DE REVISIÓN LEGAL]',
            style: CLODTextStyles.bodySmall.copyWith(
              color: CLODColors.rojoUbicacion,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
