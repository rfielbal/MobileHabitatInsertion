import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

fun releaseSigningProperty(name: String): String? {
    return (keystoreProperties.getProperty(name) ?: providers.environmentVariable("WHEELLO_${name.uppercase()}").orNull)
        ?.trim()
        ?.takeIf { it.isNotEmpty() }
}

android {
    namespace = "com.example.mobile_habitat_insertion"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.mobile_habitat_insertion"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            val releaseStoreFile = releaseSigningProperty("storeFile")
            if (releaseStoreFile != null) {
                storeFile = rootProject.file(releaseStoreFile)
            }
            storePassword = releaseSigningProperty("storePassword")
            keyAlias = releaseSigningProperty("keyAlias")
            keyPassword = releaseSigningProperty("keyPassword")
        }
    }

    buildTypes {
        release {
            val releaseSigning = signingConfigs.getByName("release")
            val releaseStoreFile = releaseSigning.storeFile
            if (releaseStoreFile == null ||
                !releaseStoreFile.exists() ||
                releaseSigning.storePassword.isNullOrBlank() ||
                releaseSigning.keyAlias.isNullOrBlank() ||
                releaseSigning.keyPassword.isNullOrBlank()
            ) {
                throw GradleException(
                    "Configuration de signature release manquante. " +
                        "Créez android/key.properties à partir de android/key.properties.example " +
                        "et utilisez toujours la même clé pour les APK Wheello."
                )
            }
            signingConfig = releaseSigning
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
