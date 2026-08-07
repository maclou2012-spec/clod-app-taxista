import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/clod_theme.dart';
import '../../widgets/clod_error_text.dart';

class EnRevisionScreen extends StatefulWidget {
  const EnRevisionScreen({super.key});

  @override
  State<EnRevisionScreen> createState() => _EnRevisionScreenState();
}

class _EnRevisionScreenState extends State<EnRevisionScreen> {
  final ApiService _apiService = ApiService();

  bool _cargando = true;
  String? _errorMensaje;
  bool _documentosCompletos = false;
  String? _verificacionFacialEstado;
  String? _estadoVerificacion;

  @override
  void initState() {
    super.initState();
    _cargarEstado();
  }

  Future<void> _cargarEstado() async {
    try {
      final data = await _apiService.obtenerEstadoRegistro();
      if (mounted) {
        setState(() {
          _documentosCompletos = data['documentos_completos'] as bool? ?? false;
          _verificacionFacialEstado =
              data['verificacion_facial_estado'] as String?;
          _estadoVerificacion = data['estado_verificacion'] as String?;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMensaje = 'No se pudo cargar el estado de tu registro.';
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
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 64),
                        Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F7FC),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.access_time,
                              size: 36,
                              color: CLODColors.azulCLOD,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Tu perfil está en revisión',
                          textAlign: TextAlign.center,
                          style: CLODTextStyles.headingMedium.copyWith(
                            color: CLODColors.carbon,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Nuestro equipo valida tus documentos. Normalmente '
                          'toma menos de 24 horas.',
                          textAlign: TextAlign.center,
                          style: CLODTextStyles.bodyMedium.copyWith(
                            color: CLODColors.carbon.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 40),
                        _FilaEstado(
                          etiqueta: 'Documentos',
                          valor: _documentosCompletos
                              ? 'Recibidos'
                              : 'Incompletos',
                          completo: _documentosCompletos,
                        ),
                        const SizedBox(height: 16),
                        _FilaEstado(
                          etiqueta: 'Identidad',
                          valor: _verificacionFacialEstado == 'activa'
                              ? 'Verificada'
                              : 'Pendiente',
                          completo: _verificacionFacialEstado == 'activa',
                        ),
                        const SizedBox(height: 16),
                        _FilaEstado(
                          etiqueta: 'Aprobación final',
                          valor: switch (_estadoVerificacion) {
                            'aprobado' => 'Aprobada',
                            'rechazado' => 'Rechazada',
                            _ => 'En proceso',
                          },
                          completo: _estadoVerificacion == 'aprobado',
                        ),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _FilaEstado extends StatelessWidget {
  const _FilaEstado({
    required this.etiqueta,
    required this.valor,
    required this.completo,
  });

  final String etiqueta;
  final String valor;
  final bool completo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD3D1C7)),
      ),
      child: Row(
        children: [
          Icon(
            completo ? Icons.check_circle : Icons.hourglass_empty,
            size: 20,
            color: completo
                ? CLODColors.azulCLOD
                : CLODColors.carbon.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              etiqueta,
              style: CLODTextStyles.bodyLarge.copyWith(
                color: CLODColors.carbon,
              ),
            ),
          ),
          Text(
            valor,
            style: CLODTextStyles.bodyMedium.copyWith(
              color: completo
                  ? CLODColors.azulCLOD
                  : CLODColors.carbon.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
