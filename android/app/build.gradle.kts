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
// credential never lands in version control. It is emitted as a string
// resource and referenced by the manifest because the native Facebook SDK
// initialises itself from there before any Dart code runs — with the key absent
// the SDK fails to initialise and takes the rest of the plugin registry down
// with it. The SDK rejects a raw manifest literal outright ("App Ids cannot be
// directly placed in the manifest"), so a resource is required, not just
// preferable.
//
// The same value has to be handed to Dart with
// --dart-define=FACEBOOK_APP_ID=... ; CustomAuthBackend refuses to open the
// Facebook flow when that define is missing, so the placeholder below can only
// ever surface as the friendly "not configured" message.
val facebookAppId: String =
    localProperties.getProperty("facebook.app.id")?.trim().orEmpty()
        .ifEmpty { "000000000000000" }

// Facebook Client Token (Meta developer console -> Settings -> Basic).
//
// Distinct from the App ID and from the App Secret. It is a public,
// client-side value, shipped inside every install, and the SDK refuses to
// initialise without it ("A valid Facebook app client token must be set").
// Meta presents it in the form <app-id>|<hash>.
val facebookClientToken: String =
    localProperties.getProperty("facebook.client.token")?.trim().orEmpty()
        .ifEmpty { "$facebookAppId|00000000000000000000000000000000" }

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

        // The Facebook SDK refuses a raw literal in the manifest and only
        // accepts the App ID through a string resource, so it is generated here
        // rather than hand-written into res/values/strings.xml.
        resValue("string", "facebook_app_id", facebookAppId)
        resValue("string", "facebook_client_token", facebookClientToken)
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

dependencies {
    // flutter_facebook_auth depends on the Facebook SDK with `implementation`,
    // so facebook-core is on the runtime classpath but not the compile one.
    // MainActivity has to start the SDK before plugin registration, so the
    // artifact is declared here too. Keep the version in step with the one
    // flutter_facebook_auth resolves.
    implementation("com.facebook.android:facebook-core:18.1.3")
}
