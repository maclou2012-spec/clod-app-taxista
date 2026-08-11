import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/viaje_en_curso_args.dart';
import '../../services/api_service.dart';
import '../../services/location_tracking_service.dart';
import '../../services/socket_service.dart';
import '../../theme/clod_theme.dart';
import '../../widgets/dev_menu_button.dart';

String? _campoSolicitud(Map<String, dynamic> solicitud, List<String> llaves) {
  for (final llave in llaves) {
    final valor = solicitud[llave];
    if (valor != null) return valor.toString();
  }
  return null;
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  final SocketService _socketService = SocketService();

  bool _cargandoPerfil = true;
  String _nombre = '';
  bool _disponible = false;
  bool _cargandoDisponibilidad = false;

  GoogleMapController? _mapController;
  final LocationTrackingService _locationService = LocationTrackingService();
  StreamSubscription<Map<String, dynamic>>? _nuevaSolicitudSub;
  bool _solicitudVisible = false;

  static const LatLng _centroVeracruz = LatLng(19.1738, -96.1342);

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
    _socketService.conectar();
    _inicializarUbicacion();
    _nuevaSolicitudSub = _socketService.nuevaSolicitud.listen(
      _onNuevaSolicitud,
    );
  }

  @override
  void dispose() {
    // El socket y el seguimiento de ubicación se quedan vivos aunque el
    // usuario navegue a otra pantalla — solo se detienen al desactivar la
    // disponibilidad, o el socket en un logout real (Bloque 5).
    _nuevaSolicitudSub?.cancel();
    super.dispose();
  }

  Future<void> _inicializarUbicacion() async {
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
      if (mounted && _locationService.posicionActual.value == null) {
        _locationService.posicionActual.value = posicion;
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(LatLng(posicion.latitude, posicion.longitude)),
        );
      }
    } catch (e) {
      // Sin ubicación disponible por ahora; el mapa se queda centrado por
      // defecto hasta que el GPS responda.
    }
  }

  void _onNuevaSolicitud(Map<String, dynamic> solicitud) {
    if (!mounted || _solicitudVisible) return;
    _solicitudVisible = true;

    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: CLODColors.carbon,
      builder: (sheetContext) => _TarjetaSolicitud(
        solicitud: solicitud,
        onIgnorar: () => Navigator.of(sheetContext).pop(),
        onAceptar: () => _aceptarSolicitud(sheetContext, solicitud),
      ),
    ).whenComplete(() => _solicitudVisible = false);
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
    if (nuevoValor) {
      await _activarConVerificacion();
    } else {
      await _cambiarDisponibilidad(false);
    }
  }

  Future<void> _activarConVerificacion() async {
    setState(() => _disponible = true);

    final resultado = await context.push<bool>(
      '/verificacion-facial',
      extra: 'inicio_turno',
    );

    if (!mounted) return;

    if (resultado == true) {
      await _cambiarDisponibilidad(true);
    } else {
      setState(() => _disponible = false);
    }
  }

  Future<void> _cambiarDisponibilidad(bool nuevoValor) async {
    final valorAnterior = _disponible;
    setState(() {
      _disponible = nuevoValor;
      _cargandoDisponibilidad = true;
    });

    try {
      await _apiService.cambiarDisponibilidad(nuevoValor);
      if (nuevoValor) {
        _socketService.emitirDisponible();
        _locationService.iniciar();
      } else {
        _socketService.emitirNoDisponible();
        _locationService.detener();
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      final mensaje = data is Map<String, dynamic>
          ? data['mensaje'] as String?
          : null;
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
      body: Stack(
        children: [
          SafeArea(
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
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.4,
                        child: ValueListenableBuilder<Position?>(
                          valueListenable: _locationService.posicionActual,
                          builder: (context, posicion, _) {
                            return GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: posicion != null
                                    ? LatLng(
                                        posicion.latitude,
                                        posicion.longitude,
                                      )
                                    : _centroVeracruz,
                                zoom: 15,
                              ),
                              onMapCreated: (controller) {
                                _mapController = controller;
                                final posicionConocida =
                                    _locationService.posicionActual.value;
                                if (posicionConocida != null) {
                                  controller.animateCamera(
                                    CameraUpdate.newLatLng(
                                      LatLng(
                                        posicionConocida.latitude,
                                        posicionConocida.longitude,
                                      ),
                                    ),
                                  );
                                }
                              },
                              markers: posicion != null
                                  ? {
                                      Marker(
                                        markerId: const MarkerId(
                                          'mi_ubicacion',
                                        ),
                                        position: LatLng(
                                          posicion.latitude,
                                          posicion.longitude,
                                        ),
                                      ),
                                    }
                                  : {},
                            );
                          },
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
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
                              const SizedBox(height: 12),
                              _IndicadorConexionSocket(
                                socketService: _socketService,
                              ),
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: CLODColors.azulMarino.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
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
                                        _disponible
                                            ? 'Conectado'
                                            : 'Desconectado',
                                        style: CLODTextStyles.bodySmall
                                            .copyWith(
                                              color: CLODColors.grisClaro
                                                  .withValues(alpha: 0.6),
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
                                  color: CLODColors.grisClaro.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          const DevMenuButton(),
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
            CLODColors.grisClaro.withValues(alpha: 0.4),
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
                color: CLODColors.grisClaro.withValues(alpha: 0.6),
              ),
            ),
          ],
        );
      },
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
          Text(valor, style: CLODTextStyles.headingMedium),
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

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Nueva solicitud',
              textAlign: TextAlign.center,
              style: CLODTextStyles.headingMedium,
            ),
            const SizedBox(height: 20),
            _filaDato(Icons.person, nombrePasajero),
            const SizedBox(height: 12),
            _filaDato(Icons.location_on, origen),
            if (tarifa != null) ...[
              const SizedBox(height: 12),
              _filaDato(Icons.attach_money, '\$$tarifa MXN (referencia)'),
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
                        color: CLODColors.grisClaro.withValues(alpha: 0.4),
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

  Widget _filaDato(IconData icono, String texto) {
    return Row(
      children: [
        Icon(icono, size: 20, color: CLODColors.azulCLOD),
        const SizedBox(width: 12),
        Expanded(child: Text(texto, style: CLODTextStyles.bodyLarge)),
      ],
    );
  }
}
