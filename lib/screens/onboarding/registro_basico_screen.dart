import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/clod_theme.dart';
import '../../widgets/clod_error_text.dart';
import '../../widgets/clod_primary_button.dart';
import '../../widgets/clod_text_field.dart';

class RegistroBasicoScreen extends StatefulWidget {
  const RegistroBasicoScreen({super.key});

  @override
  State<RegistroBasicoScreen> createState() => _RegistroBasicoScreenState();
}

class _RegistroBasicoScreenState extends State<RegistroBasicoScreen> {
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _codigoReferidoController =
      TextEditingController();
  String _nombre = '';

  @override
  void initState() {
    super.initState();
    _nombreController.addListener(() {
      setState(() => _nombre = _nombreController.text);
    });
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _codigoReferidoController.dispose();
    super.dispose();
  }

  Future<void> _onCompletarRegistro(AuthProvider authProvider) async {
    final codigoReferido = _codigoReferidoController.text.trim();
    final exito = await authProvider.completarRegistro(
      nombre: _nombre.trim(),
      codigoReferido: codigoReferido.isEmpty ? null : codigoReferido,
    );
    if (exito && mounted) {
      context.go('/home-temporal');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final nombreValido = _nombre.trim().isNotEmpty;

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
                'Completa tu registro',
                textAlign: TextAlign.center,
                style: CLODTextStyles.headingMedium.copyWith(
                  color: CLODColors.carbon,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Solo necesitamos tu nombre para crear tu cuenta de taxista',
                textAlign: TextAlign.center,
                style: CLODTextStyles.bodyMedium.copyWith(
                  color: CLODColors.carbon.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Nombre completo',
                style: CLODTextStyles.bodyMedium.copyWith(
                  color: CLODColors.carbon,
                ),
              ),
              const SizedBox(height: 8),
              CLODTextField(
                controller: _nombreController,
                textCapitalization: TextCapitalization.words,
                hintText: 'Tu nombre y apellido',
              ),
              const SizedBox(height: 20),
              Text(
                'Código de referido (opcional)',
                style: CLODTextStyles.bodyMedium.copyWith(
                  color: CLODColors.carbon,
                ),
              ),
              const SizedBox(height: 8),
              CLODTextField(
                controller: _codigoReferidoController,
                textCapitalization: TextCapitalization.characters,
                hintText: 'Si alguien te invitó a CLOD',
              ),
              if (authProvider.errorMensaje != null) ...[
                const SizedBox(height: 16),
                CLODErrorText(authProvider.errorMensaje!),
              ],
              const SizedBox(height: 24),
              CLODPrimaryButton(
                label: 'Completar registro',
                cargando: authProvider.cargando,
                habilitado: nombreValido,
                onPressed: () => _onCompletarRegistro(authProvider),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
