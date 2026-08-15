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

  static const Color _borderColor = Color(0xFFD3D1C7);

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
      style: CLODTextStyles.bodyLarge.copyWith(color: CLODColors.carbon),
      decoration: InputDecoration(
        counterText: maxLength != null ? '' : null,
        hintText: hintText,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _borderColor),
        ),
      ),
    );
  }
}
