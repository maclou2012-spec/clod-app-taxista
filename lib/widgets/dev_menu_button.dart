import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/clod_theme.dart';

// Acceso rápido a todas las pantallas construidas, solo visible en debug.
// No aparece nunca en release builds (kDebugMode es una constante en
// tiempo de compilación, así que el código ni siquiera se incluye).
class DevMenuButton extends StatelessWidget {
  const DevMenuButton({super.key});

  static const List<(String, String)> _pantallas = [
    ('Contrato', '/contrato'),
    ('Datos personales', '/registro-basico-taxista'),
    ('Identificación oficial', '/identificacion-oficial'),
    ('Licencia', '/licencia'),
    ('Vehículo', '/vehiculo'),
    ('Servicio', '/servicio'),
    ('Tarifa', '/tarifa'),
    ('Seguro', '/seguro'),
    ('En revisión', '/revision'),
    ('Membresía', '/membresia'),
    ('Dashboard', '/dashboard'),
    ('Viaje en curso', '/viaje-en-curso'),
    ('Perfil', '/perfil'),
    ('Historial de viajes', '/historial'),
    ('Referidos', '/referidos'),
    ('Configuración', '/configuracion'),
    ('Contacto de emergencia', '/configuracion/contacto-emergencia'),
    ('Test Maps', '/test-maps'),
  ];

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    return Positioned(
      right: 16,
      bottom: 16,
      child: FloatingActionButton.small(
        heroTag: 'dev-menu-button',
        backgroundColor: CLODColors.azulMarino,
        onPressed: () => _abrirMenu(context),
        child: const Icon(Icons.developer_mode, color: Colors.white),
      ),
    );
  }

  void _abrirMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: CLODColors.carbon,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '[DEV] Navegación directa',
                  style: CLODTextStyles.headingSmall,
                ),
              ),
              for (final (nombre, ruta) in _pantallas)
                ListTile(
                  title: Text(nombre, style: CLODTextStyles.bodyLarge),
                  onTap: () {
                    Navigator.of(context).pop();
                    context.push(ruta);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
