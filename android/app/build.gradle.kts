import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase 
    id("com.google.gms.google-services")
}

android {
    namespace = "com.stanchat.app"
    compileSdk = 36
    ndkVersion = "27.0.12077973"
    
    compileOptions {
        // Enable core library desugaring
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }
    
    defaultConfig {
        // Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.stanchat.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26  // This is already good for flutter_local_notifications
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Enable multidex support for larger apps
        multiDexEnabled = true
    }
    
    buildTypes {
        release {
            // Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Core library desugaring - REQUIRED for flutter_local_notifications
    // Updated to version 2.1.4 or above as required
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    
    // MultiDex support
    implementation("androidx.multidex:multidex:2.0.1")
    
    // Your existing dependencies
    // implementation("com.github.AbedElazizShe:LightCompressor:1.3.2")
    
    // Import the Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:33.15.0"))
    // Firebase dependencies
    implementation("com.google.firebase:firebase-analytics")
}