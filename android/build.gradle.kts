allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    // ── Cross-drive fix (Windows) ────────────────────────────────────────
    // Gradle cannot compute relative paths across drive letters (e.g. D:\ vs C:\).
    // Pinning every sub-project's build dir under rootProject.buildDir ensures
    // all plugin artefacts (google_sign_in_android, firebase_auth, etc.) resolve
    // on the same drive as the Flutter project.
    layout.buildDirectory.set(
        rootProject.layout.buildDirectory.dir(project.name)
    )
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
