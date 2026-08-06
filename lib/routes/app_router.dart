import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/onboarding/otp_verification_screen.dart';
import '../screens/onboarding/phone_entry_screen.dart';
import '../screens/onboarding/registro_basico_screen.dart';
import '../screens/onboarding/splash_screen.dart';
import '../screens/registro/contrato_screen.dart';
import '../screens/registro/datos_personales_screen.dart';
import '../screens/registro/vehiculo_screen.dart';
import '../screens/registro/verificacion_facial_screen.dart';
import '../theme/clod_theme.dart';

class HomeTemporalScreen extends StatelessWidget {
  const HomeTemporalScreen({
    super.key,
    this.mensaje = 'Próxima pantalla en construcción',
  });

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CLODColors.carbon,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: CLODTextStyles.bodyLarge,
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => context.go('/contrato'),
              child: Text(
                '[DEV] Ir a Contrato de licenciatario',
                style: CLODTextStyles.bodySmall.copyWith(
                  color: CLODColors.azulCLOD,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/telefono',
      builder: (context, state) => const PhoneEntryScreen(),
    ),
    GoRoute(
      path: '/otp',
      builder: (context, state) {
        final telefono = state.extra as String? ?? '';
        return OtpVerificationScreen(telefono: telefono);
      },
    ),
    GoRoute(
      path: '/registro-basico',
      builder: (context, state) => const RegistroBasicoScreen(),
    ),
    GoRoute(
      path: '/contrato',
      builder: (context, state) => const ContratoScreen(),
    ),
    GoRoute(
      path: '/registro-basico-taxista',
      builder: (context, state) => const DatosPersonalesScreen(),
    ),
    GoRoute(
      path: '/identificacion-oficial',
      builder: (context, state) => const HomeTemporalScreen(
        mensaje: 'Próxima pantalla: identificación oficial',
      ),
    ),
    GoRoute(
      path: '/verificacion-facial',
      builder: (context, state) {
        final tipo = state.extra as String? ?? 'onboarding';
        return VerificacionFacialScreen(tipo: tipo);
      },
    ),
    GoRoute(
      path: '/vehiculo',
      builder: (context, state) => const VehiculoScreen(),
    ),
    GoRoute(
      path: '/servicio',
      builder: (context, state) => const HomeTemporalScreen(
        mensaje: 'Próxima pantalla: clase y plus del servicio',
      ),
    ),
    GoRoute(
      path: '/home-temporal',
      builder: (context, state) => const HomeTemporalScreen(
        mensaje: 'Próxima pantalla: dashboard',
      ),
    ),
  ],
);
