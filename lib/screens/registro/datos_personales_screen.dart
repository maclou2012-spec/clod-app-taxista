import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';
import '../../theme/clod_theme.dart';
import '../../widgets/clod_error_text.dart';
import '../../widgets/clod_primary_button.dart';
import '../../widgets/clod_text_field.dart';

// Letras, números y guiones — vacío siempre es válido (el campo es
// opcional).
final RegExp _formatoCodigoVendedor = RegExp(r'^[A-Z0-9-]{1,20}$');

class _FormateadorMayusculas extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

class DatosPersonalesScreen extends StatefulWidget {
  const DatosPersonalesScreen({super.key, this.apiService});

  // Inyectable solo para pruebas de widgets (evita llamadas de red reales
  // sin timeout, que dejan un Timer pendiente al terminar el test) — en la
  // app real siempre se omite y se usa el singleton normal.
  final ApiService? apiService;

  @override
  State<DatosPersonalesScreen> createState() => _DatosPersonalesScreenState();
}

class _DatosPersonalesScreenState extends State<DatosPersonalesScreen> {
  late final ApiService _apiService = widget.apiService ?? ApiService();

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
  final TextEditingController _codigoVendedorController =
      TextEditingController();

  String _nombre = '';
  String _contactoTelefono = '';
  String _codigoVendedor = '';
  DateTime? _fechaNacimiento;
  bool _cargando = false;
  String? _errorMensaje;

  bool get _codigoVendedorFormatoValido =>
      _codigoVendedor.trim().isEmpty ||
      _formatoCodigoVendedor.hasMatch(_codigoVendedor.trim());

  @override
  void initState() {
    super.initState();
    _nombreController.addListener(() {
      setState(() => _nombre = _nombreController.text);
    });
    _contactoTelefonoController.addListener(() {
      setState(() => _contactoTelefono = _contactoTelefonoController.text);
    });
    _codigoVendedorController.addListener(() {
      setState(() => _codigoVendedor = _codigoVendedorController.text);
    });
    _cargarPerfilActual();
  }

  Future<void> _cargarPerfilActual() async {
    try {
      final resultados = await Future.wait([
        _apiService.obtenerUsuarioActual(),
        _apiService.obtenerMiPerfilTaxista(),
      ]);
      final usuario = resultados[0]['usuario'] as Map<String, dynamic>?;
      final taxista = resultados[1]['taxista'] as Map<String, dynamic>?;
      if (!mounted) return;

      final nombre = usuario?['nombre'] as String?;
      if (nombre != null) _nombreController.text = nombre;

      if (taxista != null) {
        setState(() {
          _curpController.text = (taxista['curp'] ?? '').toString();
          _rfcController.text = (taxista['rfc'] ?? '').toString();
          _calleController.text = (taxista['direccion_calle'] ?? '').toString();
          _numeroController.text = (taxista['direccion_numero'] ?? '')
              .toString();
          _coloniaController.text = (taxista['direccion_colonia'] ?? '')
              .toString();
          _cpController.text = (taxista['direccion_cp'] ?? '').toString();
          _ciudadController.text = (taxista['direccion_ciudad'] ?? '')
              .toString();
          _contactoNombreController.text =
              (taxista['contacto_emergencia_nombre'] ?? '').toString();
          final telefonoContacto = taxista['contacto_emergencia_telefono']
              ?.toString();
          if (telefonoContacto != null && telefonoContacto.isNotEmpty) {
            _contactoTelefonoController.text = telefonoContacto;
          }
          final fechaNacimientoRaw = taxista['fecha_nacimiento']?.toString();
          if (fechaNacimientoRaw != null) {
            _fechaNacimiento = DateTime.tryParse(fechaNacimientoRaw);
          }
        });
      }
    } catch (e) {
      // El taxista puede llenar el formulario manualmente si esto falla.
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
    _codigoVendedorController.dispose();
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
        // Antes forzaba ColorScheme.light siempre — el selector de fecha
        // salía claro aunque el resto de la app estuviera en modo oscuro
        // (el modo por defecto de esta app). Ahora respeta el tema activo.
        final oscuro = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: oscuro
                ? ColorScheme.dark(
                    primary: CLODColors.azulCLOD,
                    onPrimary: Colors.white,
                    surface: CLODColors.carbon,
                    onSurface: CLODColors.grisClaro,
                  )
                : ColorScheme.light(
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

  Future<void> _intentarGuardar(String? codigoVendedor) {
    return _apiService.actualizarDatosPersonales(
      nombre: _nombre.trim(),
      fechaNacimiento: _fechaNacimiento == null
          ? null
          : _formatearFecha(_fechaNacimiento!),
      curp: _vacioAnulo(_curpController),
      rfc: _vacioAnulo(_rfcController),
      direccionCalle: _vacioAnulo(_calleController),
      direccionNumero: _vacioAnulo(_numeroController),
      direccionColonia: _vacioAnulo(_coloniaController),
      direccionCp: _vacioAnulo(_cpController),
      direccionCiudad: _vacioAnulo(_ciudadController),
      contactoEmergenciaNombre: _vacioAnulo(_contactoNombreController),
      contactoEmergenciaTelefono: _contactoTelefono,
      codigoVendedor: codigoVendedor,
    );
  }

  Future<void> _onContinuar() async {
    setState(() {
      _cargando = true;
      _errorMensaje = null;
    });

    final codigoVendedor = _codigoVendedor.trim();

    try {
      await _intentarGuardar(codigoVendedor.isEmpty ? null : codigoVendedor);
      if (mounted) context.go('/identificacion-oficial');
    } on CodigoVendedorInvalidoException catch (e) {
      await _reintentarSinCodigoVendedor(e.mensaje);
    } catch (e) {
      // El código de vendedor es opcional — si ALGO falló mientras se
      // mandaba (el backend puede no distinguir el error con un código
      // propio todavía), se reintenta sin él antes de rendirse, para que
      // nunca sea la causa de que el taxista se quede atorado aquí.
      if (codigoVendedor.isNotEmpty) {
        await _reintentarSinCodigoVendedor('No se pudo aplicar el código de vendedor.');
      } else if (mounted) {
        setState(() {
          _errorMensaje =
              'No se pudo guardar tu información. Intenta de nuevo.';
        });
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _reintentarSinCodigoVendedor(String mensajeVendedor) async {
    try {
      await _intentarGuardar(null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$mensajeVendedor Tu información se guardó de todas formas.'),
          duration: const Duration(seconds: 4),
        ),
      );
      context.go('/identificacion-oficial');
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMensaje =
              'No se pudo guardar tu información. Intenta de nuevo.';
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
          style: CLODTextStyles.bodyMedium.copyWith(
            color: CLODColors.texto(context),
          ),
        ),
        const SizedBox(height: 8),
        campo,
      ],
    );
  }

  Widget _tituloSeccion(String texto) {
    return Text(
      texto,
      style: CLODTextStyles.headingSmall.copyWith(
        color: CLODColors.texto(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  color: CLODColors.texto(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Verifica y completa tu información',
                textAlign: TextAlign.center,
                style: CLODTextStyles.bodyMedium.copyWith(
                  color: CLODColors.texto(context).withValues(alpha: 0.6),
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
                _CampoFecha(fecha: _fechaNacimiento, onTap: _seleccionarFecha),
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
                'Código de vendedor (opcional)',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿Te invitó un vendedor de CLOD? Escribe su código',
                      style: CLODTextStyles.bodySmall.copyWith(
                        color: CLODColors.texto(context).withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    CLODTextField(
                      controller: _codigoVendedorController,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        _FormateadorMayusculas(),
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9-]')),
                      ],
                      hintText: 'Código del vendedor',
                    ),
                    if (!_codigoVendedorFormatoValido) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Solo letras, números y guiones (máx. 20 caracteres).',
                        style: CLODTextStyles.bodySmall.copyWith(
                          color: CLODColors.rojoUbicacion,
                        ),
                      ),
                    ],
                  ],
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
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
          color: CLODColors.fondoTarjeta(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: CLODColors.borde(context)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: 18,
              color: CLODColors.texto(context).withValues(alpha: 0.5),
            ),
            const SizedBox(width: 10),
            Text(
              texto,
              style: CLODTextStyles.bodyLarge.copyWith(
                color: fecha == null
                    ? CLODColors.texto(context).withValues(alpha: 0.4)
                    : CLODColors.carbon,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
