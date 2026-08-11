import java.util.Properties
import java.io.FileInputStream

val secretsPropertiesFile = rootProject.file("secrets.properties")
val secretsProperties = Properties()
if (secretsPropertiesFile.exists()) {
    secretsProperties.load(FileInputStream(secretsPropertiesFile))
}

// El SDK nativo de Mapbox (descargado por el plugin mapbox_maps_flutter) lee
// el token de descarga vía la propiedad de Gradle "SDK_REGISTRY_TOKEN"
// (project.findProperty), no una variable con nombre propio — hay que
// inyectarla en cada proyecto, incluido el subproyecto del plugin, antes de
// que su build.gradle se evalúe.
gradle.beforeProject {
    extra.set(
        "SDK_REGISTRY_TOKEN",
        secretsProperties.getProperty("MAPBOX_DOWNLOADS_TOKEN", ""),
    )

    // mapbox_maps_flutter (módulo "library") llama al DSL kotlin { } en su
    // propio build.gradle asumiendo que AGP 9 lo provee automáticamente,
    // pero el Kotlin integrado de AGP 9 solo aplica a módulos "application"
    // — sin esto, la evaluación de su build.gradle falla con
    // "Could not find method kotlin()".
    if (name == "mapbox_maps_flutter") {
        apply(plugin = "org.jetbrains.kotlin.android")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
