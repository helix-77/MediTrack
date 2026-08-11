# ProGuard/R8 Rules for ML Kit Text Recognition and Firebase
-dontwarn com.google.mlkit.vision.text.**
-keep class com.google.mlkit.vision.text.** { *; }

# ML Kit common library: its internal DI (sdkinternal) classes are loaded
# reflectively by MlKitInitProvider at app startup. R8 stripping them
# causes "Unable to get provider MlKitInitProvider / Unsatisfied dependency"
# crashes in release builds only.
-dontwarn com.google.mlkit.common.**
-keep class com.google.mlkit.common.** { *; }

-dontwarn com.google.android.gms.**
-keep class com.google.android.gms.** { *; }
