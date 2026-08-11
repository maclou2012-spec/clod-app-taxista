import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/clod_theme.dart';

class AyudaScreen extends StatelessWidget {
  const AyudaScreen({super.key});

  static const String _numeroSoporte = '522295258226';

  Future<void> _abrirWhatsapp(BuildContext context) async {
    final uri = Uri.parse(
      'https://wa.me/$_numeroSoporte?text=${Uri.encodeComponent(
        'Hola, necesito ayuda con mi cuenta de TaxiCLOD',
      )}',
    );
    final exito = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!exito && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir WhatsApp.')),
      );
    }
  }

  Future<void> _llamarSoporte(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: '+$_numeroSoporte');
    final exito = await launchUrl(uri);
    if (!exito && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el marcador.')),
      );
    }
  }

  void _mostrarProximamente(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          'Preguntas frecuentes',
          style: CLODTextStyles.headingSmall.copyWith(
            color: CLODColors.carbon,
          ),
        ),
        content: Text(
          'Próximamente',
          style: CLODTextStyles.bodyMedium.copyWith(
            color: CLODColors.carbon.withValues(alpha: 0.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cerrar',
              style: CLODTextStyles.bodyMedium.copyWith(
                color: CLODColors.azulCLOD,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CLODColors.grisClaro,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                'Ayuda y soporte',
                style: CLODTextStyles.headingMedium.copyWith(
                  color: CLODColors.carbon,
                ),
              ),
              const SizedBox(height: 24),
              _FilaAyuda(
                icono: Icons.help_outline,
                titulo: 'Preguntas frecuentes',
                onTap: () => _mostrarProximamente(context),
              ),
              const SizedBox(height: 12),
              _FilaAyuda(
                icono: Icons.chat_bubble_outline,
                titulo: 'Contactar por WhatsApp',
                onTap: () => _abrirWhatsapp(context),
              ),
              const SizedBox(height: 12),
              _FilaAyuda(
                icono: Icons.call_outlined,
                titulo: 'Llamar a soporte',
                onTap: () => _llamarSoporte(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaAyuda extends StatelessWidget {
  const _FilaAyuda({
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
