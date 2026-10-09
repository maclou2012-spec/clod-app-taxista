import 'package:clay_containers/clay_containers.dart';
import 'package:flutter/material.dart';

import '../theme/clod_theme.dart';

/// Reemplazo "clay" de CLODPrimaryButton — mismo nombre de props (label,
/// onPressed, cargando, habilitado) a propósito, para que el resto de la
/// app (que sigue usando CLODPrimaryButton sin cambios) se pueda migrar a
/// este widget más adelante sin tocar cada pantalla.
///
/// Único lugar donde azulCLOD aparece como color de fondo (regla 1): el
/// relleno del botón primario. Profundidad mínima (regla 2): depth/spread
/// bajos y curveType.none.
class NeumorphicButton extends StatelessWidget {
  const NeumorphicButton({
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
      child: Opacity(
        opacity: activo ? 1 : 0.4,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: activo ? onPressed : null,
            borderRadius: BorderRadius.circular(12),
            child: ClayContainer(
              color: CLODColors.azulCLOD,
              parentColor: CLODColors.fondoPantalla(context),
              depth: 3,
              spread: 2,
              borderRadius: 12,
              curveType: CurveType.none,
              child: Center(
                child: cargando
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        label,
                        style: CLODTextStyles.bodyLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
