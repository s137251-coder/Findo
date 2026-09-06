# Google Mobile Ads and the Play Billing library used by in_app_purchase are
# reached reflectively; R8 must not strip or rename them.
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.android.ump.** { *; }
-keep class com.android.billingclient.api.** { *; }

# Flutter's embedding is entered from native code.
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }

# Play Core is referenced by Flutter's deferred components support, which this
# app does not use; silence the resulting missing-class warnings.
-dontwarn com.google.android.play.core.**
