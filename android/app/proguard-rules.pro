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

# WorkManager, pulled in by the Ads SDK, is started by androidx.startup before
# any of our code runs. Its Room database is instantiated by name -- Room does
# Class.forName(database + "_Impl") -- which R8 cannot see, so without these
# rules the generated implementation is renamed away and the app dies during
# Application.onCreate with "Failed to create an instance of WorkDatabase".
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep @androidx.room.Database class * { *; }
-keep class androidx.room.RoomDatabase { *; }
-dontwarn androidx.room.paging.**

-keep class androidx.work.impl.** { *; }
-keep class androidx.work.WorkerParameters { *; }
-keep class * extends androidx.work.ListenableWorker { <init>(...); }

# androidx.startup discovers initializers from the merged manifest and builds
# each one by reflection.
-keep class androidx.startup.** { *; }
-keep class * implements androidx.startup.Initializer { <init>(); }

# SQLite is reached from Room's generated code.
-keep class androidx.sqlite.db.** { *; }
