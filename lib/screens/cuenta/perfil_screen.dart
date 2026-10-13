import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_service.dart';
import '../../theme/clod_theme.dart';
import '../../widgets/clod_app_bar.dart';
import '../../widgets/clod_drawer.dart';
import '../../widgets/clod_error_text.dart';

/// "Mis datos personales" — se alcanza tocando la foto/nombre en el
/// encabezado del menú deslizable. Antes se llamaba "Mi perfil" y además
/// tenía una lista de accesos (Mi vehículo, Mi tarifa, Mis documentos,
/// Historial, Mis pagos, Mis referidos, Configuración, Ayuda) que ahora
/// viven en el menú mismo (Mi cuenta) o ya estaban duplicados como ítems
/// de primer nivel del drawer — ver el reporte de la tarea para el mapeo
/// completo. Esta pantalla ahora solo tiene lo que le era propio: la foto
/// y el nombre/clase del taxista.
class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final ApiService _apiService = ApiService();
  final ImagePicker _imagePicker = ImagePicker();

  bool _cargando = true;
  String? _errorMensaje;
  String _nombre = '';
  String? _claseNombre;
  String? _fotoPerfilUrl;
  bool _subiendoFoto = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final resultados = await Future.wait<dynamic>([
        _apiService.obtenerUsuarioActual(),
        _apiService.obtenerMiPerfilTaxista(),
        _apiService.obtenerClasesServicio(),
      ]);

      final usuario =
          (resultados[0] as Map<String, dynamic>)['usuario']
              as Map<String, dynamic>?;
      final taxista =
          (resultados[1] as Map<String, dynamic>)['taxista']
              as Map<String, dynamic>?;
      final clases = (resultados[2] as List<dynamic>)
          .cast<Map<String, dynamic>>();

      final claseId = taxista?['clase_id'];
      final clase = clases.firstWhere(
        (c) => c['id'] == claseId,
        orElse: () => const {},
      );

      if (mounted) {
        setState(() {
          _nombre = usuario?['nombre'] as String? ?? '';
          _claseNombre = clase['nombre'] as String?;
          _fotoPerfilUrl = usuario?['foto_perfil_url'] as String?;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMensaje = 'No se pudo cargar tu perfil.';
          _cargando = false;
        });
      }
    }
  }

  Future<void> _elegirFuenteFoto() async {
    final fuente = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: CLODColors.fondoTarjeta(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: CLODColors.azulCLOD),
              title: Text(
                'Tomar foto',
                style: CLODTextStyles.bodyLarge.copyWith(
                  color: CLODColors.texto(context),
                ),
              ),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: CLODColors.azulCLOD),
              title: Text(
                'Elegir de galería',
                style: CLODTextStyles.bodyLarge.copyWith(
                  color: CLODColors.texto(context),
                ),
              ),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (fuente == null) return;
    await _capturarYSubirFoto(fuente);
  }

  Future<void> _capturarYSubirFoto(ImageSource fuente) async {
    final imagen = await _imagePicker.pickImage(
      source: fuente,
      imageQuality: 85,
    );
    if (imagen == null) return;

    setState(() => _subiendoFoto = true);
    try {
      final url = await _apiService.subirFotoPerfil(File(imagen.path));
      if (mounted) setState(() => _fotoPerfilUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo actualizar tu foto de perfil. Intenta de nuevo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _subiendoFoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ClodAppBar(titulo: 'Mis datos personales'),
      drawer: const ClodDrawer(),
      body: SafeArea(
        child: _cargando
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    CLODColors.azulCLOD,
                  ),
                ),
              )
            : _errorMensaje != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: CLODErrorText(_errorMensaje!),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    Center(
                      child: _AvatarPerfil(
                        fotoUrl: _fotoPerfilUrl,
                        subiendo: _subiendoFoto,
                        onTap: _elegirFuenteFoto,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _nombre,
                      textAlign: TextAlign.center,
                      style: CLODTextStyles.headingMedium.copyWith(
                        color: CLODColors.texto(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Licenciatario'
                      '${_claseNombre != null ? ' · $_claseNombre' : ''}',
                      textAlign: TextAlign.center,
                      style: CLODTextStyles.bodyMedium.copyWith(
                        color: CLODColors.texto(context).withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _AvatarPerfil extends StatelessWidget {
  const _AvatarPerfil({
    required this.fotoUrl,
    required this.subiendo,
    required this.onTap,
  });

  final String? fotoUrl;
  final bool subiendo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tieneFoto = fotoUrl != null && fotoUrl!.isNotEmpty;

    return GestureDetector(
      onTap: subiendo ? null : onTap,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: CLODColors.azulMarino,
            backgroundImage: tieneFoto ? NetworkImage(fotoUrl!) : null,
            child: tieneFoto
                ? null
                : Icon(
                    Icons.person,
                    size: 40,
                    color: CLODColors.texto(context),
                  ),
          ),
          if (subiendo)
            Positioned.fill(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: Colors.black.withValues(alpha: 0.4),
                child: const CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: CLODColors.azulCLOD,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
