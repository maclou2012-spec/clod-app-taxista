import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/onboarding/otp_verification_screen.dart';
import '../screens/onboarding/phone_entry_screen.dart';
import '../screens/onboarding/registro_basico_screen.dart';
import '../screens/onboarding/splash_screen.dart';
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
        child: Text(
          mensaje,
          textAlign: TextAlign.center,
          style: CLODTextStyles.bodyLarge,
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
      path: '/home-temporal',
      builder: (context, state) => const HomeTemporalScreen(
        mensaje: 'Próxima pantalla: dashboard',
      ),
    ),
  ],
);
