import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';

import 'config/mapbox_config.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'routes/app_router.dart';
import 'theme/clod_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  MapboxOptions.setAccessToken(mapboxPublicToken);

  Stripe.publishableKey =
      'pk_test_51QWS2W08H3cXOv0qK2RLNVr2Sb6RQ1o5ifUD8RTXiipQYjqvDBe1zLidwWtIiAgZkCFff2DrSZjkpALSy2BF0NZC00op9M30Gb';
  await Stripe.instance.applySettings();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthProvider>(
      create: (_) => AuthProvider(),
      child: MaterialApp.router(
        title: 'TaxiCLOD',
        theme: CLODTheme.dark,
        routerConfig: appRouter,
      ),
    );
  }
}
