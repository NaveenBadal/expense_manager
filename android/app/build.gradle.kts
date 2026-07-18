plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.naveen.fund_flow"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.naveen.fund_flow"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "channel"
    productFlavors {
        create("development") {
            dimension = "channel"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "Fund Flow Dev")
        }
        create("production") {
            dimension = "channel"
            resValue("string", "app_name", "Fund Flow")
        }
    }

    signingConfigs {
        create("developmentRelease") {
            val keystorePath = System.getenv("DEV_KEYSTORE_PATH")
            if (!keystorePath.isNullOrBlank()) {
                storeFile = file(keystorePath)
                storePassword = System.getenv("DEV_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("DEV_KEY_ALIAS")
                keyPassword = System.getenv("DEV_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // CI supplies the permanent development keystore. Local release
            // builds fall back to the debug key and cannot update CI builds.
            signingConfig = if (System.getenv("DEV_KEYSTORE_PATH").isNullOrBlank()) {
                signingConfigs.getByName("debug")
            } else {
                signingConfigs.getByName("developmentRelease")
            }
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
