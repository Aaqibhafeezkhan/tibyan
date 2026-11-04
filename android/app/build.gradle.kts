import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The upload key for Google Play, kept outside the repository
// (android/key.properties, ignored by git). Without it, release builds
// fall back to the debug key so `flutter run --release` still works.
val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

// The store this build is for, from `--dart-define=TIBYAN_STORE=huawei`
// (Flutter hands the dart-defines to Gradle base64-encoded). The Huawei
// AppGallery build has no Google Play services: the Wear OS bridge is left
// out (src/huawei instead of src/gms) and so is play-services-wearable
// (docs/HUAWEI.md). Any other value, or none, is the Play/GitHub build.
val tibyanStore: String = (project.findProperty("dart-defines") as String?)
    ?.split(",")
    ?.mapNotNull { runCatching { String(Base64.getDecoder().decode(it)) }.getOrNull() }
    ?.firstOrNull { it.startsWith("TIBYAN_STORE=") }
    ?.substringAfter("=")
    ?: "play"
val huaweiBuild = tibyanStore == "huawei"

android {
    namespace = "app.tibyan.tibyan"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications schedules with java.time on older
        // Android versions.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "app.tibyan.tibyan"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keyProperties.containsKey("storeFile")) {
            create("upload") {
                storeFile = file(keyProperties["storeFile"] as String)
                storePassword = keyProperties["storePassword"] as String
                keyAlias = keyProperties["keyAlias"] as String
                keyPassword = keyProperties["keyPassword"] as String
            }
        }
    }

    sourceSets["main"].java.srcDir(if (huaweiBuild) "src/huawei/kotlin" else "src/gms/kotlin")

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("upload")
                ?: signingConfigs.getByName("debug")
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // «الساعة»: the Wear OS app (android/wear) through the Data Layer.
    if (!huaweiBuild) {
        implementation("com.google.android.gms:play-services-wearable:19.0.0")
    } else {
        // «الساعة» on Huawei watches through Wear Engine (docs/HUAWEI-WATCH.md).
        implementation("com.huawei.hms:wearengine:5.0.3.300")
    }
}

// Huawei's Maven repository, only for the Huawei build's Wear Engine.
if (huaweiBuild) {
    repositories {
        maven { url = uri("https://developer.huawei.com/repo/") }
    }
}
