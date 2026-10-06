# Ignore missing SLF4J binding classes (transitive logger dependencies)
-dontwarn org.slf4j.impl.StaticLoggerBinder
-dontwarn org.slf4j.**

# Flutter & FlutterFire / Firebase Plugins & Method Channels
-keep class io.flutter.plugins.firebase.** { *; }
-keep class com.google.firebase.** { *; }
-dontwarn io.flutter.plugins.firebase.**
-dontwarn com.google.firebase.**

# Flutter Native Engine & Plugins Registrars
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Play Services & Firebase Messaging
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Preserve annotations and reflection signatures
-keepattributes *Annotation*,EnclosingMethod,Signature,InnerClasses,SourceFile,LineNumberTable
