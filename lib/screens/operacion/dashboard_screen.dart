import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/parada_viaje.dart';
import '../../models/viaje_en_curso_args.dart';
import '../../providers/disponibilidad_provider.dart';
import '../../services/api_service.dart';
import '../../services/location_tracking_service.dart';
import '../../services/socket_service.dart';
import '../../theme/clod_theme.dart';
import '../../utils/mapa_utils.dart';
import '../../widgets/clod_drawer.dart';

String? _campoSolicitud(Map<String, dynamic> solicitud, List<String> llaves) {
  for (final llave in llaves) {
    final valor = solicitud[llave];
    if (valor != null) return valor.toString();
  }
  return null;
}

double? _campoDecimalSolicitud(
  Map<String, dynamic> solicitud,
  List<String> llaves,
) {
  for (final llave in llaves) {
    final valor = solicitud[llave];
    if (valor is num) return valor.toDouble();
    if (valor is String) {
      final parseado = double.tryParse(valor);
      if (parseado != null) return parseado;
    }
  }
  return null;
}

int? _campoEnteroSolicitud(
  Map<String, dynamic> solicitud,
  List<String> llaves,
) {
  final decimal = _campoDecimalSolicitud(solicitud, llaves);
  return decimal?.round();
}

// Las coordenadas pueden venir anidadas (solicitud['origen'] = {lat,lng}) o
// planas (solicitud['origen_lat'], solicitud['origen_lng']).
(double?, double?) _coordenadasSolicitud(
  Map<String, dynamic> solicitud,
  String prefijo,
) {
  final anidado = solicitud[prefijo];
  final mapa = anidado is Map<String, dynamic> ? anidado : solicitud;
  final lat = _campoDecimalSolicitud(mapa, [
    'lat',
    'latitud',
    'latitude',
    '${prefijo}_lat',
  ]);
  final lng = _campoDecimalSolicitud(mapa, [
    'lng',
    'lon',
    'longitud',
    'longitude',
    '${prefijo}_lng',
  ]);
  return (lat, lng);
}

String _formatearDistancia(double km) {
  if (km < 1) return '${(km * 1000).round()} m';
  return '${km.toStringAsFixed(1)} km';
}

/// Una celda de la capa de demanda, ya validada (lat/lng presentes).
/// Pública y separada del `CircleAnnotationOptions` de Mapbox para poder
/// probar el parseo de `obtenerZonasDemanda()` por unidad, sin un mapa real.
class CeldaDemanda {
  const CeldaDemanda({
    required this.lat,
    required this.lng,
    required this.intensidad,
  });

  final double lat;
  final double lng;
  final double intensidad;
}

// La respuesta puede no traer 'celdas' (backend sin desplegar) o traer
// celdas sin lat/lng (dato corrupto) — ambos casos se descartan en vez de
// lanzar, igual que el resto del parseo defensivo de esta app.
List<CeldaDemanda> celdasDemandaDesdeMapa(Map<String, dynamic>? datos) {
  final celdas = datos?['celdas'];
  if (celdas is! List) return const [];

  final resultado = <CeldaDemanda>[];
  for (final celda in celdas) {
    if (celda is! Map<String, dynamic>) continue;
    final lat = _campoDecimalSolicitud(celda, ['lat']);
    final lng = _campoDecimalSolicitud(celda, ['lng']);
    if (lat == null || lng == null) continue;
    final intensidad = _campoDecimalSolicitud(celda, ['intensidad']) ?? 0.3;
    resultado.add(
      CeldaDemanda(lat: lat, lng: lng, intensidad: intensidad.clamp(0.05, 1.0)),
    );
  }
  return resultado;
}

// Ausente (sin desplegar) o true -> se asume que sí hay suficiente, para no
// mostrar "aún no hay información" de más mientras el backend no confirme
// explícitamente lo contrario.
bool suficienteDatosDemandaDesdeMapa(Map<String, dynamic>? datos) {
  return datos?['suficiente_datos'] != false;
}

// Pura y separada de _DashboardScreenState para poder probarla por unidad:
// nueva_solicitud agrega al principio (más reciente primero); una lista
// fresca de /solicitudes reemplaza todo (así desaparecen solas las que ya
// no estén disponibles, sin depender de un evento de "solicitud retirada"
// que el backend no confirmó que exista todavía); nunca se duplica un id.
List<Map<String, dynamic>> conNuevaSolicitudAlFrente(
  List<Map<String, dynamic>> actuales,
  Map<String, dynamic> nueva,
) {
  final idNueva = nueva['id'];
  final sinDuplicado = actuales
      .where((s) => s['id'] != idNueva || idNueva == null)
      .toList();
  return [nueva, ...sinDuplicado];
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  final SocketService _socketService = SocketService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _cargandoPerfil = true;
  String _nombre = '';
  String? _fotoPerfilUrl;

  // --- KPIs del día (resumen-dia) -------------------------------------------
  Map<String, dynamic>? _resumenDia;
  Timer? _resumenDiaTimer;
  static const Duration _intervaloResumenDia = Duration(minutes: 5);

  // --- Lista de solicitudes en vivo ------------------------------------------
  List<Map<String, dynamic>> _solicitudes = [];
  StreamSubscription<Map<String, dynamic>>? _nuevaSolicitudSub;
  Timer? _solicitudesPollTimer;
  bool _detalleSolicitudVisible = false;
  static const Duration _intervaloSolicitudes = Duration(seconds: 15);

  // --- Mapa ------------------------------------------------------------------
  mapbox.MapboxMap? _mapboxMap;
  mapbox.PointAnnotationManager? _pointAnnotationManager;
  mapbox.PointAnnotation? _miUbicacionAnnotation;
  Uint8List? _iconoUbicacion;
  final LocationTrackingService _locationService = LocationTrackingService();
  static const double _zoomInicial = 12;

  // --- Capa de zonas de demanda ------------------------------------------
  mapbox.CircleAnnotationManager? _demandaManager;
  Map<String, dynamic>? _zonasDemanda;
  Timer? _zonasDemandaTimer;
  bool _mostrarCapaDemanda = true;
  static const Duration _intervaloZonasDemanda = Duration(minutes: 5);
  static const String _claveCapaDemanda = 'capa_demanda_visible';

  static final mapbox.Point _centroVeracruz = mapbox.Point(
    coordinates: mapbox.Position(-96.1342, 19.1738),
  );

  mapbox.Point _puntoDesdePosicion(Position? posicion) {
    if (posicion == null) return _centroVeracruz;
    return mapbox.Point(
      coordinates: mapbox.Position(posicion.longitude, posicion.latitude),
    );
  }

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
    _socketService.conectar();
    _cargarPreferenciaCapaDemanda();
    _inicializarUbicacionSiCorresponde();
    _locationService.posicionActual.addListener(_onPosicionActualizada);
    _nuevaSolicitudSub = _socketService.nuevaSolicitud.listen(
      _onNuevaSolicitud,
    );
    _cargarSolicitudesIniciales();
    _solicitudesPollTimer = Timer.periodic(
      _intervaloSolicitudes,
      (_) => _refrescarSolicitudesSilencioso(),
    );
    _cargarResumenDia();
    _resumenDiaTimer = Timer.periodic(
      _intervaloResumenDia,
      (_) => _cargarResumenDia(),
    );
    _cargarZonasDemanda();
    _zonasDemandaTimer = Timer.periodic(
      _intervaloZonasDemanda,
      (_) => _cargarZonasDemanda(),
    );
  }

  @override
  void dispose() {
    // El socket y el seguimiento de ubicación se quedan vivos aunque el
    // usuario navegue a otra pantalla — solo se detienen al desactivar la
    // disponibilidad (ver DisponibilidadProvider), o el socket en un
    // logout real.
    _locationService.posicionActual.removeListener(_onPosicionActualizada);
    _nuevaSolicitudSub?.cancel();
    _solicitudesPollTimer?.cancel();
    _resumenDiaTimer?.cancel();
    _zonasDemandaTimer?.cancel();
    super.dispose();
  }

  // --- Ubicación / mapa ------------------------------------------------------

  // Disponible -> el GPS en vivo ya lo maneja DisponibilidadProvider
  // (LocationTrackingService.iniciar/detener); aquí solo hace falta una
  // lectura puntual para centrar el mapa la primera vez si todavía no hay
  // ninguna posición conocida. No disponible -> UNA sola lectura puntual
  // (nunca seguimiento continuo) o el centro de la ciudad si ni eso se
  // pudo obtener.
  Future<void> _inicializarUbicacionSiCorresponde() async {
    if (_locationService.posicionActual.value != null) return;

    final servicioHabilitado = await Geolocator.isLocationServiceEnabled();
    if (!servicioHabilitado) return;

    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied ||
        permiso == LocationPermission.deniedForever) {
      return;
    }

    try {
      final posicion = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      // Si para cuando esto responde ya hay una posición (ej. se activó la
      // disponibilidad y el stream en vivo ya trajo una), no la pisa.
      if (_locationService.posicionActual.value == null) {
        _locationService.posicionActual.value = posicion;
      } else {
        await _sincronizarMapa(_locationService.posicionActual.value);
      }
    } catch (e) {
      // El mapa se queda centrado en la ciudad por defecto.
    }
  }

  void _onPosicionActualizada() {
    _sincronizarMapa(_locationService.posicionActual.value);
  }

  Future<void> _onMapaCreado(mapbox.MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _pointAnnotationManager = await mapboxMap.annotations
        .createPointAnnotationManager();
    _demandaManager = await mapboxMap.annotations
        .createCircleAnnotationManager();
    _iconoUbicacion = await generarIconoUbicacion();
    await _sincronizarMapa(_locationService.posicionActual.value);
    await _dibujarCapaDemanda();
  }

  Future<void> _sincronizarMapa(Position? posicion) async {
    final punto = _puntoDesdePosicion(posicion);

    _mapboxMap?.flyTo(
      mapbox.CameraOptions(center: punto, zoom: _zoomInicial),
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

  // --- Zonas de demanda --------------------------------------------------

  Future<void> _cargarPreferenciaCapaDemanda() async {
    final prefs = await SharedPreferences.getInstance();
    final valor = prefs.getBool(_claveCapaDemanda);
    if (valor != null && mounted) {
      setState(() => _mostrarCapaDemanda = valor);
      await _dibujarCapaDemanda();
    }
  }

  Future<void> _alternarCapaDemanda() async {
    setState(() => _mostrarCapaDemanda = !_mostrarCapaDemanda);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_claveCapaDemanda, _mostrarCapaDemanda);
    await _dibujarCapaDemanda();
  }

  Future<void> _cargarZonasDemanda() async {
    try {
      final datos = await _apiService.obtenerZonasDemanda();
      if (!mounted) return;
      setState(() => _zonasDemanda = datos);
      await _dibujarCapaDemanda();
    } catch (e) {
      // La capa es informativa — si falla, simplemente no se actualiza
      // esta vez; el temporizador lo vuelve a intentar en 5 minutos.
    }
  }

  // Borra y vuelve a crear SOLO las anotaciones de la capa (nunca el mapa
  // ni sus demás managers) — así se "actualiza en sitio" sin el parpadeo
  // de recrear el MapWidget completo.
  Future<void> _dibujarCapaDemanda() async {
    final manager = _demandaManager;
    if (manager == null) return;
    await manager.deleteAll();
    if (!_mostrarCapaDemanda) return;

    final celdas = celdasDemandaDesdeMapa(_zonasDemanda);
    if (celdas.isEmpty) return;

    final opciones = celdas
        .map(
          (celda) => mapbox.CircleAnnotationOptions(
            geometry: mapbox.Point(
              coordinates: mapbox.Position(celda.lng, celda.lat),
            ),
            circleColor: const Color(0xFF2ECC71).toARGB32(),
            circleOpacity: celda.intensidad * 0.55,
            circleRadius: 28,
          ),
        )
        .toList();
    await manager.createMulti(opciones);
  }

  // --- Solicitudes en vivo -----------------------------------------------

  void _onNuevaSolicitud(Map<String, dynamic> solicitud) {
    if (!mounted) return;
    setState(
      () => _solicitudes = conNuevaSolicitudAlFrente(_solicitudes, solicitud),
    );
  }

  Future<Position?> _posicionParaSolicitudes() async {
    final conocida = _locationService.posicionActual.value;
    if (conocida != null) return conocida;
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> _cargarSolicitudesIniciales() async {
    final posicion = await _posicionParaSolicitudes();
    if (!mounted || posicion == null) return;
    try {
      final solicitudes = await _apiService.obtenerSolicitudesPendientes(
        posicion.latitude,
        posicion.longitude,
      );
      if (!mounted) return;
      setState(
        () => _solicitudes = solicitudes.cast<Map<String, dynamic>>().toList(),
      );
    } catch (e) {
      // La lista simplemente se queda vacía hasta el próximo sondeo o un
      // nuevo evento de socket — no es un error bloqueante para el panel.
    }
  }

  // Reemplaza la lista completa con lo que el backend diga que sigue
  // disponible AHORA — así desaparecen solas las solicitudes que ya
  // tomó otro taxista o que expiraron, sin depender de un evento de
  // "solicitud retirada" particular.
  Future<void> _refrescarSolicitudesSilencioso() async {
    final posicion = _locationService.posicionActual.value;
    if (posicion == null) return;
    try {
      final solicitudes = await _apiService.obtenerSolicitudesPendientes(
        posicion.latitude,
        posicion.longitude,
      );
      if (!mounted) return;
      setState(
        () => _solicitudes = solicitudes.cast<Map<String, dynamic>>().toList(),
      );
    } catch (e) {
      // Silencioso a propósito — el próximo sondeo lo reintenta.
    }
  }

  void _verDetalleSolicitud(Map<String, dynamic> solicitud) {
    if (_detalleSolicitudVisible) return;
    _detalleSolicitudVisible = true;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _TarjetaSolicitud(
        solicitud: solicitud,
        onIgnorar: () => Navigator.of(sheetContext).pop(),
        onAceptar: () => _aceptarSolicitud(sheetContext, solicitud),
      ),
    ).whenComplete(() => _detalleSolicitudVisible = false);
  }

  Future<void> _aceptarSolicitud(
    BuildContext sheetContext,
    Map<String, dynamic> solicitud,
  ) async {
    final idRaw = solicitud['id'];
    final id = idRaw is int ? idRaw : int.tryParse('$idRaw');
    if (id == null) return;

    final navegadorHoja = Navigator.of(sheetContext);
    final mensajeria = ScaffoldMessenger.of(context);

    try {
      await _apiService.aceptarSolicitud(id);
      if (!mounted) return;
      navegadorHoja.pop();

      final (origenLat, origenLng) = _coordenadasSolicitud(solicitud, 'origen');
      final (destinoLat, destinoLng) = _coordenadasSolicitud(
        solicitud,
        'destino',
      );

      final args = ViajeEnCursoArgs(
        solicitudId: id,
        pasajeroNombre:
            _campoSolicitud(solicitud, [
              'pasajero_nombre',
              'nombre_pasajero',
              'nombre',
            ]) ??
            'Pasajero',
        origenDireccion:
            _campoSolicitud(solicitud, [
              'origen_direccion',
              'direccion_origen',
              'origen',
            ]) ??
            '—',
        destinoDireccion:
            _campoSolicitud(solicitud, [
              'destino_direccion',
              'direccion_destino',
              'destino',
            ]) ??
            '—',
        tarifa:
            _campoSolicitud(solicitud, ['tarifa_ofrecida', 'tarifa']) ?? '—',
        horaInicio: DateTime.now(),
        origenLat: origenLat,
        origenLng: origenLng,
        destinoLat: destinoLat,
        destinoLng: destinoLng,
        tipoViaje: tipoViajeDesdeMapa(solicitud),
        paradas: paradasDesdeMapa(solicitud),
      );

      _socketService.marcarSolicitudActiva(id);
      context.push('/viaje-en-curso', extra: args);
    } on DioException catch (e) {
      if (!mounted) return;
      navegadorHoja.pop();
      final mensaje = e.response?.statusCode == 409
          ? 'Otro taxista ya tomó esta solicitud.'
          : 'No se pudo aceptar la solicitud. Intenta de nuevo.';
      mensajeria.showSnackBar(SnackBar(content: Text(mensaje)));
      if (e.response?.statusCode == 409) _refrescarSolicitudesSilencioso();
    } catch (e) {
      if (!mounted) return;
      navegadorHoja.pop();
      mensajeria.showSnackBar(
        const SnackBar(
          content: Text('No se pudo aceptar la solicitud. Intenta de nuevo.'),
        ),
      );
    }
  }

  // --- Perfil / KPIs -------------------------------------------------------

  Future<void> _cargarPerfil() async {
    try {
      final resultado = await _apiService.obtenerUsuarioActual();
      final usuario = resultado['usuario'] as Map<String, dynamic>?;
      if (mounted) {
        setState(() {
          _nombre = usuario?['nombre'] as String? ?? '';
          _fotoPerfilUrl = usuario?['foto_perfil_url'] as String?;
          _cargandoPerfil = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargandoPerfil = false);
      }
    }
  }

  Future<void> _cargarResumenDia() async {
    try {
      final datos = await _apiService.obtenerResumenDia();
      if (mounted) setState(() => _resumenDia = datos);
    } catch (e) {
      // Los KPI simplemente no se muestran esta vez.
    }
  }

  @override
  Widget build(BuildContext context) {
    final disponibilidad = context.watch<DisponibilidadProvider>();
    final alturaMaximaSolicitudes = MediaQuery.of(context).size.height * 0.4;

    return Scaffold(
      key: _scaffoldKey,
      drawer: const ClodDrawer(),
      body: SafeArea(
        child: _cargandoPerfil
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    CLODColors.azulCLOD,
                  ),
                ),
              )
            : Column(
                children: [
                  CabeceraDashboard(
                    nombre: _nombre,
                    fotoPerfilUrl: _fotoPerfilUrl,
                    socketService: _socketService,
                    resumenDia: _resumenDia,
                    onAbrirMenu: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  IndicadorDisponibilidadDashboard(
                    disponible: disponibilidad.disponible,
                    membresiaVigente: disponibilidad.membresiaVigente,
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
                    onRenovar: () => context.push('/membresia'),
                  ),
                  if (disponibilidad.mensajeVencimientoProximo != null)
                    AvisoVencimientoMembresiaDashboard(
                      mensaje: disponibilidad.mensajeVencimientoProximo!,
                      onRenovar: () => context.push('/membresia'),
                    ),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: alturaMaximaSolicitudes,
                    ),
                    child: ListaSolicitudesDashboard(
                      solicitudes: _solicitudes,
                      onTap: _verDetalleSolicitud,
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: mapbox.MapWidget(
                            viewport: mapbox.CameraViewportState(
                              center: _puntoDesdePosicion(
                                _locationService.posicionActual.value,
                              ),
                              zoom: _zoomInicial,
                            ),
                            onMapCreated: _onMapaCreado,
                          ),
                        ),
                        Positioned(
                          right: 12,
                          top: 12,
                          child: _BotonCapaDemanda(
                            activa: _mostrarCapaDemanda,
                            onTap: _alternarCapaDemanda,
                          ),
                        ),
                        if (_mostrarCapaDemanda)
                          Positioned(
                            left: 12,
                            right: 12,
                            bottom: 12,
                            child: LeyendaCapaDemanda(
                              suficienteDatos: suficienteDatosDemandaDesdeMapa(
                                _zonasDemanda,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class CabeceraDashboard extends StatelessWidget {
  const CabeceraDashboard({
    super.key,
    required this.nombre,
    required this.fotoPerfilUrl,
    required this.socketService,
    required this.resumenDia,
    required this.onAbrirMenu,
  });

  final String nombre;
  final String? fotoPerfilUrl;
  final SocketService socketService;
  final Map<String, dynamic>? resumenDia;
  final VoidCallback onAbrirMenu;

  @override
  Widget build(BuildContext context) {
    final tieneFoto = fotoPerfilUrl != null && fotoPerfilUrl!.isNotEmpty;
    final viajesHoy = _campoEnteroSolicitud(resumenDia ?? const {}, [
      'viajes_completados_hoy',
    ]);
    final gananciasHoy = _campoDecimalSolicitud(resumenDia ?? const {}, [
      'ganancias_estimadas_hoy',
    ]);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
      decoration: BoxDecoration(
        color: CLODColors.fondoPantalla(context),
        border: Border(bottom: BorderSide(color: CLODColors.borde(context))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: FaIcon(
                  FontAwesomeIcons.bars,
                  size: 18,
                  color: CLODColors.texto(context),
                ),
                onPressed: onAbrirMenu,
              ),
              CircleAvatar(
                radius: 20,
                backgroundColor: CLODColors.azulMarino,
                backgroundImage: tieneFoto
                    ? NetworkImage(fotoPerfilUrl!)
                    : null,
                child: tieneFoto
                    ? null
                    : const FaIcon(
                        FontAwesomeIcons.user,
                        size: 16,
                        color: Colors.white,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Hola, $nombre',
                      style: CLODTextStyles.bodyLarge.copyWith(
                        color: CLODColors.texto(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _IndicadorConexionSocket(socketService: socketService),
                  ],
                ),
              ),
            ],
          ),
          if (viajesHoy != null || gananciasHoy != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: Row(
                children: [
                  if (viajesHoy != null)
                    Text(
                      '$viajesHoy ${viajesHoy == 1 ? "viaje" : "viajes"} hoy',
                      style: CLODTextStyles.bodySmall.copyWith(
                        color: CLODColors.texto(context).withValues(alpha: 0.6),
                      ),
                    ),
                  if (viajesHoy != null && gananciasHoy != null)
                    Text(
                      '  ·  ',
                      style: CLODTextStyles.bodySmall.copyWith(
                        color: CLODColors.texto(context).withValues(alpha: 0.4),
                      ),
                    ),
                  if (gananciasHoy != null)
                    Text(
                      '\$${gananciasHoy.toStringAsFixed(0)} estimadas',
                      style: CLODTextStyles.bodySmall.copyWith(
                        color: CLODColors.texto(context).withValues(alpha: 0.6),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IndicadorConexionSocket extends StatelessWidget {
  const _IndicadorConexionSocket({required this.socketService});

  final SocketService socketService;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EstadoConexionSocket>(
      valueListenable: socketService.estado,
      builder: (context, estado, _) {
        final (color, etiqueta) = switch (estado) {
          EstadoConexionSocket.conectado => (
            CLODColors.azulCLOD,
            'Conectado en tiempo real',
          ),
          EstadoConexionSocket.reconectando => (
            CLODColors.azulCLOD.withValues(alpha: 0.5),
            'Reconectando...',
          ),
          EstadoConexionSocket.desconectado => (
            CLODColors.texto(context).withValues(alpha: 0.4),
            'Sin conexión',
          ),
        };

        return Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              etiqueta,
              style: CLODTextStyles.bodySmall.copyWith(
                color: CLODColors.texto(context).withValues(alpha: 0.6),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Ya no abre/cierra la disponibilidad directo (eso vive en el switch del
// drawer) — solo refleja el estado actual y, al tocarlo, abre el menú
// donde está el switch real. Si la membresía no está vigente, en vez del
// estado disponible/no disponible muestra el aviso y un acceso directo a
// renovar (el switch deshabilitado "de verdad" vive en el drawer).
class IndicadorDisponibilidadDashboard extends StatelessWidget {
  const IndicadorDisponibilidadDashboard({
    super.key,
    required this.disponible,
    required this.onTap,
    this.membresiaVigente = true,
    this.onRenovar,
  });

  final bool disponible;
  final VoidCallback onTap;
  final bool membresiaVigente;
  final VoidCallback? onRenovar;

  @override
  Widget build(BuildContext context) {
    final color = (disponible && membresiaVigente)
        ? CLODColors.azulCLOD
        : CLODColors.texto(context).withValues(alpha: 0.4);

    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: CLODColors.fondoPantalla(context),
          border: Border(bottom: BorderSide(color: CLODColors.borde(context))),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Text(
              !membresiaVigente
                  ? 'Membresía no vigente'
                  : disponible
                  ? 'Disponible'
                  : 'No disponible',
              style: CLODTextStyles.bodyMedium.copyWith(
                color: CLODColors.texto(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (!membresiaVigente && onRenovar != null)
              TextButton(
                onPressed: onRenovar,
                style: TextButton.styleFrom(
                  foregroundColor: CLODColors.azulCLOD,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Renovar membresía'),
              )
            else
              Icon(
                Icons.chevron_right,
                size: 18,
                color: CLODColors.texto(context).withValues(alpha: 0.4),
              ),
          ],
        ),
      ),
    );
  }
}

// Recordatorio de renovación (no un bloqueo): solo aparece cuando la
// membresía SIGUE vigente pero vence en 5 días o menos.
class AvisoVencimientoMembresiaDashboard extends StatelessWidget {
  const AvisoVencimientoMembresiaDashboard({
    super.key,
    required this.mensaje,
    required this.onRenovar,
  });

  final String mensaje;
  final VoidCallback onRenovar;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: CLODColors.azulCLOD.withValues(alpha: 0.08),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: CLODColors.azulCLOD),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensaje,
              style: CLODTextStyles.bodySmall.copyWith(
                color: CLODColors.texto(context),
              ),
            ),
          ),
          TextButton(
            onPressed: onRenovar,
            style: TextButton.styleFrom(
              foregroundColor: CLODColors.azulCLOD,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Renovar'),
          ),
        ],
      ),
    );
  }
}

class ListaSolicitudesDashboard extends StatelessWidget {
  const ListaSolicitudesDashboard({
    super.key,
    required this.solicitudes,
    required this.onTap,
  });

  final List<Map<String, dynamic>> solicitudes;
  final ValueChanged<Map<String, dynamic>> onTap;

  @override
  Widget build(BuildContext context) {
    if (solicitudes.isEmpty) {
      // Compacto a propósito — deja el resto de la altura disponible para
      // el mapa en vez de ocupar el 40% completo con un estado vacío.
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          'Sin solicitudes disponibles por ahora.',
          style: CLODTextStyles.bodySmall.copyWith(
            color: CLODColors.texto(context).withValues(alpha: 0.5),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: solicitudes.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final solicitud = solicitudes[index];
        return _FilaSolicitud(
          solicitud: solicitud,
          onTap: () => onTap(solicitud),
        );
      },
    );
  }
}

class _FilaSolicitud extends StatelessWidget {
  const _FilaSolicitud({required this.solicitud, required this.onTap});

  final Map<String, dynamic> solicitud;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final origen =
        _campoSolicitud(solicitud, [
          'origen_direccion',
          'direccion_origen',
          'origen',
        ]) ??
        '—';
    final tarifa = _campoSolicitud(solicitud, ['tarifa_ofrecida', 'tarifa']);
    final distanciaKm = _campoDecimalSolicitud(solicitud, ['distancia_km']);
    final tipoViaje = tipoViajeDesdeMapa(solicitud);
    final paradas = paradasDesdeMapa(solicitud);
    final montoExtraParadas = _campoDecimalSolicitud(solicitud, [
      'monto_extra_paradas',
    ]);
    final totalEstimado = _campoDecimalSolicitud(solicitud, [
      'total_estimado',
      'monto_total',
    ]);
    final montoFinal =
        totalEstimado ??
        (tarifa != null
            ? (double.tryParse(tarifa) ?? 0) + (montoExtraParadas ?? 0)
            : null);

    return Material(
      color: CLODColors.azulMarino.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (tipoViaje != 'normal')
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: CLODColors.azulMarino.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tipoViaje == 'colectivo' ? 'Colectivo' : 'Paradas',
                          style: CLODTextStyles.bodySmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      origen,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CLODTextStyles.bodyMedium.copyWith(
                        color: CLODColors.texto(context),
                      ),
                    ),
                  ),
                  if (distanciaKm != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      _formatearDistancia(distanciaKm),
                      style: CLODTextStyles.bodySmall.copyWith(
                        color: CLODColors.azulCLOD,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              if (paradas.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '${paradas.length} ${paradas.length == 1 ? "parada" : "paradas"}',
                  style: CLODTextStyles.bodySmall.copyWith(
                    color: CLODColors.texto(context).withValues(alpha: 0.5),
                  ),
                ),
              ],
              if (montoFinal != null) ...[
                const SizedBox(height: 4),
                Text(
                  '\$${montoFinal.toStringAsFixed(2)} MXN (referencia)',
                  style: CLODTextStyles.bodyMedium.copyWith(
                    color: CLODColors.azulCLOD,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BotonCapaDemanda extends StatelessWidget {
  const _BotonCapaDemanda({required this.activa, required this.onTap});

  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: (oscuro ? CLODColors.carbon : Colors.white).withValues(
        alpha: 0.85,
      ),
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            Icons.layers_outlined,
            size: 20,
            color: activa
                ? const Color(0xFF2ECC71)
                : CLODColors.texto(context).withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

class LeyendaCapaDemanda extends StatelessWidget {
  const LeyendaCapaDemanda({super.key, required this.suficienteDatos});

  final bool suficienteDatos;

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (oscuro ? CLODColors.carbon : Colors.white).withValues(
          alpha: 0.9,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        suficienteDatos
            ? 'Zonas con más solicitudes en este día y horario '
                  '(información histórica)'
            : 'Aún no hay suficiente información de demanda',
        textAlign: TextAlign.center,
        style: CLODTextStyles.bodySmall.copyWith(
          color: CLODColors.texto(context).withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

class _TarjetaSolicitud extends StatelessWidget {
  const _TarjetaSolicitud({
    required this.solicitud,
    required this.onIgnorar,
    required this.onAceptar,
  });

  final Map<String, dynamic> solicitud;
  final VoidCallback onIgnorar;
  final VoidCallback onAceptar;

  @override
  Widget build(BuildContext context) {
    final nombrePasajero =
        _campoSolicitud(solicitud, [
          'pasajero_nombre',
          'nombre_pasajero',
          'nombre',
        ]) ??
        'Pasajero';
    final origen =
        _campoSolicitud(solicitud, [
          'origen_direccion',
          'direccion_origen',
          'origen',
        ]) ??
        '—';
    final tarifa = _campoSolicitud(solicitud, ['tarifa_ofrecida', 'tarifa']);
    final tipoViaje = tipoViajeDesdeMapa(solicitud);
    final paradas = paradasDesdeMapa(solicitud);
    final montoExtraParadas = _campoDecimalSolicitud(solicitud, [
      'monto_extra_paradas',
    ]);
    final totalEstimado = _campoDecimalSolicitud(solicitud, [
      'total_estimado',
      'monto_total',
    ]);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Solicitud de viaje',
              textAlign: TextAlign.center,
              style: CLODTextStyles.headingMedium,
            ),
            if (tipoViaje != 'normal') ...[
              const SizedBox(height: 8),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: CLODColors.azulMarino.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tipoViaje == 'colectivo'
                        ? 'Viaje colectivo'
                        : 'Con paradas de servicio',
                    style: CLODTextStyles.bodySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            _filaDato(FontAwesomeIcons.user, nombrePasajero),
            const SizedBox(height: 12),
            _filaDato(FontAwesomeIcons.locationDot, origen),
            if (paradas.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final parada in paradas)
                Padding(
                  padding: const EdgeInsets.only(left: 32, top: 4),
                  child: Text(
                    '${parada.orden}. ${parada.direccion} — '
                    '${parada.esServicio ? "recoger/dejar paquete" : "recoger a otra persona"}',
                    style: CLODTextStyles.bodySmall.copyWith(
                      color: CLODColors.texto(context).withValues(alpha: 0.6),
                    ),
                  ),
                ),
            ],
            if (tarifa != null) ...[
              const SizedBox(height: 12),
              _filaDato(
                FontAwesomeIcons.dollarSign,
                '\$${(totalEstimado ?? (double.tryParse(tarifa) ?? 0) + (montoExtraParadas ?? 0)).toStringAsFixed(2)} MXN (referencia)',
              ),
              if (paradas.isNotEmpty && montoExtraParadas != null)
                Padding(
                  padding: const EdgeInsets.only(left: 32, top: 4),
                  child: Text(
                    'Ruta \$$tarifa + ${paradas.length} '
                    '${paradas.length == 1 ? "parada" : "paradas"} × extra',
                    style: CLODTextStyles.bodySmall.copyWith(
                      color: CLODColors.texto(context).withValues(alpha: 0.5),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onIgnorar,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CLODColors.grisClaro,
                      side: BorderSide(
                        color: CLODColors.texto(context).withValues(alpha: 0.4),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Ignorar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAceptar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CLODColors.azulCLOD,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Aceptar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _filaDato(FaIconData icono, String texto) {
    return Row(
      children: [
        FaIcon(icono, size: 20, color: CLODColors.azulCLOD),
        const SizedBox(width: 12),
        Expanded(child: Text(texto, style: CLODTextStyles.bodyLarge)),
      ],
    );
  }
}
