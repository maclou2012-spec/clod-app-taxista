import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../models/foraneo_conductor.dart';
import '../../services/foraneo_conductor_service.dart';
import '../../theme/clod_theme.dart';
import '../../utils/errores_api.dart';
import '../../utils/fechas.dart';
import '../../utils/json.dart';
import '../../widgets/buscar_lugar_sheet.dart';
import '../../widgets/clod_app_bar.dart';
import '../../widgets/clod_error_text.dart';

/// Publicar un viaje foráneo (POST /api/conductor-foraneo/viajes). El taxista
/// decide ruta, hora, asientos y precio; CLOD solo pone un tope por asiento.
class PublicarViajeScreen extends StatefulWidget {
  const PublicarViajeScreen({super.key});

  @override
  State<PublicarViajeScreen> createState() => _PublicarViajeScreenState();
}

class _PublicarViajeScreenState extends State<PublicarViajeScreen> {
  final ForaneoConductorService _servicio = ForaneoConductorService();
  final _origenCiudad = TextEditingController();
  final _destinoCiudad = TextEditingController();
  final _precio = TextEditingController();
  final _notas = TextEditingController();

  PerfilForaneo? _perfil;
  LugarForaneo? _origen;
  LugarForaneo? _destino;
  final List<ParadaNueva> _paradas = [];
  DateTime? _salida;
  int _asientos = 3;
  bool _reservaInmediata = true;
  String _equipaje = 'mediano';
  bool _mascotas = false;
  bool _fumar = false;
  bool _dosAtras = false;
  bool _soloMujeres = false;
  bool _paquetes = false;

  CotizacionForanea? _cotizacion;
  bool _cotizando = false;
  bool _publicando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final c in [_origenCiudad, _destinoCiudad, _precio]) {
      c.addListener(() => setState(() {}));
    }
    _servicio
        .perfil()
        .then((p) {
          if (!mounted) return;
          setState(() {
            _perfil = p;
            _asientos = _asientos.clamp(1, p.asientosMaximos);
          });
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    for (final c in [_origenCiudad, _destinoCiudad, _precio, _notas]) {
      c.dispose();
    }
    super.dispose();
  }

  double? get _precioAsiento =>
      double.tryParse(_precio.text.replaceAll(',', '.'));

  Future<void> _cotizar() async {
    final o = _origen;
    final d = _destino;
    if (o == null || d == null) return;
    setState(() {
      _cotizando = true;
      _cotizacion = null;
    });
    try {
      final c = await _servicio.cotizar(
        origen: o,
        destino: d,
        paradas: [for (final p in _paradas) p.lugar],
      );
      if (mounted) setState(() => _cotizacion = c);
    } catch (e) {
      if (mounted) setState(() => _error = ErrorApi.desde(e).mensaje);
    } finally {
      if (mounted) setState(() => _cotizando = false);
    }
  }

  Future<void> _elegir(
    String titulo,
    ValueChanged<LugarForaneo> alElegir,
  ) async {
    final l = await buscarLugar(context, titulo: titulo);
    if (l == null) return;
    setState(() => alElegir(l));
    await _cotizar();
  }

  Future<void> _agregarParada() async {
    final ciudad = TextEditingController();
    final precio = TextEditingController();
    LugarForaneo? lugar;
    final parada = await showDialog<ParadaNueva>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Agregar parada'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ciudad,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Ciudad'),
                  onChanged: (_) => setLocal(() {}),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final l = await buscarLugar(
                      context,
                      titulo: 'Punto de la parada',
                    );
                    if (l != null) setLocal(() => lugar = l);
                  },
                  icon: const Icon(Icons.place_outlined),
                  label: Text(
                    lugar?.direccion ?? 'Elegir el punto',
                    maxLines: 2,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: precio,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Precio desde el origen (opcional)',
                    helperText: 'Si lo dejas vacío, se calcula por distancia.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: ciudad.text.trim().length >= 2 && lugar != null
                  ? () => Navigator.pop(
                      context,
                      ParadaNueva(
                        ciudad: ciudad.text.trim(),
                        lugar: lugar!,
                        precioDesdeOrigen: double.tryParse(
                          precio.text.replaceAll(',', '.'),
                        ),
                      ),
                    )
                  : null,
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
    ciudad.dispose();
    precio.dispose();
    if (parada == null) return;
    setState(() => _paradas.add(parada));
    await _cotizar();
  }

  Future<void> _elegirSalida() async {
    final ahora = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: _salida ?? ahora.add(const Duration(days: 1)),
      firstDate: ahora,
      lastDate: ahora.add(const Duration(days: 90)),
    );
    if (fecha == null || !mounted) return;
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _salida ?? ahora.add(const Duration(hours: 2)),
      ),
    );
    if (hora == null) return;
    setState(
      () => _salida = DateTime(
        fecha.year,
        fecha.month,
        fecha.day,
        hora.hour,
        hora.minute,
      ),
    );
  }

  String? get _faltante {
    if (_origenCiudad.text.trim().length < 2 || _origen == null) {
      return 'Indica la ciudad y el punto de salida.';
    }
    if (_destinoCiudad.text.trim().length < 2 || _destino == null) {
      return 'Indica la ciudad y el punto de llegada.';
    }
    final s = _salida;
    if (s == null) return 'Elige la fecha y la hora de salida.';
    if (s.isBefore(DateTime.now().add(const Duration(hours: 1)))) {
      return 'La salida debe ser al menos en una hora.';
    }
    final precio = _precioAsiento;
    if (precio == null || precio < 1) return 'Escribe tu precio por asiento.';
    final tope = _cotizacion?.precioMaxAsiento;
    if (tope != null && precio > tope) {
      return 'El precio por asiento no puede pasar de ${formatoPesos(tope)}.';
    }
    return null;
  }

  Future<void> _publicar() async {
    final problema = _faltante;
    if (problema != null) {
      setState(() => _error = problema);
      return;
    }
    setState(() {
      _publicando = true;
      _error = null;
    });
    try {
      final notas = _notas.text.trim();
      final id = await _servicio.publicar({
        'origen_ciudad': _origenCiudad.text.trim(),
        'origen_punto': _origen!.direccion,
        'origen_lat': _origen!.lat,
        'origen_lng': _origen!.lng,
        'destino_ciudad': _destinoCiudad.text.trim(),
        'destino_punto': _destino!.direccion,
        'destino_lat': _destino!.lat,
        'destino_lng': _destino!.lng,
        // UTC con Z: el backend respeta el desfase.
        'salida_en': _salida!.toUtc().toIso8601String(),
        'asientos_totales': _asientos,
        'precio_asiento': _precioAsiento,
        if (_paradas.isNotEmpty)
          'paradas': [for (final p in _paradas) p.aJson()],
        'reserva_inmediata': _reservaInmediata,
        'equipaje': _equipaje,
        'permite_mascotas': _mascotas,
        'permite_fumar': _fumar,
        'max_dos_atras': _dosAtras,
        'solo_mujeres': _soloMujeres,
        'acepta_paquetes': _paquetes,
        if (notas.isNotEmpty) 'notas': notas,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('¡Viaje publicado!')));
      context.pushReplacement('/foraneos/viaje/$id');
    } catch (e) {
      final err = ErrorApi.desde(e);
      if (!mounted) return;
      setState(
        () => _error = switch (err.codigo) {
          'MEMBRESIA_NO_VIGENTE' =>
            'Tu membresía de TaxiCLOD no está vigente. Renuévala para publicar.',
          'DISTANCIA_CORTA' => 'Los viajes foráneos son de 30 km o más.',
          'VIAJE_TRASLAPADO' =>
            'Ya tienes otro viaje cerca de esa hora (±3 h).',
          _ => err.mensaje,
        },
      );
    } finally {
      if (mounted) setState(() => _publicando = false);
    }
  }

  Widget _titulo(String t) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(
      t,
      style: CLODTextStyles.headingSmall.copyWith(
        color: CLODColors.texto(context),
      ),
    ),
  );

  Widget _punto({
    required String etiqueta,
    required TextEditingController ciudad,
    required LugarForaneo? lugar,
    required VoidCallback onElegir,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: ciudad,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: 'Ciudad de $etiqueta'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: onElegir,
        icon: const Icon(Icons.place_outlined),
        label: Text(
          lugar?.direccion ?? 'Elegir el punto de $etiqueta',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final texto = CLODColors.texto(context);
    final tenue = texto.withValues(alpha: 0.65);
    final c = _cotizacion;
    final maxAsientos = _perfil?.asientosMaximos ?? 4;
    return Scaffold(
      appBar: const ClodAppBar(titulo: 'Publicar viaje'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _titulo('Ruta'),
            _punto(
              etiqueta: 'salida',
              ciudad: _origenCiudad,
              lugar: _origen,
              onElegir: () => _elegir('Punto de salida', (l) => _origen = l),
            ),
            const SizedBox(height: 12),
            _punto(
              etiqueta: 'llegada',
              ciudad: _destinoCiudad,
              lugar: _destino,
              onElegir: () => _elegir('Punto de llegada', (l) => _destino = l),
            ),
            const SizedBox(height: 8),
            for (final (i, p) in _paradas.indexed)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.more_vert,
                  color: CLODColors.azulCLOD,
                ),
                title: Text('Parada ${i + 1}: ${p.ciudad}'),
                subtitle: Text(
                  [
                    p.lugar.direccion,
                    if (p.precioDesdeOrigen != null)
                      formatoPesos(p.precioDesdeOrigen!),
                  ].join(' · '),
                  maxLines: 2,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() => _paradas.removeAt(i));
                    _cotizar();
                  },
                ),
              ),
            if (_paradas.length < 5)
              TextButton.icon(
                onPressed: _agregarParada,
                icon: const Icon(Icons.add),
                label: const Text('Agregar parada (opcional)'),
              ),
            if (_cotizando) const LinearProgressIndicator(),
            if (c != null)
              Text(
                '${c.distanciaKm.toStringAsFixed(0)} km · unas ${(c.duracionMin / 60).toStringAsFixed(1)} h',
                style: CLODTextStyles.bodySmall.copyWith(color: tenue),
              ),
            _titulo('Salida'),
            OutlinedButton.icon(
              onPressed: _elegirSalida,
              icon: const Icon(Icons.event),
              label: Text(
                _salida == null
                    ? 'Elegir fecha y hora'
                    : textoDiaHora(_salida!),
              ),
            ),
            _titulo('Asientos y precio'),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Asientos para pasajeros',
                    style: CLODTextStyles.bodyMedium.copyWith(color: texto),
                  ),
                ),
                IconButton(
                  onPressed: _asientos > 1
                      ? () => setState(() => _asientos--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '$_asientos',
                  style: CLODTextStyles.headingSmall.copyWith(color: texto),
                ),
                IconButton(
                  onPressed: _asientos < maxAsientos
                      ? () => setState(() => _asientos++)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            TextField(
              controller: _precio,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: 'Tu precio por asiento (del origen al destino)',
                prefixText: r'$ ',
                helperText: c != null
                    ? 'Máximo permitido por CLOD: ${formatoPesos(c.precioMaxAsiento)}'
                    : null,
              ),
            ),
            if (c != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'El pasajero paga además un cargo de servicio CLOD de ${formatoPesos(c.tarifaServicioCliente)}; '
                  'el precio del asiento es completo para ti.',
                  style: CLODTextStyles.bodySmall.copyWith(color: tenue),
                ),
              ),
            _titulo('Reservas y preferencias'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _reservaInmediata,
              onChanged: (v) => setState(() => _reservaInmediata = v),
              title: const Text('Reserva inmediata'),
              subtitle: Text(
                _reservaInmediata
                    ? 'Se confirman solas.'
                    : 'Tú apruebas cada reserva.',
              ),
            ),
            DropdownButtonFormField<String>(
              initialValue: _equipaje,
              decoration: const InputDecoration(labelText: 'Equipaje'),
              items: [
                for (final e in opcionesEquipaje.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _equipaje = v ?? 'mediano'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _dosAtras,
              onChanged: (v) => setState(() => _dosAtras = v ?? false),
              title: const Text('Máximo dos personas atrás'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _mascotas,
              onChanged: (v) => setState(() => _mascotas = v ?? false),
              title: const Text('Acepto mascotas'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _paquetes,
              onChanged: (v) => setState(() => _paquetes = v ?? false),
              title: const Text('Acepto paquetes'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _fumar,
              onChanged: (v) => setState(() => _fumar = v ?? false),
              title: const Text('Se permite fumar'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _soloMujeres,
              onChanged: (v) => setState(() => _soloMujeres = v ?? false),
              title: const Text('Solo mujeres'),
            ),
            TextField(
              controller: _notas,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notas para los pasajeros (opcional)',
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: CLODErrorText(_error!),
              ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: CLODColors.azulCLOD,
                ),
                onPressed: _publicando ? null : _publicar,
                child: Text(_publicando ? 'Publicando…' : 'Publicar viaje'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
