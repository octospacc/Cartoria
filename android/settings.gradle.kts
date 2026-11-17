pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
}

gradle.settingsEvaluated {
    listOf("super_native_extensions", "irondash_engine_context").forEach { pluginName ->
        findProject(":$pluginName")?.let { descriptor ->
            val dummyDir = File(rootProject.projectDir, "build/dummy_$pluginName")
            dummyDir.mkdirs()
            File(dummyDir, "build.gradle").writeText("""
                apply plugin: 'com.android.library'
                android {
                    namespace 'com.superlist.$pluginName'
                    compileSdk 34
                }
            """.trimIndent())
            descriptor.projectDir = dummyDir
            descriptor.buildFileName = "build.gradle"
        }
    }
}

include(":app")
