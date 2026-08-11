import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_service.dart';
import '../../theme/clod_theme.dart';
import '../../widgets/clod_error_text.dart';
import '../../widgets/clod_primary_button.dart';
import '../../widgets/clod_text_field.dart';

class VehiculoScreen extends StatefulWidget {
  const VehiculoScreen({super.key, this.datosIniciales});

  // Si vienen datos (edición desde Perfil), se precargan los campos y al
  // guardar se regresa a la pantalla anterior en vez de seguir el flujo de
  // registro inicial.
  final Map<String, dynamic>? datosIniciales;

  @override
  State<VehiculoScreen> createState() => _VehiculoScreenState();
}

class _VehiculoScreenState extends State<VehiculoScreen> {
  final ApiService _apiService = ApiService();
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _marcaController = TextEditingController();
  final TextEditingController _modeloController = TextEditingController();
  final TextEditingController _anioController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _placasController = TextEditingController();

  String _placas = '';
  File? _foto;
  bool _cargando = false;
  String? _errorMensaje;

  bool get _modoEdicion => widget.datosIniciales != null;

  @override
  void initState() {
    super.initState();
    final datos = widget.datosIniciales;
    if (datos != null) {
      _marcaController.text = (datos['marca'] ?? '').toString();
      _modeloController.text = (datos['modelo'] ?? '').toString();
      _anioController.text = (datos['anio'] ?? '').toString();
      _colorController.text = (datos['color'] ?? '').toString();
      _placasController.text = (datos['placas'] ?? '').toString();
      _placas = _placasController.text;
    }
    _placasController.addListener(() {
      setState(() => _placas = _placasController.text);
    });
  }

  @override
  void dispose() {
    _marcaController.dispose();
    _modeloController.dispose();
    _anioController.dispose();
    _colorController.dispose();
    _placasController.dispose();
    super.dispose();
  }

  bool get _formularioValido => _placas.trim().isNotEmpty;

  String? _vacioAnulo(TextEditingController controller) {
    final texto = controller.text.trim();
    return texto.isEmpty ? null : texto;
  }

  Future<void> _tomarFotoVehiculo() async {
    final XFile? imagen = await _imagePicker.pickImage(
      source: ImageSource.camera,
    );
    if (imagen == null) return;
    setState(() => _foto = File(imagen.path));
  }

  Future<void> _onContinuar() async {
    setState(() {
      _cargando = true;
      _errorMensaje = null;
    });

    try {
      await _apiService.registrarVehiculo(
        placas: _placas.trim(),
        marca: _vacioAnulo(_marcaController),
        modelo: _vacioAnulo(_modeloController),
        anio: int.tryParse(_anioController.text.trim()),
        color: _vacioAnulo(_colorController),
        foto: _foto,
      );
      if (mounted) {
        if (_modoEdicion) {
          context.pop();
        } else {
          context.go('/servicio');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMensaje = 'No se pudo guardar tu vehículo. Intenta de nuevo.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
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
                'Tu vehículo',
                textAlign: TextAlign.center,
                style: CLODTextStyles.headingMedium.copyWith(
                  color: CLODColors.carbon,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'El que uses en tus turnos',
                textAlign: TextAlign.center,
                style: CLODTextStyles.bodyMedium.copyWith(
                  color: CLODColors.carbon.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _campoConEtiqueta(
                      'Marca',
                      CLODTextField(
                        controller: _marcaController,
                        textCapitalization: TextCapitalization.words,
                        hintText: 'Ej. Nissan',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _campoConEtiqueta(
                      'Modelo',
                      CLODTextField(
                        controller: _modeloController,
                        textCapitalization: TextCapitalization.words,
                        hintText: 'Ej. Versa',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _campoConEtiqueta(
                      'Año',
                      CLODTextField(
                        controller: _anioController,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        hintText: '2020',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _campoConEtiqueta(
                      'Color',
                      CLODTextField(
                        controller: _colorController,
                        textCapitalization: TextCapitalization.words,
                        hintText: 'Blanco',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _campoConEtiqueta(
                'Placas',
                CLODTextField(
                  controller: _placasController,
                  textCapitalization: TextCapitalization.characters,
                  hintText: 'ABC-1234',
                ),
              ),
              const SizedBox(height: 20),
              _AreaFotoVehiculo(
                foto: _foto,
                onTap: _tomarFotoVehiculo,
              ),
              if (_errorMensaje != null) ...[
                const SizedBox(height: 16),
                CLODErrorText(_errorMensaje!),
              ],
              const SizedBox(height: 24),
              CLODPrimaryButton(
                label: _modoEdicion ? 'Guardar cambios' : 'Continuar',
                cargando: _cargando,
                habilitado: _formularioValido,
                onPressed: _onContinuar,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _AreaFotoVehiculo extends StatelessWidget {
  const _AreaFotoVehiculo({required this.foto, required this.onTap});

  final File? foto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: foto == null ? _DashedRectPainter() : null,
        child: SizedBox(
          height: 160,
          width: double.infinity,
          child: foto == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.camera_alt,
                        size: 36,
                        color: CLODColors.azulCLOD,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Foto del vehículo',
                        style: CLODTextStyles.bodyMedium.copyWith(
                          color: CLODColors.carbon.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    foto!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 160,
                  ),
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
