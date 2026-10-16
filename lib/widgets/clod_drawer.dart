import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/disponibilidad_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../services/secure_storage_service.dart';
import '../services/socket_service.dart';
import '../theme/clod_theme.dart';
import 'neumorphic_toggle.dart';

/// Menú lateral de TaxiCLOD — encabezado (toca para "Mis datos
/// personales") + switch de disponibilidad voluntaria (antes vivía en el
/// Dashboard) + "Mi cuenta" primero, expandible, con todo lo que antes
/// estaba repartido entre "Mi perfil" y "Configuración" (ambas pantallas ya
/// no existen — ver el reporte de la tarea para el mapeo completo).
class ClodDrawer extends StatefulWidget {
  const ClodDrawer({super.key, this.apiService});

  // Inyectable solo para pruebas de widgets (evita llamadas de red reales
  // sin timeout, que dejan un Timer pendiente al terminar el test) — en la
  // app real siempre se omite y se usa el singleton normal.
  final ApiService? apiService;

  @override
  State<ClodDrawer> createState() => _ClodDrawerState();
}

class _ClodDrawerState extends State<ClodDrawer> {
  late final ApiService _apiService = widget.apiService ?? ApiService();
  String _nombre = '';
  String? _fotoPerfilUrl;

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
    // Idempotente (ver DisponibilidadProvider.cargarEstadoInicial) — si
    // DashboardScreen ya lo pidió, esto no repite la llamada.
    context.read<DisponibilidadProvider>().cargarEstadoInicial();
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

  // Mismo gate de verificación facial y misma lógica de disponibilidad que
  // ya existía en DashboardScreen — solo que ahora el switch vive aquí, y
  // el cambio real de estado pasa por DisponibilidadProvider (compartido
  // con el indicador del panel).
  Future<void> _onToggleDisponibilidad(bool nuevoValor) async {
    final provider = context.read<DisponibilidadProvider>();
    if (!nuevoValor) {
      await _cambiarConManejoDeError(provider, false);
      return;
    }

    provider.establecerSinGuardar(true);
    final resultado = await context.push<bool>(
      '/verificacion-facial',
      extra: 'inicio_turno',
    );
    if (!mounted) return;

    if (resultado == true) {
      await _cambiarConManejoDeError(provider, true);
    } else {
      provider.establecerSinGuardar(false);
    }
  }

  void _irARenovarMembresia(BuildContext context) {
    Navigator.of(context).pop();
    context.push('/membresia');
  }

  Future<void> _cambiarConManejoDeError(
    DisponibilidadProvider provider,
    bool nuevoValor,
  ) async {
    try {
      await provider.cambiarDisponibilidad(nuevoValor);
    } on MembresiaNoVigenteException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.mensaje)));
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      final mensaje = data is Map<String, dynamic>
          ? data['mensaje'] as String?
          : null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensaje ?? 'No se pudo actualizar tu disponibilidad.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo actualizar tu disponibilidad.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fotoPerfilUrl = _fotoPerfilUrl;
    final tieneFoto = fotoPerfilUrl != null && fotoPerfilUrl.isNotEmpty;
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final disponibilidad = context.watch<DisponibilidadProvider>();

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
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                Navigator.of(context).pop();
                                context.push('/perfil');
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
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
                                        _nombre.isEmpty
                                            ? 'Taxista CLOD'
                                            : _nombre,
                                        style: CLODTextStyles.headingSmall
                                            .copyWith(
                                              color: CLODColors.texto(
                                                context,
                                              ),
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      color: CLODColors.texto(
                                        context,
                                      ).withValues(alpha: 0.4),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: CLODColors.fondoTarjeta(context),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: CLODColors.borde(context),
                            ),
                          ),
                          // SwitchListTile pinta su propio fondo/ripple en
                          // el Material ancestro más cercano — sin este
                          // Material aparte, el Container de arriba (que SÍ
                          // tiene su propio color) lo tapa y el framework
                          // avisa que el ripple queda invisible.
                          child: Material(
                            type: MaterialType.transparency,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  value: disponibilidad.disponible,
                                  onChanged:
                                      disponibilidad.cargando ||
                                          !disponibilidad.membresiaVigente
                                      ? null
                                      : _onToggleDisponibilidad,
                                  activeTrackColor: CLODColors.azulCLOD,
                                  title: Text(
                                    'Disponibilidad voluntaria',
                                    style: CLODTextStyles.bodyMedium.copyWith(
                                      color: CLODColors.texto(context),
                                    ),
                                  ),
                                  subtitle: Text(
                                    !disponibilidad.membresiaVigente
                                        ? 'Membresía no vigente'
                                        : disponibilidad.disponible
                                        ? 'Conectado'
                                        : 'Desconectado',
                                    style: CLODTextStyles.bodySmall.copyWith(
                                      color: CLODColors.texto(
                                        context,
                                      ).withValues(alpha: 0.6),
                                    ),
                                  ),
                                ),
                                if (!disponibilidad.membresiaVigente)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 10,
                                    ),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: () => _irARenovarMembresia(
                                          context,
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              CLODColors.azulCLOD,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text(
                                          'Renovar membresía',
                                        ),
                                      ),
                                    ),
                                  )
                                else if (disponibilidad
                                        .mensajeVencimientoProximo !=
                                    null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 10,
                                    ),
                                    child: Text(
                                      disponibilidad.mensajeVencimientoProximo!,
                                      style: CLODTextStyles.bodySmall
                                          .copyWith(
                                            color: CLODColors.texto(
                                              context,
                                            ).withValues(alpha: 0.7),
                                          ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Divider(color: CLODColors.borde(context), height: 1),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          children: [
                            _SubmenuExpandible(
                              icono: FontAwesomeIcons.circleUser,
                              titulo: 'Mi cuenta',
                              hijos: [
                                _ItemSubmenu(
                                  icono: FontAwesomeIcons.car,
                                  titulo: 'Mi vehículo',
                                  onTap: () => _irAMiVehiculo(context),
                                ),
                                _ItemSubmenu(
                                  icono: FontAwesomeIcons.tag,
                                  titulo: 'Mi tarifa',
                                  onTap: () => _irAMiTarifa(context),
                                ),
                                _ItemSubmenu(
                                  icono: FontAwesomeIcons.fileLines,
                                  titulo: 'Mis documentos',
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    context.push('/mis-documentos');
                                  },
                                ),
                                _ItemSubmenu(
                                  icono: FontAwesomeIcons.receipt,
                                  titulo: 'Mis pagos y facturas',
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    context.push('/mis-pagos');
                                  },
                                ),
                                _ItemSubmenu(
                                  icono: FontAwesomeIcons.phone,
                                  titulo: 'Contacto de emergencia',
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    context.push('/contacto-emergencia');
                                  },
                                ),
                                _ItemSubmenu(
                                  icono: FontAwesomeIcons.fileContract,
                                  titulo: 'Contrato de licenciatario',
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    context.push('/contrato', extra: true);
                                  },
                                ),
                                _FilaModoOscuroSubmenu(),
                                _ItemSubmenu(
                                  icono: FontAwesomeIcons.rightFromBracket,
                                  titulo: 'Cerrar sesión',
                                  colorTexto: CLODColors.rojoUbicacion,
                                  onTap: () => _cerrarSesion(context),
                                ),
                              ],
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
                            _ItemMenu(
                              icono: FontAwesomeIcons.gaugeHigh,
                              titulo: 'Panel',
                              onTap: () {
                                Navigator.of(context).pop();
                                context.go('/dashboard');
                              },
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

  // "Mi vehículo"/"Mi tarifa" necesitan los datos actuales como extra para
  // que VehiculoScreen/TarifaScreen entren en modo edición (si no, se
  // comportan como si fueran parte del registro inicial) — antes
  // PerfilScreen los precargaba de una vez al entrar; ahora se piden justo
  // al tocar cada uno, para no cargar ambos de más en cada apertura del
  // drawer.
  Future<void> _irAMiVehiculo(BuildContext context) async {
    Navigator.of(context).pop();
    Map<String, dynamic>? vehiculo;
    try {
      vehiculo = await _apiService.obtenerVehiculo();
    } catch (e) {
      // VehiculoScreen puede quedarse con el formulario en blanco si esto
      // falla — no bloquea la navegación.
    }
    if (context.mounted) context.push('/vehiculo', extra: vehiculo);
  }

  Future<void> _irAMiTarifa(BuildContext context) async {
    Navigator.of(context).pop();
    Map<String, dynamic>? taxista;
    try {
      final resultado = await _apiService.obtenerMiPerfilTaxista();
      taxista = resultado['taxista'] as Map<String, dynamic>?;
    } catch (e) {
      // TarifaScreen puede quedarse con el formulario en blanco si esto
      // falla — no bloquea la navegación.
    }
    if (context.mounted) context.push('/tarifa', extra: taxista);
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
        initiallyExpanded: true,
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
