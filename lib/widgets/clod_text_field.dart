import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/clod_theme.dart';

class CLODTextField extends StatelessWidget {
  const CLODTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.textAlign = TextAlign.start,
    this.maxLength,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String? hintText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final TextAlign textAlign;
  final int? maxLength;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      textAlign: textAlign,
      maxLength: maxLength,
      maxLines: maxLines,
      style: CLODTextStyles.bodyLarge.copyWith(
        color: CLODColors.texto(context),
      ),
      decoration: InputDecoration(
        counterText: maxLength != null ? '' : null,
        hintText: hintText,
        filled: true,
        // Antes era Colors.white fijo — quedaba una caja blanca brillando
        // sobre el fondo oscuro del tema (esta app usa oscuro por
        // defecto). fondoTarjeta ya responde al tema igual que el resto de
        // las superficies de tarjeta de la app.
        fillColor: CLODColors.fondoTarjeta(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: CLODColors.borde(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: CLODColors.borde(context)),
        ),
      ),
    );
  }
}
