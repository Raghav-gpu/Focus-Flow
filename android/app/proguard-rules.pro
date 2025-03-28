# Keep flutter_local_notifications classes and generic signatures
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class androidx.core.app.NotificationCompat { *; }
-keep class androidx.core.app.NotificationManagerCompat { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**
-keepattributes Signature
-keepattributes *Annotation*