import 'package:flutter/material.dart';

import '../theme/clod_theme.dart';

/// Barra superior compartida por las pantallas de contenido plano (no
/// flotando sobre un mapa) que necesitan acceso al menú lateral.
///
/// Un solo botón a la izquierda, comportamiento automático de AppBar: flecha
/// de regreso si la pantalla tiene algo a qué volver en la pila de
/// navegación, o el ícono de menú si no lo hay (ej. Dashboard, la raíz tras
/// iniciar sesión). No se agrega un botón de menú aparte en `actions` —eso
/// duplicaría el botón de la izquierda con uno idéntico a la derecha.
class ClodAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ClodAppBar({super.key, required this.titulo});

  final String titulo;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: CLODColors.fondoPantalla(context),
      iconTheme: IconThemeData(color: CLODColors.texto(context)),
      title: Text(
        titulo,
        style: CLODTextStyles.headingSmall.copyWith(
          color: CLODColors.texto(context),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
