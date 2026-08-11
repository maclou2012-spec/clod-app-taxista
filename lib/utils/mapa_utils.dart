import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/clod_theme.dart';

// Mapbox (a diferencia de Google Maps) no trae un pin por defecto para
// PointAnnotation — hay que darle una imagen explícita o no se ve nada.
Future<Uint8List> generarIconoUbicacion() async {
  const double tamano = 48;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const centro = Offset(tamano / 2, tamano / 2);

  canvas.drawCircle(centro, tamano / 2, Paint()..color = Colors.white);
  canvas.drawCircle(
    centro,
    tamano / 2 - 4,
    Paint()..color = CLODColors.azulCLOD,
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(tamano.toInt(), tamano.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}
