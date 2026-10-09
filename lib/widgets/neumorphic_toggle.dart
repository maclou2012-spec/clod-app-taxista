import 'package:clay_containers/clay_containers.dart';
import 'package:flutter/material.dart';

import '../theme/clod_theme.dart';

/// Switch "clay" simple (on/off) — para disponibilidad y modo oscuro.
///
/// Monocromía estricta (regla 1): el track es exactamente el color de
/// fondo de la pantalla cuando está apagado — azulCLOD solo aparece en la
/// posición "encendido". Profundidad mínima (regla 2): depth/spread bajos
/// y curveType.none.
class NeumorphicToggle extends StatelessWidget {
  const NeumorphicToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  static const double _width = 52;
  static const double _height = 30;
  static const double _thumbSize = 22;

  @override
  Widget build(BuildContext context) {
    final fondo = CLODColors.fondoPantalla(context);
    final activo = onChanged != null;
    final trackColor = value ? CLODColors.azulCLOD : fondo;

    return Opacity(
      opacity: activo ? 1 : 0.4,
      child: GestureDetector(
        onTap: activo ? () => onChanged!(!value) : null,
        child: ClayContainer(
          width: _width,
          height: _height,
          color: trackColor,
          parentColor: fondo,
          depth: value ? 3 : 2,
          spread: 2,
          curveType: CurveType.none,
          borderRadius: _height / 2,
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: ClayContainer(
                width: _thumbSize,
                height: _thumbSize,
                color: Colors.white,
                parentColor: trackColor,
                depth: 2,
                spread: 1,
                curveType: CurveType.none,
                borderRadius: _thumbSize / 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
