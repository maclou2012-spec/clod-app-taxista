import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/clod_theme.dart';
import '../../widgets/clod_error_text.dart';
import '../../widgets/clod_primary_button.dart';
import '../../widgets/clod_text_field.dart';

class PhoneEntryScreen extends StatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  State<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends State<PhoneEntryScreen> {
  final TextEditingController _telefonoController = TextEditingController();
  String _telefono = '';

  @override
  void initState() {
    super.initState();
    _telefonoController.addListener(() {
      setState(() {
        _telefono = _telefonoController.text;
      });
    });
  }

  @override
  void dispose() {
    _telefonoController.dispose();
    super.dispose();
  }

  Future<void> _onEnviarCodigo(AuthProvider authProvider) async {
    final exito = await authProvider.enviarCodigo(_telefono);
    if (exito && mounted) {
      context.go('/otp', extra: _telefono);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final telefonoValido = _telefono.length == 10;

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
                'Ingresa tu número de teléfono',
                textAlign: TextAlign.center,
                style: CLODTextStyles.headingMedium.copyWith(
                  color: CLODColors.carbon,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Te enviaremos un código de verificación por SMS',
                textAlign: TextAlign.center,
                style: CLODTextStyles.bodyMedium.copyWith(
                  color: CLODColors.carbon.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: CLODColors.carbon.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Text(
                      '+52',
                      style: CLODTextStyles.bodyLarge.copyWith(
                        color: CLODColors.carbon,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CLODTextField(
                      controller: _telefonoController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      hintText: '10 dígitos',
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    ),
                  ),
                ],
              ),
              if (authProvider.errorMensaje != null) ...[
                const SizedBox(height: 12),
                CLODErrorText(authProvider.errorMensaje!),
              ],
              const SizedBox(height: 24),
              CLODPrimaryButton(
                label: 'Enviar código',
                cargando: authProvider.cargando,
                habilitado: telefonoValido,
                onPressed: () => _onEnviarCodigo(authProvider),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: CLODColors.carbon.withValues(alpha: 0.15),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'o continúa con',
                      style: CLODTextStyles.bodySmall.copyWith(
                        color: CLODColors.carbon.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: CLODColors.carbon.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SocialIconButton(
                    child: Text(
                      'G',
                      style: CLODTextStyles.bodyLarge.copyWith(
                        color: CLODColors.carbon,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  _SocialIconButton(
                    child: Icon(Icons.facebook, color: CLODColors.azulMarino),
                  ),
                  const SizedBox(width: 20),
                  _SocialIconButton(
                    child: Icon(Icons.apple, color: CLODColors.carbon),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialIconButton extends StatelessWidget {
  const _SocialIconButton({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: CLODColors.carbon.withValues(alpha: 0.15),
        ),
      ),
      child: Center(child: child),
    );
  }
}
