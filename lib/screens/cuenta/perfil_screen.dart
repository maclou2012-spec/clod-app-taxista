import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';
import '../../theme/clod_theme.dart';
import '../../widgets/clod_error_text.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final ApiService _apiService = ApiService();

  bool _cargando = true;
  String? _errorMensaje;
  String _nombre = '';
  String? _claseNombre;
  Map<String, dynamic>? _taxista;
  Map<String, dynamic>? _vehiculo;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final resultados = await Future.wait<dynamic>([
        _apiService.obtenerUsuarioActual(),
        _apiService.obtenerMiPerfilTaxista(),
        _apiService.obtenerClasesServicio(),
        _apiService.obtenerVehiculo(),
      ]);

      final usuario = (resultados[0] as Map<String, dynamic>)['usuario']
          as Map<String, dynamic>?;
      final taxista = (resultados[1] as Map<String, dynamic>)['taxista']
          as Map<String, dynamic>?;
      final clases = (resultados[2] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final vehiculo = resultados[3] as Map<String, dynamic>?;

      final claseId = taxista?['clase_id'];
      final clase = clases.firstWhere(
        (c) => c['id'] == claseId,
        orElse: () => const {},
      );

      if (mounted) {
        setState(() {
          _nombre = usuario?['nombre'] as String? ?? '';
          _claseNombre = clase['nombre'] as String?;
          _taxista = taxista;
          _vehiculo = vehiculo;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMensaje = 'No se pudo cargar tu perfil.';
          _cargando = false;
        });
      }
    }
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
            : _errorMensaje != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: CLODErrorText(_errorMensaje!),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),
                        Center(
                          child: CircleAvatar(
                            radius: 40,
                            backgroundColor: CLODColors.azulMarino,
                            child: const Icon(
                              Icons.person,
                              size: 40,
                              color: CLODColors.grisClaro,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _nombre,
                          textAlign: TextAlign.center,
                          style: CLODTextStyles.headingMedium.copyWith(
                            color: CLODColors.carbon,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Licenciatario'
                          '${_claseNombre != null ? ' · $_claseNombre' : ''}',
                          textAlign: TextAlign.center,
                          style: CLODTextStyles.bodyMedium.copyWith(
                            color: CLODColors.carbon.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 32),
                        _FilaAcceso(
                          icono: Icons.directions_car,
                          titulo: 'Mi vehículo',
                          onTap: () => context.push(
                            '/vehiculo',
                            extra: _vehiculo,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _FilaAcceso(
                          icono: Icons.attach_money,
                          titulo: 'Mi tarifa',
                          onTap: () => context.push(
                            '/tarifa',
                            extra: _taxista,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _FilaAcceso(
                          icono: Icons.description,
                          titulo: 'Mis documentos',
                          onTap: () => context.push('/revision'),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _FilaAcceso extends StatelessWidget {
  const _FilaAcceso({
    required this.icono,
    required this.titulo,
    required this.onTap,
  });

  final IconData icono;
  final String titulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD3D1C7)),
        ),
        child: Row(
          children: [
            Icon(icono, size: 20, color: CLODColors.azulCLOD),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                titulo,
                style: CLODTextStyles.bodyLarge.copyWith(
                  color: CLODColors.carbon,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: CLODColors.carbon.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}
