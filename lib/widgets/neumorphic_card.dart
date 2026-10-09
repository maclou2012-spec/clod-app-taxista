import 'package:clay_containers/clay_containers.dart';
import 'package:flutter/material.dart';

import '../theme/clod_theme.dart';

/// Reemplazo "clay" de un Container/Card plano.
///
/// Monocromía estricta (regla 1): la superficie del ClayContainer es
/// EXACTAMENTE el color de fondo de la pantalla (fondoPantalla), nunca un
/// tono aparte — el relieve se nota solo por la sombra dual, no por un
/// cambio de color. Profundidad mínima (regla 2): depth/spread bajos y
/// curveType.none, para una superficie plana y legible.
class NeumorphicCard extends StatelessWidget {
  const NeumorphicCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin = EdgeInsets.zero,
    this.borderRadius = 16,
    this.concave = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final double borderRadius;

  /// Ya no tiene efecto visual (regla 2 exige curveType.none siempre) — se
  /// conserva el parámetro para no romper las pantallas que ya lo pasan.
  final bool concave;

  @override
  Widget build(BuildContext context) {
    final superficie = CLODColors.fondoPantalla(context);

    return Padding(
      padding: margin,
      child: ClayContainer(
        color: superficie,
        parentColor: superficie,
        depth: 3,
        spread: 2,
        borderRadius: borderRadius,
        curveType: CurveType.none,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
