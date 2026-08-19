import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/calificar_pasajero_args.dart';
import '../../services/api_service.dart';
import '../../theme/clod_theme.dart';
import '../../widgets/clod_primary_button.dart';
import '../../widgets/clod_text_field.dart';

class CalificarPasajeroScreen extends StatefulWidget {
  const CalificarPasajeroScreen({super.key, required this.args});

  final CalificarPasajeroArgs args;

  @override
  State<CalificarPasajeroScreen> createState() =>
      _CalificarPasajeroScreenState();
}

class _CalificarPasajeroScreenState extends State<CalificarPasajeroScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _comentarioController = TextEditingController();

  int _puntuacion = 0;
  bool _enviando = false;

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  void _onSeleccionarEstrella(int valor) {
    setState(() => _puntuacion = valor == _puntuacion ? 0 : valor);
  }

  void _irAResumen() {
    context.go('/resumen-viaje', extra: widget.args.viajeArgs);
  }

  Future<void> _enviarCalificacion() async {
    if (_puntuacion == 0) return;

    setState(() => _enviando = true);

    final comentario = _comentarioController.text.trim();
    try {
      await _apiService.calificarViaje(
        widget.args.viajeId,
        _puntuacion,
        comentario.isEmpty ? null : comentario,
      );
      if (!mounted) return;
      _irAResumen();
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo enviar tu calificación. Intenta de nuevo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CLODColors.carbon,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              Text(
                '¿Cómo estuvo tu pasajero?',
                textAlign: TextAlign.center,
                style: CLODTextStyles.headingMedium,
              ),
              const SizedBox(height: 8),
              Text(
                widget.args.viajeArgs.pasajeroNombre,
                textAlign: TextAlign.center,
                style: CLODTextStyles.bodyMedium.copyWith(
                  color: CLODColors.grisClaro.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 32),
              _SelectorEstrellas(
                puntuacion: _puntuacion,
                onSeleccionar: _onSeleccionarEstrella,
              ),
              const SizedBox(height: 32),
              Text(
                'Comentario (opcional)',
                style: CLODTextStyles.bodyMedium,
              ),
              const SizedBox(height: 8),
              CLODTextField(
                controller: _comentarioController,
                hintText: 'Cuéntanos más sobre el viaje',
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 24),
              CLODPrimaryButton(
                label: 'Enviar calificación',
                cargando: _enviando,
                habilitado: _puntuacion > 0,
                onPressed: _enviarCalificacion,
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _enviando ? null : _irAResumen,
                  child: Text(
                    'Omitir',
                    style: CLODTextStyles.bodyMedium.copyWith(
                      color: CLODColors.grisClaro.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectorEstrellas extends StatelessWidget {
  const _SelectorEstrellas({
    required this.puntuacion,
    required this.onSeleccionar,
  });

  final int puntuacion;
  final ValueChanged<int> onSeleccionar;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (indice) {
        final valor = indice + 1;
        final seleccionada = valor <= puntuacion;
        return IconButton(
          iconSize: 40,
          onPressed: () => onSeleccionar(valor),
          icon: Icon(
            seleccionada ? Icons.star : Icons.star_border,
            color: CLODColors.azulCLOD,
          ),
        );
      }),
    );
  }
}
