import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../theme/clod_theme.dart';
import '../../widgets/clod_error_text.dart';
import '../../widgets/clod_primary_button.dart';

class SeguroScreen extends StatefulWidget {
  const SeguroScreen({super.key});

  @override
  State<SeguroScreen> createState() => _SeguroScreenState();
}

class _SeguroScreenState extends State<SeguroScreen> {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final ImagePicker _imagePicker = ImagePicker();

  File? _foto;
  bool _subiendo = false;
  bool _listo = false;
  String? _errorMensaje;

  bool get _formularioValido => _listo;

  Future<void> _capturarYSubir() async {
    final XFile? imagen = await _imagePicker.pickImage(
      source: ImageSource.camera,
    );
    if (imagen == null) return;

    final archivo = File(imagen.path);

    setState(() {
      _foto = archivo;
      _subiendo = true;
      _listo = false;
      _errorMensaje = null;
    });

    try {
      final url = await _storageService.subirDocumento(
        archivo,
        'poliza_seguro',
      );
      await _apiService.registrarDocumento(
        tipoDocumento: 'poliza_seguro',
        urlArchivo: url,
      );
      if (mounted) {
        setState(() => _listo = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMensaje = 'No se pudo subir la foto. Intenta de nuevo.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _subiendo = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CLODColors.grisClaro,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              Text(
                'Póliza de seguro',
                textAlign: TextAlign.center,
                style: CLODTextStyles.headingMedium.copyWith(
                  color: CLODColors.carbon,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sube tu comprobante vigente',
                textAlign: TextAlign.center,
                style: CLODTextStyles.bodyMedium.copyWith(
                  color: CLODColors.carbon.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 32),
              _AreaCaptura(
                etiqueta: 'Foto de tu póliza',
                foto: _foto,
                subiendo: _subiendo,
                listo: _listo,
                onTap: _capturarYSubir,
              ),
              if (_errorMensaje != null) ...[
                const SizedBox(height: 8),
                CLODErrorText(_errorMensaje!),
              ],
              const SizedBox(height: 24),
              CLODPrimaryButton(
                label: 'Continuar',
                habilitado: _formularioValido,
                onPressed: () => context.go('/revision'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _AreaCaptura extends StatelessWidget {
  const _AreaCaptura({
    required this.etiqueta,
    required this.foto,
    required this.subiendo,
    required this.listo,
    required this.onTap,
  });

  final String etiqueta;
  final File? foto;
  final bool subiendo;
  final bool listo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: subiendo ? null : onTap,
      child: CustomPaint(
        painter: foto == null ? _DashedRectPainter() : null,
        child: SizedBox(
          height: 140,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (foto == null)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.camera_alt,
                        size: 32,
                        color: CLODColors.azulCLOD,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        etiqueta,
                        style: CLODTextStyles.bodyMedium.copyWith(
                          color: CLODColors.carbon.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    foto!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 140,
                  ),
                ),
              if (subiendo)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              if (listo && !subiendo)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: CLODColors.azulCLOD,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(8),
    );
    final paint = Paint()
      ..color = CLODColors.azulCLOD
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    const dashWidth = 8.0;
    const dashSpace = 6.0;
    final path = Path()..addRRect(rrect);

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
