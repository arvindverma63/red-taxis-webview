# Flutter Proguard Rules for Release Builds
-dontwarn org.slf4j.impl.StaticLoggerBinder
-dontwarn org.slf4j.**
-keepattributes *Annotation*
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}
