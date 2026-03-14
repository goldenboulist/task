# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }

# Windows Notification
-keep class com.mrtnetwork.windowsnotification.** { *; }

# Keep notification related classes
-keep class * implements com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin
-keep class * extends com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin

# Keep model classes
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
-keep class com.mrtnetwork.windowsnotification.notification_message.** { *; }
