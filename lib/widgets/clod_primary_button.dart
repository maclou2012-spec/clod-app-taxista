import 'package:flutter/material.dart';

import '../theme/clod_theme.dart';

class CLODPrimaryButton extends StatelessWidget {
  const CLODPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.cargando = false,
    this.habilitado = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool cargando;
  final bool habilitado;

  @override
  Widget build(BuildContext context) {
    final activo = habilitado && !cargando;

    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: activo ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: CLODColors.azulCLOD,
          foregroundColor: Colors.white,
          disabledBackgroundColor: CLODColors.azulCLOD.withValues(alpha: 0.4),
        ),
        child: cargando
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: CLODTextStyles.bodyLarge.copyWith(color: Colors.white),
              ),
      ),
    );
  }
}
