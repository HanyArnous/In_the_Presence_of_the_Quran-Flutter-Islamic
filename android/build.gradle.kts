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
    afterEvaluate {
        val androidExtension = extensions.findByName("android") ?: return@afterEvaluate

        val getNamespaceMethod = androidExtension.javaClass.methods.firstOrNull {
            it.name == "getNamespace" && it.parameterCount == 0
        }
        val currentNamespace = getNamespaceMethod?.invoke(androidExtension) as? String

        if (currentNamespace.isNullOrEmpty()) {
            val setNamespaceMethod = androidExtension.javaClass.methods.firstOrNull {
                it.name == "setNamespace" && it.parameterCount == 1
            }
            val groupString = (group as? String)?.takeIf { it.isNotEmpty() }
            val fallbackNamespace = groupString ?: "com.example.${name}"
            setNamespaceMethod?.invoke(androidExtension, fallbackNamespace)
        }

        val javaTasks = tasks.withType(org.gradle.api.tasks.compile.JavaCompile::class.java)
        val javaTarget = javaTasks.firstOrNull()?.targetCompatibility

        if (!javaTarget.isNullOrEmpty()) {
            val kotlinTarget = when {
                javaTarget.startsWith("1.8") || javaTarget == "8" ->
                    org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8
                javaTarget.startsWith("11") ->
                    org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
                javaTarget.startsWith("17") ->
                    org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
                else -> null
            }

            if (kotlinTarget != null) {
                tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java)
                    .configureEach {
                        compilerOptions {
                            jvmTarget.set(kotlinTarget)
                        }
                    }
            }
        }

        tasks.configureEach {
            if (name.contains("processDebugManifest") ||
                name.contains("processReleaseManifest")
            ) {
                doFirst {
                    val manifestFile = file("$projectDir/src/main/AndroidManifest.xml")
                    if (manifestFile.exists()) {
                        val manifestContent = manifestFile.readText()
                        if (manifestContent.contains("package=")) {
                            val updatedContent =
                                manifestContent.replace(Regex("package=\"[^\"]*\""), "")
                            manifestFile.writeText(updatedContent)
                            println("Removed 'package' attribute from $manifestFile")
                        }
                    }
                }
            }
        }

        if (name == "flutter_sensors") {
            tasks.withType(org.gradle.api.tasks.compile.JavaCompile::class.java)
                .configureEach {
                    sourceCompatibility = "21"
                    targetCompatibility = "21"
                }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
