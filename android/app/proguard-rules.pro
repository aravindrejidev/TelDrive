# This file is not active by default (minifyEnabled is false in
# android/app/build.gradle). Keep it around and flip minifyEnabled to true
# once you're ready to ship a smaller release build.

-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**
-keep class dev.fluttercommunity.workmanager.** { *; }
-keep class com.tekartik.sqflite.** { *; }
