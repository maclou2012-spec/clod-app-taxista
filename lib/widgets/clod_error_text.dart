import 'package:flutter/material.dart';

import '../theme/clod_theme.dart';

class CLODErrorText extends StatelessWidget {
  const CLODErrorText(this.mensaje, {super.key});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Text(
      mensaje,
      textAlign: TextAlign.center,
      style: CLODTextStyles.bodySmall.copyWith(color: CLODColors.rojoUbicacion),
    );
  }
}
