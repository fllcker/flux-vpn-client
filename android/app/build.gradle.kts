import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// android/key.properties — gitignored (see android/.gitignore), holds the
// upload keystore's passwords/alias. Missing on a fresh checkout/CI without
// it copied in separately; falls back to debug signing rather than failing
// the build outright.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
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

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Falls back to the debug key when key.properties isn't present
            // (fresh checkout/CI without the keystore copied in) so
            // `flutter build apk --release` still works, just unsigned for
            // real distribution.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
    implementation("androidx.core:core-ktx:1.13.1")
}
