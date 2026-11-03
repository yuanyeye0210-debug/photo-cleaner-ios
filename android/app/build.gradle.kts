plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.yuanye.photocleaner"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.yuanye.photocleaner"
        minSdk = 26
        targetSdk = 35
        // CI 会传入运行编号，保证每次新包都能覆盖安装
        versionCode = (System.getenv("GITHUB_RUN_NUMBER")?.toIntOrNull() ?: 1)
        versionName = "1.0." + (System.getenv("GITHUB_RUN_NUMBER") ?: "0")
    }

    // 固定的签名文件：每次编出来的包签名一致，可以直接覆盖安装（仅供自己侧载使用）
    signingConfigs {
        create("sideload") {
            storeFile = file("signing/photocleaner.jks")
            storePassword = "photocleaner"
            keyAlias = "photocleaner"
            keyPassword = "photocleaner"
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.getByName("sideload")
        }
        debug {
            signingConfig = signingConfigs.getByName("sideload")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
        freeCompilerArgs += listOf("-opt-in=androidx.compose.foundation.ExperimentalFoundationApi")
    }
    // 按 CPU 架构分包：手机用 arm64-v8a（体积小一半），x86_64 给电脑上的模拟器，armeabi-v7a 给很老的 32 位手机
    splits {
        abi {
            isEnable = true
            reset()
            include("arm64-v8a", "armeabi-v7a", "x86_64")
            isUniversalApk = false
        }
    }
    buildFeatures { compose = true; buildConfig = true }
    androidResources { noCompress += "tflite" }
    packaging { resources.excludes += "/META-INF/{AL2.0,LGPL2.1}" }
    testOptions { unitTests.isReturnDefaultValues = false }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2024.12.01")
    implementation(composeBom)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.exifinterface:exifinterface:1.3.7")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.9.0")

    // 图片加载（内存缓存：长按看大图时先秒出缩略图）
    implementation("io.coil-kt:coil-compose:2.7.0")
    implementation("io.coil-kt:coil-video:2.7.0")

    // Google ML Kit（模型打包在 App 里，离线运行）
    implementation("com.google.mlkit:image-labeling:17.0.9")
    implementation("com.google.mlkit:barcode-scanning:17.3.0")
    implementation("com.google.mlkit:text-recognition-chinese:16.0.1")
    implementation("com.google.mlkit:face-detection:16.1.7")
    // MediaPipe 图像特征向量（AI 相似度）
    implementation("com.google.mediapipe:tasks-vision:0.10.20")

    // 视频压缩成 HEVC（H.265）：Media3 Transformer，用手机自带的硬件编码器
    implementation("androidx.media3:media3-transformer:1.4.1")
    implementation("androidx.media3:media3-effect:1.4.1")
    implementation("androidx.media3:media3-common:1.4.1")
    implementation("androidx.media3:media3-muxer:1.4.1")
    // 桌面小组件
    implementation("androidx.glance:glance-appwidget:1.1.1")

    testImplementation("junit:junit:4.13.2")
}
