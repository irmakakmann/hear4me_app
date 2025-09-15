plugins {
    // Pin Android Gradle Plugin to 7.4.2 for old plugins (like tflite_flutter 0.9.x)
    id("com.android.application") apply false
    id("com.android.library") apply false
    // Kotlin plugin version compatible with AGP 7.4.x
    kotlin("android") apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// (Optional) If you previously changed build dirs, keep it — otherwise you can drop it.
val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(newBuildDir)
subprojects {
    layout.buildDirectory.set(newBuildDir.dir(project.name))
    evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
