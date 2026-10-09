import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../services/secure_storage_service.dart';
import '../../services/socket_service.dart';
import '../../theme/clod_theme.dart';
import '../../widgets/clod_app_bar.dart';
import '../../widgets/clod_drawer.dart';

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
      appBar: const ClodAppBar(titulo: 'Configuración'),
      drawer: const ClodDrawer(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FilaConfiguracion(
                    icono: Icons.emergency_outlined,
                    titulo: 'Contacto de emergencia',
                    onTap: () =>
                        context.push('/configuracion/contacto-emergencia'),
                  ),
                  const SizedBox(height: 12),
                  _FilaConfiguracion(
                    icono: Icons.description_outlined,
                    titulo: 'Contrato de licenciatario',
                    onTap: () => context.push('/contrato', extra: true),
                  ),
                  const SizedBox(height: 12),
                  const _FilaModoOscuro(),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Divider(color: CLODColors.borde(context)),
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
          color: CLODColors.fondoTarjeta(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: CLODColors.borde(context)),
        ),
        child: Row(
          children: [
            Icon(icono, size: 20, color: CLODColors.azulCLOD),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                titulo,
                style: CLODTextStyles.bodyLarge.copyWith(
                  color: CLODColors.texto(context),
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: CLODColors.texto(context).withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaModoOscuro extends StatelessWidget {
  const _FilaModoOscuro();

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final activo = themeProvider.modo == ThemeMode.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: CLODColors.fondoTarjeta(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CLODColors.borde(context)),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: activo,
        onChanged: (_) => context.read<ThemeProvider>().alternar(),
        activeTrackColor: CLODColors.azulCLOD,
        secondary: Icon(
          Icons.dark_mode_outlined,
          size: 20,
          color: CLODColors.azulCLOD,
        ),
        title: Text(
          'Modo oscuro',
          style: CLODTextStyles.bodyLarge.copyWith(
            color: CLODColors.texto(context),
          ),
        ),
      ),
    );
  }
}
