val allowLocalReleaseSmokeCleartext =
    providers.environmentVariable("POLYCIRCLE_ANDROID_LOCAL_RELEASE_SMOKE")
        .orNull == "true"

plugins {
    id("com.android.application")

    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.polycircle.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Permanent Polycircle Android application ID.
        applicationId = "com.polycircle.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Production stays cleartext-disabled. Local optimized Android smoke
        // builds may explicitly enable emulator networking from the host shell.
        manifestPlaceholders["polycircleUsesCleartextTraffic"] = "false"
    }

    buildTypes {
        debug {
            manifestPlaceholders["polycircleUsesCleartextTraffic"] = "true"
        }

        release {
            manifestPlaceholders["polycircleUsesCleartextTraffic"] =
                allowLocalReleaseSmokeCleartext.toString()
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Google Play's privacy-preserving age-range API. This complements, but
    // does not replace, the Play Console Restrict Minor Access requirement for
    // an adult-only dating/matchmaking app.
    implementation("com.google.android.play:age-signals:0.0.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
