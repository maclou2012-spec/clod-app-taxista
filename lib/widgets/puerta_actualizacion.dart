import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/config_app_service.dart';
import '../theme/clod_theme.dart';

/// Envuelve toda la app (en `MaterialApp.router(builder: …)`):
/// - `actualizacion = obligatoria` → pantalla que no se cierra, con «Actualizar».
/// - `disponible` → aviso que se puede cerrar, como máximo una vez al día.
/// - Al volver de segundo plano, vuelve a pedir la configuración si pasó > 1 h.
class PuertaActualizacion extends StatefulWidget {
  const PuertaActualizacion({super.key, required this.child});

  final Widget child;

  @override
  State<PuertaActualizacion> createState() => _PuertaActualizacionState();
}

class _PuertaActualizacionState extends State<PuertaActualizacion>
    with WidgetsBindingObserver {
  static const String _claveAviso = 'aviso_actualizacion_dia';
  final ConfigAppService _config = ConfigAppService();
  bool _avisoCerrado = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _config.config.addListener(_alCambiar);
    _alCambiar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _config.config.removeListener(_alCambiar);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _config.alVolver();
  }

  static String _hoy() {
    final d = DateTime.now();
    return '${d.year}-${d.month}-${d.day}';
  }

  Future<void> _alCambiar() async {
    final c = _config.config.value;
    var cerrado = true;
    if (c != null && c.actualizacionDisponible && c.urlActualizar != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        cerrado = prefs.getString(_claveAviso) == _hoy();
      } catch (_) {
        cerrado = false;
      }
    }
    if (mounted) setState(() => _avisoCerrado = cerrado);
  }

  Future<void> _cerrarAviso() async {
    setState(() => _avisoCerrado = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_claveAviso, _hoy());
    } catch (_) {}
  }

  Future<void> _actualizar(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ConfigApp?>(
      valueListenable: _config.config,
      builder: (context, c, _) {
        final url = c?.urlActualizar;
        if (c != null && c.actualizacionObligatoria && url != null) {
          return _PantallaObligatoria(onActualizar: () => _actualizar(url));
        }
        return Stack(
          children: [
            widget.child,
            if (!_avisoCerrado && c != null && url != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: SafeArea(
                  child: _AvisoDisponible(
                    onActualizar: () => _actualizar(url),
                    onCerrar: _cerrarAviso,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PantallaObligatoria extends StatelessWidget {
  const _PantallaObligatoria({required this.onActualizar});

  final VoidCallback onActualizar;

  @override
  Widget build(BuildContext context) {
    final texto = CLODColors.texto(context);
    // PopScope: el botón "atrás" de Android no la cierra.
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.system_update,
                  size: 64,
                  color: CLODColors.azulCLOD,
                ),
                const SizedBox(height: 24),
                Text(
                  'Actualiza la app',
                  textAlign: TextAlign.center,
                  style: CLODTextStyles.headingMedium.copyWith(color: texto),
                ),
                const SizedBox(height: 12),
                Text(
                  'Hay una versión nueva que necesitas para seguir usando la '
                  'app. Solo toma un momento.',
                  textAlign: TextAlign.center,
                  style: CLODTextStyles.bodyMedium.copyWith(
                    color: texto.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: CLODColors.azulCLOD,
                    ),
                    onPressed: onActualizar,
                    child: const Text('Actualizar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvisoDisponible extends StatelessWidget {
  const _AvisoDisponible({required this.onActualizar, required this.onCerrar});

  final VoidCallback onActualizar;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(14),
      color: CLODColors.azulMarino,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            const Icon(Icons.system_update, color: Colors.white),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Hay una versión nueva de la app.',
                style: TextStyle(color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: onActualizar,
              child: const Text(
                'Actualizar',
                style: TextStyle(color: Colors.white),
              ),
            ),
            // Sin tooltip: este aviso vive encima del Navigator, sin Overlay.
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: onCerrar,
            ),
          ],
        ),
      ),
    );
  }
}

/// Etiqueta discreta «Modo de prueba» para las pantallas de pago.
class EtiquetaModoPrueba extends StatelessWidget {
  const EtiquetaModoPrueba({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ConfigApp?>(
      valueListenable: ConfigAppService().config,
      builder: (context, c, _) {
        if (c != null && !c.modoPrueba) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: CLODColors.borde(context)),
            ),
            child: Text(
              'Modo de prueba',
              style: CLODTextStyles.bodySmall.copyWith(
                color: CLODColors.texto(context).withValues(alpha: 0.6),
              ),
            ),
          ),
        );
      },
    );
  }
}
