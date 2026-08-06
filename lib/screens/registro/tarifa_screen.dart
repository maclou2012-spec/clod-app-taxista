import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';
import '../../theme/clod_theme.dart';
import '../../widgets/clod_error_text.dart';
import '../../widgets/clod_primary_button.dart';

class TarifaScreen extends StatefulWidget {
  const TarifaScreen({super.key});

  @override
  State<TarifaScreen> createState() => _TarifaScreenState();
}

class _TarifaScreenState extends State<TarifaScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _montoController = TextEditingController();

  String _montoTexto = '';
  bool _cargando = false;
  String? _errorMensaje;

  @override
  void initState() {
    super.initState();
    _montoController.addListener(() {
      setState(() => _montoTexto = _montoController.text);
    });
  }

  @override
  void dispose() {
    _montoController.dispose();
    super.dispose();
  }

  double get _monto => double.tryParse(_montoTexto) ?? 0;

  bool get _formularioValido => _monto > 0;

  Future<void> _onContinuar() async {
    setState(() {
      _cargando = true;
      _errorMensaje = null;
    });

    try {
      await _apiService.actualizarTarifa(_monto);
      if (mounted) {
        context.go('/seguro');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMensaje = 'No se pudo guardar tu tarifa. Intenta de nuevo.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final estiloMonto = CLODTextStyles.headingLarge.copyWith(
      fontSize: 44,
      color: CLODColors.carbon,
    );

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
                'Tu Tarifa Mínima',
                textAlign: TextAlign.center,
                style: CLODTextStyles.headingMedium.copyWith(
                  color: CLODColors.carbon,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tú decides cuánto cobras por tu servicio, la tarifa base es '
                'el monto mínimo que deseas cobrar a éso se le sumará el '
                'costo por Km  el coso por minuto de viaje',
                textAlign: TextAlign.center,
                style: CLODTextStyles.bodyMedium.copyWith(
                  color: CLODColors.carbon.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tarifa de Viaje = Tarifa Mínima + (Distancia_km × '
                'Costo_por_km) + (Tiempo_min × Costo_por_minuto)',
                textAlign: TextAlign.center,
                style: CLODTextStyles.bodySmall.copyWith(
                  color: CLODColors.carbon.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Escribe tu tarifa mínima, puedes ajustarla cuando quieras '
                'desde tu panel de control:',
                textAlign: TextAlign.center,
                style: CLODTextStyles.bodyMedium.copyWith(
                  color: CLODColors.carbon.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('\$', style: estiloMonto),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _montoController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                      textAlign: TextAlign.center,
                      style: estiloMonto,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        filled: false,
                        hintText: '0.00',
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'MXN',
                    style: CLODTextStyles.bodyMedium.copyWith(
                      color: CLODColors.carbon.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F7FC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: CLODColors.azulCLOD),
                ),
                child: Text(
                  'Nota: trata de ser lo más justo posible a la hora de '
                  'cobrar tus servicios ya que es un factor que te referirá '
                  'más clientes o por el contrario pueden verse afectadas '
                  'tus ganancias.',
                  textAlign: TextAlign.center,
                  style: CLODTextStyles.bodyMedium.copyWith(
                    color: CLODColors.carbon,
                  ),
                ),
              ),
              if (_errorMensaje != null) ...[
                const SizedBox(height: 16),
                CLODErrorText(_errorMensaje!),
              ],
              const SizedBox(height: 24),
              CLODPrimaryButton(
                label: 'Continuar',
                cargando: _cargando,
                habilitado: _formularioValido,
                onPressed: _onContinuar,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
