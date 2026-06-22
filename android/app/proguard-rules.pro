# Suppress R8/Proguard warnings about missing ML Kit language packs that aren't used in the app.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Agora RTC SDK
-keep class io.agora.** { *; }
-dontwarn io.agora.**
