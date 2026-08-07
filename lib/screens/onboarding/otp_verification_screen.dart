import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/clod_theme.dart';
import '../../widgets/clod_error_text.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key, required this.telefono});

  final String telefono;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  static const int _duracionReenvioSegundos = 60;

  final PinInputController _pinController = PinInputController();
  Timer? _resendTimer;
  int _segundosRestantes = _duracionReenvioSegundos;

  @override
  void initState() {
    super.initState();
    _iniciarConteoRegresivo();
  }

  void _iniciarConteoRegresivo() {
    _segundosRestantes = _duracionReenvioSegundos;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_segundosRestantes <= 1) {
        timer.cancel();
        setState(() => _segundosRestantes = 0);
      } else {
        setState(() => _segundosRestantes--);
      }
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _verificarCodigo(String codigo) async {
    final authProvider = context.read<AuthProvider>();
    final resultado = await authProvider.verificarCodigo(codigo);
    if (!mounted) return;

    switch (resultado) {
      case VerificacionResultado.requiereRegistro:
        context.go('/registro-basico');
      case VerificacionResultado.exito:
        context.go('/dashboard');
      case VerificacionResultado.error:
        _pinController.clear();
    }
  }

  Future<void> _reenviarCodigo(AuthProvider authProvider) async {
    _pinController.clear();
    _iniciarConteoRegresivo();
    await authProvider.enviarCodigo(widget.telefono);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final puedeReenviar = _segundosRestantes == 0 && !authProvider.cargando;

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
                'Verifica tu código',
                textAlign: TextAlign.center,
                style: CLODTextStyles.headingMedium.copyWith(
                  color: CLODColors.carbon,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enviamos un código de 6 dígitos a +52 ${widget.telefono}',
                textAlign: TextAlign.center,
                style: CLODTextStyles.bodyMedium.copyWith(
                  color: CLODColors.carbon.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 32),
              MaterialPinField(
                length: 6,
                pinController: _pinController,
                enabled: !authProvider.cargando,
                autoFocus: true,
                keyboardType: TextInputType.number,
                theme: MaterialPinTheme(
                  shape: MaterialPinShape.outlined,
                  cellSize: const Size(46, 56),
                  spacing: 6,
                  fillColor: Colors.white,
                  focusedFillColor: Colors.white,
                  filledFillColor: Colors.white,
                  completeFillColor: Colors.white,
                  borderColor: CLODColors.carbon.withValues(alpha: 0.15),
                  focusedBorderColor: CLODColors.azulCLOD,
                  filledBorderColor: CLODColors.azulCLOD,
                  completeBorderColor: CLODColors.azulCLOD,
                  textStyle: CLODTextStyles.headingMedium.copyWith(
                    color: CLODColors.carbon,
                  ),
                ),
                onCompleted: _verificarCodigo,
              ),
              if (authProvider.cargando) ...[
                const SizedBox(height: 20),
                Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        CLODColors.azulCLOD,
                      ),
                    ),
                  ),
                ),
              ],
              if (authProvider.errorMensaje != null) ...[
                const SizedBox(height: 16),
                CLODErrorText(authProvider.errorMensaje!),
              ],
              const SizedBox(height: 32),
              Center(
                child: TextButton(
                  onPressed:
                      puedeReenviar ? () => _reenviarCodigo(authProvider) : null,
                  child: Text(
                    _segundosRestantes == 0
                        ? 'Reenviar código'
                        : 'Reenviar código en ${_segundosRestantes}s',
                    style: CLODTextStyles.bodyMedium.copyWith(
                      color: _segundosRestantes == 0
                          ? CLODColors.azulCLOD
                          : CLODColors.carbon.withValues(alpha: 0.4),
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
