import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../routes/app_router.dart';
import '../../services/api_service.dart';
import '../../theme/clod_theme.dart';
import '../../widgets/clod_error_text.dart';
import '../../widgets/clod_text_field.dart';

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

const List<String> _estadosValidos = ['pendiente', 'cumplido', 'por_pagar', 'pagado'];

// El backend no siempre expone un solo campo "estado" — se intenta leerlo
// directo primero, y si no viene o no es uno de los 4 valores esperados, se
// deriva a partir de banderas booleanas individuales.
String _estadoReferido(Map<String, dynamic> referido) {
  final estadoDirecto = _campoTexto(referido, ['estado', 'estado_pago']);
  if (estadoDirecto != null && _estadosValidos.contains(estadoDirecto)) {
    return estadoDirecto;
  }
  if (_campoBooleano(referido, ['pagado'])) return 'pagado';
  if (_campoBooleano(referido, ['pago_solicitado', 'solicitado_pago'])) {
    return 'por_pagar';
  }
  if (_campoBooleano(referido, ['cumplido', 'completado', 'activo'])) {
    return 'cumplido';
  }
  return 'pendiente';
}

class ReferidosScreen extends StatefulWidget {
  const ReferidosScreen({super.key});

  @override
  State<ReferidosScreen> createState() => _ReferidosScreenState();
}

class _ReferidosScreenState extends State<ReferidosScreen> with RouteAware {
  final ApiService _apiService = ApiService();

  static const int _porPagina = 5;

  bool _cargando = true;
  String? _errorMensaje;
  String _codigo = '';
  int _cumplidos = 0;
  int _requeridos = 0;
  int _montoBono = 0;
  bool _listoParaPago = false;
  List<Map<String, dynamic>> _referidos = [];
  int _pagina = 1;
  int _totalReferidos = 0;
  bool _cargandoLista = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  // Se llama cuando esta pantalla vuelve a quedar visible tras hacer pop de
  // una ruta que la cubría (ej. volver de otra pantalla) — así el progreso
  // de referidos no se queda desactualizado si cambió mientras estuvo tapada.
  @override
  void didPopNext() {
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final resultados = await Future.wait<dynamic>([
        _apiService.obtenerMiCodigoReferido(),
        _apiService.obtenerProgresoReferidos(),
        _apiService.obtenerListaReferidos(pagina: 1),
      ]);

      final codigoData = resultados[0] as Map<String, dynamic>;
      final progresoData = resultados[1] as Map<String, dynamic>;
      final paginaData = resultados[2] as Map<String, dynamic>;
      final listaData = (paginaData['referidos'] as List<dynamic>)
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
            'monto_por_completar',
            'monto_bono',
            'monto',
            'bono_monto',
          ], porDefecto: 500);
          _listoParaPago = _campoBooleano(progresoData, ['listo_para_pago']);
          _referidos = listaData;
          _pagina = 1;
          _totalReferidos = paginaData['total'] as int;
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

  Future<void> _cargarPaginaReferidos(int pagina) async {
    setState(() => _cargandoLista = true);
    try {
      final paginaData = await _apiService.obtenerListaReferidos(
        pagina: pagina,
      );
      final listaData = (paginaData['referidos'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      if (mounted) {
        setState(() {
          _referidos = listaData;
          _pagina = pagina;
          _totalReferidos = paginaData['total'] as int;
        });
      }
    } catch (e) {
      // Si falla el cambio de página, se queda en la página anterior.
    } finally {
      if (mounted) {
        setState(() => _cargandoLista = false);
      }
    }
  }

  Future<void> _mostrarDialogoSolicitarPago() async {
    final exito = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DialogoSolicitarPago(
        onConfirmar: _apiService.solicitarPagoReferido,
      ),
    );

    if (exito == true && mounted) {
      await _mostrarConfirmacionExito();
      await _cargarDatos();
    }
  }

  Future<void> _mostrarConfirmacionExito() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          '¡Listo!',
          style: CLODTextStyles.headingSmall.copyWith(
            color: CLODColors.carbon,
          ),
        ),
        content: Text(
          'Tu pago fue solicitado, lo procesaremos pronto',
          style: CLODTextStyles.bodyMedium.copyWith(
            color: CLODColors.carbon.withValues(alpha: 0.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Entendido',
              style: CLODTextStyles.bodyMedium.copyWith(
                color: CLODColors.azulCLOD,
              ),
            ),
          ),
        ],
      ),
    );
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
                        if (_listoParaPago) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _mostrarDialogoSolicitarPago,
                            icon: const Icon(Icons.payments_outlined),
                            label: const Text('Solicitar pago'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: CLODColors.azulMarino,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                            ),
                          ),
                        ],
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
                        if (_totalReferidos > 0) ...[
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
                          if (_cargandoLista)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 24,
                              ),
                              child: Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    CLODColors.azulCLOD,
                                  ),
                                ),
                              ),
                            )
                          else
                            for (final referido in _referidos) ...[
                              _FilaReferido(referido: referido),
                              const SizedBox(height: 8),
                            ],
                          const SizedBox(height: 8),
                          _ControlesPaginacion(
                            pagina: _pagina,
                            totalPaginas: (_totalReferidos / _porPagina)
                                .ceil()
                                .clamp(1, 1 << 30),
                            cargando: _cargandoLista,
                            onAnterior: () =>
                                _cargarPaginaReferidos(_pagina - 1),
                            onSiguiente: () =>
                                _cargarPaginaReferidos(_pagina + 1),
                          ),
                        ],
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _DialogoSolicitarPago extends StatefulWidget {
  const _DialogoSolicitarPago({required this.onConfirmar});

  final Future<Map<String, dynamic>> Function(String clabe) onConfirmar;

  @override
  State<_DialogoSolicitarPago> createState() => _DialogoSolicitarPagoState();
}

class _DialogoSolicitarPagoState extends State<_DialogoSolicitarPago> {
  final TextEditingController _clabeController = TextEditingController();

  bool _cargando = false;
  String? _errorMensaje;
  String _clabe = '';

  @override
  void initState() {
    super.initState();
    _clabeController.addListener(() {
      setState(() => _clabe = _clabeController.text);
    });
  }

  @override
  void dispose() {
    _clabeController.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    setState(() {
      _cargando = true;
      _errorMensaje = null;
    });

    try {
      await widget.onConfirmar(_clabe);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      final mensaje = data is Map<String, dynamic>
          ? data['mensaje'] as String?
          : null;
      if (mounted) {
        setState(() {
          _errorMensaje =
              mensaje ?? 'No se pudo solicitar el pago. Intenta de nuevo.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMensaje = 'No se pudo solicitar el pago. Intenta de nuevo.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Text(
        'Solicitar pago',
        style: CLODTextStyles.headingSmall.copyWith(
          color: CLODColors.carbon,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ingresa la CLABE donde quieres recibir tu pago',
            style: CLODTextStyles.bodyMedium.copyWith(
              color: CLODColors.carbon.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          CLODTextField(
            controller: _clabeController,
            keyboardType: TextInputType.number,
            maxLength: 18,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            hintText: '18 dígitos',
          ),
          if (_errorMensaje != null) ...[
            const SizedBox(height: 12),
            CLODErrorText(_errorMensaje!),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _cargando
              ? null
              : () => Navigator.of(context).pop(false),
          child: Text(
            'Cancelar',
            style: CLODTextStyles.bodyMedium.copyWith(
              color: CLODColors.carbon.withValues(alpha: 0.6),
            ),
          ),
        ),
        TextButton(
          onPressed: (_cargando || _clabe.length != 18) ? null : _confirmar,
          child: _cargando
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      CLODColors.azulCLOD,
                    ),
                  ),
                )
              : Text(
                  'Confirmar',
                  style: CLODTextStyles.bodyMedium.copyWith(
                    color: CLODColors.azulCLOD,
                  ),
                ),
        ),
      ],
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
    final estado = _estadoReferido(referido);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD3D1C7)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              nombre,
              style: CLODTextStyles.bodyLarge.copyWith(
                color: CLODColors.carbon,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _BadgeEstado(estado: estado),
        ],
      ),
    );
  }
}

class _BadgeEstado extends StatelessWidget {
  const _BadgeEstado({required this.estado});

  // pendiente | cumplido | por_pagar | pagado

  // Excepción deliberada a la paleta cerrada de marca: estos 4 estados
  // necesitan distinguirse de un vistazo (semántica de semáforo), algo que
  // los tonos de azul/carbón por sí solos no lograban con suficiente
  // contraste visual — decisión explícita del equipo de producto.
  static const Color _gris = Color(0xFF9CA3AF);
  static const Color _ambar = Color(0xFFF59E0B);
  static const Color _verde = Color(0xFF16A34A);

  final String estado;

  @override
  Widget build(BuildContext context) {
    final (Color colorFondo, Color colorTexto, String etiqueta) =
        switch (estado) {
          'pagado' => (_verde.withValues(alpha: 0.15), _verde, 'Pagado'),
          'por_pagar' => (_ambar.withValues(alpha: 0.15), _ambar, 'Por pagar'),
          'cumplido' => (
            CLODColors.azulCLOD.withValues(alpha: 0.15),
            CLODColors.azulCLOD,
            'Cumplido',
          ),
          _ => (_gris.withValues(alpha: 0.15), _gris, 'Pendiente'),
        };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        etiqueta,
        style: CLODTextStyles.bodySmall.copyWith(
          color: colorTexto,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ControlesPaginacion extends StatelessWidget {
  const _ControlesPaginacion({
    required this.pagina,
    required this.totalPaginas,
    required this.cargando,
    required this.onAnterior,
    required this.onSiguiente,
  });

  final int pagina;
  final int totalPaginas;
  final bool cargando;
  final VoidCallback onAnterior;
  final VoidCallback onSiguiente;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: (!cargando && pagina > 1) ? onAnterior : null,
          child: Text(
            'Anterior',
            style: CLODTextStyles.bodyMedium.copyWith(
              color: CLODColors.azulCLOD,
            ),
          ),
        ),
        Text(
          'Página $pagina de $totalPaginas',
          style: CLODTextStyles.bodySmall.copyWith(
            color: CLODColors.carbon.withValues(alpha: 0.6),
          ),
        ),
        TextButton(
          onPressed: (!cargando && pagina < totalPaginas)
              ? onSiguiente
              : null,
          child: Text(
            'Siguiente',
            style: CLODTextStyles.bodyMedium.copyWith(
              color: CLODColors.azulCLOD,
            ),
          ),
        ),
      ],
    );
  }
}
