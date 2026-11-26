import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';
import '../../services/secure_storage_service.dart';
import '../../services/socket_service.dart';
import '../../theme/clod_theme.dart';
import '../../utils/errores_api.dart';
import '../../utils/json.dart';
import '../../widgets/clod_error_text.dart';

const List<String> _motivos = [
  'Ya no doy servicio de taxi',
  'No recibí suficientes solicitudes',
  'Problemas con la app',
  'Preocupaciones de privacidad',
  'Otro',
];

/// Confirmación final de la baja (POST /api/perfil/cuenta/eliminar). Solo se
/// llega aquí si GET /api/perfil/cuenta/elegibilidad no encontró bloqueos;
/// si al confirmar el backend responde 409, se muestran sus motivos.
class EliminarCuentaScreen extends StatefulWidget {
  const EliminarCuentaScreen({super.key, this.avisos = const []});

  /// `avisos[].mensaje` de la elegibilidad (saldo a favor, membresía vigente).
  final List<String> avisos;

  @override
  State<EliminarCuentaScreen> createState() => _EliminarCuentaScreenState();
}

class _EliminarCuentaScreenState extends State<EliminarCuentaScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _confirmacion = TextEditingController();
  String? _motivo;
  bool _eliminando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _confirmacion.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _confirmacion.dispose();
    super.dispose();
  }

  bool get _puedeEliminar =>
      !_eliminando && _confirmacion.text.trim() == 'ELIMINAR';

  Future<void> _eliminar() async {
    setState(() {
      _eliminando = true;
      _error = null;
    });
    try {
      await _api.eliminarCuenta(motivo: _motivo);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Cuenta eliminada'),
          content: const Text('Tu cuenta de TaxiCLOD fue eliminada.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      await SecureStorageService().borrarTokens();
      SocketService().desconectar();
      await FirebaseAuth.instance.signOut();
      if (mounted) context.go('/telefono');
    } catch (e) {
      final err = ErrorApi.desde(e);
      if (!mounted) return;
      final bloqueos = aListaMapas(
        err.datos['bloqueos'],
      ).map((b) => aTexto(b['mensaje'])).whereType<String>().toList();
      setState(() {
        _error = err.status == 409
            ? (bloqueos.isNotEmpty
                  ? bloqueos.join('\n')
                  : 'Tu cuenta no se puede eliminar ahora: revisa tus '
                        'viajes en curso y tu saldo.')
            : err.mensaje;
      });
    } finally {
      if (mounted) setState(() => _eliminando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final texto = CLODColors.texto(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Eliminar mi cuenta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Esta acción no se puede deshacer',
                style: CLODTextStyles.headingMedium.copyWith(color: texto),
              ),
              const SizedBox(height: 16),
              const _Bloque(
                titulo: 'Se elimina',
                items: [
                  'Tu cuenta y tus datos de acceso',
                  'Tus documentos y tu foto de verificación',
                  'Tus datos personales y tu foto de perfil',
                ],
              ),
              const SizedBox(height: 12),
              const _Bloque(
                titulo: 'Se conserva sin tus datos personales',
                items: [
                  'El registro de tus viajes, membresías y saldos, ya sin '
                      'tu nombre ni tus datos de contacto',
                ],
              ),
              if (widget.avisos.isNotEmpty) ...[
                const SizedBox(height: 12),
                _Bloque(titulo: 'Ten en cuenta', items: widget.avisos),
              ],
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                initialValue: _motivo,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '¿Por qué te vas? (opcional)',
                ),
                items: [
                  for (final m in _motivos)
                    DropdownMenuItem(value: m, child: Text(m)),
                ],
                onChanged: (v) => setState(() => _motivo = v),
              ),
              const SizedBox(height: 20),
              Text(
                'Escribe ELIMINAR para confirmar',
                style: CLODTextStyles.bodyMedium.copyWith(color: texto),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmacion,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(hintText: 'ELIMINAR'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                CLODErrorText(_error!),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: CLODColors.azulMarino,
                  ),
                  onPressed: _puedeEliminar ? _eliminar : null,
                  child: _eliminando
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Eliminar mi cuenta definitivamente'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bloque extends StatelessWidget {
  const _Bloque({required this.titulo, required this.items});

  final String titulo;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final texto = CLODColors.texto(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CLODColors.fondoTarjeta(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CLODColors.borde(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: CLODTextStyles.bodyLarge.copyWith(
              color: CLODColors.azulCLOD,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '•  $item',
                style: CLODTextStyles.bodyMedium.copyWith(
                  color: texto.withValues(alpha: 0.8),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
