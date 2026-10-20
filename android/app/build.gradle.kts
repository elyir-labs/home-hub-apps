plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "app.elyir.houses"
    compileSdk = 34

    defaultConfig {
        applicationId = "app.elyir.houses"
        minSdk = 26
        targetSdk = 34
        versionCode = 1
        versionName = "0.1"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }

    buildFeatures { buildConfig = true }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("com.android.billingclient:billing:8.3.0")
    testImplementation("junit:junit:4.13.2")
    // android.jar's org.json only throws under JVM tests; the real one reads startup.json there.
    testImplementation("org.json:json:20240303")
}
