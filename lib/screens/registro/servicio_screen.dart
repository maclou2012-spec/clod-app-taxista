import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';
import '../../theme/clod_theme.dart';
import '../../widgets/clod_error_text.dart';
import '../../widgets/clod_primary_button.dart';

class ServicioScreen extends StatefulWidget {
  const ServicioScreen({super.key});

  @override
  State<ServicioScreen> createState() => _ServicioScreenState();
}

class _ServicioScreenState extends State<ServicioScreen> {
  final ApiService _apiService = ApiService();

  bool _cargando = true;
  String? _errorCarga;
  List<Map<String, dynamic>> _clases = [];
  List<Map<String, dynamic>> _caracteristicas = [];
  int? _claseSeleccionadaId;
  final Set<int> _plusSeleccionados = {};

  @override
  void initState() {
    super.initState();
    _cargarCatalogos();
  }

  Future<void> _cargarCatalogos() async {
    try {
      final resultados = await Future.wait([
        _apiService.obtenerClasesServicio(),
        _apiService.obtenerCaracteristicasPlus(),
      ]);
      if (mounted) {
        setState(() {
          _clases = resultados[0].cast<Map<String, dynamic>>();
          _caracteristicas = resultados[1].cast<Map<String, dynamic>>();
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorCarga = 'No se pudieron cargar las opciones. Intenta de nuevo.';
          _cargando = false;
        });
      }
    }
  }

  Future<void> _onSeleccionarClase(int claseId) async {
    setState(() => _claseSeleccionadaId = claseId);
    try {
      await _apiService.seleccionarClase(claseId);
    } catch (e) {
      // Guardado optimista: si falla, el taxista puede volver a tocar el chip.
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
      // Guardado optimista.
    }
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
        child: _cargando
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    CLODColors.azulCLOD,
                  ),
                ),
              )
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
                        const SizedBox(height: 48),
                        Text(
                          'Tu servicio',
                          textAlign: TextAlign.center,
                          style: CLODTextStyles.headingMedium.copyWith(
                            color: CLODColors.carbon,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Elige tu clase y diferenciadores',
                          textAlign: TextAlign.center,
                          style: CLODTextStyles.bodyMedium.copyWith(
                            color: CLODColors.carbon.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 32),
                        _tituloSeccion('Clase de servicio'),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: _clases.map((clase) {
                            final id = clase['id'] as int;
                            final nombre = clase['nombre'] as String? ?? '';
                            return _ChipSeleccionable(
                              texto: nombre,
                              seleccionado: _claseSeleccionadaId == id,
                              onTap: () => _onSeleccionarClase(id),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 32),
                        _tituloSeccion('Características plus'),
                        const SizedBox(height: 16),
                        Wrap(
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
                        const SizedBox(height: 32),
                        CLODPrimaryButton(
                          label: 'Continuar',
                          habilitado: _claseSeleccionadaId != null,
                          onPressed: () => context.go('/tarifa'),
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
