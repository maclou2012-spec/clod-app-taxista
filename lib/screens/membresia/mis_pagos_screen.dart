import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

bool _campoBool(Map<String, dynamic> mapa, List<String> llaves) {
  final valor = _campo(mapa, llaves);
  if (valor is bool) return valor;
  if (valor is num) return valor != 0;
  if (valor is String) return valor == 'true' || valor == '1';
  return false;
}

num? _campoMonto(Map<String, dynamic> mapa) {
  final valor = _campo(mapa, ['monto']);
  if (valor is num) return valor;
  if (valor is String) return num.tryParse(valor);
  return null;
}

int? _campoId(Map<String, dynamic> mapa) {
  final valor = mapa['id'];
  if (valor is int) return valor;
  if (valor is num) return valor.toInt();
  if (valor is String) return int.tryParse(valor);
  return null;
}

DateTime? _fechaPago(Map<String, dynamic> pago) {
  const llaves = ['fecha_inicio', 'fecha_pago', 'creado_en', 'created_at'];
  for (final llave in llaves) {
    final valor = pago[llave];
    if (valor is String) {
      final fecha = DateTime.tryParse(valor);
      if (fecha != null) return fecha.toLocal();
    }
  }
  return null;
}

String _formatearFechaCorta(String? fechaIso) {
  if (fechaIso == null) return '—';
  final fecha = DateTime.tryParse(fechaIso);
  if (fecha == null) return '—';
  return _formatearFecha(fecha);
}

String _formatearFecha(DateTime fecha) {
  final dia = fecha.day.toString().padLeft(2, '0');
  final mes = fecha.month.toString().padLeft(2, '0');
  return '$dia/$mes/${fecha.year}';
}

String _formatearPlan(String? tipo) {
  return switch (tipo) {
    'mensual' => 'Membresía mensual',
    'diaria' => 'Membresía diaria',
    _ => 'Membresía',
  };
}

String _formatearMonto(num? monto) {
  if (monto == null) return '—';
  return '\$${monto.toStringAsFixed(2)} MXN';
}

class MisPagosScreen extends StatefulWidget {
  const MisPagosScreen({super.key});

  @override
  State<MisPagosScreen> createState() => _MisPagosScreenState();
}

class _MisPagosScreenState extends State<MisPagosScreen> {
  final ApiService _apiService = ApiService();

  bool _cargando = true;
  String? _errorMensaje;
  String? _fechaFinActiva;
  List<Map<String, dynamic>> _pagos = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final resultados = await Future.wait<dynamic>([
        _apiService.obtenerEstadoMembresia(),
        _apiService.obtenerHistorialMembresias(),
      ]);
      if (!mounted) return;

      final estado = resultados[0] as Map<String, dynamic>;
      final membresiaActiva =
          estado['membresia_activa'] as Map<String, dynamic>?;
      final pagos =
          (resultados[1] as List<dynamic>)
              .whereType<Map<String, dynamic>>()
              .toList()
            ..sort((a, b) {
              final fechaA = _fechaPago(a);
              final fechaB = _fechaPago(b);
              if (fechaA == null || fechaB == null) return 0;
              return fechaB.compareTo(fechaA);
            });

      setState(() {
        _fechaFinActiva = membresiaActiva?['fecha_fin'] as String?;
        _pagos = pagos;
        _cargando = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMensaje = 'No se pudo cargar tu historial de pagos.';
          _cargando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 48),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Mis pagos y facturas',
                style: CLODTextStyles.headingMedium.copyWith(
                  color: CLODColors.texto(context),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
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
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: [
                        _TarjetaEstadoMembresia(fechaFin: _fechaFinActiva),
                        const SizedBox(height: 24),
                        Text(
                          'Historial de pagos',
                          style: CLODTextStyles.bodyMedium.copyWith(
                            color: CLODColors.texto(
                              context,
                            ).withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_pagos.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: Text(
                                'Aún no tienes pagos registrados',
                                style: CLODTextStyles.bodyMedium.copyWith(
                                  color: CLODColors.texto(
                                    context,
                                  ).withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                          )
                        else
                          for (final pago in _pagos) ...[
                            _TarjetaPago(pago: pago),
                            const SizedBox(height: 12),
                          ],
                        const SizedBox(height: 24),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaEstadoMembresia extends StatelessWidget {
  const _TarjetaEstadoMembresia({required this.fechaFin});

  final String? fechaFin;

  @override
  Widget build(BuildContext context) {
    final fecha = fechaFin == null ? null : DateTime.tryParse(fechaFin!);
    final activa = fecha != null && fecha.isAfter(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CLODColors.fondoTarjeta(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CLODColors.borde(context)),
      ),
      child: Row(
        children: [
          Icon(
            activa ? Icons.check_circle : Icons.error_outline,
            color: activa
                ? CLODColors.azulCLOD
                : CLODColors.texto(context).withValues(alpha: 0.4),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              activa
                  ? 'Activa hasta ${_formatearFechaCorta(fechaFin)}'
                  : 'Sin membresía activa',
              style: CLODTextStyles.bodyLarge.copyWith(
                color: CLODColors.texto(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaPago extends StatefulWidget {
  const _TarjetaPago({required this.pago});

  final Map<String, dynamic> pago;

  @override
  State<_TarjetaPago> createState() => _TarjetaPagoState();
}

class _TarjetaPagoState extends State<_TarjetaPago> {
  final ApiService _apiService = ApiService();

  bool _solicitando = false;
  String? _resultado; // 'generada' | 'en_revision'
  String? _error;

  Future<void> _solicitarFactura(int membresiaId) async {
    setState(() {
      _solicitando = true;
      _error = null;
    });
    try {
      final enRevision = await _apiService.solicitarFacturaTardia(membresiaId);
      if (mounted) {
        setState(() => _resultado = enRevision ? 'en_revision' : 'generada');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo solicitar la factura. Intenta de nuevo.';
        });
      }
    } finally {
      if (mounted) setState(() => _solicitando = false);
    }
  }

  Future<void> _abrirFactura(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final pago = widget.pago;
    final id = _campoId(pago);
    final tipo = _campoTexto(pago, ['tipo']);
    final monto = _campoMonto(pago);
    final fecha = _fechaPago(pago);
    final facturado = _campoBool(pago, ['solicita_factura']);
    final pdfUrl = _campoTexto(pago, [
      'pdf_url',
      'factura_pdf_url',
      'factura_url',
    ]);
    final periodoAbierto = fecha == null || fecha.year == DateTime.now().year;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CLODColors.fondoTarjeta(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CLODColors.borde(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatearPlan(tipo),
                style: CLODTextStyles.bodyLarge.copyWith(
                  color: CLODColors.texto(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _formatearMonto(monto),
                style: CLODTextStyles.bodyLarge.copyWith(
                  color: CLODColors.azulCLOD,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            fecha != null ? _formatearFecha(fecha) : '—',
            style: CLODTextStyles.bodySmall.copyWith(
              color: CLODColors.texto(context).withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 12),
          _estadoFacturacion(facturado, periodoAbierto, id, pdfUrl),
        ],
      ),
    );
  }

  Widget _estadoFacturacion(
    bool facturado,
    bool periodoAbierto,
    int? id,
    String? pdfUrl,
  ) {
    if (facturado) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _BadgeFacturado(),
          if (pdfUrl != null) ...[
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => _abrirFactura(pdfUrl),
              child: Text(
                'Ver factura',
                style: CLODTextStyles.bodySmall.copyWith(
                  color: CLODColors.azulCLOD,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      );
    }

    if (_resultado == 'generada') {
      return const _BadgeFacturado();
    }
    if (_resultado == 'en_revision') {
      return Text(
        'Tu solicitud está en revisión, te avisaremos',
        style: CLODTextStyles.bodySmall.copyWith(
          color: CLODColors.texto(context).withValues(alpha: 0.6),
        ),
      );
    }

    if (!periodoAbierto) {
      return Text(
        'Periodo fiscal cerrado',
        style: CLODTextStyles.bodySmall.copyWith(
          color: CLODColors.texto(context).withValues(alpha: 0.4),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_error != null) ...[
          CLODErrorText(_error!),
          const SizedBox(height: 6),
        ],
        SizedBox(
          height: 36,
          child: OutlinedButton(
            onPressed: (_solicitando || id == null)
                ? null
                : () => _solicitarFactura(id),
            style: OutlinedButton.styleFrom(
              foregroundColor: CLODColors.azulCLOD,
              side: BorderSide(color: CLODColors.azulCLOD),
            ),
            child: _solicitando
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        CLODColors.azulCLOD,
                      ),
                    ),
                  )
                : Text(
                    'Solicitar factura',
                    style: CLODTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _BadgeFacturado extends StatelessWidget {
  const _BadgeFacturado();

  // Excepción deliberada a la paleta cerrada de marca, igual que en
  // referidos_screen.dart — el verde de "facturado" necesita distinguirse
  // de un vistazo de los demás estados.
  static const Color _verde = Color(0xFF16A34A);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _verde.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Facturado',
        style: CLODTextStyles.bodySmall.copyWith(
          color: _verde,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
