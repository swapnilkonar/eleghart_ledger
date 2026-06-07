# ── ML Kit Text Recognition ──────────────────────────────────────────────────
# Keep all optional script recognizer modules that R8 would otherwise strip
-keep class com.google.mlkit.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }
-dontwarn com.google.mlkit.**

# Specific missing classes called via reflection at runtime
-keep class com.google.mlkit.vision.text.chinese.** { *; }
-keep class com.google.mlkit.vision.text.devanagari.** { *; }
-keep class com.google.mlkit.vision.text.japanese.** { *; }
-keep class com.google.mlkit.vision.text.korean.** { *; }
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ── pdfx / PDFium ────────────────────────────────────────────────────────────
-keep class com.pdfx.** { *; }
-keep class io.scer.pdf_renderer.** { *; }
-dontwarn com.pdfx.**
-dontwarn io.scer.pdf_renderer.**

# ── flutter_gemma / MediaPipe ─────────────────────────────────────────────────
-dontwarn com.google.auto.value.extension.memoized.Memoized
-dontwarn com.google.mediapipe.proto.CalculatorProfileProto$CalculatorProfile
-dontwarn com.google.mediapipe.proto.GraphTemplateProto$CalculatorGraphTemplate
-keep class com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**

# ── Flutter ───────────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**
