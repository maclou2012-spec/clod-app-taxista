import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../services/secure_storage_service.dart';
import '../services/socket_service.dart';
import '../theme/clod_theme.dart';
import 'neumorphic_toggle.dart';

/// Menú lateral de TaxiCLOD — mismo componente (mismo look "vidrio
/// esmerilado") ya construido para clod_pasajero_app; esta app no tenía
/// ningún menú deslizable todavía (su único acceso a Historial/Referidos/
/// Configuración era el ícono de perfil en la esquina del Dashboard, y
/// PerfilScreen en sí no tenía ni botón de regreso). Carga su propio
/// nombre/foto para que cualquier pantalla pueda agregar este Drawer sin
/// duplicar la llamada a obtenerUsuarioActual().
class ClodDrawer extends StatefulWidget {
  const ClodDrawer({super.key});

  @override
  State<ClodDrawer> createState() => _ClodDrawerState();
}

class _ClodDrawerState extends State<ClodDrawer> {
  final ApiService _apiService = ApiService();
  String _nombre = '';
  String? _fotoPerfilUrl;

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  Future<void> _cargarPerfil() async {
    try {
      final resultado = await _apiService.obtenerUsuarioActual();
      final usuario = resultado['usuario'] as Map<String, dynamic>?;
      if (!mounted) return;
      setState(() {
        _nombre = usuario?['nombre'] as String? ?? '';
        _fotoPerfilUrl = usuario?['foto_perfil_url'] as String?;
      });
    } catch (e) {
      // Sin datos de perfil por ahora; el drawer muestra un nombre genérico.
    }
  }

  Future<void> _cerrarSesion(BuildContext context) async {
    await SecureStorageService().borrarTokens();
    SocketService().desconectar();
    if (context.mounted) {
      context.go('/telefono');
    }
  }

  @override
  Widget build(BuildContext context) {
    final fotoPerfilUrl = _fotoPerfilUrl;
    final tieneFoto = fotoPerfilUrl != null && fotoPerfilUrl.isNotEmpty;
    final oscuro = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: oscuro ? 0.4 : 0.15),
              blurRadius: 16,
              offset: const Offset(4, 0),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: CLODColors.fondoPantalla(
                  context,
                ).withValues(alpha: oscuro ? 0.68 : 0.55),
                border: Border(
                  right: BorderSide(
                    width: 1,
                    color: Colors.white.withValues(alpha: oscuro ? 0.12 : 0.35),
                  ),
                ),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Image.asset(
                                  'assets/images/icono.png',
                                  height: 40,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'CLOD',
                                  style: CLODTextStyles.headingSmall.copyWith(
                                    color: CLODColors.texto(context),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor: CLODColors.azulMarino,
                                  backgroundImage: tieneFoto
                                      ? NetworkImage(fotoPerfilUrl)
                                      : null,
                                  child: tieneFoto
                                      ? null
                                      : const FaIcon(
                                          FontAwesomeIcons.solidUser,
                                          size: 22,
                                          color: Colors.white,
                                        ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    _nombre.isEmpty ? 'Taxista CLOD' : _nombre,
                                    style: CLODTextStyles.headingSmall.copyWith(
                                      color: CLODColors.texto(context),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Divider(color: CLODColors.borde(context), height: 1),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          children: [
                            _ItemMenu(
                              icono: FontAwesomeIcons.gaugeHigh,
                              titulo: 'Panel',
                              onTap: () {
                                Navigator.of(context).pop();
                                context.go('/dashboard');
                              },
                            ),
                            _ItemMenu(
                              icono: FontAwesomeIcons.clockRotateLeft,
                              titulo: 'Historial de viajes',
                              onTap: () {
                                Navigator.of(context).pop();
                                context.push('/historial');
                              },
                            ),
                            _ItemMenu(
                              icono: FontAwesomeIcons.gift,
                              titulo: 'Mis referidos',
                              onTap: () {
                                Navigator.of(context).pop();
                                context.push('/referidos');
                              },
                            ),
                            _SubmenuExpandible(
                              icono: FontAwesomeIcons.circleUser,
                              titulo: 'Mi cuenta',
                              hijos: [
                                _ItemSubmenu(
                                  icono: FontAwesomeIcons.idCard,
                                  titulo: 'Mi perfil',
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    context.push('/perfil');
                                  },
                                ),
                                _FilaModoOscuroSubmenu(),
                                _ItemSubmenu(
                                  icono: FontAwesomeIcons.gear,
                                  titulo: 'Configuración',
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    context.push('/configuracion');
                                  },
                                ),
                                _ItemSubmenu(
                                  icono: FontAwesomeIcons.rightFromBracket,
                                  titulo: 'Cerrar sesión',
                                  colorTexto: CLODColors.rojoUbicacion,
                                  onTap: () => _cerrarSesion(context),
                                ),
                              ],
                            ),
                            _ItemMenu(
                              icono: FontAwesomeIcons.circleQuestion,
                              titulo: 'Ayuda y soporte',
                              onTap: () {
                                Navigator.of(context).pop();
                                context.push('/ayuda');
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemMenu extends StatelessWidget {
  const _ItemMenu({
    required this.icono,
    required this.titulo,
    required this.onTap,
  });

  final FaIconData icono;
  final String titulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: Colors.transparent,
      selectedTileColor: Colors.transparent,
      leading: FaIcon(icono, size: 18, color: CLODColors.azulCLOD),
      title: Text(
        titulo,
        style: CLODTextStyles.bodyLarge.copyWith(
          color: CLODColors.texto(context),
        ),
      ),
      onTap: onTap,
    );
  }
}

class _SubmenuExpandible extends StatelessWidget {
  const _SubmenuExpandible({
    required this.icono,
    required this.titulo,
    required this.hijos,
  });

  final FaIconData icono;
  final String titulo;
  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: FaIcon(icono, size: 18, color: CLODColors.azulCLOD),
        title: Text(
          titulo,
          style: CLODTextStyles.bodyLarge.copyWith(
            color: CLODColors.texto(context),
          ),
        ),
        iconColor: CLODColors.azulCLOD,
        collapsedIconColor: CLODColors.texto(context).withValues(alpha: 0.5),
        childrenPadding: EdgeInsets.zero,
        backgroundColor: CLODColors.azulCLOD.withValues(alpha: 0.08),
        collapsedBackgroundColor: Colors.transparent,
        children: hijos,
      ),
    );
  }
}

class _ItemSubmenu extends StatelessWidget {
  const _ItemSubmenu({
    required this.icono,
    required this.titulo,
    required this.onTap,
    this.colorTexto,
  });

  final FaIconData icono;
  final String titulo;
  final VoidCallback onTap;
  final Color? colorTexto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: ListTile(
        tileColor: Colors.transparent,
        selectedTileColor: Colors.transparent,
        leading: FaIcon(
          icono,
          size: 16,
          color: colorTexto ?? CLODColors.azulCLOD,
        ),
        title: Text(
          titulo,
          style: CLODTextStyles.bodyMedium.copyWith(
            color: colorTexto ?? CLODColors.texto(context),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _FilaModoOscuroSubmenu extends StatelessWidget {
  const _FilaModoOscuroSubmenu();

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final activo = themeProvider.modo == ThemeMode.dark;

    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: ListTile(
        tileColor: Colors.transparent,
        selectedTileColor: Colors.transparent,
        leading: FaIcon(
          FontAwesomeIcons.moon,
          size: 16,
          color: CLODColors.azulCLOD,
        ),
        title: Text(
          'Modo oscuro',
          style: CLODTextStyles.bodyMedium.copyWith(
            color: CLODColors.texto(context),
          ),
        ),
        trailing: NeumorphicToggle(
          value: activo,
          onChanged: (_) => context.read<ThemeProvider>().alternar(),
        ),
      ),
    );
  }
}
