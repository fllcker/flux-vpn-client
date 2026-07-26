plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "rip.freeinternet.flux"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "rip.freeinternet.flux"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // libv2ray.aar (tool/android-xray-lite) was built with -androidapi 24 —
        // must not go below that.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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

// libv2ray.aar — xray-core built for Android via gomobile bind, see
// tool/android-xray-lite/README.md for how to (re)produce it. Not fetched
// automatically like the Windows binaries (scripts/fetch_xray.ps1) yet —
// gomobile builds take too long to do on every CI run, revisit once Android
// CI exists.
repositories {
    flatDir { dirs("libs") }
}

dependencies {
    implementation(":libv2ray@aar")
}
