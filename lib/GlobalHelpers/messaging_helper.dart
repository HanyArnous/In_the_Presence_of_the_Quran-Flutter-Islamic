import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // تهيئة الـ Plugin وتجهيز القنوات فوراً
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    await flutterLocalNotificationsPlugin.initialize(
        const InitializationSettings(android: initializationSettingsAndroid));

    // تسجيل القنوات الأربعة لضمان الظهور
    final List<String> channelIds = [
      'zikr_channel',
      'prayer_channel',
      'ayah_channel',
      'hadith_channel'
    ];
    for (var id in channelIds) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(AndroidNotificationChannel(
              id, id.replaceAll('_', ' '),
              importance: Importance.max));
    }

    // التنفيذ بناءً على اسم المهمة (موحد مع الواجهة)
    switch (task) {
      case "ayahNot":
      case "ayahNotTest":
        await _showNotification(
            2, "آية اليوم", "﴿فَاذْكُرُونِي أَذْكُرْكُمْ﴾", "ayah_channel");
        break;
      case "sallahEnable":
        await _showNotification(
            1, "ذكر الله", "اللهم صلِ وسلم على نبينا محمد", "prayer_channel");
        break;
      case "hadithNot":
      case "hadithNotTest":
        await _showNotification(3, "حديث اليوم",
            "قال رسول الله ﷺ: الدال على الخير كفاعله", "hadith_channel");
        break;
      case "zikrNotification":
      case "zikrNotificationTest":
      case "zikrNotificationTest2":
        await _showNotification(
            0, "ذكر اليوم", "سبحان الله والحمد لله", "zikr_channel");
        break;
      default:
        // Handle other tasks or ignore
        break;
    }
    return Future.value(true);
  });
}

// دالة عرض موحدة لتقليل الأخطاء
Future<void> _showNotification(
    int id, String title, String body, String channel) async {
  await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      NotificationDetails(
          android: AndroidNotificationDetails(channel, channel,
              importance: Importance.max, priority: Priority.high)));
}

FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void initMessaging() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}
