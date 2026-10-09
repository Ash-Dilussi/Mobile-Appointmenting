import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val dormantCallIntegrationEnabled =
    providers.gradleProperty("booklyDormantCallIntegration")
        .orNull
        ?.toBooleanStrictOrNull()
        ?: false

val releaseSigningProperties = Properties()
val releaseSigningFile = rootProject.file("key.properties")
if (releaseSigningFile.exists()) {
    FileInputStream(releaseSigningFile).use(releaseSigningProperties::load)
}

fun releaseSigningValue(propertyName: String, environmentName: String): String? =
    releaseSigningProperties.getProperty(propertyName)?.takeIf { it.isNotBlank() }
        ?: System.getenv(environmentName)?.takeIf { it.isNotBlank() }

val releaseStoreFilePath = releaseSigningValue("storeFile", "BOOKLY_ANDROID_STORE_FILE")
val releaseStorePassword = releaseSigningValue("storePassword", "BOOKLY_ANDROID_STORE_PASSWORD")
val releaseKeyAlias = releaseSigningValue("keyAlias", "BOOKLY_ANDROID_KEY_ALIAS")
val releaseKeyPassword = releaseSigningValue("keyPassword", "BOOKLY_ANDROID_KEY_PASSWORD")
val releaseTaskRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
val releaseSigningConfigured = listOf(
    releaseStoreFilePath,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { !it.isNullOrBlank() }

if (releaseTaskRequested && !releaseSigningConfigured) {
    throw GradleException(
        "Bookly release signing is not configured. Copy android/key.properties.example " +
            "to android/key.properties and supply the production keystore values, or set " +
            "the BOOKLY_ANDROID_STORE_FILE, BOOKLY_ANDROID_STORE_PASSWORD, " +
            "BOOKLY_ANDROID_KEY_ALIAS, and BOOKLY_ANDROID_KEY_PASSWORD environment variables.",
    )
}

if (releaseTaskRequested && !rootProject.file(releaseStoreFilePath!!).isFile) {
    throw GradleException(
        "The configured Bookly release keystore does not exist: $releaseStoreFilePath",
    )
}

android {
    namespace = "com.ashDilussi.bookly"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        applicationId = "com.ashDilussi.bookly"
        minSdk = 24
        // Google Play requires phone/tablet submissions to target API 36 from
        // August 31, 2026. Keep this explicit so an older Flutter default
        // cannot silently produce a non-submittable bundle.
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        buildConfigField(
            "boolean",
            "DORMANT_CALL_INTEGRATION_ENABLED",
            dormantCallIntegrationEnabled.toString(),
        )

        // Enable all ABIs for sqlite3_flutter_libs compatibility
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
        }
    }

    signingConfigs {
        create("release") {
            if (releaseSigningConfigured) {
                storeFile = rootProject.file(releaseStoreFilePath!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // Never fall back to the debug key for a release artifact.
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
