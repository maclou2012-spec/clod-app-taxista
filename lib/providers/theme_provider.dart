import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _clave = 'modo_oscuro';

  // Default actual de la app (panel operacional oscuro) — se mantiene hasta
  // que el usuario elija explícitamente lo contrario.
  ThemeMode modo = ThemeMode.dark;

  Future<void> cargarPreferencia() async {
    final prefs = await SharedPreferences.getInstance();
    final oscuro = prefs.getBool(_clave);
    if (oscuro != null) {
      modo = oscuro ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();
    }
  }

  Future<void> alternar() async {
    modo = modo == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_clave, modo == ThemeMode.dark);
  }
}
