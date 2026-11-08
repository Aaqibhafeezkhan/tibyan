pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
    // Embeds the R8 mapping UUID in release builds and uploads the mapping to GlitchTip
    // (only with SENTRY_AUTH_TOKEN). 6.22.0 bundles sentry-android 8.56.0, the same
    // version sentry_flutter 9.30.1 uses.
    id("io.sentry.android.gradle") version "6.22.0" apply false
}

include(":app")
include(":wear")
