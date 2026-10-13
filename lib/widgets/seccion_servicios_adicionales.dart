import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;

import '../models/parada_viaje.dart';
import '../services/api_service.dart';
import '../theme/clod_theme.dart';

/// Switches y montos extra de "paradas de servicio" y "viaje colectivo" —
/// antes vivía en ConfiguracionScreen (ya eliminada), ahora se usa como una
/// sección dentro de TarifaScreen ("Mi tarifa"). Misma lógica, textos y
/// guardado de siempre, solo que ahora es un widget público reutilizable en
/// vez de una clase privada de esa pantalla.
class SeccionServiciosAdicionales extends StatefulWidget {
  const SeccionServiciosAdicionales({super.key});

  @override
  State<SeccionServiciosAdicionales> createState() =>
      _SeccionServiciosAdicionalesState();
}

class _SeccionServiciosAdicionalesState
    extends State<SeccionServiciosAdicionales> {
  final ApiService _apiService = ApiService();

  bool _cargando = true;
  String? _errorCarga;

  bool _aceptaParadasServicio = false;
  final _montoParadasServicioController = TextEditingController();
  bool _guardandoParadasServicio = false;
  String? _errorParadasServicio;
  bool _guardadoParadasServicio = false;

  bool _aceptaViajeColectivo = false;
  final _montoViajeColectivoController = TextEditingController();
  bool _guardandoViajeColectivo = false;
  String? _errorViajeColectivo;
  bool _guardadoViajeColectivo = false;

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  @override
  void dispose() {
    _montoParadasServicioController.dispose();
    _montoViajeColectivoController.dispose();
    super.dispose();
  }

  Future<void> _cargarPerfil() async {
    try {
      final resultado = await _apiService.obtenerMiPerfilTaxista();
      final taxista =
          resultado['taxista'] as Map<String, dynamic>? ?? resultado;
      if (!mounted) return;
      setState(() {
        _aceptaParadasServicio = taxista['acepta_paradas_servicio'] == true;
        _montoParadasServicioController.text = montoParadaComoTexto(
          taxista['monto_extra_parada_servicio'],
        );
        _aceptaViajeColectivo = taxista['acepta_viaje_colectivo'] == true;
        _montoViajeColectivoController.text = montoParadaComoTexto(
          taxista['monto_extra_parada_colectivo'],
        );
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorCarga = 'No se pudo cargar tu configuración de paradas.';
      });
    }
  }

  Future<void> _guardar(bool esServicio) async {
    final controller = esServicio
        ? _montoParadasServicioController
        : _montoViajeColectivoController;
    final monto = parsearMontoParada(controller.text);

    if (monto == null) {
      setState(() {
        if (esServicio) {
          _errorParadasServicio = 'Ingresa un monto válido.';
        } else {
          _errorViajeColectivo = 'Ingresa un monto válido.';
        }
      });
      return;
    }

    setState(() {
      if (esServicio) {
        _guardandoParadasServicio = true;
        _errorParadasServicio = null;
        _guardadoParadasServicio = false;
      } else {
        _guardandoViajeColectivo = true;
        _errorViajeColectivo = null;
        _guardadoViajeColectivo = false;
      }
    });

    try {
      await _apiService.actualizarPreferenciasParadas(
        aceptaParadasServicio: _aceptaParadasServicio,
        montoExtraParadaServicio:
            parsearMontoParada(_montoParadasServicioController.text) ?? 0,
        aceptaViajeColectivo: _aceptaViajeColectivo,
        montoExtraParadaColectivo:
            parsearMontoParada(_montoViajeColectivoController.text) ?? 0,
      );
      if (!mounted) return;
      setState(() {
        if (esServicio) {
          _guardandoParadasServicio = false;
          _guardadoParadasServicio = true;
        } else {
          _guardandoViajeColectivo = false;
          _guardadoViajeColectivo = true;
        }
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        setState(() {
          if (esServicio) {
            _guardadoParadasServicio = false;
          } else {
            _guardadoViajeColectivo = false;
          }
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (esServicio) {
          _guardandoParadasServicio = false;
          _errorParadasServicio = 'No se pudo guardar. Intenta de nuevo.';
        } else {
          _guardandoViajeColectivo = false;
          _errorViajeColectivo = 'No se pudo guardar. Intenta de nuevo.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(CLODColors.azulCLOD),
          ),
        ),
      );
    }
    if (_errorCarga != null) {
      return Text(
        _errorCarga!,
        style: CLODTextStyles.bodyMedium.copyWith(
          color: CLODColors.texto(context).withValues(alpha: 0.6),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Servicios adicionales',
          style: CLODTextStyles.headingSmall.copyWith(
            color: CLODColors.texto(context),
          ),
        ),
        const SizedBox(height: 12),
        _TarjetaServicioAdicional(
          titulo: 'Paradas de servicio',
          descripcion:
              'Para recoger o dejar un paquete u objeto, o dejar a un '
              'pasajero que ya viaja. No se usan para subir personas. Tú '
              'decides cuánto cobrar por cada una.',
          activo: _aceptaParadasServicio,
          onSwitchChanged: (valor) {
            setState(() => _aceptaParadasServicio = valor);
            _guardar(true);
          },
          montoController: _montoParadasServicioController,
          guardando: _guardandoParadasServicio,
          error: _errorParadasServicio,
          guardado: _guardadoParadasServicio,
          onGuardarMonto: () => _guardar(true),
        ),
        const SizedBox(height: 16),
        _TarjetaServicioAdicional(
          titulo: 'Viaje colectivo',
          descripcion:
              'El pasajero puede subir a otras personas durante el viaje '
              '(hasta 4 pasajeros en total). Tú decides cuánto cobrar por '
              'cada parada.',
          activo: _aceptaViajeColectivo,
          onSwitchChanged: (valor) {
            setState(() => _aceptaViajeColectivo = valor);
            _guardar(false);
          },
          montoController: _montoViajeColectivoController,
          guardando: _guardandoViajeColectivo,
          error: _errorViajeColectivo,
          guardado: _guardadoViajeColectivo,
          onGuardarMonto: () => _guardar(false),
        ),
        const SizedBox(height: 12),
        Text(
          'Los cambios no afectan viajes ya aceptados.',
          style: CLODTextStyles.bodySmall.copyWith(
            color: CLODColors.texto(context).withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Estas opciones son voluntarias; puedes cambiarlas cuando quieras.',
          style: CLODTextStyles.bodySmall.copyWith(
            color: CLODColors.texto(context).withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

class _TarjetaServicioAdicional extends StatelessWidget {
  const _TarjetaServicioAdicional({
    required this.titulo,
    required this.descripcion,
    required this.activo,
    required this.onSwitchChanged,
    required this.montoController,
    required this.guardando,
    required this.error,
    required this.guardado,
    required this.onGuardarMonto,
  });

  final String titulo;
  final String descripcion;
  final bool activo;
  final ValueChanged<bool> onSwitchChanged;
  final TextEditingController montoController;
  final bool guardando;
  final String? error;
  final bool guardado;
  final VoidCallback onGuardarMonto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CLODColors.fondoTarjeta(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CLODColors.borde(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titulo,
                  style: CLODTextStyles.bodyLarge.copyWith(
                    color: CLODColors.texto(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (guardando)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      CLODColors.azulCLOD,
                    ),
                  ),
                )
              else
                Switch(
                  value: activo,
                  onChanged: onSwitchChanged,
                  activeTrackColor: CLODColors.azulCLOD,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            descripcion,
            style: CLODTextStyles.bodySmall.copyWith(
              color: CLODColors.texto(context).withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Monto extra por cada parada',
            style: CLODTextStyles.bodySmall.copyWith(
              color: CLODColors.texto(context).withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: montoController,
                  enabled: activo && !guardando,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  style: CLODTextStyles.bodyLarge.copyWith(
                    color: CLODColors.texto(context),
                  ),
                  decoration: InputDecoration(
                    prefixText: '\$ ',
                    suffixText: 'MXN',
                    hintText: '0.00',
                    filled: true,
                    fillColor: CLODColors.fondoPantalla(context),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: CLODColors.borde(context)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: CLODColors.borde(context)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: activo && !guardando ? onGuardarMonto : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: CLODColors.azulCLOD,
                  side: BorderSide(
                    color: CLODColors.azulCLOD.withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                child: const Text('Guardar'),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              style: CLODTextStyles.bodySmall.copyWith(
                color: CLODColors.rojoUbicacion,
              ),
            ),
          ],
          if (guardado) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.check_circle, size: 16, color: CLODColors.azulCLOD),
                const SizedBox(width: 6),
                Text(
                  'Guardado',
                  style: CLODTextStyles.bodySmall.copyWith(
                    color: CLODColors.azulCLOD,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
