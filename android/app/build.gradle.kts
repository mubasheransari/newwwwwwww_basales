plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")

    // ✅ REQUIRED for Firebase (generates values.xml / FirebaseOptions)
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.new_amst_flutter"

    // ✅ required by your plugins
    ndkVersion = "27.0.12077973"

    // ✅ required by camera_android etc.
    compileSdk = 36

    defaultConfig {
        // ✅ MUST match google-services.json -> client -> package_name
        applicationId = "com.example.voice_assistance_web_app"

        // ✅ firebase-auth 23.x requires minSdk >= 23
        minSdk = flutter.minSdkVersion

        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }
        release {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }
}

flutter {
    source = "../.."
}
