import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';
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

class DatosPersonalesScreen extends StatefulWidget {
  const DatosPersonalesScreen({super.key});

  @override
  State<DatosPersonalesScreen> createState() => _DatosPersonalesScreenState();
}

class _DatosPersonalesScreenState extends State<DatosPersonalesScreen> {
  final ApiService _apiService = ApiService();

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _curpController = TextEditingController();
  final TextEditingController _rfcController = TextEditingController();
  final TextEditingController _calleController = TextEditingController();
  final TextEditingController _numeroController = TextEditingController();
  final TextEditingController _coloniaController = TextEditingController();
  final TextEditingController _cpController = TextEditingController();
  final TextEditingController _ciudadController = TextEditingController();
  final TextEditingController _contactoNombreController =
      TextEditingController();
  final TextEditingController _contactoTelefonoController =
      TextEditingController();

  String _nombre = '';
  String _contactoTelefono = '';
  DateTime? _fechaNacimiento;
  bool _cargando = false;
  String? _errorMensaje;

  List<Map<String, dynamic>> _localidades = [];
  int? _localidadId;
  bool _cargandoLocalidades = true;

  @override
  void initState() {
    super.initState();
    _nombreController.addListener(() {
      setState(() => _nombre = _nombreController.text);
    });
    _contactoTelefonoController.addListener(() {
      setState(() => _contactoTelefono = _contactoTelefonoController.text);
    });
    _cargarPerfilActual();
    _cargarLocalidades();
  }

  Future<void> _cargarPerfilActual() async {
    try {
      final respuesta = await _apiService.obtenerUsuarioActual();
      final usuario = respuesta['usuario'] as Map<String, dynamic>?;
      final nombre = usuario?['nombre'] as String?;
      if (nombre != null && mounted) {
        _nombreController.text = nombre;
      }
    } catch (e) {
      // El taxista puede escribir su nombre manualmente si esto falla.
    }
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
    _nombreController.dispose();
    _curpController.dispose();
    _rfcController.dispose();
    _calleController.dispose();
    _numeroController.dispose();
    _coloniaController.dispose();
    _cpController.dispose();
    _ciudadController.dispose();
    _contactoNombreController.dispose();
    _contactoTelefonoController.dispose();
    super.dispose();
  }

  bool get _formularioValido =>
      _nombre.trim().isNotEmpty && _contactoTelefono.length == 10;

  String? _vacioAnulo(TextEditingController controller) {
    final texto = controller.text.trim();
    return texto.isEmpty ? null : texto;
  }

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaNacimiento ?? DateTime(DateTime.now().year - 30),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
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
      setState(() => _fechaNacimiento = fecha);
    }
  }

  String _formatearFecha(DateTime fecha) {
    final mes = fecha.month.toString().padLeft(2, '0');
    final dia = fecha.day.toString().padLeft(2, '0');
    return '${fecha.year}-$mes-$dia';
  }

  Future<void> _onContinuar() async {
    setState(() {
      _cargando = true;
      _errorMensaje = null;
    });

    try {
      await _apiService.actualizarDatosPersonales(
        nombre: _nombre.trim(),
        fechaNacimiento:
            _fechaNacimiento == null ? null : _formatearFecha(_fechaNacimiento!),
        curp: _vacioAnulo(_curpController),
        rfc: _vacioAnulo(_rfcController),
        direccionCalle: _vacioAnulo(_calleController),
        direccionNumero: _vacioAnulo(_numeroController),
        direccionColonia: _vacioAnulo(_coloniaController),
        direccionCp: _vacioAnulo(_cpController),
        direccionCiudad: _vacioAnulo(_ciudadController),
        contactoEmergenciaNombre: _vacioAnulo(_contactoNombreController),
        contactoEmergenciaTelefono: _contactoTelefono,
        localidadId: _localidadId,
      );
      if (mounted) {
        context.go('/identificacion-oficial');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMensaje = 'No se pudo guardar tu información. Intenta de nuevo.';
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

  Widget _tituloSeccion(String texto) {
    return Text(
      texto,
      style: CLODTextStyles.headingSmall.copyWith(color: CLODColors.carbon),
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
                'Datos personales',
                textAlign: TextAlign.center,
                style: CLODTextStyles.headingMedium.copyWith(
                  color: CLODColors.carbon,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Verifica y completa tu información',
                textAlign: TextAlign.center,
                style: CLODTextStyles.bodyMedium.copyWith(
                  color: CLODColors.carbon.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 32),
              _campoConEtiqueta(
                'Nombre completo',
                CLODTextField(
                  controller: _nombreController,
                  textCapitalization: TextCapitalization.words,
                  hintText: 'Tu nombre y apellido',
                ),
              ),
              const SizedBox(height: 20),
              _campoConEtiqueta(
                'Fecha de nacimiento',
                _CampoFecha(
                  fecha: _fechaNacimiento,
                  onTap: _seleccionarFecha,
                ),
              ),
              const SizedBox(height: 20),
              _campoConEtiqueta(
                'CURP',
                CLODTextField(
                  controller: _curpController,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 18,
                  hintText: '18 caracteres',
                ),
              ),
              const SizedBox(height: 20),
              _campoConEtiqueta(
                'RFC',
                CLODTextField(
                  controller: _rfcController,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 13,
                  hintText: '13 caracteres',
                ),
              ),
              const SizedBox(height: 20),
              _campoConEtiqueta(
                'Localidad',
                _SelectorLocalidad(
                  localidades: _localidades,
                  localidadId: _localidadId,
                  cargando: _cargandoLocalidades,
                  onChanged: (valor) => setState(() => _localidadId = valor),
                ),
              ),
              const SizedBox(height: 32),
              _tituloSeccion('Dirección'),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _campoConEtiqueta(
                      'Calle',
                      CLODTextField(
                        controller: _calleController,
                        textCapitalization: TextCapitalization.words,
                        hintText: 'Nombre de la calle',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _campoConEtiqueta(
                      'Número',
                      CLODTextField(
                        controller: _numeroController,
                        keyboardType: TextInputType.text,
                        hintText: '123',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _campoConEtiqueta(
                'Colonia',
                CLODTextField(
                  controller: _coloniaController,
                  textCapitalization: TextCapitalization.words,
                  hintText: 'Tu colonia',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _campoConEtiqueta(
                      'Código postal',
                      CLODTextField(
                        controller: _cpController,
                        keyboardType: TextInputType.number,
                        maxLength: 5,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        hintText: '91000',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _campoConEtiqueta(
                      'Ciudad',
                      CLODTextField(
                        controller: _ciudadController,
                        textCapitalization: TextCapitalization.words,
                        hintText: 'Tu ciudad',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _tituloSeccion('Contacto de emergencia'),
              const SizedBox(height: 16),
              _campoConEtiqueta(
                'Nombre del contacto',
                CLODTextField(
                  controller: _contactoNombreController,
                  textCapitalization: TextCapitalization.words,
                  hintText: 'Nombre completo',
                ),
              ),
              const SizedBox(height: 20),
              _campoConEtiqueta(
                'Teléfono del contacto',
                CLODTextField(
                  controller: _contactoTelefonoController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  hintText: '10 dígitos',
                ),
              ),
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
