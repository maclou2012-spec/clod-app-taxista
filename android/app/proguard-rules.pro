# flutter_stripe empaqueta una referencia opcional al módulo de
# "push provisioning" (emitir tarjetas a Google Pay) de
# react-native-stripe-sdk, que esta app nunca usa — las clases reales no
# están presentes y R8 (en modo estricto, con minifyEnabled activado por
# defecto en builds release recientes de Flutter) lo trata como error en
# vez de advertencia. Reglas tal cual las sugiere
# build/app/outputs/mapping/release/missing_rules.txt tras el primer
# intento de build fallido.
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivity$g
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Args
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Error
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider
