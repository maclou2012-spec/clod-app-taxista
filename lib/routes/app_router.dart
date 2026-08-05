import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/onboarding/phone_entry_screen.dart';
import '../screens/onboarding/splash_screen.dart';
import '../theme/clod_theme.dart';

class HomeTemporalScreen extends StatelessWidget {
  const HomeTemporalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CLODColors.carbon,
      body: Center(
        child: Text(
          'Próxima pantalla: verificación de código OTP',
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
      builder: (context, state) => const HomeTemporalScreen(),
    ),
  ],
);
