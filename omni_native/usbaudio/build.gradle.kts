plugins {
  id("com.android.library")
}

android {
  namespace = "echo.music.usbaudio"
  compileSdk = 37

  defaultConfig {
    minSdk = 26
    consumerProguardFiles("consumer-rules.pro")
  }

  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_21
    targetCompatibility = JavaVersion.VERSION_21
  }
}

kotlin { jvmToolchain(21) }

dependencies {
  compileOnly(libs.media3)
  compileOnly("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.10.2")
  testImplementation(libs.media3)
  testImplementation(libs.junit)
}
