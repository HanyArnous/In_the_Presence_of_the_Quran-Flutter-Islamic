plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties

// ضبط نسخة الجافا للكوتلن لتفادي تحذير jvmTarget
kotlin {
    jvmToolchain(17)
}

android {
    namespace = "com.hanyarnous.quranpresence"
    // Android 15 (API 35) - مطلوب للعرض حتى حافة الشاشة وفحص خدمات المقدمة
    // compileSdk 36 لحل تضارب androidx.core 1.17 مع target 35
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.hanyarnous.quranpresence"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    // الطريقة الصحيحة والحديثة لإعدادات الكوتلن
    kotlinOptions {
        jvmTarget = "17"
    }

    signingConfigs {
        create("release") {
            val keystoreProperties = Properties()
            val keystorePropertiesFile = rootProject.file("key.properties")
            if (!keystorePropertiesFile.exists()) {
                throw GradleException("key.properties not found at ${keystorePropertiesFile.absolutePath}. Create it from key.properties.example")
            }
            keystorePropertiesFile.inputStream().use { input ->
                keystoreProperties.load(input)
            }
            val keyAliasProp = keystoreProperties.getProperty("keyAlias") ?: throw GradleException("keyAlias missing in key.properties")
            val keyPasswordProp = keystoreProperties.getProperty("keyPassword") ?: throw GradleException("keyPassword missing in key.properties")
            val storeFilePathProp = keystoreProperties.getProperty("storeFile") ?: throw GradleException("storeFile missing in key.properties")
            val storePasswordProp = keystoreProperties.getProperty("storePassword") ?: throw GradleException("storePassword missing in key.properties")

            val storeFileProp = rootProject.file(storeFilePathProp)
            if (!storeFileProp.exists()) {
                throw GradleException("Keystore file not found: ${storeFileProp.absolutePath} (storeFile=$storeFilePathProp)")
            }

            keyAlias = keyAliasProp
            keyPassword = keyPasswordProp
            storeFile = storeFileProp
            storePassword = storePasswordProp
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
    
    // إضافة إعدادات لإخفاء تحذيرات Java
    tasks.withType<JavaCompile> {
        options.compilerArgs.addAll(listOf("-Xlint:none"))
    }
}

flutter {
    source = "../.."
}

dependencies {
    // السطر المطلوب لحل مشكلة الإشعارات
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Android 15 Edge-to-Edge الحديث (بدل APIs المتوقفة)
    implementation("androidx.activity:activity-ktx:1.9.2")
    implementation("androidx.core:core-ktx:1.13.1")
}
