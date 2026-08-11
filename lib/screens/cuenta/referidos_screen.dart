import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/api_service.dart';
import '../../theme/clod_theme.dart';
import '../../widgets/clod_error_text.dart';

dynamic _campo(Map<String, dynamic> mapa, List<String> llaves) {
  for (final llave in llaves) {
    final valor = mapa[llave];
    if (valor != null) return valor;
  }
  return null;
}

String? _campoTexto(Map<String, dynamic> mapa, List<String> llaves) {
  return _campo(mapa, llaves)?.toString();
}

int _campoEntero(
  Map<String, dynamic> mapa,
  List<String> llaves, {
  int porDefecto = 0,
}) {
  final valor = _campo(mapa, llaves);
  if (valor is int) return valor;
  if (valor is num) return valor.toInt();
  if (valor is String) return int.tryParse(valor) ?? porDefecto;
  return porDefecto;
}

bool _campoBooleano(Map<String, dynamic> mapa, List<String> llaves) {
  final valor = _campo(mapa, llaves);
  return valor == true || valor == 1 || valor == '1';
}

class ReferidosScreen extends StatefulWidget {
  const ReferidosScreen({super.key});

  @override
  State<ReferidosScreen> createState() => _ReferidosScreenState();
}

class _ReferidosScreenState extends State<ReferidosScreen> {
  final ApiService _apiService = ApiService();

  bool _cargando = true;
  String? _errorMensaje;
  String _codigo = '';
  int _cumplidos = 0;
  int _requeridos = 0;
  int _montoBono = 0;
  List<Map<String, dynamic>> _referidos = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final resultados = await Future.wait<dynamic>([
        _apiService.obtenerMiCodigoReferido(),
        _apiService.obtenerProgresoReferidos(),
        _apiService.obtenerListaReferidos(),
      ]);

      final codigoData = resultados[0] as Map<String, dynamic>;
      final progresoData = resultados[1] as Map<String, dynamic>;
      final listaData = (resultados[2] as List<dynamic>)
          .cast<Map<String, dynamic>>();

      if (mounted) {
        setState(() {
          _codigo = _campoTexto(codigoData, ['codigo', 'codigo_referido']) ?? '';
          _cumplidos = _campoEntero(progresoData, [
            'referidos_cumplidos',
            'cumplidos',
            'completados',
          ]);
          _requeridos = _campoEntero(
            progresoData,
            ['referidos_requeridos', 'requeridos', 'meta'],
            porDefecto: 5,
          );
          _montoBono = _campoEntero(progresoData, [
            'monto_bono',
            'monto',
            'bono_monto',
          ], porDefecto: 500);
          _referidos = listaData;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMensaje = 'No se pudo cargar tus referidos.';
          _cargando = false;
        });
      }
    }
  }

  Future<void> _compartirCodigo() async {
    if (_codigo.isEmpty) return;
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Únete a CLOD como taxista con mi código $_codigo y activa tu '
            'directorio digital',
      ),
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
                        Text(
                          'Mis referidos',
                          textAlign: TextAlign.center,
                          style: CLODTextStyles.headingMedium.copyWith(
                            color: CLODColors.carbon,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Gana \$$_montoBono MXN por cada $_requeridos',
                          textAlign: TextAlign.center,
                          style: CLODTextStyles.bodyMedium.copyWith(
                            color: CLODColors.carbon.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 24,
                          ),
                          decoration: BoxDecoration(
                            color: CLODColors.azulMarino,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Tu código',
                                style: CLODTextStyles.bodySmall.copyWith(
                                  color: CLODColors.grisClaro.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _codigo,
                                style: CLODTextStyles.headingLarge,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _BarraProgreso(
                          cumplidos: _cumplidos,
                          requeridos: _requeridos,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _compartirCodigo,
                          icon: const Icon(Icons.share),
                          label: const Text('Compartir código'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CLODColors.azulCLOD,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                        if (_referidos.isNotEmpty) ...[
                          const SizedBox(height: 32),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Tus referidos',
                              style: CLODTextStyles.headingSmall.copyWith(
                                color: CLODColors.carbon,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          for (final referido in _referidos) ...[
                            _FilaReferido(referido: referido),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _BarraProgreso extends StatelessWidget {
  const _BarraProgreso({required this.cumplidos, required this.requeridos});

  final int cumplidos;
  final int requeridos;

  @override
  Widget build(BuildContext context) {
    final proporcion = requeridos > 0
        ? (cumplidos / requeridos).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: proporcion,
            minHeight: 10,
            backgroundColor: CLODColors.azulMarino.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(CLODColors.azulCLOD),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$cumplidos de $requeridos',
          textAlign: TextAlign.center,
          style: CLODTextStyles.bodyMedium.copyWith(
            color: CLODColors.carbon.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _FilaReferido extends StatelessWidget {
  const _FilaReferido({required this.referido});

  final Map<String, dynamic> referido;

  @override
  Widget build(BuildContext context) {
    final nombre =
        _campoTexto(referido, ['nombre', 'nombre_referido']) ?? 'Referido';
    final cumplido = _campoBooleano(referido, [
      'cumplido',
      'completado',
      'activo',
    ]);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD3D1C7)),
      ),
      child: Row(
        children: [
          Icon(
            cumplido ? Icons.check_circle : Icons.hourglass_empty,
            size: 20,
            color: cumplido
                ? CLODColors.azulCLOD
                : CLODColors.carbon.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              nombre,
              style: CLODTextStyles.bodyLarge.copyWith(
                color: CLODColors.carbon,
              ),
            ),
          ),
          Text(
            cumplido ? 'Cumplido' : 'Pendiente',
            style: CLODTextStyles.bodyMedium.copyWith(
              color: cumplido
                  ? CLODColors.azulCLOD
                  : CLODColors.carbon.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
