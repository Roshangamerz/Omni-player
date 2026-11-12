# Flutter / Dart
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# audioplayers plugin
-keep class xyz.luan.audioplayers.** { *; }
-dontwarn xyz.luan.audioplayers.**

# shared_preferences plugin
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# http plugin
-keep class com.android.volley.** { *; }
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# Keep Flutter plugin registrant
-keep class com.omniplayer.music.GeneratedPluginRegistrant { *; }

# Keep JSON serialization classes
-keepattributes Signature
-keepattributes *Annotation*

# Omni Native Services
-keep class com.omniplayer.music.** { *; }
-keep class androidx.media.** { *; }
-keep class androidx.core.** { *; }

# OkHttp (used by http package)
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
