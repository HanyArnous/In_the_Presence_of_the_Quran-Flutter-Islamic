import 'package:flutter/material.dart';
import 'package:nabd/GlobalHelpers/hive_helper.dart';
import 'package:workmanager/workmanager.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// تهيئة الإشعارات المحلية
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // تهيئة الإشعارات
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    switch (task) {
      case "zikrNotificationTest":
      case "zikrNotificationTest2":
        await _showTestNotification();
        break;
      case "sallahEnable":
        await _showPrayerNotification();
        break;
      case "sallahDisable":
        // Handle disabling prayer notifications
        break;
      case "ayahNot":
      case "ayahNotTest":
        await _showAyahNotification();
        break;
      case "hadithNot":
      case "hadithNotTest":
        await _showHadithNotification();
        break;
      default:
        debugPrint("Unknown task: $task");
    }
    
    return Future.value(true);
  });
}

Future<void> _showTestNotification() async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'zikr_channel',
    'Zikr Notifications',
    channelDescription: 'Notifications for daily zikr reminders',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: false,
  );
  
  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

  await flutterLocalNotificationsPlugin.show(
    0,
    'اختبار الإشعار',
    'هذا إشعار اختبار من تطبيق في رحاب القرآن',
    platformChannelSpecifics,
  );
}

Future<void> _showPrayerNotification() async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'prayer_channel',
    'Prayer Notifications',
    channelDescription: 'Notifications for prayer times',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: false,
  );
  
  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

  await flutterLocalNotificationsPlugin.show(
    1,
    'وقت الصلاة',
    'حان الآن وقت الصلاة',
    platformChannelSpecifics,
  );
}

Future<void> _showAyahNotification() async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'ayah_channel',
    'Ayah Notifications',
    channelDescription: 'Notifications for Quran verses',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: false,
  );
  
  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

  await flutterLocalNotificationsPlugin.show(
    2,
    'آية قرآنية',
    'اقرأ آية من القرآن الكريم اليوم',
    platformChannelSpecifics,
  );
}

Future<void> _showHadithNotification() async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'hadith_channel',
    'Hadith Notifications',
    channelDescription: 'Notifications for hadith',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: false,
  );
  
  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

  await flutterLocalNotificationsPlugin.show(
    3,
    'حديث شريف',
    'اقرأ حديثاً من الأحاديث النبوية الشريفة',
    platformChannelSpecifics,
  );
}
