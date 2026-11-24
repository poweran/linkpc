plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Prefer pre-installed NDK from Android SDK on CI/runners to avoid 1GB+ download overhead
val detectedNdkVersion: String = run {
    val androidHome = System.getenv("ANDROID_HOME") ?: System.getenv("ANDROID_SDK_ROOT")
    if (androidHome != null) {
        val ndkDir = File(androidHome, "ndk")
        if (ndkDir.isDirectory) {
            val installed = ndkDir.listFiles()?.filter { it.isDirectory }?.map { it.name }?.sortedDescending()
            if (!installed.isNullOrEmpty()) {
                return@run installed.first()
            }
        }
    }
    flutter.ndkVersion
}

android {
    namespace = "net.linkpc.client"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = detectedNdkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "net.linkpc.client"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            abiFilters.add("arm64-v8a")
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    buildTypes {
        release {
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.core:core-ktx:1.12.0")
    implementation(fileTree(mapOf("dir" to "libs", "include" to listOf("*.aar", "*.jar"))))
}
