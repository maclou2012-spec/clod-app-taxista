import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val secretsPropertiesFile = rootProject.file("secrets.properties")
val secretsProperties = Properties()
if (secretsPropertiesFile.exists()) {
    secretsProperties.load(FileInputStream(secretsPropertiesFile))
}

// key.properties (y el .jks que apunta) viven FUERA del repo / están en
// .gitignore — ver android/.gitignore. Sin ese archivo (ej. un clon nuevo
// del repo sin la keystore), el build release cae de vuelta a la firma
// debug en vez de fallar, igual que antes de este cambio.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hayKeystoreConfigurada = keystorePropertiesFile.exists()
if (hayKeystoreConfigurada) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.clod.taxiclod"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.clod.taxiclod"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders["mapsApiKey"] = secretsProperties.getProperty("MAPS_API_KEY", "")
    }

    lint {
        // El lint "vital" que corre como parte de assembleRelease intenta
        // resolver com.google.android.gms:play-services-tapandpay (una
        // dependencia opcional de stripe_android para "push provisioning"
        // de Google Pay, que esta app no usa) y esa versión no está
        // publicada en ningún repo configurado — rompe la resolución de
        // dependencias antes de analizar una sola línea de código, no por
        // un hallazgo de lint real.
        checkReleaseBuilds = false
    }

    signingConfigs {
        if (hayKeystoreConfigurada) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Sin key.properties (ej. checkout nuevo sin la keystore local),
            // cae a la firma debug — igual que antes de este cambio — en vez
            // de que el build entero falle.
            signingConfig = if (hayKeystoreConfigurada) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // El template reciente de Flutter ya activa minifyEnabled/
            // shrinkResources por defecto en release (no hay que ponerlo
            // explícito aquí) — el primer intento de build falló porque R8
            // trataba como error una referencia opcional de flutter_stripe a
            // clases de "push provisioning" (emitir tarjetas a Google Pay)
            // que esta app nunca usa. Las reglas en proguard-rules.pro (las
            // mismas que sugirió el propio R8 en missing_rules.txt) lo
            // resuelven sin apagar R8.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
