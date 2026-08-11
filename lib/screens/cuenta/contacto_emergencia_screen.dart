import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';
import '../../theme/clod_theme.dart';
import '../../widgets/clod_error_text.dart';
import '../../widgets/clod_primary_button.dart';
import '../../widgets/clod_text_field.dart';

class ContactoEmergenciaScreen extends StatefulWidget {
  const ContactoEmergenciaScreen({super.key});

  @override
  State<ContactoEmergenciaScreen> createState() =>
      _ContactoEmergenciaScreenState();
}

class _ContactoEmergenciaScreenState extends State<ContactoEmergenciaScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();

  bool _cargandoPerfil = true;
  bool _guardando = false;
  String? _errorMensaje;
  String _nombre = '';
  String _telefono = '';

  @override
  void initState() {
    super.initState();
    _nombreController.addListener(() {
      setState(() => _nombre = _nombreController.text);
    });
    _telefonoController.addListener(() {
      setState(() => _telefono = _telefonoController.text);
    });
    _cargarActual();
  }

  Future<void> _cargarActual() async {
    try {
      final respuesta = await _apiService.obtenerMiPerfilTaxista();
      final taxista = respuesta['taxista'] as Map<String, dynamic>?;
      final nombre = taxista?['contacto_emergencia_nombre'] as String?;
      final telefono = taxista?['contacto_emergencia_telefono'] as String?;
      if (mounted) {
        if (nombre != null) _nombreController.text = nombre;
        if (telefono != null) _telefonoController.text = telefono;
        setState(() => _cargandoPerfil = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargandoPerfil = false);
      }
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  bool get _formularioValido =>
      _nombre.trim().isNotEmpty && _telefono.length == 10;

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _errorMensaje = null;
    });

    try {
      await _apiService.actualizarPerfilTaxista(
        contactoEmergenciaNombre: _nombre.trim(),
        contactoEmergenciaTelefono: _telefono,
      );
      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMensaje = 'No se pudo guardar el contacto. Intenta de nuevo.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
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
    return Scaffold(
      backgroundColor: CLODColors.grisClaro,
      body: SafeArea(
        child: _cargandoPerfil
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    CLODColors.azulCLOD,
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 48),
                    Text(
                      'Contacto de emergencia',
                      textAlign: TextAlign.center,
                      style: CLODTextStyles.headingMedium.copyWith(
                        color: CLODColors.carbon,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'A quién contactar en caso de una emergencia durante '
                      'un viaje',
                      textAlign: TextAlign.center,
                      style: CLODTextStyles.bodyMedium.copyWith(
                        color: CLODColors.carbon.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _campoConEtiqueta(
                      'Nombre del contacto',
                      CLODTextField(
                        controller: _nombreController,
                        textCapitalization: TextCapitalization.words,
                        hintText: 'Nombre completo',
                      ),
                    ),
                    const SizedBox(height: 20),
                    _campoConEtiqueta(
                      'Teléfono del contacto',
                      CLODTextField(
                        controller: _telefonoController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        hintText: '10 dígitos',
                      ),
                    ),
                    if (_errorMensaje != null) ...[
                      const SizedBox(height: 16),
                      CLODErrorText(_errorMensaje!),
                    ],
                    const SizedBox(height: 24),
                    CLODPrimaryButton(
                      label: 'Guardar',
                      cargando: _guardando,
                      habilitado: _formularioValido,
                      onPressed: _guardar,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }
}
