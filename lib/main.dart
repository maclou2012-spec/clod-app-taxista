import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';

import 'config/mapbox_config.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/disponibilidad_provider.dart';
import 'providers/theme_provider.dart';
import 'routes/app_router.dart';
import 'services/config_app_service.dart';
import 'theme/clod_theme.dart';
import 'widgets/puerta_actualizacion.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  MapboxOptions.setAccessToken(mapboxPublicToken);

  // Llave de Stripe, versión mínima y modo. La llave se aplica al pagar
  // (services/stripe_config.dart), nunca fija en el código.
  await ConfigAppService().inicializar();

  final themeProvider = ThemeProvider();
  await themeProvider.cargarPreferencia();

  runApp(MyApp(themeProvider: themeProvider));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.themeProvider});

  final ThemeProvider themeProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        // No se carga el estado inicial aquí (a diferencia de ThemeProvider)
        // porque en este punto todavía no hay sesión iniciada —
        // DashboardScreen llama a cargarEstadoInicial() una sola vez al
        // entrar, ya con el taxista autenticado.
        ChangeNotifierProvider<DisponibilidadProvider>(
          create: (_) => DisponibilidadProvider(),
        ),
      ],
      child: Builder(
        builder: (context) {
          return MaterialApp.router(
            title: 'TaxiCLOD',
            debugShowCheckedModeBanner: false,
            theme: CLODTheme.light,
            darkTheme: CLODTheme.dark,
            themeMode: context.watch<ThemeProvider>().modo,
            routerConfig: appRouter,
            builder: (context, child) =>
                PuertaActualizacion(child: child ?? const SizedBox.shrink()),
          );
        },
      ),
    );
  }
}
