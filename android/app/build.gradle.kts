plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.ironvault.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.ironvault.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    applicationVariants.all {
        // This renames the Gradle artifact under:
        // build/app/outputs/apk/release/
        // Flutter also creates a separate normalized copy under:
        // build/app/outputs/flutter-apk/app-release.apk
        // That second copy is controlled by Flutter tooling, not Gradle,
        // so it cannot be renamed here.
        // For distribution, always use the Gradle artifact from outputs/apk/release/.
        outputs.all {
            val output = this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            val cleanVersionName = versionName?.substringBefore('+') ?: "unknown"
            output.outputFileName = "ironvault-v${cleanVersionName}.apk"
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
}
