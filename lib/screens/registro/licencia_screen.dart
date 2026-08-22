import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../theme/clod_theme.dart';
import '../../widgets/clod_error_text.dart';
import '../../widgets/clod_primary_button.dart';
import '../../widgets/clod_text_field.dart';

String? _campoTexto(Map<String, dynamic> mapa, List<String> llaves) {
  for (final llave in llaves) {
    final valor = mapa[llave];
    if (valor != null) return valor.toString();
  }
  return null;
}

int? _campoEntero(Map<String, dynamic> mapa, List<String> llaves) {
  for (final llave in llaves) {
    final valor = mapa[llave];
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();
    if (valor is String) {
      final parseado = int.tryParse(valor);
      if (parseado != null) return parseado;
    }
  }
  return null;
}

const Color _colorBordeCampo = Color(0xFFD3D1C7);

class LicenciaScreen extends StatefulWidget {
  const LicenciaScreen({super.key});

  @override
  State<LicenciaScreen> createState() => _LicenciaScreenState();
}

class _LicenciaScreenState extends State<LicenciaScreen> {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _licenciaController = TextEditingController();

  String _licenciaNumero = '';
  DateTime? _vigencia;
  File? _fotoLicencia;
  bool _subiendoFoto = false;
  bool _fotoLista = false;
  String? _errorFoto;

  bool _cargando = false;
  String? _errorMensaje;

  List<Map<String, dynamic>> _localidades = [];
  int? _localidadId;
  bool _cargandoLocalidades = true;

  @override
  void initState() {
    super.initState();
    _licenciaController.addListener(() {
      setState(() => _licenciaNumero = _licenciaController.text);
    });
    _cargarLocalidades();
  }

  Future<void> _cargarLocalidades() async {
    try {
      final datos = await _apiService.obtenerLocalidades();
      if (mounted) {
        setState(() {
          _localidades = datos.whereType<Map<String, dynamic>>().toList();
          _cargandoLocalidades = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cargandoLocalidades = false);
    }
  }

  @override
  void dispose() {
    _licenciaController.dispose();
    super.dispose();
  }

  bool get _formularioValido => _licenciaNumero.trim().isNotEmpty;

  Future<void> _seleccionarVigencia() async {
    final ahora = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: _vigencia ?? ahora.add(const Duration(days: 365)),
      firstDate: ahora,
      lastDate: ahora.add(const Duration(days: 365 * 10)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: CLODColors.azulCLOD,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: CLODColors.carbon,
            ),
          ),
          child: child!,
        );
      },
    );
    if (fecha != null) {
      setState(() => _vigencia = fecha);
    }
  }

  String _formatearFecha(DateTime fecha) {
    final mes = fecha.month.toString().padLeft(2, '0');
    final dia = fecha.day.toString().padLeft(2, '0');
    return '${fecha.year}-$mes-$dia';
  }

  Future<void> _capturarYSubirFoto() async {
    final XFile? imagen = await _imagePicker.pickImage(
      source: ImageSource.camera,
    );
    if (imagen == null) return;

    final archivo = File(imagen.path);

    setState(() {
      _fotoLicencia = archivo;
      _subiendoFoto = true;
      _fotoLista = false;
      _errorFoto = null;
    });

    try {
      final url = await _storageService.subirDocumento(
        archivo,
        'licencia_foto',
      );
      await _apiService.registrarDocumento(
        tipoDocumento: 'licencia_foto',
        urlArchivo: url,
      );
      if (mounted) {
        setState(() => _fotoLista = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorFoto = 'No se pudo subir la foto. Intenta de nuevo.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _subiendoFoto = false);
      }
    }
  }

  Future<void> _onContinuar() async {
    setState(() {
      _cargando = true;
      _errorMensaje = null;
    });

    try {
      await _apiService.actualizarLicencia(
        licenciaNumero: _licenciaNumero.trim(),
        licenciaVigencia:
            _vigencia == null ? null : _formatearFecha(_vigencia!),
        localidadId: _localidadId,
      );
      if (mounted) {
        context.go('/servicio');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMensaje = 'No se pudo guardar tu licencia. Intenta de nuevo.';
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
                'Datos de licencia',
                textAlign: TextAlign.center,
                style: CLODTextStyles.headingMedium.copyWith(
                  color: CLODColors.carbon,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tu permiso vigente de SEMOVI',
                textAlign: TextAlign.center,
                style: CLODTextStyles.bodyMedium.copyWith(
                  color: CLODColors.carbon.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 32),
              _campoConEtiqueta(
                'Número de licencia (SEMOVI)',
                CLODTextField(
                  controller: _licenciaController,
                  hintText: 'Ej. 123456',
                ),
              ),
              const SizedBox(height: 20),
              _campoConEtiqueta(
                'Vigencia',
                _CampoFecha(
                  fecha: _vigencia,
                  onTap: _seleccionarVigencia,
                ),
              ),
              const SizedBox(height: 20),
              _campoConEtiqueta(
                'Localidad donde operas',
                _SelectorLocalidad(
                  localidades: _localidades,
                  localidadId: _localidadId,
                  cargando: _cargandoLocalidades,
                  onChanged: (valor) => setState(() => _localidadId = valor),
                ),
              ),
              const SizedBox(height: 20),
              _campoConEtiqueta(
                'Foto de la licencia',
                _AreaCaptura(
                  etiqueta: 'Foto de la licencia',
                  foto: _fotoLicencia,
                  subiendo: _subiendoFoto,
                  listo: _fotoLista,
                  onTap: _capturarYSubirFoto,
                ),
              ),
              if (_errorFoto != null) ...[
                const SizedBox(height: 8),
                CLODErrorText(_errorFoto!),
              ],
              if (_errorMensaje != null) ...[
                const SizedBox(height: 16),
                CLODErrorText(_errorMensaje!),
              ],
              const SizedBox(height: 24),
              CLODPrimaryButton(
                label: 'Continuar',
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

class _CampoFecha extends StatelessWidget {
  const _CampoFecha({required this.fecha, required this.onTap});

  static const Color _colorBorde = Color(0xFFD3D1C7);

  final DateTime? fecha;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final texto = fecha == null
        ? 'Selecciona una fecha'
        : '${fecha!.day.toString().padLeft(2, '0')}/'
            '${fecha!.month.toString().padLeft(2, '0')}/'
            '${fecha!.year}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _colorBorde),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: 18,
              color: CLODColors.carbon.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 10),
            Text(
              texto,
              style: CLODTextStyles.bodyLarge.copyWith(
                color: fecha == null
                    ? CLODColors.carbon.withValues(alpha: 0.4)
                    : CLODColors.carbon,
              ),
            ),
          ],
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

class _SelectorLocalidad extends StatelessWidget {
  const _SelectorLocalidad({
    required this.localidades,
    required this.localidadId,
    required this.cargando,
    required this.onChanged,
  });

  final List<Map<String, dynamic>> localidades;
  final int? localidadId;
  final bool cargando;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    // Solo agrupamos visualmente por estado (prefijo en la etiqueta) si hay
    // más de uno activo — hoy solo Colima, así que se ve como una lista
    // plana de localidades.
    final estados = localidades
        .map((localidad) => _campoTexto(localidad, ['estado']))
        .whereType<String>()
        .toSet();
    final mostrarEstado = estados.length > 1;

    final items = localidades.map((localidad) {
      final id = _campoEntero(localidad, ['id']);
      final nombre = _campoTexto(localidad, ['nombre']) ?? '—';
      final estado = _campoTexto(localidad, ['estado']);
      final etiqueta = mostrarEstado && estado != null
          ? '$estado — $nombre'
          : nombre;
      return DropdownMenuItem<int>(value: id, child: Text(etiqueta));
    }).toList();

    return DropdownButtonFormField<int>(
      initialValue: localidadId,
      isExpanded: true,
      items: items,
      onChanged: cargando ? null : onChanged,
      style: CLODTextStyles.bodyLarge.copyWith(color: CLODColors.carbon),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: cargando ? 'Cargando...' : 'Selecciona tu localidad',
        hintStyle: CLODTextStyles.bodyLarge.copyWith(
          color: CLODColors.carbon.withValues(alpha: 0.4),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _colorBordeCampo),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _colorBordeCampo),
        ),
      ),
    );
  }
}
