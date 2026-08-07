import 'package:flutter/material.dart';

import '../../theme/clod_theme.dart';

// Placeholder — la pantalla real de viaje en curso (mapa con ruta, botón de
// completar/cancelar) se construye en el Paso 6 de este bloque.
class ViajeEnCursoScreen extends StatelessWidget {
  const ViajeEnCursoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CLODColors.carbon,
      body: Center(
        child: Text(
          'Viaje en curso\n(próximamente)',
          textAlign: TextAlign.center,
          style: CLODTextStyles.bodyLarge,
        ),
      ),
    );
  }
}
