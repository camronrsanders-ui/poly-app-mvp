val allowLocalReleaseSmokeCleartext =
    providers.environmentVariable("POLYCIRCLE_ANDROID_LOCAL_RELEASE_SMOKE")
        .orNull == "true"

plugins {
    id("com.android.application")

    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeystorePath =
    providers.environmentVariable("POLYCIRCLE_ANDROID_KEYSTORE_PATH")
        .orNull
        ?.takeIf { it.isNotBlank() }
val releaseKeystorePassword =
    providers.environmentVariable("POLYCIRCLE_ANDROID_KEYSTORE_PASSWORD")
        .orNull
        ?.takeIf { it.isNotBlank() }
val releaseKeyAlias =
    providers.environmentVariable("POLYCIRCLE_ANDROID_KEY_ALIAS")
        .orNull
        ?.takeIf { it.isNotBlank() }
val releaseKeyPassword =
    providers.environmentVariable("POLYCIRCLE_ANDROID_KEY_PASSWORD")
        .orNull
        ?.takeIf { it.isNotBlank() }

val releaseSigningValues = listOf(
    releaseKeystorePath,
    releaseKeystorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
)
val hasCompleteReleaseSigning = releaseSigningValues.all { it != null }

android {
    namespace = "com.polycircle.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        resValues = true
    }

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

    flavorDimensions += "environment"

    productFlavors {
        create("production") {
            dimension = "environment"
            resValue("string", "app_name", "Polycircle")
        }

        create("staging") {
            dimension = "environment"
            applicationIdSuffix = ".staging"
            versionNameSuffix = "-staging"
            resValue("string", "app_name", "Polycircle Staging")
        }
    }

    signingConfigs {
        if (hasCompleteReleaseSigning) {
            create("release") {
                storeFile = file(releaseKeystorePath!!)
                storePassword = releaseKeystorePassword!!
                keyAlias = releaseKeyAlias!!
                keyPassword = releaseKeyPassword!!
            }
        }
    }

    buildTypes {
        debug {
            manifestPlaceholders["polycircleUsesCleartextTraffic"] = "true"
        }

        release {
            manifestPlaceholders["polycircleUsesCleartextTraffic"] =
                allowLocalReleaseSmokeCleartext.toString()
            signingConfig = if (hasCompleteReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                null
            }
        }
    }
}

val verifyReleaseSigning by tasks.registering {
    group = "verification"
    description = "Require complete external signing before Android release builds."
    doLast {
        if (!hasCompleteReleaseSigning) {
            throw GradleException(
                "Android release signing is incomplete. Provide all of " +
                    "POLYCIRCLE_ANDROID_KEYSTORE_PATH, " +
                    "POLYCIRCLE_ANDROID_KEYSTORE_PASSWORD, " +
                    "POLYCIRCLE_ANDROID_KEY_ALIAS, and " +
                    "POLYCIRCLE_ANDROID_KEY_PASSWORD."
            )
        }

        val keystore = file(releaseKeystorePath!!)
        if (!keystore.isFile) {
            throw GradleException(
                "Android release keystore was not found at POLYCIRCLE_ANDROID_KEYSTORE_PATH."
            )
        }
    }
}

tasks.matching {
    it.name.startsWith("pre") &&
        it.name.endsWith("ReleaseBuild")
}.configureEach {
    dependsOn(verifyReleaseSigning)
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
