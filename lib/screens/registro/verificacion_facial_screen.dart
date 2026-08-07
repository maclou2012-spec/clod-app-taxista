import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_service.dart';
import '../../theme/clod_theme.dart';
import '../../widgets/clod_error_text.dart';
import '../../widgets/clod_primary_button.dart';

class VerificacionFacialScreen extends StatefulWidget {
  const VerificacionFacialScreen({super.key, required this.tipo});

  final String tipo;

  @override
  State<VerificacionFacialScreen> createState() =>
      _VerificacionFacialScreenState();
}

class _VerificacionFacialScreenState extends State<VerificacionFacialScreen> {
  final ApiService _apiService = ApiService();
  final ImagePicker _imagePicker = ImagePicker();

  bool _cargando = false;
  String? _errorMensaje;

  bool get _esOnboarding => widget.tipo == 'onboarding';

  String get _textoInstruccion => _esOnboarding
      ? 'Esta será tu referencia de identidad'
      : 'Confirma tu identidad para conectarte';

  Future<void> _iniciarVerificacion() async {
    setState(() => _errorMensaje = null);

    final XFile? imagen = await _imagePicker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
    );

    if (imagen == null) return;

    setState(() => _cargando = true);

    try {
      final foto = File(imagen.path);

      if (_esOnboarding) {
        await _apiService.subirFotoReferencia(foto);
        if (mounted) {
          context.go('/vehiculo');
        }
      } else {
        final respuesta = await _apiService.verificarIdentidadFacial(
          foto,
          widget.tipo,
        );
        final esCoincidencia = respuesta['esCoincidencia'] == true;

        if (!mounted) return;

        if (esCoincidencia) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/dashboard');
          }
        } else {
          setState(() {
            _errorMensaje = 'No pudimos confirmar tu identidad, intenta de nuevo';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMensaje = 'No se pudo procesar la foto. Intenta de nuevo.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CLODColors.carbon,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Verificación facial',
                  textAlign: TextAlign.center,
                  style: CLODTextStyles.headingMedium,
                ),
                const SizedBox(height: 32),
                const _MarcoOvaladoPunteado(
                  child: Icon(
                    Icons.face,
                    size: 96,
                    color: CLODColors.azulCLOD,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _textoInstruccion,
                  textAlign: TextAlign.center,
                  style: CLODTextStyles.bodyMedium.copyWith(
                    color: CLODColors.grisClaro.withValues(alpha: 0.8),
                  ),
                ),
                if (_errorMensaje != null) ...[
                  const SizedBox(height: 16),
                  CLODErrorText(_errorMensaje!),
                ],
                const SizedBox(height: 32),
                CLODPrimaryButton(
                  label: 'Iniciar verificación',
                  cargando: _cargando,
                  onPressed: _iniciarVerificacion,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MarcoOvaladoPunteado extends StatelessWidget {
  const _MarcoOvaladoPunteado({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedOvalPainter(),
      child: SizedBox(
        width: 220,
        height: 280,
        child: Center(child: child),
      ),
    );
  }
}

class _DashedOvalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..color = CLODColors.azulCLOD
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    const dashWidth = 8.0;
    const dashSpace = 6.0;
    final path = Path()..addOval(rect);

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
