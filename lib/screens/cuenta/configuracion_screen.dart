import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/secure_storage_service.dart';
import '../../services/socket_service.dart';
import '../../theme/clod_theme.dart';

class ConfiguracionScreen extends StatelessWidget {
  const ConfiguracionScreen({super.key});

  Future<void> _cerrarSesion(BuildContext context) async {
    await SecureStorageService().borrarTokens();
    SocketService().desconectar();
    if (context.mounted) {
      context.go('/telefono');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CLODColors.grisClaro,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 48),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Configuración',
                style: CLODTextStyles.headingMedium.copyWith(
                  color: CLODColors.carbon,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FilaConfiguracion(
                    icono: Icons.emergency_outlined,
                    titulo: 'Contacto de emergencia',
                    onTap: () => context.push('/configuracion/contacto-emergencia'),
                  ),
                  const SizedBox(height: 12),
                  _FilaConfiguracion(
                    icono: Icons.description_outlined,
                    titulo: 'Contrato de licenciatario',
                    onTap: () => context.push('/contrato', extra: true),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Divider(color: CLODColors.carbon.withValues(alpha: 0.12)),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => _cerrarSesion(context),
                    child: Text(
                      'Cerrar sesión',
                      style: CLODTextStyles.bodyLarge.copyWith(
                        color: CLODColors.rojoUbicacion,
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

class _FilaConfiguracion extends StatelessWidget {
  const _FilaConfiguracion({
    required this.icono,
    required this.titulo,
    required this.onTap,
  });

  final IconData icono;
  final String titulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD3D1C7)),
        ),
        child: Row(
          children: [
            Icon(icono, size: 20, color: CLODColors.azulCLOD),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                titulo,
                style: CLODTextStyles.bodyLarge.copyWith(
                  color: CLODColors.carbon,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: CLODColors.carbon.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}
