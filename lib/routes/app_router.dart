import 'package:go_router/go_router.dart';

import '../models/viaje_en_curso_args.dart';
import '../screens/cuenta/configuracion_screen.dart';
import '../screens/cuenta/contacto_emergencia_screen.dart';
import '../screens/cuenta/historial_screen.dart';
import '../screens/cuenta/perfil_screen.dart';
import '../screens/cuenta/referidos_screen.dart';
import '../screens/onboarding/otp_verification_screen.dart';
import '../screens/onboarding/phone_entry_screen.dart';
import '../screens/onboarding/registro_basico_screen.dart';
import '../screens/onboarding/splash_screen.dart';
import '../screens/membresia/membresia_activa_screen.dart';
import '../screens/membresia/seleccion_membresia_screen.dart';
import '../screens/operacion/dashboard_screen.dart';
import '../screens/operacion/resumen_viaje_screen.dart';
import '../screens/operacion/viaje_en_curso_screen.dart';
import '../screens/registro/contrato_screen.dart';
import '../screens/registro/datos_personales_screen.dart';
import '../screens/registro/en_revision_screen.dart';
import '../screens/registro/identificacion_oficial_screen.dart';
import '../screens/registro/licencia_screen.dart';
import '../screens/registro/seguro_screen.dart';
import '../screens/registro/servicio_screen.dart';
import '../screens/registro/tarifa_screen.dart';
import '../screens/registro/vehiculo_screen.dart';
import '../screens/registro/verificacion_facial_screen.dart';
import '../screens/test_maps_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
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
      builder: (context, state) =>
          ContratoScreen(soloLectura: state.extra == true),
    ),
    GoRoute(
      path: '/registro-basico-taxista',
      builder: (context, state) => const DatosPersonalesScreen(),
    ),
    GoRoute(
      path: '/identificacion-oficial',
      builder: (context, state) => const IdentificacionOficialScreen(),
    ),
    GoRoute(
      path: '/licencia',
      builder: (context, state) => const LicenciaScreen(),
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
      builder: (context, state) => VehiculoScreen(
        datosIniciales: state.extra as Map<String, dynamic>?,
      ),
    ),
    GoRoute(
      path: '/servicio',
      builder: (context, state) => const ServicioScreen(),
    ),
    GoRoute(
      path: '/tarifa',
      builder: (context, state) => TarifaScreen(
        datosIniciales: state.extra as Map<String, dynamic>?,
      ),
    ),
    GoRoute(path: '/seguro', builder: (context, state) => const SeguroScreen()),
    GoRoute(
      path: '/revision',
      builder: (context, state) => const EnRevisionScreen(),
    ),
    GoRoute(
      path: '/perfil',
      builder: (context, state) => const PerfilScreen(),
    ),
    GoRoute(
      path: '/historial',
      builder: (context, state) => const HistorialScreen(),
    ),
    GoRoute(
      path: '/referidos',
      builder: (context, state) => const ReferidosScreen(),
    ),
    GoRoute(
      path: '/configuracion',
      builder: (context, state) => const ConfiguracionScreen(),
    ),
    GoRoute(
      path: '/configuracion/contacto-emergencia',
      builder: (context, state) => const ContactoEmergenciaScreen(),
    ),
    GoRoute(
      path: '/membresia',
      builder: (context, state) => const SeleccionMembresiaScreen(),
    ),
    GoRoute(
      path: '/membresia-activa',
      builder: (context, state) => const MembresiaActivaScreen(),
    ),
    GoRoute(
      path: '/test-maps',
      builder: (context, state) => const TestMapsScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/viaje-en-curso',
      builder: (context, state) =>
          ViajeEnCursoScreen(args: state.extra as ViajeEnCursoArgs),
    ),
    GoRoute(
      path: '/resumen-viaje',
      builder: (context, state) =>
          ResumenViajeScreen(args: state.extra as ViajeEnCursoArgs),
    ),
  ],
);
