# Keep TensorFlow Lite & GPU delegate classes
-keep class org.tensorflow.** { *; }
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }
-keep class com.google.flatbuffers.** { *; }

# Don’t fail on any warnings from these packages
-dontwarn org.tensorflow.**
-dontwarn org.tensorflow.lite.**
-dontwarn org.tensorflow.lite.gpu.**
-dontwarn com.google.flatbuffers.**
