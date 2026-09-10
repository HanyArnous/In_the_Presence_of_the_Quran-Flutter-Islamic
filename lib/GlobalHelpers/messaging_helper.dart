import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'package:quran/quran.dart' as quran;
import 'package:nabd/core/notifications/data/40hadith.dart';

FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // تهيئة Hive في الخلفية لتتبع العشوائية وعدم التكرار
      try {
        await Hive.initFlutter();
        if (!Hive.isBoxOpen("name")) {
          await Hive.openBox("name");
        }
      } catch (_) {}

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      await flutterLocalNotificationsPlugin.initialize(
          const InitializationSettings(android: initializationSettingsAndroid));

      final List<String> channelIds = [
        'zikr_channel',
        'prayer_channel',
        'ayah_channel',
        'hadith_channel'
      ];
      for (var id in channelIds) {
        final isPrayer = id == 'prayer_channel';
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(AndroidNotificationChannel(
                id, id.replaceAll('_', ' '),
                importance: Importance.max,
                sound: RawResourceAndroidNotificationSound(isPrayer ? 'azan' : 'notification'),
                playSound: true,
                enableVibration: true));
      }

      switch (task) {
        case "ayahNot":
        case "ayahNotTest":
          await _showRandomAyahNotification();
          break;
        case "sallahEnable":
          await _showNotification(
              _randomId(), "ذكر الله", "اللهم صلِ وسلم على نبينا محمد", "prayer_channel");
          break;
        case "hadithNot":
        case "hadithNotTest":
          await _showRandomHadithNotification();
          break;
        case "zikrNotification":
        case "zikrNotificationTest":
        case "zikrNotificationTest2":
          await _showRandomZikrNotification();
          break;
        default:
          break;
      }
    } catch (e) {
      // ignore
    }
    return Future.value(true);
  });
}

int _randomId() => DateTime.now().millisecondsSinceEpoch % 2147483647;

Future<void> _showRandomAyahNotification() async {
  final random = Random();
  String ayahText = "﴿فَاذْكُرُونِي أَذْكُرْكُمْ﴾";
  String title = "آية اليوم";
  int surah = 2;
  int verse = 152;

  try {
    // قراءة السجل لتجنب التكرار
    List<String> history = [];
    try {
      final raw = Hive.box("name").get("ayahHistory");
      if (raw is List) history = raw.map((e) => e.toString()).toList();
      if (raw is String && raw.isNotEmpty) history = [raw];
    } catch (_) {}

    // اختيار عشوائي غير مكرر (حتى 20 محاولة)
    String pickedKey = "";
    for (int attempt = 0; attempt < 20; attempt++) {
      surah = random.nextInt(114) + 1;
      int verseCount;
      try {
        verseCount = quran.getVerseCount(surah);
      } catch (_) {
        continue;
      }
      if (verseCount <= 0) continue;
      verse = random.nextInt(verseCount) + 1;
      pickedKey = "$surah-$verse";
      if (!history.contains(pickedKey)) break;
      // إذا كل المحاولات مكررة، اقبل الأخير
      if (attempt == 19) break;
    }

    // جلب نص الآية
    try {
      ayahText = quran.getVerse(surah, verse);
      String surahName;
      try {
        surahName = quran.getSurahNameArabic(surah);
      } catch (_) {
        surahName = "سورة $surah";
      }
      title = "$surahName - آية $verse";
      if (ayahText.length > 140) {
        ayahText = ayahText.substring(0, 140) + "…";
      }
      ayahText = ayahText.trim();
    } catch (_) {
      // fallback
    }

    // تحديث السجل (احتفظ بآخر 50)
    try {
      history.insert(0, pickedKey);
      if (history.length > 50) history = history.sublist(0, 50);
      await Hive.box("name").put("ayahHistory", history);
      await Hive.box("name").put("lastAyahKey", pickedKey);
    } catch (_) {}
  } catch (_) {}

  await _showNotification(_randomId(), title, ayahText, "ayah_channel");
}

Future<void> _showRandomHadithNotification() async {
  final random = Random();
  String body = "قال رسول الله ﷺ: الدال على الخير كفاعله";
  String title = "حديث اليوم";

  try {
    if (hadithes.isEmpty) {
      await _showNotification(_randomId(), title, body, "hadith_channel");
      return;
    }

    List<int> history = [];
    try {
      final raw = Hive.box("name").get("hadithHistory");
      if (raw is List) history = raw.map((e) => int.tryParse(e.toString()) ?? -1).where((e) => e >= 0).toList();
    } catch (_) {}

    int idx;
    // اختر عشوائي غير مكرر في آخر 15
    for (int attempt = 0; attempt < 20; attempt++) {
      idx = random.nextInt(hadithes.length);
      if (!history.contains(idx)) break;
      if (attempt == 19) {
        idx = random.nextInt(hadithes.length);
        break;
      }
    }
    // إذا لم نجد idx بعد الحلقة (حالة نادرة)، استخدم الأول
    idx = random.nextInt(hadithes.length);
    // حاول مرة أخرى بمنطق أدق
    for (int attempt = 0; attempt < 30; attempt++) {
      int cand = random.nextInt(hadithes.length);
      if (!history.contains(cand)) {
        idx = cand;
        break;
      }
    }

    // جلب النص
    try {
      final item = hadithes[idx];
      String rawHadith = (item["hadith"] ?? item["text"] ?? body).toString();
      // نظف
      rawHadith = rawHadith.replaceAll(RegExp(r'\s+'), ' ').trim();
      // خذ أول 140 حرف
      if (rawHadith.length > 140) {
        // حاول قطع عند جملة
        String cut = rawHadith.substring(0, 140);
        int lastDot = cut.lastIndexOf("،");
        if (lastDot > 80) cut = cut.substring(0, lastDot);
        body = cut + "…";
      } else {
        body = rawHadith;
      }
      // عنوان
      title = "حديث شريف";
      // استخرج رقم الحديث إن وجد
      final match = RegExp(r'الحديث ([\u0621-\u064A]+|\d+)').firstMatch(rawHadith);
      if (match != null) {
        title = "الحديث ${match.group(1)}";
      }
    } catch (_) {}

    // حدث السجل
    try {
      history.insert(0, idx);
      if (history.length > 50) history = history.sublist(0, 50);
      await Hive.box("name").put("hadithHistory", history);
      await Hive.box("name").put("lastHadithIndex", idx);
    } catch (_) {}
  } catch (_) {}

  await _showNotification(_randomId(), title, body, "hadith_channel");
}

Future<void> _showRandomZikrNotification() async {
  const List<String> azkar = [
    "سبحان الله والحمد لله",
    "لا إله إلا الله والله أكبر",
    "أستغفر الله العظيم",
    "اللهم صلِ على محمد",
    "لا حول ولا قوة إلا بالله",
    "سبحان الله وبحمده سبحان الله العظيم",
    "الحمد لله رب العالمين",
  ];
  final random = Random();
  String picked = azkar[random.nextInt(azkar.length)];
  try {
    final last = Hive.box("name").get("lastZikrText")?.toString();
    if (picked == last) {
      picked = azkar[(azkar.indexOf(picked) + 1) % azkar.length];
    }
    await Hive.box("name").put("lastZikrText", picked);
  } catch (_) {}
  await _showNotification(_randomId(), "ذكر اليوم", picked, "zikr_channel");
}

Future<void> _showNotification(
    int id, String title, String body, String channel) async {
  final isPrayer = channel == 'prayer_channel';
  await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      NotificationDetails(
          android: AndroidNotificationDetails(
            channel,
            channel,
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            sound: RawResourceAndroidNotificationSound(isPrayer ? 'azan' : 'notification'),
            enableVibration: true,
            visibility: NotificationVisibility.public,
            category: isPrayer ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.reminder,
            fullScreenIntent: isPrayer,
            timeoutAfter: isPrayer ? 60000 : null,
            styleInformation: BigTextStyleInformation(
              body,
              htmlFormatBigText: false,
              contentTitle: title,
              htmlFormatContentTitle: false,
            ),
            actions: isPrayer
                ? [
                    const AndroidNotificationAction('stop_azan', 'إيقاف', cancelNotification: true, showsUserInterface: true),
                  ]
                : null,
          )));
}

void initMessaging() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}
