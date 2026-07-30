# ProGuard/R8 Rules for ML Kit Text Recognition and Firebase
-dontwarn com.google.mlkit.vision.text.**
-keep class com.google.mlkit.vision.text.** { *; }

-dontwarn com.google.android.gms.**
-keep class com.google.android.gms.** { *; }
