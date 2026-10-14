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
            // minifyEnabled/shrinkResources quedan DESACTIVADOS a propósito
            // para este primer release: activar R8 sin antes probar y
            // agregar las reglas ProGuard necesarias para Mapbox/Firebase/
            // Stripe/geolocator puede romper el build o la app en tiempo de
            // ejecución de forma silenciosa — queda pendiente para una
            // siguiente iteración, ya probada.
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
