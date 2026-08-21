package com.clod.taxiclod

import io.flutter.embedding.android.FlutterFragmentActivity

// flutter_stripe requiere FlutterFragmentActivity (no FlutterActivity) en
// Android, ya que la hoja de pago nativa de Stripe usa Fragments.
class MainActivity : FlutterFragmentActivity()
