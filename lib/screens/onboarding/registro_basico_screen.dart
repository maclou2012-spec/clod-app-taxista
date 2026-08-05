import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/clod_theme.dart';

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
              TextField(
                controller: _nombreController,
                textCapitalization: TextCapitalization.words,
                style: CLODTextStyles.bodyLarge.copyWith(
                  color: CLODColors.carbon,
                ),
                decoration: InputDecoration(
                  hintText: 'Tu nombre y apellido',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: CLODColors.carbon.withValues(alpha: 0.15),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Código de referido (opcional)',
                style: CLODTextStyles.bodyMedium.copyWith(
                  color: CLODColors.carbon,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _codigoReferidoController,
                textCapitalization: TextCapitalization.characters,
                style: CLODTextStyles.bodyLarge.copyWith(
                  color: CLODColors.carbon,
                ),
                decoration: InputDecoration(
                  hintText: 'Si alguien te invitó a CLOD',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: CLODColors.carbon.withValues(alpha: 0.15),
                    ),
                  ),
                ),
              ),
              if (authProvider.errorMensaje != null) ...[
                const SizedBox(height: 16),
                Text(
                  authProvider.errorMensaje!,
                  textAlign: TextAlign.center,
                  style: CLODTextStyles.bodySmall.copyWith(
                    color: CLODColors.rojoUbicacion,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: nombreValido && !authProvider.cargando
                      ? () => _onCompletarRegistro(authProvider)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CLODColors.azulCLOD,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        CLODColors.azulCLOD.withValues(alpha: 0.4),
                  ),
                  child: authProvider.cargando
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Completar registro',
                          style: CLODTextStyles.bodyLarge.copyWith(
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
