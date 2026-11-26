import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/foraneo_conductor.dart';
import '../services/foraneo_conductor_service.dart';
import '../theme/clod_theme.dart';

/// Busca una dirección (GET /api/geocoding/buscar) y devuelve el lugar con sus
/// coordenadas. Sirve para el punto de salida, de llegada y las paradas.
Future<LugarForaneo?> buscarLugar(
  BuildContext context, {
  required String titulo,
}) => showModalBottomSheet<LugarForaneo>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _BuscarLugar(titulo: titulo),
);

class _BuscarLugar extends StatefulWidget {
  const _BuscarLugar({required this.titulo});

  final String titulo;

  @override
  State<_BuscarLugar> createState() => _BuscarLugarState();
}

class _BuscarLugarState extends State<_BuscarLugar> {
  final ForaneoConductorService _servicio = ForaneoConductorService();
  final TextEditingController _texto = TextEditingController();
  Timer? _espera;
  List<LugarForaneo> _resultados = [];
  bool _buscando = false;
  String? _error;

  // Centro para ordenar resultados; Colima si no hay ubicación.
  double _lat = 19.2433;
  double _lng = -103.7247;

  @override
  void initState() {
    super.initState();
    Geolocator.getLastKnownPosition()
        .then((p) {
          if (p != null) {
            _lat = p.latitude;
            _lng = p.longitude;
          }
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    _espera?.cancel();
    _texto.dispose();
    super.dispose();
  }

  void _alEscribir(String valor) {
    _espera?.cancel();
    if (valor.trim().length < 3) return;
    _espera = Timer(
      const Duration(milliseconds: 450),
      () => _buscar(valor.trim()),
    );
  }

  Future<void> _buscar(String q) async {
    setState(() {
      _buscando = true;
      _error = null;
    });
    try {
      final r = await _servicio.buscarLugares(q, _lat, _lng);
      if (mounted) setState(() => _resultados = r);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'No pudimos buscar. Revisa tu conexión.');
      }
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final texto = CLODColors.texto(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                widget.titulo,
                style: CLODTextStyles.headingSmall.copyWith(color: texto),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: TextField(
                controller: _texto,
                autofocus: true,
                onChanged: _alEscribir,
                decoration: InputDecoration(
                  hintText: 'Calle, colonia, lugar conocido…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _buscando
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _error!,
                  style: CLODTextStyles.bodySmall.copyWith(color: texto),
                ),
              ),
            Expanded(
              child: ListView(
                children: [
                  for (final l in _resultados)
                    ListTile(
                      leading: const Icon(
                        Icons.place_outlined,
                        color: CLODColors.azulCLOD,
                      ),
                      title: Text(l.direccion),
                      onTap: () => Navigator.pop(context, l),
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
