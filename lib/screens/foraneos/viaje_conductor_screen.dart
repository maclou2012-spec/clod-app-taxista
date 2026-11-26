import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/foraneo_conductor.dart';
import '../../services/foraneo_conductor_service.dart';
import '../../theme/clod_theme.dart';
import '../../utils/errores_api.dart';
import '../../utils/fechas.dart';
import '../../utils/json.dart';
import '../../widgets/clod_app_bar.dart';

/// Un viaje foráneo del taxista: aprobar o rechazar reservas, iniciar (desde
/// una hora antes), abordar con el código del pasajero, marcar a quien no se
/// presentó, finalizar y calificar pasajeros. Mientras está en curso manda su
/// ubicación para que los pasajeros lo sigan.
class ViajeConductorScreen extends StatefulWidget {
  const ViajeConductorScreen({super.key, required this.viajeId});

  final int viajeId;

  @override
  State<ViajeConductorScreen> createState() => _ViajeConductorScreenState();
}

class _ViajeConductorScreenState extends State<ViajeConductorScreen> {
  final ForaneoConductorService _servicio = ForaneoConductorService();
  ViajeConductorDetalle? _viaje;
  bool _cargando = true;
  bool _enviando = false;
  String? _error;
  Timer? _ubicacion;
  final Set<int> _calificadas = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _ubicacion?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final v = await _servicio.viaje(widget.viajeId);
      if (!mounted) return;
      setState(() {
        _viaje = v;
        _error = null;
      });
      _ajustarUbicacion(v.enCurso);
    } catch (e) {
      if (mounted) setState(() => _error = ErrorApi.desde(e).mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Ubicación cada 15 s mientras el viaje está en curso y la pantalla abierta.
  void _ajustarUbicacion(bool enCurso) {
    if (!enCurso) {
      _ubicacion?.cancel();
      _ubicacion = null;
      return;
    }
    _ubicacion ??= Timer.periodic(const Duration(seconds: 15), (_) async {
      try {
        final p = await Geolocator.getCurrentPosition();
        await _servicio.enviarUbicacion(p.latitude, p.longitude);
      } catch (_) {
        // Sin GPS o sin red: se reintenta en el siguiente ciclo.
      }
    });
  }

  Future<void> _hacer(Future<void> Function() fn, {String? exito}) async {
    setState(() => _enviando = true);
    try {
      await fn();
      if (mounted && exito != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(exito)));
      }
      await _cargar();
    } catch (e) {
      final err = ErrorApi.desde(e);
      if (!mounted) return;
      final mensaje = switch (err.codigo) {
        'MUY_PRONTO' => 'Podrás iniciar el viaje una hora antes de la salida.',
        'PAGO_PENDIENTE' =>
          'Este pasajero todavía no paga con tarjeta; no puede abordar aún.',
        'CODIGO_INCORRECTO' =>
          'Código incorrecto. Pídeselo otra vez al pasajero.',
        _ => err.mensaje,
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensaje)));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<bool> _confirmar(String titulo, String texto, String accion) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(titulo),
          content: Text(texto),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(accion),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _abordar(ReservaConductor r) async {
    final controller = TextEditingController();
    final codigo = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('Abordar: ${r.pasajero ?? 'pasajero'}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Pídele su código de abordaje de 4 dígitos.'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 4,
                style: CLODTextStyles.headingLarge.copyWith(letterSpacing: 12),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setLocal(() {}),
                decoration: const InputDecoration(counterText: ''),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: controller.text.length == 4
                  ? () => Navigator.pop(context, controller.text)
                  : null,
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    ).whenComplete(controller.dispose);
    if (codigo == null) return;
    await _hacer(
      () => _servicio.abordar(r.id, codigo),
      exito: '${r.pasajero ?? 'Pasajero'} a bordo',
    );
  }

  Future<void> _calificar(ReservaConductor r) async {
    var puntuacion = 0;
    final comentario = TextEditingController();
    final enviar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('Califica a ${r.pasajero ?? 'tu pasajero'}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      onPressed: () => setLocal(() => puntuacion = i),
                      icon: Icon(
                        i <= puntuacion
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: CLODColors.azulCLOD,
                        size: 32,
                      ),
                    ),
                ],
              ),
              TextField(
                controller: comentario,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Comentario (opcional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: puntuacion > 0
                  ? () => Navigator.pop(context, true)
                  : null,
              child: const Text('Enviar'),
            ),
          ],
        ),
      ),
    );
    final texto = comentario.text.trim();
    comentario.dispose();
    if (enviar != true) return;
    await _hacer(() async {
      await _servicio.calificarPasajero(
        r.id,
        puntuacion: puntuacion,
        comentario: texto.isEmpty ? null : texto,
      );
      _calificadas.add(r.id);
    }, exito: '¡Gracias por calificar!');
  }

  @override
  Widget build(BuildContext context) {
    final v = _viaje;
    return Scaffold(
      appBar: ClodAppBar(
        titulo: v == null
            ? 'Viaje'
            : '${v.viaje.origenCiudad} → ${v.viaje.destinoCiudad}',
      ),
      body: SafeArea(
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : v == null
            ? Center(child: Text(_error ?? 'No encontramos este viaje.'))
            : RefreshIndicator(onRefresh: _cargar, child: _contenido(v)),
      ),
      bottomNavigationBar: v == null ? null : _acciones(v),
    );
  }

  Widget _contenido(ViajeConductorDetalle d) {
    final v = d.viaje;
    final texto = CLODColors.texto(context);
    final tenue = texto.withValues(alpha: 0.65);
    final activas = d.reservas.where(
      (r) => const {
        'solicitada',
        'confirmada',
        'abordo',
        'completada',
      }.contains(r.estado),
    );
    final otras = d.reservas.where((r) => !activas.contains(r));
    final salio = v.salida != null && DateTime.now().isAfter(v.salida!);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          textoEstadoViaje(v.estado),
          style: CLODTextStyles.headingMedium.copyWith(color: texto),
        ),
        Text(
          [
            if (v.salida != null) 'Sale ${textoDiaHora(v.salida!)}',
            if (v.precioAsiento != null)
              '${formatoPesos(v.precioAsiento!)} por asiento',
            '${v.asientosReservados}/${v.asientosTotales} asientos',
          ].join(' · '),
          style: CLODTextStyles.bodyMedium.copyWith(color: tenue),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Punto(Icons.trip_origin, v.origenCiudad, d.origenPunto),
                for (final p in d.paradas)
                  _Punto(
                    Icons.more_vert,
                    p.ciudad,
                    [
                      p.punto,
                      if (p.precioDesdeOrigen != null)
                        '${formatoPesos(p.precioDesdeOrigen!)} desde el origen',
                    ].whereType<String>().join(' · '),
                  ),
                _Punto(
                  Icons.location_on_outlined,
                  v.destinoCiudad,
                  d.destinoPunto,
                ),
                if (d.notas != null) ...[
                  const Divider(),
                  Text(
                    d.notas!,
                    style: CLODTextStyles.bodySmall.copyWith(color: tenue),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Pasajeros',
          style: CLODTextStyles.headingSmall.copyWith(color: texto),
        ),
        if (d.reservas.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Aún no hay reservas.',
              style: CLODTextStyles.bodyMedium.copyWith(color: tenue),
            ),
          ),
        for (final r in [...activas, ...otras]) _tarjetaReserva(d, r, salio),
      ],
    );
  }

  Widget _tarjetaReserva(
    ViajeConductorDetalle d,
    ReservaConductor r,
    bool salio,
  ) {
    final texto = CLODColors.texto(context);
    final tenue = texto.withValues(alpha: 0.65);
    final enCurso = d.enCurso;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${r.pasajero ?? 'Pasajero'} · ${r.asientos} asiento${r.asientos == 1 ? '' : 's'}',
                    style: CLODTextStyles.bodyLarge.copyWith(
                      color: texto,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  textoEstadoReserva(r.estado),
                  style: CLODTextStyles.bodySmall.copyWith(
                    color: CLODColors.azulCLOD,
                  ),
                ),
              ],
            ),
            Text(
              [
                '${d.ciudadDe(r.subeParadaId, esSubida: true)} → ${d.ciudadDe(r.bajaParadaId, esSubida: false)}',
                if (r.montoAsientos != null) formatoPesos(r.montoAsientos!),
                r.metodoPago == 'tarjeta'
                    ? (r.pagado ? 'pagado con tarjeta' : 'tarjeta pendiente')
                    : 'efectivo',
                if (r.calificacionPasajero != null)
                  '★ ${r.calificacionPasajero!.toStringAsFixed(1)}',
              ].join(' · '),
              style: CLODTextStyles.bodySmall.copyWith(color: tenue),
            ),
            if (r.mensaje != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '«${r.mensaje}»',
                  style: CLODTextStyles.bodySmall.copyWith(color: texto),
                ),
              ),
            if (r.estado == 'solicitada' && r.responderAntes != null)
              Text(
                'Responde antes de ${textoDiaHora(r.responderAntes!)}',
                style: CLODTextStyles.bodySmall.copyWith(color: tenue),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (r.estado == 'solicitada') ...[
                  OutlinedButton(
                    onPressed: _enviando
                        ? null
                        : () => _hacer(
                            () => _servicio.responderReserva(
                              r.id,
                              aprobar: false,
                            ),
                          ),
                    child: const Text('Rechazar'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: CLODColors.azulCLOD,
                    ),
                    onPressed: _enviando
                        ? null
                        : () => _hacer(
                            () =>
                                _servicio.responderReserva(r.id, aprobar: true),
                            exito: 'Reserva confirmada',
                          ),
                    child: const Text('Aprobar'),
                  ),
                ],
                if (r.telefono != null &&
                    const {'confirmada', 'abordo'}.contains(r.estado))
                  OutlinedButton.icon(
                    onPressed: () =>
                        launchUrl(Uri(scheme: 'tel', path: r.telefono)),
                    icon: const Icon(Icons.call_outlined, size: 18),
                    label: const Text('Llamar'),
                  ),
                if (enCurso && r.estado == 'confirmada')
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: CLODColors.azulCLOD,
                    ),
                    onPressed: _enviando || r.esperandoPago
                        ? null
                        : () => _abordar(r),
                    child: Text(r.esperandoPago ? 'Esperando pago' : 'Abordar'),
                  ),
                if (r.estado == 'confirmada' && salio)
                  TextButton(
                    onPressed: _enviando
                        ? null
                        : () async {
                            if (await _confirmar(
                              'No se presentó',
                              '¿${r.pasajero ?? 'El pasajero'} no llegó al punto de subida?',
                              'Sí, no llegó',
                            )) {
                              await _hacer(() => _servicio.noSePresento(r.id));
                            }
                          },
                    child: const Text('No se presentó'),
                  ),
                if (r.estado == 'completada' && !_calificadas.contains(r.id))
                  TextButton(
                    onPressed: _enviando ? null : () => _calificar(r),
                    child: const Text('Calificar pasajero'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget? _acciones(ViajeConductorDetalle d) {
    final hijos = <Widget>[
      if (d.puedeCancelar)
        Expanded(
          child: OutlinedButton(
            onPressed: _enviando
                ? null
                : () async {
                    if (await _confirmar(
                      'Cancelar viaje',
                      'Se avisará a tus pasajeros y a quien pagó con tarjeta se le devuelve todo.',
                      'Cancelar viaje',
                    )) {
                      await _hacer(
                        () => _servicio.cancelarViaje(d.viaje.id),
                        exito: 'Viaje cancelado',
                      );
                    }
                  },
            child: const Text('Cancelar'),
          ),
        ),
      if (d.puedeIniciar) ...[
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: CLODColors.azulCLOD),
            onPressed: _enviando
                ? null
                : () async {
                    if (await _confirmar(
                      'Iniciar viaje',
                      'Las reservas que no aprobaste se rechazan. Los pasajeros podrán seguirte en el mapa.',
                      'Iniciar',
                    )) {
                      await _hacer(
                        () => _servicio.iniciar(d.viaje.id),
                        exito: 'Viaje iniciado',
                      );
                    }
                  },
            child: const Text('Iniciar viaje'),
          ),
        ),
      ],
      if (d.enCurso)
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: CLODColors.azulCLOD),
            onPressed: _enviando
                ? null
                : () async {
                    if (await _confirmar(
                      'Finalizar viaje',
                      'Los pasajeros a bordo quedan como completados y quien no abordó, como no presentado.',
                      'Finalizar',
                    )) {
                      await _hacer(
                        () => _servicio.finalizar(d.viaje.id),
                        exito: 'Viaje terminado',
                      );
                    }
                  },
            child: const Text('Finalizar viaje'),
          ),
        ),
    ];
    if (hijos.isEmpty) return null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(children: hijos),
      ),
    );
  }
}

class _Punto extends StatelessWidget {
  const _Punto(this.icono, this.ciudad, this.detalle);

  final IconData icono;
  final String ciudad;
  final String detalle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 20, color: CLODColors.azulCLOD),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ciudad,
                style: CLODTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (detalle.isNotEmpty)
                Text(
                  detalle,
                  style: CLODTextStyles.bodySmall.copyWith(
                    color: CLODColors.texto(context).withValues(alpha: 0.65),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
