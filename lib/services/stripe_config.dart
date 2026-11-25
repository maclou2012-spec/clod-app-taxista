import 'package:flutter_stripe/flutter_stripe.dart';

import 'config_app_service.dart';

String? _llaveAplicada;

/// Deja Stripe listo con la llave publicable del modo vigente, que da
/// GET /api/publico/config-app (nunca fija en el código: cambia cuando CLOD
/// pasa a producción). Devuelve false si el servidor no da llave: entonces no
/// se ofrece pago con tarjeta.
Future<bool> prepararStripe() async {
  final servicio = ConfigAppService();
  if (servicio.config.value?.stripePublishableKey == null) {
    await servicio.refrescar();
  }
  final llave = servicio.config.value?.stripePublishableKey;
  if (llave == null) return false;
  if (_llaveAplicada != llave) {
    Stripe.publishableKey = llave;
    await Stripe.instance.applySettings();
    _llaveAplicada = llave;
  }
  return true;
}
