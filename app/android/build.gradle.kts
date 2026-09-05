allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Some plugins (e.g. file_picker's flutter_plugin_android_lifecycle dependency)
// ship their own android/build.gradle hardcoding an older compileSdk than they
// actually require, independent of this app's own compileSdk setting. Force
// every Android library subproject to compile against the same SDK the app
// uses. plugins.withId (rather than afterEvaluate) avoids "project already
// evaluated" errors from Flutter's own evaluationDependsOn(":app") ordering.
subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.gradle.LibraryExtension> {
            compileSdk = 37
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
