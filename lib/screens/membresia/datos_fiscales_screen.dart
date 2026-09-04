import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';
import '../../theme/clod_theme.dart';
import '../../widgets/clod_error_text.dart';
import '../../widgets/clod_primary_button.dart';
import '../../widgets/clod_text_field.dart';

class _Opcion {
  const _Opcion(this.clave, this.etiqueta);

  final String clave;
  final String etiqueta;
}

const List<_Opcion> _usosCfdi = [
  _Opcion('G03', 'G03 - Gastos en general'),
  _Opcion('P01', 'P01 - Por definir'),
];

class DatosFiscalesScreen extends StatefulWidget {
  const DatosFiscalesScreen({super.key});

  @override
  State<DatosFiscalesScreen> createState() => _DatosFiscalesScreenState();
}

class _DatosFiscalesScreenState extends State<DatosFiscalesScreen> {
  final ApiService _apiService = ApiService();

  final TextEditingController _rfcController = TextEditingController();
  final TextEditingController _razonSocialController = TextEditingController();
  final TextEditingController _cpController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  List<_Opcion> _regimenesFiscales = [];
  String _regimenFiscal = '';
  String _usoCfdi = _usosCfdi.first.clave;

  bool _cargandoDatos = true;
  String? _errorCarga;
  bool _guardando = false;
  String? _errorMensaje;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _rfcController,
      _razonSocialController,
      _cpController,
      _emailController,
    ]) {
      controller.addListener(() => setState(() {}));
    }
    _cargarTodo();
  }

  Future<void> _cargarTodo() async {
    try {
      final resultados = await Future.wait<dynamic>([
        _apiService.obtenerRegimenesFiscales(),
        _apiService.obtenerDatosFiscales(),
      ]);
      if (!mounted) return;

      final catalogo = (resultados[0] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => _Opcion(
              item['clave'].toString(),
              '${item['clave']} - ${item['descripcion']}',
            ),
          )
          .toList();
      if (catalogo.isEmpty) {
        setState(() {
          _errorCarga = 'No se pudo cargar el formulario. Intenta de nuevo.';
        });
        return;
      }

      final datos = resultados[1] as Map<String, dynamic>?;
      final regimen = datos?['regimen_fiscal']?.toString();
      final uso = datos?['uso_cfdi']?.toString();

      setState(() {
        _regimenesFiscales = catalogo;
        _regimenFiscal = catalogo.any((o) => o.clave == regimen)
            ? regimen!
            : catalogo.firstOrNull?.clave ?? '';
        if (_usosCfdi.any((o) => o.clave == uso)) {
          _usoCfdi = uso!;
        }
        if (datos != null) {
          _rfcController.text = (datos['rfc'] ?? '').toString();
          _razonSocialController.text = (datos['razon_social'] ?? '')
              .toString();
          _cpController.text = (datos['codigo_postal_fiscal'] ?? '').toString();
          _emailController.text = (datos['email_fiscal'] ?? '').toString();
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorCarga = 'No se pudo cargar el formulario. Intenta de nuevo.';
        });
      }
    } finally {
      if (mounted) setState(() => _cargandoDatos = false);
    }
  }

  @override
  void dispose() {
    _rfcController.dispose();
    _razonSocialController.dispose();
    _cpController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  bool get _formularioValido =>
      _regimenFiscal.isNotEmpty &&
      _rfcController.text.trim().length >= 12 &&
      _razonSocialController.text.trim().isNotEmpty &&
      _cpController.text.trim().length == 5 &&
      _emailController.text.trim().contains('@');

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _errorMensaje = null;
    });

    try {
      await _apiService.guardarDatosFiscales(
        rfc: _rfcController.text.trim().toUpperCase(),
        razonSocial: _razonSocialController.text.trim(),
        regimenFiscal: _regimenFiscal,
        codigoPostalFiscal: _cpController.text.trim(),
        usoCfdi: _usoCfdi,
        emailFiscal: _emailController.text.trim(),
      );
      if (mounted) context.pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMensaje =
              'No se pudieron guardar tus datos fiscales. Intenta de nuevo.';
        });
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
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

  Widget _selector({
    required String valor,
    required List<_Opcion> opciones,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: valor,
      isExpanded: true,
      items: opciones
          .map(
            (opcion) => DropdownMenuItem(
              value: opcion.clave,
              child: Text(opcion.etiqueta, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
      style: CLODTextStyles.bodyLarge.copyWith(
        color: CLODColors.texto(context),
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: CLODColors.borde(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: CLODColors.borde(context)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        iconTheme: IconThemeData(color: CLODColors.texto(context)),
      ),
      body: SafeArea(
        top: false,
        child: _cargandoDatos
            ? const Center(child: CircularProgressIndicator())
            : _errorCarga != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: CLODErrorText(_errorCarga!),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'Datos fiscales',
                      textAlign: TextAlign.center,
                      style: CLODTextStyles.headingMedium.copyWith(
                        color: CLODColors.texto(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Los usaremos para generar tu factura',
                      textAlign: TextAlign.center,
                      style: CLODTextStyles.bodyMedium.copyWith(
                        color: CLODColors.texto(context).withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _campoConEtiqueta(
                      'RFC',
                      CLODTextField(
                        controller: _rfcController,
                        hintText: 'Ej. XAXX010101000',
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _campoConEtiqueta(
                      'Razón social',
                      CLODTextField(
                        controller: _razonSocialController,
                        hintText: 'Nombre o razón social',
                        textCapitalization: TextCapitalization.words,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _campoConEtiqueta(
                      'Régimen fiscal',
                      _selector(
                        valor: _regimenFiscal,
                        opciones: _regimenesFiscales,
                        onChanged: (valor) =>
                            setState(() => _regimenFiscal = valor!),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _campoConEtiqueta(
                      'Código postal fiscal',
                      CLODTextField(
                        controller: _cpController,
                        hintText: 'Ej. 28000',
                        keyboardType: TextInputType.number,
                        maxLength: 5,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _campoConEtiqueta(
                      'Uso de CFDI',
                      _selector(
                        valor: _usoCfdi,
                        opciones: _usosCfdi,
                        onChanged: (valor) => setState(() => _usoCfdi = valor!),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _campoConEtiqueta(
                      'Email fiscal',
                      CLODTextField(
                        controller: _emailController,
                        hintText: 'correo@ejemplo.com',
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                    if (_errorMensaje != null) ...[
                      const SizedBox(height: 16),
                      CLODErrorText(_errorMensaje!),
                    ],
                    const SizedBox(height: 24),
                    CLODPrimaryButton(
                      label: 'Guardar',
                      cargando: _guardando,
                      habilitado: _formularioValido,
                      onPressed: _guardar,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }
}
