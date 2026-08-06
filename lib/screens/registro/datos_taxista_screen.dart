import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';
import '../../theme/clod_theme.dart';
import '../../widgets/clod_error_text.dart';
import '../../widgets/clod_primary_button.dart';
import '../../widgets/clod_text_field.dart';

class DatosTaxistaScreen extends StatefulWidget {
  const DatosTaxistaScreen({super.key});

  @override
  State<DatosTaxistaScreen> createState() => _DatosTaxistaScreenState();
}

class _DatosTaxistaScreenState extends State<DatosTaxistaScreen> {
  final ApiService _apiService = ApiService();

  final TextEditingController _licenciaController = TextEditingController();
  final TextEditingController _contactoNombreController =
      TextEditingController();
  final TextEditingController _contactoTelefonoController =
      TextEditingController();

  String _licencia = '';
  String _contactoNombre = '';
  String _contactoTelefono = '';

  bool _cargando = false;
  String? _errorMensaje;

  @override
  void initState() {
    super.initState();
    _licenciaController.addListener(() {
      setState(() => _licencia = _licenciaController.text);
    });
    _contactoNombreController.addListener(() {
      setState(() => _contactoNombre = _contactoNombreController.text);
    });
    _contactoTelefonoController.addListener(() {
      setState(() => _contactoTelefono = _contactoTelefonoController.text);
    });
  }

  @override
  void dispose() {
    _licenciaController.dispose();
    _contactoNombreController.dispose();
    _contactoTelefonoController.dispose();
    super.dispose();
  }

  bool get _formularioValido =>
      _licencia.trim().isNotEmpty &&
      _contactoNombre.trim().isNotEmpty &&
      _contactoTelefono.length == 10;

  Future<void> _onContinuar() async {
    setState(() {
      _cargando = true;
      _errorMensaje = null;
    });

    try {
      await _apiService.actualizarPerfilTaxista(
        licenciaNumero: _licencia.trim(),
        contactoEmergenciaNombre: _contactoNombre.trim(),
        contactoEmergenciaTelefono: _contactoTelefono,
      );
      if (mounted) {
        context.go('/verificacion-facial');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMensaje = 'No se pudo guardar tu información. Intenta de nuevo.';
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
                'Tus datos',
                textAlign: TextAlign.center,
                style: CLODTextStyles.headingMedium.copyWith(
                  color: CLODColors.carbon,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Necesarios para tu licencia CLOD',
                textAlign: TextAlign.center,
                style: CLODTextStyles.bodyMedium.copyWith(
                  color: CLODColors.carbon.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Número de licencia (SEMOVI)',
                style: CLODTextStyles.bodyMedium.copyWith(
                  color: CLODColors.carbon,
                ),
              ),
              const SizedBox(height: 8),
              CLODTextField(
                controller: _licenciaController,
                hintText: 'Ej. 123456',
              ),
              const SizedBox(height: 20),
              Text(
                'Nombre del contacto de emergencia',
                style: CLODTextStyles.bodyMedium.copyWith(
                  color: CLODColors.carbon,
                ),
              ),
              const SizedBox(height: 8),
              CLODTextField(
                controller: _contactoNombreController,
                textCapitalization: TextCapitalization.words,
                hintText: 'Nombre completo',
              ),
              const SizedBox(height: 20),
              Text(
                'Teléfono del contacto de emergencia',
                style: CLODTextStyles.bodyMedium.copyWith(
                  color: CLODColors.carbon,
                ),
              ),
              const SizedBox(height: 8),
              CLODTextField(
                controller: _contactoTelefonoController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                hintText: '10 dígitos',
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
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
