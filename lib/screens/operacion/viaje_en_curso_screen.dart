import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/calificar_pasajero_args.dart';
import '../../models/viaje_en_curso_args.dart';
import '../../services/api_service.dart';
import '../../services/location_tracking_service.dart';
import '../../services/socket_service.dart';
import '../../theme/clod_theme.dart';
import '../../utils/mapa_utils.dart';
import '../../widgets/boton_flotante_vidrio.dart';
import '../../widgets/clod_drawer.dart';
import '../../widgets/clod_primary_button.dart';

enum _EstadoViajeTaxista { enCamino, llego, enCurso, esperandoConfirmacion }

// El permiso de ubicación se negó (o quedó denegado para siempre) — se
// distingue de un timeout/otra falla para poder explicarle al taxista cómo
// activarlo, en vez de un mensaje genérico.
class _PermisoUbicacionDenegado implements Exception {}

// La respuesta de completar puede traer el id del viaje anidado bajo
// 'viaje' o plano — si no viene ninguno, usamos el id de la solicitud como
// respaldo (algunos backends aún no distinguen solicitud_id de viaje_id).
int _extraerViajeId(Map<String, dynamic> data, int solicitudIdFallback) {
  final viaje = data['viaje'];
  final mapa = viaje is Map<String, dynamic> ? viaje : data;
  final valor = mapa['id'] ?? mapa['viaje_id'] ?? mapa['viajeId'];
  if (valor is int) return valor;
  if (valor is num) return valor.toInt();
  if (valor is String) return int.tryParse(valor) ?? solicitudIdFallback;
  return solicitudIdFallback;
}

// "Esperando confirmación" no es un valor de estado aparte en el backend:
// es en_curso con un solicitar-fin pendiente (finSolicitadoEn más reciente
// que cualquier finRechazadoEn). Se deriva aquí para que tanto una solicitud
// recién aceptada como una reanudada desde /detalle usen la misma regla.
_EstadoViajeTaxista _estadoInicialDesde(ViajeEnCursoArgs args) {
  if (args.estado == 'en_curso' &&
      args.finSolicitadoEn != null &&
      (args.finRechazadoEn == null ||
          args.finRechazadoEn!.isBefore(args.finSolicitadoEn!))) {
    return _EstadoViajeTaxista.esperandoConfirmacion;
  }
  switch (args.estado) {
    case 'en_espera':
      return _EstadoViajeTaxista.llego;
    case 'en_curso':
      return _EstadoViajeTaxista.enCurso;
    default:
      return _EstadoViajeTaxista.enCamino;
  }
}

String _formatearMinSeg(int totalSegundos) {
  final minutos = totalSegundos ~/ 60;
  final segundos = totalSegundos % 60;
  return '$minutos:${segundos.toString().padLeft(2, '0')}';
}

// Para leer el /detalle que llega del sondeo periódico — mismas llaves que
// usa splash_screen.dart al reanudar desde el mismo endpoint.
String? _campoTexto(Map<String, dynamic> mapa, List<String> llaves) {
  for (final llave in llaves) {
    final valor = mapa[llave];
    if (valor != null) return valor.toString();
  }
  return null;
}

DateTime? _campoFecha(Map<String, dynamic> mapa, List<String> llaves) {
  for (final llave in llaves) {
    final valor = mapa[llave];
    if (valor is String) {
      final parseado = DateTime.tryParse(valor);
      if (parseado != null) return parseado.toLocal();
    }
  }
  return null;
}

// Un fin_rechazado_en solo cuenta como rechazo de la solicitud de
// confirmación VIGENTE si es más reciente que su fin_solicitado_en — si no,
// es el rastro de un rechazo anterior ya resuelto (ej. de un ciclo de
// "pedir confirmación" previo) y no debe disparar la transición de nuevo.
bool _rechazoVigente(Map<String, dynamic> detalle) {
  final finRechazadoEn = _campoFecha(detalle, ['fin_rechazado_en']);
  if (finRechazadoEn == null) return false;
  final finSolicitadoEn = _campoFecha(detalle, ['fin_solicitado_en']);
  if (finSolicitadoEn == null) return true;
  return !finRechazadoEn.isBefore(finSolicitadoEn);
}

class ViajeEnCursoScreen extends StatefulWidget {
  const ViajeEnCursoScreen({super.key, required this.args});

  final ViajeEnCursoArgs args;

  @override
  State<ViajeEnCursoScreen> createState() => _ViajeEnCursoScreenState();
}

class _ViajeEnCursoScreenState extends State<ViajeEnCursoScreen>
    with WidgetsBindingObserver {
  final ApiService _apiService = ApiService();
  final SocketService _socketService = SocketService();
  final LocationTrackingService _locationService = LocationTrackingService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Solo se usa en el paso "aceptado" — en los demás pasos no se monta
  // ningún MapWidget, así que estas referencias se quedan en null.
  mapbox.MapboxMap? _mapboxMap;
  mapbox.PointAnnotationManager? _pointAnnotationManager;
  mapbox.PointAnnotation? _miUbicacionAnnotation;
  Uint8List? _iconoUbicacion;

  late _EstadoViajeTaxista _estado = _estadoInicialDesde(widget.args);
  bool _marcandoLlegada = false;
  bool _completando = false;
  bool _cancelando = false;

  // Cronómetro compartido por "llego" (esperando desde) y "enCurso" (tiempo
  // transcurrido) — solo cambia de qué DateTime calcula la diferencia.
  Timer? _relojTimer;
  late DateTime? _llegadaEn = widget.args.llegadaEn;
  DateTime? _inicioViajeEn;

  // Código de seguridad (paso "llego") — el controller también maneja el
  // estado de error y la sacudida (triggerError/clearError, ver
  // package:pin_code_fields), así que no hace falta un AnimationController
  // propio para la sacudida.
  final PinInputController _codigoController = PinInputController();
  bool _enviandoCodigo = false;
  String? _mensajeErrorCodigo;
  int? _segundosBloqueoRestantes;
  Timer? _bloqueoTimer;

  // "Esperando confirmación del pasajero" (dentro de enCurso)
  Timer? _confirmacionTimer;
  late int? _segundosRestantesConfirmacion =
      widget.args.segundosRestantesConfirmacion;
  DateTime? _ultimoRechazoEn;
  StreamSubscription<Map<String, dynamic>>? _viajeCompletadoSub;
  StreamSubscription<Map<String, dynamic>>? _finViajeRechazadoSub;

  // Respaldo sin socket: mientras el viaje está en_curso (y especialmente
  // esperando confirmación), consultamos /detalle cada 10s por si el
  // pasajero cerró el viaje o rechazó la confirmación y el evento de socket
  // no llegó. Un solo vuelo a la vez, se detiene en segundo plano.
  Timer? _detallePollTimer;
  bool _consultandoDetalle = false;

  static final mapbox.Point _centroVeracruz = mapbox.Point(
    coordinates: mapbox.Position(-96.1342, 19.1738),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _socketService.unirseSolicitud(widget.args.solicitudId);
    _locationService.posicionActual.addListener(_onPosicionActualizada);
    _viajeCompletadoSub = _socketService.viajeCompletado.listen(
      _onViajeCompletado,
    );
    _finViajeRechazadoSub = _socketService.finViajeRechazado.listen(
      _onFinViajeRechazado,
    );
    if (_estado == _EstadoViajeTaxista.esperandoConfirmacion) {
      _iniciarCuentaRegresivaConfirmacion();
    }
    if (_estado == _EstadoViajeTaxista.llego ||
        _estado == _EstadoViajeTaxista.enCurso) {
      _iniciarReloj();
    }
    if (_debeConsultarDetalle) _iniciarSondeoDetalle();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationService.posicionActual.removeListener(_onPosicionActualizada);
    _bloqueoTimer?.cancel();
    _relojTimer?.cancel();
    _confirmacionTimer?.cancel();
    _detallePollTimer?.cancel();
    _viajeCompletadoSub?.cancel();
    _finViajeRechazadoSub?.cancel();
    _codigoController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_debeConsultarDetalle) {
        _consultarDetallePeriodico();
        _iniciarSondeoDetalle();
      }
    } else if (state == AppLifecycleState.paused) {
      _detallePollTimer?.cancel();
    }
  }

  // --- Respaldo sin socket (/detalle) ---------------------------------------

  bool get _debeConsultarDetalle =>
      _estado == _EstadoViajeTaxista.enCurso ||
      _estado == _EstadoViajeTaxista.esperandoConfirmacion;

  void _iniciarSondeoDetalle() {
    _detallePollTimer?.cancel();
    _detallePollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _consultarDetallePeriodico(),
    );
  }

  Future<Map<String, dynamic>?> _consultarDetalleConGuard() async {
    if (_consultandoDetalle) return null;
    _consultandoDetalle = true;
    try {
      return await _apiService.obtenerDetalleSolicitud(
        widget.args.solicitudId,
      );
    } catch (e) {
      return null;
    } finally {
      _consultandoDetalle = false;
    }
  }

  Future<void> _consultarDetallePeriodico() async {
    if (!mounted || !_debeConsultarDetalle) return;
    final detalle = await _consultarDetalleConGuard();
    if (detalle == null || !mounted) return;

    if (_campoTexto(detalle, ['estado']) == 'completado') {
      _onViajeCompletado(detalle);
      return;
    }
    if (_estado == _EstadoViajeTaxista.esperandoConfirmacion &&
        _rechazoVigente(detalle)) {
      _onFinViajeRechazado(detalle);
    }
  }

  // Tras un 409 de "completar"/"finalizar sin confirmación", el estado del
  // viaje ya cambió — lo más probable es que el pasajero lo haya cerrado él
  // mismo (POST /finalizar-pasajero). Confirmamos con /detalle y seguimos a
  // calificar en vez de mostrar un error que no refleja lo que pasó.
  Future<void> _resincronizarTrasEstadoInvalido() async {
    final detalle = await _consultarDetalleConGuard();
    if (!mounted) return;
    if (detalle != null && _campoTexto(detalle, ['estado']) == 'completado') {
      _onViajeCompletado(detalle);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('El estado del viaje cambió. Intenta de nuevo.'),
      ),
    );
  }

  // --- Mapa (solo paso "aceptado") -----------------------------------------

  mapbox.Point _puntoDesdePosicion(Position? posicion) {
    if (posicion == null) return _centroVeracruz;
    return mapbox.Point(
      coordinates: mapbox.Position(posicion.longitude, posicion.latitude),
    );
  }

  void _onPosicionActualizada() {
    // El envío de ubicación en vivo (LocationTrackingService, usado por el
    // seguimiento del pasajero) sigue funcionando sin importar el paso —
    // esto solo redibuja el pin en EL MAPA de este widget, que ya no existe
    // fuera de "aceptado".
    if (_estado != _EstadoViajeTaxista.enCamino) return;
    final posicion = _locationService.posicionActual.value;
    if (posicion != null) {
      _sincronizarMapa(posicion);
    }
  }

  Future<void> _onMapaCreado(mapbox.MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _pointAnnotationManager = await mapboxMap.annotations
        .createPointAnnotationManager();
    _iconoUbicacion = await generarIconoUbicacion();
    final posicionConocida = _locationService.posicionActual.value;
    if (posicionConocida != null) {
      await _sincronizarMapa(posicionConocida);
    }
  }

  Future<void> _sincronizarMapa(Position posicion) async {
    final punto = _puntoDesdePosicion(posicion);

    _mapboxMap?.flyTo(
      mapbox.CameraOptions(center: punto),
      mapbox.MapAnimationOptions(duration: 500),
    );

    final manager = _pointAnnotationManager;
    final icono = _iconoUbicacion;
    if (manager == null || icono == null) return;

    final anotacionActual = _miUbicacionAnnotation;
    if (anotacionActual == null) {
      _miUbicacionAnnotation = await manager.create(
        mapbox.PointAnnotationOptions(geometry: punto, image: icono),
      );
    } else {
      anotacionActual.geometry = punto;
      await manager.update(anotacionActual);
    }
  }

  // --- Cronómetro -----------------------------------------------------------

  void _iniciarReloj() {
    _relojTimer?.cancel();
    _relojTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  String get _textoCronometro {
    final DateTime? desde = _estado == _EstadoViajeTaxista.llego
        ? _llegadaEn
        : _inicioViajeEn;
    if (desde == null) return '';
    final segundos = DateTime.now().difference(desde).inSeconds;
    return _formatearMinSeg(segundos < 0 ? 0 : segundos);
  }

  // --- He llegado -------------------------------------------------------

  Future<void> _marcarLlegada() async {
    setState(() => _marcandoLlegada = true);

    try {
      await _apiService.marcarLlegada(widget.args.solicitudId);
      if (mounted) {
        // El mapa de "aceptado" se destruye al salir del árbol (deja de
        // construirse en build()) — se limpian las referencias para no
        // quedarnos con un MapboxMap/manager de un widget ya desmontado.
        _mapboxMap = null;
        _pointAnnotationManager = null;
        _miUbicacionAnnotation = null;
        setState(() {
          _estado = _EstadoViajeTaxista.llego;
          _llegadaEn = DateTime.now();
        });
        _iniciarReloj();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo marcar la llegada. Intenta de nuevo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _marcandoLlegada = false);
    }
  }

  // --- Código de seguridad / iniciar viaje ----------------------------------

  Future<void> _intentarIniciarViaje() async {
    final codigo = _codigoController.text;
    if (codigo.length != 4 ||
        _enviandoCodigo ||
        _segundosBloqueoRestantes != null) {
      return;
    }

    setState(() {
      _enviandoCodigo = true;
      _mensajeErrorCodigo = null;
    });

    final respuesta = await _apiService.iniciarViaje(
      widget.args.solicitudId,
      codigo,
    );
    if (!mounted) return;

    switch (respuesta.resultado) {
      case IniciarViajeResultado.exito:
        setState(() {
          _estado = _EstadoViajeTaxista.enCurso;
          _inicioViajeEn = DateTime.now();
        });
        _iniciarReloj();
        _iniciarSondeoDetalle();
      case IniciarViajeResultado.codigoIncorrecto:
        _manejarCodigoIncorrecto(respuesta.intentosRestantes);
      case IniciarViajeResultado.bloqueado:
        _manejarBloqueo(respuesta.segundosRestantes);
      case IniciarViajeResultado.estadoInvalido:
        setState(
          () => _mensajeErrorCodigo =
              'El estado del viaje cambió. Vuelve a intentarlo.',
        );
      case IniciarViajeResultado.otroError:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo iniciar el viaje. Intenta de nuevo.'),
          ),
        );
    }

    setState(() => _enviandoCodigo = false);
  }

  void _manejarCodigoIncorrecto(int? intentosRestantes) {
    setState(() {
      _mensajeErrorCodigo = intentosRestantes != null
          ? 'Código incorrecto. Te quedan $intentosRestantes '
                '${intentosRestantes == 1 ? "intento" : "intentos"}'
          : 'Código incorrecto. Intenta de nuevo.';
    });
    _codigoController.triggerError();
    _codigoController.text = '';
    _codigoController.requestFocus();
  }

  void _manejarBloqueo(int? segundosRestantes) {
    final total = segundosRestantes ?? 0;
    setState(() {
      _mensajeErrorCodigo = null;
      _segundosBloqueoRestantes = total;
    });
    _codigoController.clear();

    _bloqueoTimer?.cancel();
    if (total <= 0) return;
    _bloqueoTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final restante = (_segundosBloqueoRestantes ?? 1) - 1;
      if (restante <= 0) {
        timer.cancel();
        setState(() => _segundosBloqueoRestantes = null);
      } else {
        setState(() => _segundosBloqueoRestantes = restante);
      }
    });
  }

  // --- Cancelar (el pasajero no llegó) --------------------------------------

  Future<void> _mostrarDialogoCancelar() async {
    final motivo = await showDialog<CancelarViajeMotivo>(
      context: context,
      builder: (dialogContext) => const _DialogoCancelarViaje(),
    );
    if (motivo != null && mounted) await _cancelarSolicitud(motivo);
  }

  Future<void> _cancelarSolicitud(CancelarViajeMotivo motivo) async {
    setState(() => _cancelando = true);
    try {
      await _apiService.cancelarSolicitudTaxista(
        widget.args.solicitudId,
        motivo,
      );
      _socketService.salirSolicitud(widget.args.solicitudId);
      _socketService.marcarSolicitudActiva(null);
      if (mounted) context.go('/dashboard');
    } on DioException catch (e) {
      if (mounted) {
        final mensaje = e.response?.statusCode == 409
            ? 'Ya no se puede cancelar — el estado del viaje cambió.'
            : 'No se pudo cancelar. Intenta de nuevo.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensaje)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo cancelar. Intenta de nuevo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelando = false);
    }
  }

  // --- Completar viaje -------------------------------------------------

  Future<Position> _leerUbicacionActual() async {
    final servicioHabilitado = await Geolocator.isLocationServiceEnabled();
    if (!servicioHabilitado) throw _PermisoUbicacionDenegado();

    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied ||
        permiso == LocationPermission.deniedForever) {
      throw _PermisoUbicacionDenegado();
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
  }

  Future<void> _tocarCompletarViaje() async {
    if (_completando) return;
    setState(() => _completando = true);

    Position? posicion;
    var permisoDenegado = false;
    try {
      posicion = await _leerUbicacionActual();
    } on _PermisoUbicacionDenegado {
      permisoDenegado = true;
    } catch (e) {
      // Timeout u otra falla de lectura — se trata igual que "no se pudo
      // verificar", con la alternativa de pedir confirmación al pasajero.
    }

    if (!mounted) return;

    if (posicion == null) {
      setState(() => _completando = false);
      await _mostrarHojaNoEnDestino(
        motivo: permisoDenegado
            ? _MotivoHoja.permisoDenegado
            : _MotivoHoja.fallaUbicacion,
      );
      return;
    }

    // No se guarda ni se imprime la posición — solo se manda a
    // ApiService.completarViaje, que a su vez usa un Dio sin log.
    final respuesta = await _apiService.completarViaje(
      widget.args.solicitudId,
      lat: posicion.latitude,
      lng: posicion.longitude,
      accuracy: posicion.accuracy,
    );
    if (!mounted) return;
    setState(() => _completando = false);

    switch (respuesta.resultado) {
      case CompletarViajeResultado.exito:
        _irACalificar(respuesta.data!);
      case CompletarViajeResultado.fueraDeDestino:
        await _mostrarHojaNoEnDestino(
          motivo: _MotivoHoja.fueraDeDestino,
          distanciaM: respuesta.distanciaM,
          radioM: respuesta.radioM,
          puedeConfirmacionBackend: respuesta.puedeConfirmacion ?? true,
        );
      case CompletarViajeResultado.ubicacionPocoPrecisa:
        await _mostrarHojaNoEnDestino(motivo: _MotivoHoja.pocoPrecisa);
      case CompletarViajeResultado.estadoInvalido:
        await _resincronizarTrasEstadoInvalido();
      case CompletarViajeResultado.sinCoordenadas:
      case CompletarViajeResultado.otroError:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo completar el viaje. Intenta de nuevo.'),
          ),
        );
    }
  }

  Future<void> _mostrarHojaNoEnDestino({
    required _MotivoHoja motivo,
    double? distanciaM,
    double? radioM,
    bool puedeConfirmacionBackend = true,
  }) async {
    final puedeConfirmacion = puedeConfirmacionBackend && _puedeVolverAPedirConfirmacion;
    final segundosParaReintentar = _puedeVolverAPedirConfirmacion
        ? null
        : 60 - DateTime.now().difference(_ultimoRechazoEn!).inSeconds;

    final accion = await showModalBottomSheet<_AccionHoja>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _HojaNoEnDestino(
        motivo: motivo,
        distanciaM: distanciaM,
        radioM: radioM,
        puedeConfirmacion: puedeConfirmacion,
        segundosParaReintentar: segundosParaReintentar != null && segundosParaReintentar > 0
            ? segundosParaReintentar
            : null,
      ),
    );
    if (!mounted || accion != _AccionHoja.pedirConfirmacion) return;
    await _solicitarConfirmacion();
  }

  bool get _puedeVolverAPedirConfirmacion {
    final ultimo = _ultimoRechazoEn;
    if (ultimo == null) return true;
    return DateTime.now().difference(ultimo) >= const Duration(seconds: 60);
  }

  Future<void> _solicitarConfirmacion() async {
    setState(() => _completando = true);
    try {
      await _apiService.solicitarFinViaje(widget.args.solicitudId);
      if (!mounted) return;
      setState(() {
        _estado = _EstadoViajeTaxista.esperandoConfirmacion;
        _segundosRestantesConfirmacion = 300;
      });
      _iniciarCuentaRegresivaConfirmacion();
    } on DioException catch (e) {
      if (mounted) {
        final mensaje = e.response?.statusCode == 409
            ? 'Ya no se puede pedir confirmación ahora mismo.'
            : 'No se pudo enviar la solicitud. Intenta de nuevo.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensaje)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo enviar la solicitud. Intenta de nuevo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _completando = false);
    }
  }

  void _iniciarCuentaRegresivaConfirmacion() {
    _confirmacionTimer?.cancel();
    _confirmacionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final restante = (_segundosRestantesConfirmacion ?? 1) - 1;
      if (restante <= 0) {
        timer.cancel();
        setState(() => _segundosRestantesConfirmacion = 0);
      } else {
        setState(() => _segundosRestantesConfirmacion = restante);
      }
    });
  }

  Future<void> _finalizarSinConfirmacion() async {
    if (_completando) return;
    setState(() => _completando = true);
    final respuesta = await _apiService.completarViaje(widget.args.solicitudId);
    if (!mounted) return;
    if (respuesta.resultado == CompletarViajeResultado.exito) {
      _confirmacionTimer?.cancel();
      _irACalificar(respuesta.data!);
      return;
    }
    if (respuesta.resultado == CompletarViajeResultado.estadoInvalido) {
      await _resincronizarTrasEstadoInvalido();
      if (mounted) setState(() => _completando = false);
      return;
    }
    setState(() => _completando = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No se pudo finalizar el viaje. Intenta de nuevo.'),
      ),
    );
  }

  void _onViajeCompletado(Map<String, dynamic> data) {
    if (!mounted) return;
    _confirmacionTimer?.cancel();
    _socketService.salirSolicitud(widget.args.solicitudId);
    _socketService.marcarSolicitudActiva(null);
    _irACalificar(data);
  }

  void _onFinViajeRechazado(Map<String, dynamic> data) {
    if (!mounted) return;
    _confirmacionTimer?.cancel();
    setState(() {
      _estado = _EstadoViajeTaxista.enCurso;
      _segundosRestantesConfirmacion = null;
      _ultimoRechazoEn = DateTime.now();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('El pasajero indica que aún no llega a su destino'),
      ),
    );
  }

  void _irACalificar(Map<String, dynamic> data) {
    final viajeId = _extraerViajeId(data, widget.args.solicitudId);
    context.go(
      '/calificar-pasajero',
      extra: CalificarPasajeroArgs(viajeId: viajeId, viajeArgs: widget.args),
    );
  }

  // --- Navegación externa ----------------------------------------------

  // Mientras el taxista va hacia el pasajero, navega al punto de recogida;
  // una vez que llegó (esperando, en viaje o esperando confirmación),
  // navega al destino final.
  double? get _navLat => _estado == _EstadoViajeTaxista.enCamino
      ? widget.args.origenLat
      : widget.args.destinoLat;

  double? get _navLng => _estado == _EstadoViajeTaxista.enCamino
      ? widget.args.origenLng
      : widget.args.destinoLng;

  Future<void> _abrirNavegacionExterna() async {
    final lat = _navLat;
    final lng = _navLng;
    if (lat == null || lng == null) return;

    final uri = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
    final exito = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!exito && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir una app de navegación.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const ClodDrawer(),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: _estado == _EstadoViajeTaxista.enCamino
                  ? _vistaConMapa(context)
                  : _vistaSinMapa(context),
            ),
            Positioned(
              top: 12,
              left: 16,
              child: BotonFlotanteVidrio(
                icono: FontAwesomeIcons.bars,
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vistaConMapa(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: mapbox.MapWidget(
            viewport: mapbox.CameraViewportState(
              center: _puntoDesdePosicion(
                _locationService.posicionActual.value,
              ),
              zoom: 15,
            ),
            onMapCreated: _onMapaCreado,
          ),
        ),
        _panelInferior(
          context,
          children: [
            Text(
              widget.args.pasajeroNombre,
              style: CLODTextStyles.headingSmall.copyWith(
                color: CLODColors.texto(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Yendo al punto de encuentro',
              style: CLODTextStyles.bodyMedium.copyWith(
                color: CLODColors.azulCLOD,
              ),
            ),
            const SizedBox(height: 20),
            _botonWaze(context),
            const SizedBox(height: 12),
            CLODPrimaryButton(
              label: 'He llegado',
              cargando: _marcandoLlegada,
              onPressed: _marcarLlegada,
            ),
          ],
        ),
      ],
    );
  }

  // Sin mapa (A): "llego", "enCurso" y "esperandoConfirmacion" — el área que
  // dejaba el MapWidget se ocupa con un panel de contenido limpio, no con un
  // hueco vacío arriba.
  Widget _vistaSinMapa(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.args.pasajeroNombre,
            style: CLODTextStyles.headingMedium.copyWith(
              color: CLODColors.texto(context),
            ),
          ),
          const SizedBox(height: 8),
          if (_estado != _EstadoViajeTaxista.llego) ...[
            Text(
              'Destino',
              style: CLODTextStyles.bodySmall.copyWith(
                color: CLODColors.texto(context).withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.args.destinoDireccion,
              style: CLODTextStyles.bodyLarge.copyWith(
                color: CLODColors.texto(context),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_estado != _EstadoViajeTaxista.esperandoConfirmacion) ...[
            Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.stopwatch,
                  size: 16,
                  color: CLODColors.azulCLOD,
                ),
                const SizedBox(width: 8),
                Text(
                  _estado == _EstadoViajeTaxista.llego
                      ? 'Esperando: $_textoCronometro min'
                      : 'Tiempo transcurrido: $_textoCronometro',
                  style: CLODTextStyles.bodyMedium.copyWith(
                    color: CLODColors.texto(context).withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          _botonWaze(context),
          const SizedBox(height: 16),
          switch (_estado) {
            _EstadoViajeTaxista.llego => _SeccionCodigoSeguridad(
              controller: _codigoController,
              enviando: _enviandoCodigo,
              mensajeError: _mensajeErrorCodigo,
              segundosBloqueo: _segundosBloqueoRestantes,
              onIniciar: _intentarIniciarViaje,
              onCancelar: _cancelando ? null : _mostrarDialogoCancelar,
              cancelando: _cancelando,
            ),
            _EstadoViajeTaxista.enCurso => CLODPrimaryButton(
              label: 'Completar viaje',
              cargando: _completando,
              onPressed: _tocarCompletarViaje,
            ),
            _EstadoViajeTaxista.esperandoConfirmacion =>
              _SeccionEsperandoConfirmacion(
                segundosRestantes: _segundosRestantesConfirmacion ?? 0,
                onFinalizarSinConfirmacion: _completando
                    ? null
                    : _finalizarSinConfirmacion,
                cargando: _completando,
              ),
            _EstadoViajeTaxista.enCamino => const SizedBox.shrink(),
          },
        ],
      ),
    );
  }

  Widget _panelInferior(BuildContext context, {required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: CLODColors.fondoTarjeta(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    );
  }

  Widget _botonWaze(BuildContext context) {
    if (_navLat == null || _navLng == null) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _abrirNavegacionExterna,
        icon: Icon(Icons.navigation_outlined, color: CLODColors.azulCLOD),
        label: Text(
          'Abrir en Waze o Google Maps',
          style: CLODTextStyles.bodyLarge.copyWith(color: CLODColors.azulCLOD),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: CLODColors.azulCLOD.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

enum _MotivoHoja { fueraDeDestino, pocoPrecisa, fallaUbicacion, permisoDenegado }

enum _AccionHoja { pedirConfirmacion, volver }

// El taxista ya marcó "He llegado" (estado en_espera) — le pide al pasajero
// su código de seguridad de 4 dígitos antes de poder iniciar el viaje.
class _SeccionCodigoSeguridad extends StatelessWidget {
  const _SeccionCodigoSeguridad({
    required this.controller,
    required this.enviando,
    required this.mensajeError,
    required this.segundosBloqueo,
    required this.onIniciar,
    required this.onCancelar,
    required this.cancelando,
  });

  final PinInputController controller;
  final bool enviando;
  final String? mensajeError;
  final int? segundosBloqueo;
  final VoidCallback onIniciar;
  final VoidCallback? onCancelar;
  final bool cancelando;

  @override
  Widget build(BuildContext context) {
    final bloqueado = segundosBloqueo != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Pide el código de seguridad al pasajero',
          style: CLODTextStyles.headingSmall.copyWith(
            color: CLODColors.texto(context),
          ),
        ),
        const SizedBox(height: 16),
        // ListenableBuilder re-renderiza esta sección (no toda la pantalla)
        // en cada tecleo, para habilitar el botón solo con los 4 dígitos.
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MaterialPinField(
                  length: 4,
                  pinController: controller,
                  enabled: !bloqueado && !enviando,
                  autoFocus: true,
                  keyboardType: TextInputType.number,
                  textCapitalization: TextCapitalization.none,
                  obscureText: false,
                  errorText: mensajeError,
                  // clearErrorOnInput (true por defecto) borra el error en
                  // CUALQUIER cambio de texto, incluido el controller.text =
                  // '' programático que usa _manejarCodigoIncorrecto para
                  // vaciar las casillas — eso apagaba el mensaje de error
                  // apenas se disparaba. Se maneja a mano: solo se limpia
                  // cuando el propio pasajero empieza a escribir el
                  // siguiente intento (texto no vacío).
                  clearErrorOnInput: false,
                  onChanged: (texto) {
                    if (texto.isNotEmpty) controller.clearError();
                  },
                  onCompleted: (_) => onIniciar(),
                  theme: MaterialPinTheme(
                    shape: MaterialPinShape.outlined,
                    cellSize: const Size(52, 60),
                    spacing: 10,
                    fillColor: CLODColors.fondoPantalla(context),
                    focusedFillColor: CLODColors.fondoPantalla(context),
                    filledFillColor: CLODColors.fondoPantalla(context),
                    completeFillColor: CLODColors.fondoPantalla(context),
                    borderColor: CLODColors.borde(context),
                    focusedBorderColor: CLODColors.azulCLOD,
                    filledBorderColor: CLODColors.azulCLOD,
                    completeBorderColor: CLODColors.azulCLOD,
                    errorColor: CLODColors.rojoUbicacion,
                    errorBorderColor: CLODColors.rojoUbicacion,
                    errorFillColor: CLODColors.fondoPantalla(context),
                    disabledColor: CLODColors.texto(
                      context,
                    ).withValues(alpha: 0.3),
                    disabledFillColor: CLODColors.fondoPantalla(
                      context,
                    ).withValues(alpha: 0.5),
                    disabledBorderColor: CLODColors.texto(
                      context,
                    ).withValues(alpha: 0.15),
                    textStyle: CLODTextStyles.headingMedium.copyWith(
                      color: CLODColors.texto(context),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Si el pasajero no puede ver su código, pídele los '
                  'últimos 4 dígitos de su número de teléfono.',
                  textAlign: TextAlign.center,
                  style: CLODTextStyles.bodySmall.copyWith(
                    color: CLODColors.texto(context).withValues(alpha: 0.6),
                  ),
                ),
                if (bloqueado) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Demasiados intentos. Intenta de nuevo en '
                    '${_formatearMinSeg(segundosBloqueo!)}',
                    textAlign: TextAlign.center,
                    style: CLODTextStyles.bodyMedium.copyWith(
                      color: CLODColors.rojoUbicacion,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                CLODPrimaryButton(
                  label: 'Iniciar viaje',
                  cargando: enviando,
                  habilitado: controller.text.length == 4 && !bloqueado,
                  onPressed: onIniciar,
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: onCancelar,
                    child: cancelando
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                CLODColors.texto(context).withValues(alpha: 0.6),
                              ),
                            ),
                          )
                        : Text(
                            'El pasajero no llegó',
                            style: CLODTextStyles.bodyMedium.copyWith(
                              color: CLODColors.texto(context).withValues(alpha: 0.6),
                            ),
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DialogoCancelarViaje extends StatefulWidget {
  const _DialogoCancelarViaje();

  @override
  State<_DialogoCancelarViaje> createState() => _DialogoCancelarViajeState();
}

class _DialogoCancelarViajeState extends State<_DialogoCancelarViaje> {
  CancelarViajeMotivo _motivo = CancelarViajeMotivo.pasajeroNoLlego;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('¿Cancelar el viaje?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cancelar no tiene ninguna consecuencia para ti.',
            style: CLODTextStyles.bodyMedium.copyWith(
              color: CLODColors.texto(context).withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          _OpcionMotivo(
            titulo: 'El pasajero no llegó',
            seleccionado: _motivo == CancelarViajeMotivo.pasajeroNoLlego,
            onTap: () =>
                setState(() => _motivo = CancelarViajeMotivo.pasajeroNoLlego),
          ),
          _OpcionMotivo(
            titulo: 'El pasajero no responde',
            seleccionado: _motivo == CancelarViajeMotivo.pasajeroNoResponde,
            onTap: () => setState(
              () => _motivo = CancelarViajeMotivo.pasajeroNoResponde,
            ),
          ),
          _OpcionMotivo(
            titulo: 'Otro motivo',
            seleccionado: _motivo == CancelarViajeMotivo.otro,
            onTap: () => setState(() => _motivo = CancelarViajeMotivo.otro),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Volver',
            style: CLODTextStyles.bodyLarge.copyWith(
              color: CLODColors.texto(context).withValues(alpha: 0.6),
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_motivo),
          child: Text(
            'Cancelar viaje',
            style: CLODTextStyles.bodyLarge.copyWith(
              color: CLODColors.rojoUbicacion,
            ),
          ),
        ),
      ],
    );
  }
}

class _OpcionMotivo extends StatelessWidget {
  const _OpcionMotivo({
    required this.titulo,
    required this.seleccionado,
    required this.onTap,
  });

  final String titulo;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              seleccionado
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: seleccionado
                  ? CLODColors.azulCLOD
                  : CLODColors.texto(context).withValues(alpha: 0.4),
            ),
            const SizedBox(width: 12),
            Text(
              titulo,
              style: CLODTextStyles.bodyLarge.copyWith(
                color: CLODColors.texto(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HojaNoEnDestino extends StatelessWidget {
  const _HojaNoEnDestino({
    required this.motivo,
    required this.distanciaM,
    required this.radioM,
    required this.puedeConfirmacion,
    required this.segundosParaReintentar,
  });

  final _MotivoHoja motivo;
  final double? distanciaM;
  final double? radioM;
  final bool puedeConfirmacion;
  final int? segundosParaReintentar;

  @override
  Widget build(BuildContext context) {
    final (titulo, cuerpo) = switch (motivo) {
      _MotivoHoja.fueraDeDestino => (
        'Aún no estás en el punto de destino',
        distanciaM != null
            ? 'Estás a ~${distanciaM!.round()} m del destino.'
            : 'Tu ubicación no coincide con el destino del viaje.',
      ),
      _MotivoHoja.pocoPrecisa => (
        'No pudimos verificar tu ubicación',
        'La señal de GPS es poco precisa en este momento.',
      ),
      _MotivoHoja.fallaUbicacion => (
        'No pudimos verificar tu ubicación',
        'No se pudo obtener tu posición a tiempo. Verifica tu GPS e '
            'intenta de nuevo.',
      ),
      _MotivoHoja.permisoDenegado => (
        'Necesitamos tu ubicación',
        'Activa el permiso de ubicación de TaxiCLOD en Ajustes del '
            'teléfono para poder verificar que llegaste al destino.',
      ),
    };

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: CLODColors.texto(context).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              titulo,
              style: CLODTextStyles.headingSmall.copyWith(
                color: CLODColors.texto(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              cuerpo,
              style: CLODTextStyles.bodyMedium.copyWith(
                color: CLODColors.texto(context).withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            if (puedeConfirmacion)
              CLODPrimaryButton(
                label: 'Pedir confirmación al pasajero',
                onPressed: () =>
                    Navigator.of(context).pop(_AccionHoja.pedirConfirmacion),
              )
            else if (segundosParaReintentar != null)
              Text(
                'Podrás volver a pedir confirmación en '
                '${segundosParaReintentar}s',
                textAlign: TextAlign.center,
                style: CLODTextStyles.bodySmall.copyWith(
                  color: CLODColors.texto(context).withValues(alpha: 0.5),
                ),
              ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(_AccionHoja.volver),
              child: Text(
                'Volver al viaje',
                style: CLODTextStyles.bodyLarge.copyWith(
                  color: CLODColors.texto(context).withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeccionEsperandoConfirmacion extends StatelessWidget {
  const _SeccionEsperandoConfirmacion({
    required this.segundosRestantes,
    required this.onFinalizarSinConfirmacion,
    required this.cargando,
  });

  final int segundosRestantes;
  final VoidCallback? onFinalizarSinConfirmacion;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    final agotado = segundosRestantes <= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.hourglass_top, color: CLODColors.azulCLOD, size: 36),
        const SizedBox(height: 12),
        Text(
          'Esperando la confirmación del pasajero',
          textAlign: TextAlign.center,
          style: CLODTextStyles.headingSmall.copyWith(
            color: CLODColors.texto(context),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          agotado ? '0:00' : _formatearMinSeg(segundosRestantes),
          textAlign: TextAlign.center,
          style: CLODTextStyles.headingLarge.copyWith(
            color: CLODColors.texto(context).withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 24),
        CLODPrimaryButton(
          label: 'Finalizar sin confirmación',
          habilitado: agotado,
          cargando: cargando,
          onPressed: onFinalizarSinConfirmacion,
        ),
      ],
    );
  }
}
