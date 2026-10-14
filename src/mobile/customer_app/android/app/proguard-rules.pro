# Flutter Proguard Rules for Release Builds
-dontwarn org.slf4j.impl.StaticLoggerBinder
-dontwarn org.slf4j.**
-keepattributes *Annotation*,EnclosingMethod,Signature,InnerClasses,SourceFile,LineNumberTable
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}

# Flutter & Plugins
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Play Core & Deferred Components
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Google Play Services & Google Maps
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

