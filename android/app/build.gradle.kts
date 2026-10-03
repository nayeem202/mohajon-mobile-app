import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("keystore.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) load(keystorePropertiesFile.inputStream())
}

val localPropertiesFile = rootProject.file("local.properties")
val localProperties = Properties().apply {
    if (localPropertiesFile.exists()) load(localPropertiesFile.inputStream())
}

// Facebook App ID (Meta developer console -> Settings -> Basic).
//
// Read from android/local.properties, which is git-ignored, so the Meta
// credential never lands in version control. It is injected into the manifest
// because the native Facebook SDK initialises itself from there before any
// Dart code runs — with the key absent the SDK fails to initialise and takes
// the rest of the plugin registry down with it.
//
// The same value has to be handed to Dart with
// --dart-define=FACEBOOK_APP_ID=... ; CustomAuthBackend refuses to open the
// Facebook flow when that define is missing, so the placeholder below can only
// ever surface as the friendly "not configured" message.
val facebookAppId: String =
    localProperties.getProperty("facebook.app.id")?.trim().orEmpty()
        .ifEmpty { "000000000000000" }

android {
    namespace = "com.example.inventory_1"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.inventory_1"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders["facebookAppId"] = facebookAppId
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            if (keystoreProperties.isEmpty()) {
                throw GradleException("Release signing is not configured. Provide android/key.properties before building production.")
            }
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
