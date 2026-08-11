import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';
import '../../theme/clod_theme.dart';
import '../../widgets/clod_error_text.dart';
import '../../widgets/clod_primary_button.dart';
import '../../widgets/clod_text_field.dart';

class TarifaScreen extends StatefulWidget {
  const TarifaScreen({super.key, this.datosIniciales});

  // Si vienen datos (edición desde Perfil), se precargan los campos y al
  // guardar se regresa a la pantalla anterior en vez de seguir el flujo de
  // registro inicial.
  final Map<String, dynamic>? datosIniciales;

  @override
  State<TarifaScreen> createState() => _TarifaScreenState();
}

class _TarifaScreenState extends State<TarifaScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _montoController = TextEditingController();
  final TextEditingController _costoPorKmController = TextEditingController();
  final TextEditingController _costoPorMinutoController =
      TextEditingController();

  static final List<TextInputFormatter> _formateadoresDecimales = [
    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
  ];

  String _montoTexto = '';
  bool _cargando = false;
  String? _errorMensaje;

  bool get _modoEdicion => widget.datosIniciales != null;

  @override
  void initState() {
    super.initState();
    final datos = widget.datosIniciales;
    if (datos != null) {
      _montoController.text = (datos['tarifa_base'] ?? '').toString();
      _costoPorKmController.text = (datos['costo_por_km'] ?? '').toString();
      _costoPorMinutoController.text =
          (datos['costo_por_minuto'] ?? '').toString();
      _montoTexto = _montoController.text;
    }
    _montoController.addListener(() {
      setState(() => _montoTexto = _montoController.text);
    });
  }

  @override
  void dispose() {
    _montoController.dispose();
    _costoPorKmController.dispose();
    _costoPorMinutoController.dispose();
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
      await _apiService.actualizarTarifa(
        _monto,
        costoPorKm: double.tryParse(_costoPorKmController.text),
        costoPorMinuto: double.tryParse(_costoPorMinutoController.text),
      );
      if (mounted) {
        if (_modoEdicion) {
          context.pop();
        } else {
          context.go('/seguro');
        }
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

  Widget _campoConEtiqueta(String etiqueta, Widget campo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: CLODTextStyles.bodyMedium.copyWith(color: CLODColors.carbon),
        ),
        const SizedBox(height: 8),
        campo,
      ],
    );
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
                'Define tu propio esquema de cobro. Estos valores son solo '
                'tu referencia personal — tú decides cuánto cobrar en cada '
                'viaje.',
                textAlign: TextAlign.center,
                style: CLODTextStyles.bodyMedium.copyWith(
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
                      inputFormatters: _formateadoresDecimales,
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
              _campoConEtiqueta(
                'Costo por km (opcional)',
                CLODTextField(
                  controller: _costoPorKmController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: _formateadoresDecimales,
                  hintText: '0.00',
                ),
              ),
              const SizedBox(height: 20),
              _campoConEtiqueta(
                'Costo por minuto (opcional)',
                CLODTextField(
                  controller: _costoPorMinutoController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: _formateadoresDecimales,
                  hintText: '0.00',
                ),
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
                label: _modoEdicion ? 'Guardar cambios' : 'Continuar',
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
