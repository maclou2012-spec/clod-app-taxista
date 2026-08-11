import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

// Pantalla temporal para confirmar que el token de Mapbox configurado vía
// secrets.properties carga el mapa correctamente.
class TestMapsScreen extends StatelessWidget {
  const TestMapsScreen({super.key});

  static final CameraViewportState _colima = CameraViewportState(
    center: Point(coordinates: Position(-103.7247, 19.2433)),
    zoom: 14,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: MapWidget(viewport: _colima));
  }
}
