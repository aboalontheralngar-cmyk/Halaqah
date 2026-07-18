import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    FileInputStream(keystorePropertiesFile).use { input ->
        keystoreProperties.load(input)
    }
}

val requireReleaseSigning =
    System.getenv("HALAQAH_REQUIRE_RELEASE_SIGNING")?.equals("true", ignoreCase = true) == true
val requestedApplicationId = System.getenv("HALAQAH_APPLICATION_ID")
    ?.trim()
    ?.takeIf { it.isNotEmpty() }

if (requireReleaseSigning && !hasReleaseSigning) {
    throw GradleException(
        "Production signing is required, but android/key.properties is missing."
    )
}
if (requireReleaseSigning &&
    (requestedApplicationId == null || requestedApplicationId.startsWith("com.example"))) {
    throw GradleException(
        "Production builds require a permanent HALAQAH_APPLICATION_ID outside com.example."
    )
}

android {
    namespace = "com.example.halaqah_teacher"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Keep the installed development identity until the permanent store ID
        // is chosen. Production CI must supply HALAQAH_APPLICATION_ID.
        applicationId = requestedApplicationId ?: "com.example.halaqah_teacher"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Android 6.0+ is required by the secure key storage used to protect
        // encrypted Halaqah backup passphrases.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // A debug-signed release remains available for staged device tests.
            // Production CI sets HALAQAH_REQUIRE_RELEASE_SIGNING=true and cannot
            // continue without the private keystore and permanent application ID.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
