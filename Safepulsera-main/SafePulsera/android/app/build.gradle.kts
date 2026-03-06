plugins {
    id("com.android.application")
    id("kotlin-android")
    // El Flutter Gradle Plugin debe aplicarse después de los plugins de Android y Kotlin.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.safe_allergy2"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // CORRECCIÓN: Habilitar desugaring para soporte de Java 8+ en dispositivos antiguos
        isCoreLibraryDesugaringEnabled = true
        
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.safe_allergy2"
        
        // CORRECCIÓN: minSdk 21 es necesario para muchas librerías de notificaciones modernas
        minSdk = flutter.minSdkVersion 
        
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // NOTA: Para subir a la Play Store necesitarás crear un almacén de claves (keystore)
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // CORRECCIÓN: Librería necesaria para que funcione 'isCoreLibraryDesugaringEnabled'
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")
}
