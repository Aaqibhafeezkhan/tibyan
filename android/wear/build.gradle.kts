// «الساعة» on Wear OS: a tile with today's portion and a misbaha whose
// counts join the phone's (docs/WATCH.md). Same application id as the
// phone app, as the Data Layer requires; signed with the same key.
import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

// The phone's upload key (android/key.properties, ignored by git).
val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

android {
    namespace = "app.tibyan.tibyan.wear"
    compileSdk = 36

    defaultConfig {
        applicationId = "app.tibyan.tibyan"
        minSdk = 30
        targetSdk = 36
        // Play needs a code no phone build uses: the phone's codes are small
        // build numbers, so the watch counts from 900000 (docs/WATCH.md).
        versionCode = 900002
        versionName = "1.1"
    }

    signingConfigs {
        if (keyProperties.containsKey("storeFile")) {
            create("upload") {
                // Resolved as the phone app does (relative to android/app).
                storeFile = project(":app").file(keyProperties["storeFile"] as String)
                storePassword = keyProperties["storePassword"] as String
                keyAlias = keyProperties["keyAlias"] as String
                keyPassword = keyProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("upload")
                ?: signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("com.google.android.gms:play-services-wearable:19.0.0")
    implementation("androidx.wear.tiles:tiles:1.4.1")
    implementation("androidx.wear.protolayout:protolayout:1.2.1")
    implementation("androidx.wear.watchface:watchface-complications-data-source-ktx:1.2.1")
    implementation("com.google.guava:guava:33.3.1-android")
}
