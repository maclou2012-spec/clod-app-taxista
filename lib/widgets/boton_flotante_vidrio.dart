import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../theme/clod_theme.dart';

/// Botón circular flotante con vidrio esmerilado, para controles sueltos
/// sobre un mapa o una pantalla completa sin AppBar (recentrar, zoom, menú).
class BotonFlotanteVidrio extends StatelessWidget {
  const BotonFlotanteVidrio({
    super.key,
    required this.icono,
    required this.onTap,
    this.tamano = 20,
  });

  final FaIconData icono;
  final VoidCallback onTap;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;

    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: (oscuro ? CLODColors.carbon : Colors.white).withValues(
            alpha: 0.55,
          ),
          shape: CircleBorder(
            side: BorderSide(
              color: Colors.white.withValues(alpha: oscuro ? 0.08 : 0.5),
            ),
          ),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FaIcon(
                icono,
                size: tamano,
                color: CLODColors.texto(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
