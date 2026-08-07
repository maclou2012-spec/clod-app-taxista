import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/clod_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();

  bool _cargandoPerfil = true;
  String _nombre = '';
  bool _disponible = false;
  bool _cargandoDisponibilidad = false;

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  Future<void> _cargarPerfil() async {
    try {
      final resultados = await Future.wait([
        _apiService.obtenerUsuarioActual(),
        _apiService.obtenerMiPerfilTaxista(),
      ]);
      final usuario = resultados[0]['usuario'] as Map<String, dynamic>?;
      final taxista = resultados[1]['taxista'] as Map<String, dynamic>?;
      final disponibleRaw = taxista?['disponible'];
      if (mounted) {
        setState(() {
          _nombre = usuario?['nombre'] as String? ?? '';
          _disponible = disponibleRaw == true || disponibleRaw == 1;
          _cargandoPerfil = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargandoPerfil = false);
      }
    }
  }

  Future<void> _onToggleDisponibilidad(bool nuevoValor) async {
    final valorAnterior = _disponible;
    setState(() {
      _disponible = nuevoValor;
      _cargandoDisponibilidad = true;
    });

    try {
      await _apiService.cambiarDisponibilidad(nuevoValor);
    } on DioException catch (e) {
      final data = e.response?.data;
      final mensaje =
          data is Map<String, dynamic> ? data['mensaje'] as String? : null;
      if (mounted) {
        setState(() => _disponible = valorAnterior);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              mensaje ?? 'No se pudo actualizar tu disponibilidad.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _disponible = valorAnterior);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo actualizar tu disponibilidad.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _cargandoDisponibilidad = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CLODColors.carbon,
      body: SafeArea(
        child: _cargandoPerfil
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    CLODColors.azulCLOD,
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: CLODColors.azulMarino,
                          child: const Icon(
                            Icons.person,
                            color: CLODColors.grisClaro,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Hola, $_nombre',
                            style: CLODTextStyles.headingMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: CLODColors.azulMarino.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Disponibilidad voluntaria',
                                  style: CLODTextStyles.bodyLarge,
                                ),
                              ),
                              Switch(
                                value: _disponible,
                                activeThumbColor: CLODColors.azulCLOD,
                                onChanged: _cargandoDisponibilidad
                                    ? null
                                    : _onToggleDisponibilidad,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _disponible ? 'Conectado' : 'Desconectado',
                              style: CLODTextStyles.bodySmall.copyWith(
                                color: CLODColors.grisClaro.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _TarjetaEstadistica(
                            etiqueta: 'Viajes hoy',
                            valor: '0',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _TarjetaEstadistica(
                            etiqueta: 'Estimado',
                            valor: '\$0',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    Text(
                      'Tú decides cuándo conectarte y qué solicitudes tomar',
                      textAlign: TextAlign.center,
                      style: CLODTextStyles.bodySmall.copyWith(
                        color: CLODColors.grisClaro.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _TarjetaEstadistica extends StatelessWidget {
  const _TarjetaEstadistica({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: CLODColors.azulMarino.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            valor,
            style: CLODTextStyles.headingMedium,
          ),
          const SizedBox(height: 4),
          Text(
            etiqueta,
            style: CLODTextStyles.bodySmall.copyWith(
              color: CLODColors.grisClaro.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
