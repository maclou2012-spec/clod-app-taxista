import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../routes/app_router.dart';
import '../../services/api_service.dart';
import '../../theme/clod_theme.dart';
import '../../widgets/clod_error_text.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> with RouteAware {
  final ApiService _apiService = ApiService();
  final ImagePicker _imagePicker = ImagePicker();

  bool _cargando = true;
  String? _errorMensaje;
  String _nombre = '';
  String? _claseNombre;
  String? _fotoPerfilUrl;
  bool _subiendoFoto = false;
  Map<String, dynamic>? _taxista;
  Map<String, dynamic>? _vehiculo;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  // Se vuelve a cargar el vehículo/taxista al regresar de "Mi vehículo" para
  // que número de taxi, foto y demás cambios recién guardados no se vean
  // como si no hubieran quedado, aunque _cargando ya no muestre el spinner.
  @override
  void didPopNext() {
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final resultados = await Future.wait<dynamic>([
        _apiService.obtenerUsuarioActual(),
        _apiService.obtenerMiPerfilTaxista(),
        _apiService.obtenerClasesServicio(),
        _apiService.obtenerVehiculo(),
      ]);

      final usuario = (resultados[0] as Map<String, dynamic>)['usuario']
          as Map<String, dynamic>?;
      final taxista = (resultados[1] as Map<String, dynamic>)['taxista']
          as Map<String, dynamic>?;
      final clases = (resultados[2] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final vehiculo = resultados[3] as Map<String, dynamic>?;

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
          _taxista = taxista;
          _vehiculo = vehiculo;
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
      backgroundColor: Colors.white,
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
                  color: CLODColors.carbon,
                ),
              ),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: CLODColors.azulCLOD),
              title: Text(
                'Elegir de galería',
                style: CLODTextStyles.bodyLarge.copyWith(
                  color: CLODColors.carbon,
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
      backgroundColor: CLODColors.grisClaro,
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
                            color: CLODColors.carbon,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Licenciatario'
                          '${_claseNombre != null ? ' · $_claseNombre' : ''}',
                          textAlign: TextAlign.center,
                          style: CLODTextStyles.bodyMedium.copyWith(
                            color: CLODColors.carbon.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 32),
                        _FilaAcceso(
                          icono: Icons.directions_car,
                          titulo: 'Mi vehículo',
                          onTap: () => context.push(
                            '/vehiculo',
                            extra: _vehiculo,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _FilaAcceso(
                          icono: Icons.attach_money,
                          titulo: 'Mi tarifa',
                          onTap: () => context.push(
                            '/tarifa',
                            extra: _taxista,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _FilaAcceso(
                          icono: Icons.description,
                          titulo: 'Mis documentos',
                          onTap: () => context.push('/revision'),
                        ),
                        const SizedBox(height: 12),
                        _FilaAcceso(
                          icono: Icons.history,
                          titulo: 'Historial de viajes',
                          onTap: () => context.push('/historial'),
                        ),
                        const SizedBox(height: 12),
                        _FilaAcceso(
                          icono: Icons.card_giftcard,
                          titulo: 'Mis referidos',
                          onTap: () => context.push('/referidos'),
                        ),
                        const SizedBox(height: 12),
                        _FilaAcceso(
                          icono: Icons.settings,
                          titulo: 'Configuración',
                          onTap: () => context.push('/configuracion'),
                        ),
                        const SizedBox(height: 12),
                        _FilaAcceso(
                          icono: Icons.help_outline,
                          titulo: 'Ayuda y soporte',
                          onTap: () => context.push('/ayuda'),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _FilaAcceso extends StatelessWidget {
  const _FilaAcceso({
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
                : const Icon(
                    Icons.person,
                    size: 40,
                    color: CLODColors.grisClaro,
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
