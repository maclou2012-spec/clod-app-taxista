import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/foraneo_conductor.dart';
import '../../services/foraneo_conductor_service.dart';
import '../../theme/clod_theme.dart';
import '../../utils/errores_api.dart';
import '../../utils/fechas.dart';
import '../../utils/json.dart';
import '../../widgets/clod_app_bar.dart';

/// Viajes foráneos del taxista: pedir el servicio, sus viajes publicados y
/// publicar uno nuevo. Es opcional y se suma a su servicio local.
class ForaneosScreen extends StatefulWidget {
  const ForaneosScreen({super.key});

  @override
  State<ForaneosScreen> createState() => _ForaneosScreenState();
}

class _ForaneosScreenState extends State<ForaneosScreen> {
  final ForaneoConductorService _servicio = ForaneoConductorService();
  PerfilForaneo? _perfil;
  List<ViajeConductor> _viajes = [];
  bool _cargando = true;
  bool _solicitando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final perfil = await _servicio.perfil();
      final viajes = perfil.habilitado
          ? await _servicio.misViajes()
          : <ViajeConductor>[];
      if (!mounted) return;
      setState(() {
        _perfil = perfil;
        _viajes = viajes;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = ErrorApi.desde(e).mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _solicitar() async {
    setState(() => _solicitando = true);
    try {
      await _servicio.solicitarServicio();
      await _cargar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ErrorApi.desde(e).mensaje)));
      }
    } finally {
      if (mounted) setState(() => _solicitando = false);
    }
  }

  Future<void> _abrir(String ruta) async {
    await context.push(ruta);
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final p = _perfil;
    return Scaffold(
      appBar: const ClodAppBar(titulo: 'Viajes foráneos'),
      floatingActionButton: p != null && p.habilitado
          ? FloatingActionButton.extended(
              backgroundColor: CLODColors.azulCLOD,
              foregroundColor: Colors.white,
              onPressed: () => _abrir('/foraneos/publicar'),
              icon: const Icon(Icons.add_road),
              label: const Text('Publicar viaje'),
            )
          : null,
      body: SafeArea(
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _cargar,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    if (p == null)
                      Text(_error ?? 'No pudimos cargar tus viajes.')
                    else if (!p.habilitado)
                      _EstadoServicio(
                        perfil: p,
                        solicitando: _solicitando,
                        onSolicitar: _solicitar,
                      )
                    else ...[
                      _Resumen(
                        perfil: p,
                        onBilletera: () => _abrir('/foraneos/billetera'),
                      ),
                      const SizedBox(height: 16),
                      if (_viajes.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 32),
                          child: Text(
                            'Publica tu primer viaje: tú eliges la ruta, la hora, los asientos y el precio.',
                            textAlign: TextAlign.center,
                            style: CLODTextStyles.bodyMedium.copyWith(
                              color: CLODColors.texto(
                                context,
                              ).withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      for (final v in _viajes)
                        Card(
                          child: ListTile(
                            title: Text(
                              '${v.origenCiudad} → ${v.destinoCiudad}',
                            ),
                            subtitle: Text(
                              [
                                textoEstadoViaje(v.estado),
                                if (v.salida != null) textoDiaHora(v.salida!),
                                '${v.asientosReservados}/${v.asientosTotales} asientos',
                              ].join(' · '),
                            ),
                            trailing: v.porAprobar > 0
                                ? Badge(
                                    label: Text('${v.porAprobar}'),
                                    child: const Icon(
                                      Icons.person_add_alt_1,
                                      color: CLODColors.azulCLOD,
                                    ),
                                  )
                                : v.precioAsiento != null
                                ? Text(formatoPesos(v.precioAsiento!))
                                : null,
                            onTap: () => _abrir('/foraneos/viaje/${v.id}'),
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

class _EstadoServicio extends StatelessWidget {
  const _EstadoServicio({
    required this.perfil,
    required this.solicitando,
    required this.onSolicitar,
  });

  final PerfilForaneo perfil;
  final bool solicitando;
  final VoidCallback onSolicitar;

  @override
  Widget build(BuildContext context) {
    final texto = CLODColors.texto(context);
    final (titulo, detalle) = switch (perfil.servicio) {
      'pendiente' => (
        'Tu solicitud está en revisión',
        'Una persona de CLOD revisa tu cuenta y te avisamos cuando puedas publicar viajes.',
      ),
      'suspendido' => (
        'Viajes foráneos en pausa',
        'Escríbenos desde Ayuda para saber más.',
      ),
      _ => (
        'Ofrece viajes a otras ciudades',
        'Publica un viaje con tu ruta, tu hora y tu precio por asiento. Los pasajeros reservan desde '
            'CLOD y tú apruebas o rechazas cada reserva. Usa tu misma membresía de TaxiCLOD.',
      ),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.route, size: 40, color: CLODColors.azulCLOD),
            const SizedBox(height: 12),
            Text(
              titulo,
              style: CLODTextStyles.headingSmall.copyWith(color: texto),
            ),
            const SizedBox(height: 8),
            Text(
              detalle,
              style: CLODTextStyles.bodyMedium.copyWith(
                color: texto.withValues(alpha: 0.75),
              ),
            ),
            if (perfil.servicio == 'sin_solicitar') ...[
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: CLODColors.azulCLOD,
                ),
                onPressed: solicitando ? null : onSolicitar,
                child: Text(
                  solicitando ? 'Enviando…' : 'Quiero ofrecer viajes foráneos',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.perfil, required this.onBilletera});

  final PerfilForaneo perfil;
  final VoidCallback onBilletera;

  @override
  Widget build(BuildContext context) {
    final texto = CLODColors.texto(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (perfil.vehiculo != null)
              Text(
                '${perfil.vehiculo} · ${perfil.asientosMaximos} asientos para pasajeros',
                style: CLODTextStyles.bodyMedium.copyWith(color: texto),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.star_rounded,
                  size: 18,
                  color: CLODColors.azulCLOD,
                ),
                const SizedBox(width: 4),
                Text(
                  perfil.calificacion != null
                      ? '${perfil.calificacion!.toStringAsFixed(1)} (${perfil.resenas} reseñas)'
                      : 'Aún sin reseñas',
                  style: CLODTextStyles.bodySmall.copyWith(color: texto),
                ),
                const Spacer(),
                if (!perfil.membresiaVigente)
                  Text(
                    'Membresía vencida',
                    style: CLODTextStyles.bodySmall.copyWith(
                      color: CLODColors.azulMarino,
                    ),
                  ),
              ],
            ),
            const Divider(height: 20),
            InkWell(
              onTap: onBilletera,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      perfil.saldo < 0
                          ? 'Por depositar a CLOD: ${formatoPesos(perfil.saldo.abs())}'
                          : 'Saldo a tu favor: ${formatoPesos(perfil.saldo)}',
                      style: CLODTextStyles.bodyMedium.copyWith(color: texto),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
