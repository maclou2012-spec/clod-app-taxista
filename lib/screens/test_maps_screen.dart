import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Pantalla temporal para confirmar que la Google Maps API key configurada
// vía secrets.properties carga el mapa correctamente. Eliminar cuando el
// Bloque 4 (Operación diaria) integre el mapa real.
class TestMapsScreen extends StatelessWidget {
  const TestMapsScreen({super.key});

  static const CameraPosition _veracruz = CameraPosition(
    target: LatLng(19.1738, -96.1342),
    zoom: 13,
  );

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: GoogleMap(
        initialCameraPosition: _veracruz,
      ),
    );
  }
}
