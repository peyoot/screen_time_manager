plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.keekey.screen_time_manager"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.keekey.screen_time_manager"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // 生成 BuildConfig.FLAVOR，供 monitor 通道的 getAppInfo 回传给 Dart。
    buildFeatures {
        buildConfig = true
    }

    // 产品风味：free（免费版）/ pro（专业版）。
    // 两者共用同一 applicationId，安装时相互覆盖升级；配额差异由 Dart 侧
    // 依据 native 回传的 BuildConfig.FLAVOR 决定（见 lib/config/app_info.dart）。
    flavorDimensions += "tier"
    productFlavors {
        create("free") {
            dimension = "tier"
        }
        create("pro") {
            dimension = "tier"
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
    // 权威计时核心（ScreenTimeCore）的 JVM 单元测试依赖。
    testImplementation("junit:junit:4.13.2")
}
