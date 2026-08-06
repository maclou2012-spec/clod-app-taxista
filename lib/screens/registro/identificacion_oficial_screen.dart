import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../theme/clod_theme.dart';
import '../../widgets/clod_error_text.dart';
import '../../widgets/clod_primary_button.dart';

class IdentificacionOficialScreen extends StatefulWidget {
  const IdentificacionOficialScreen({super.key});

  @override
  State<IdentificacionOficialScreen> createState() =>
      _IdentificacionOficialScreenState();
}

class _IdentificacionOficialScreenState
    extends State<IdentificacionOficialScreen> {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final ImagePicker _imagePicker = ImagePicker();

  File? _fotoFrente;
  File? _fotoReverso;
  bool _subiendoFrente = false;
  bool _subiendoReverso = false;
  bool _frenteListo = false;
  bool _reversoListo = false;
  String? _errorFrente;
  String? _errorReverso;

  bool get _formularioValido => _frenteListo && _reversoListo;

  Future<void> _capturarYSubir({required bool esFrente}) async {
    final XFile? imagen = await _imagePicker.pickImage(
      source: ImageSource.camera,
    );
    if (imagen == null) return;

    final archivo = File(imagen.path);
    final tipoDocumento = esFrente ? 'ine_frente' : 'ine_reverso';

    setState(() {
      if (esFrente) {
        _fotoFrente = archivo;
        _subiendoFrente = true;
        _frenteListo = false;
        _errorFrente = null;
      } else {
        _fotoReverso = archivo;
        _subiendoReverso = true;
        _reversoListo = false;
        _errorReverso = null;
      }
    });

    try {
      final url = await _storageService.subirDocumento(archivo, tipoDocumento);
      await _apiService.registrarDocumento(
        tipoDocumento: tipoDocumento,
        urlArchivo: url,
      );
      if (mounted) {
        setState(() {
          if (esFrente) {
            _frenteListo = true;
          } else {
            _reversoListo = true;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (esFrente) {
            _errorFrente = 'No se pudo subir la foto. Intenta de nuevo.';
          } else {
            _errorReverso = 'No se pudo subir la foto. Intenta de nuevo.';
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          if (esFrente) {
            _subiendoFrente = false;
          } else {
            _subiendoReverso = false;
          }
        });
      }
    }
  }

  Widget _campoConEtiqueta(String etiqueta, Widget campo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: CLODTextStyles.bodyMedium.copyWith(color: CLODColors.carbon),
        ),
        const SizedBox(height: 8),
        campo,
      ],
    );
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
                'Identificación oficial',
                textAlign: TextAlign.center,
                style: CLODTextStyles.headingMedium.copyWith(
                  color: CLODColors.carbon,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sube ambos lados de tu INE',
                textAlign: TextAlign.center,
                style: CLODTextStyles.bodyMedium.copyWith(
                  color: CLODColors.carbon.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 32),
              _campoConEtiqueta(
                'Frente de tu INE',
                _AreaCaptura(
                  etiqueta: 'Foto del frente',
                  foto: _fotoFrente,
                  subiendo: _subiendoFrente,
                  listo: _frenteListo,
                  onTap: () => _capturarYSubir(esFrente: true),
                ),
              ),
              if (_errorFrente != null) ...[
                const SizedBox(height: 8),
                CLODErrorText(_errorFrente!),
              ],
              const SizedBox(height: 20),
              _campoConEtiqueta(
                'Reverso de tu INE',
                _AreaCaptura(
                  etiqueta: 'Foto del reverso',
                  foto: _fotoReverso,
                  subiendo: _subiendoReverso,
                  listo: _reversoListo,
                  onTap: () => _capturarYSubir(esFrente: false),
                ),
              ),
              if (_errorReverso != null) ...[
                const SizedBox(height: 8),
                CLODErrorText(_errorReverso!),
              ],
              const SizedBox(height: 24),
              CLODPrimaryButton(
                label: 'Continuar',
                habilitado: _formularioValido,
                onPressed: () => context.go('/licencia'),
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
