import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/clod_theme.dart';
import '../../widgets/clod_app_bar.dart';
import '../../widgets/clod_drawer.dart';

/// Enlaces a los tres documentos del taxista — reutiliza tal cual las
/// pantallas de identificación/licencia/seguro que ya existían (hasta ahora
/// solo alcanzables desde el flujo de registro inicial). Antes "Mis
/// documentos" en Mi perfil apuntaba por error a EnRevisionScreen (la
/// pantalla de "tu perfil está en revisión" del registro, no un listado de
/// documentos real) — este hub es el destino real que le faltaba.
class MisDocumentosScreen extends StatelessWidget {
  const MisDocumentosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ClodAppBar(titulo: 'Mis documentos'),
      drawer: const ClodDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FilaDocumento(
                icono: Icons.badge_outlined,
                titulo: 'Identificación oficial',
                onTap: () => context.push('/identificacion-oficial'),
              ),
              const SizedBox(height: 12),
              _FilaDocumento(
                icono: Icons.directions_car_outlined,
                titulo: 'Licencia',
                onTap: () => context.push('/licencia'),
              ),
              const SizedBox(height: 12),
              _FilaDocumento(
                icono: Icons.shield_outlined,
                titulo: 'Seguro',
                onTap: () => context.push('/seguro'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaDocumento extends StatelessWidget {
  const _FilaDocumento({
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
