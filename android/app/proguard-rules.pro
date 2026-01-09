# Flutter-specific ProGuard rules

# Keep Flutter classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Dart FFI callbacks
-keep class * extends java.lang.Object {
    native <methods>;
}

# Keep secure storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Keep Gson (if used by plugins)
-keepattributes Signature
-keepattributes *Annotation*

# Preserve line numbers for debugging stack traces
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
