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
  final TextEditingController _numeroEconomicoController =
      TextEditingController();
  final TextEditingController _observacionesController =
      TextEditingController();

  String _placas = '';
  File? _foto;
  String? _fotoUrlExistente;
  bool _cargando = false;
  String? _errorMensaje;

  bool _cargandoCaracteristicas = true;
  List<Map<String, dynamic>> _caracteristicas = [];
  final Set<int> _plusSeleccionados = {};

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
      _numeroEconomicoController.text =
          (datos['numero_economico'] ?? '').toString();
      _fotoUrlExistente = datos['foto_url'] as String?;
      _placas = _placasController.text;
    }
    _placasController.addListener(() {
      setState(() => _placas = _placasController.text);
    });
    _cargarCaracteristicas();
  }

  @override
  void dispose() {
    _marcaController.dispose();
    _modeloController.dispose();
    _anioController.dispose();
    _colorController.dispose();
    _placasController.dispose();
    _numeroEconomicoController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  // El catálogo de plus, las observaciones y los plus ya activos viven en el
  // perfil del taxista, no en los datosIniciales (que son solo el vehículo)
  // — se cargan aparte.
  Future<void> _cargarCaracteristicas() async {
    try {
      final catalogoFuture = _apiService.obtenerCaracteristicasPlus();
      final perfilFuture = _apiService.obtenerMiPerfilTaxista();
      final catalogo = await catalogoFuture;
      final perfil = await perfilFuture;
      if (!mounted) return;
      final taxista = perfil['taxista'] as Map<String, dynamic>?;
      final activos = (taxista?['caracteristicas'] as List<dynamic>?) ?? [];
      setState(() {
        _caracteristicas = catalogo.cast<Map<String, dynamic>>();
        _observacionesController.text =
            (taxista?['observaciones'] ?? '').toString();
        _plusSeleccionados
          ..clear()
          ..addAll(activos.map((id) => id as int));
        _cargandoCaracteristicas = false;
      });
    } catch (e) {
      if (mounted) setState(() => _cargandoCaracteristicas = false);
    }
  }

  Future<void> _onTogglePlus(int caracteristicaId) async {
    final estabaSeleccionado = _plusSeleccionados.contains(caracteristicaId);
    setState(() {
      if (estabaSeleccionado) {
        _plusSeleccionados.remove(caracteristicaId);
      } else {
        _plusSeleccionados.add(caracteristicaId);
      }
    });
    try {
      if (estabaSeleccionado) {
        await _apiService.quitarPlus(caracteristicaId);
      } else {
        await _apiService.agregarPlus(caracteristicaId);
      }
    } catch (e) {
      // Guardado optimista: si falla, el taxista puede volver a tocar el chip.
    }
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
        numeroEconomico: _vacioAnulo(_numeroEconomicoController),
        foto: _foto,
      );
      await _apiService.actualizarObservacionesServicio(
        _observacionesController.text.trim(),
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
              _campoConEtiqueta(
                'Número de taxi (opcional)',
                CLODTextField(
                  controller: _numeroEconomicoController,
                  textCapitalization: TextCapitalization.characters,
                  hintText: 'Ej. 042',
                ),
              ),
              const SizedBox(height: 20),
              _AreaFotoVehiculo(
                foto: _foto,
                fotoUrlExistente: _fotoUrlExistente,
                onTap: _tomarFotoVehiculo,
              ),
              const SizedBox(height: 28),
              Text(
                'Servicios plus',
                style: CLODTextStyles.bodyMedium.copyWith(
                  color: CLODColors.carbon,
                ),
              ),
              const SizedBox(height: 8),
              _cargandoCaracteristicas
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    )
                  : Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _caracteristicas.map((caracteristica) {
                        final id = caracteristica['id'] as int;
                        final nombre =
                            caracteristica['nombre'] as String? ?? '';
                        return _ChipSeleccionable(
                          texto: nombre,
                          seleccionado: _plusSeleccionados.contains(id),
                          onTap: () => _onTogglePlus(id),
                        );
                      }).toList(),
                    ),
              const SizedBox(height: 20),
              _campoConEtiqueta(
                'Observaciones (opcional)',
                CLODTextField(
                  controller: _observacionesController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 4,
                  hintText: 'Ej. Acepto mascotas, tengo espacio para equipaje...',
                ),
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

class _ChipSeleccionable extends StatelessWidget {
  const _ChipSeleccionable({
    required this.texto,
    required this.seleccionado,
    required this.onTap,
  });

  static const Color _colorBorde = Color(0xFFD3D1C7);

  final String texto;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: seleccionado ? CLODColors.azulCLOD : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: seleccionado ? CLODColors.azulCLOD : _colorBorde,
          ),
        ),
        child: Text(
          texto,
          style: CLODTextStyles.bodyMedium.copyWith(
            color: seleccionado ? Colors.white : CLODColors.carbon,
          ),
        ),
      ),
    );
  }
}

class _AreaFotoVehiculo extends StatelessWidget {
  const _AreaFotoVehiculo({
    required this.foto,
    required this.fotoUrlExistente,
    required this.onTap,
  });

  final File? foto;
  final String? fotoUrlExistente;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hayFoto = foto != null || fotoUrlExistente != null;
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: hayFoto ? null : _DashedRectPainter(),
        child: SizedBox(
          height: 160,
          width: double.infinity,
          child: !hayFoto
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
                  child: foto != null
                      ? Image.file(
                          foto!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 160,
                        )
                      : Image.network(
                          fotoUrlExistente!,
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
