import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nabd/GlobalHelpers/hive_helper.dart';
import 'package:workmanager/workmanager.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:quran/quran.dart' as quran;
import 'package:nabd/core/notifications/data/40hadith.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      try {
        await Hive.initFlutter();
        if (!Hive.isBoxOpen("name")) await Hive.openBox("name");
      } catch (_) {}
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );
      await flutterLocalNotificationsPlugin.initialize(initializationSettings);
      switch (task) {
        case "zikrNotificationTest":
        case "zikrNotificationTest2":
          await _showRandomZikr();
          break;
        case "sallahEnable":
          // تم توحيد القناة مع messaging_helper: ذكر بدون زر إيقاف وغير دائم
          await _showNotification(_randId(), "ذكر الله", "اللهم صلِ وسلم على نبينا محمد ﷺ", 'zikr_channel_v2');
          break;
        case "sallahDisable":
          break;
        case "ayahNot":
        case "ayahNotTest":
          await _showRandomAyah();
          break;
        case "hadithNot":
        case "hadithNotTest":
          await _showRandomHadith();
          break;
        default:
          debugPrint("Unknown task: $task");
      }
    } catch (_) {}
    return Future.value(true);
  });
}

int _randId() => DateTime.now().millisecondsSinceEpoch % 2147483647;

Future<void> _showRandomAyah() async {
  final r = Random();
  String text = "﴿فَاذْكُرُونِي أَذْكُرْكُمْ﴾";
  String title = "آية اليوم";
  try {
    List<String> hist = [];
    try {
      final raw = Hive.box("name").get("ayahHistory");
      if (raw is List) hist = raw.map((e) => e.toString()).toList();
    } catch (_) {}
    String key = "";
    int surah = 2, verse = 152;
    for (int i = 0; i < 20; i++) {
      surah = r.nextInt(114) + 1;
      int cnt;
      try { cnt = quran.getVerseCount(surah); } catch (_) { continue; }
      verse = r.nextInt(cnt) + 1;
      key = "$surah-$verse";
      if (!hist.contains(key)) break;
    }
    try {
      text = quran.getVerse(surah, verse);
      final name = quran.getSurahNameArabic(surah);
      title = "$name - آية $verse";
      if (text.length > 140) text = text.substring(0, 140) + "…";
    } catch (_) {}
    try {
      hist.insert(0, key);
      if (hist.length > 50) hist = hist.sublist(0, 50);
      await Hive.box("name").put("ayahHistory", hist);
    } catch (_) {}
  } catch (_) {}
  await _showNotification(_randId(), title, text.trim(), 'ayah_channel');
}

Future<void> _showRandomHadith() async {
  final r = Random();
  String body = "قال رسول الله ﷺ: الدال على الخير كفاعله";
  String title = "حديث شريف";
  try {
    if (hadithes.isEmpty) {
      await _showNotification(_randId(), title, body, 'hadith_channel');
      return;
    }
    List<int> hist = [];
    try {
      final raw = Hive.box("name").get("hadithHistory");
      if (raw is List) hist = raw.map((e) => int.tryParse(e.toString()) ?? -1).where((e) => e >= 0).toList();
    } catch (_) {}
    int idx = r.nextInt(hadithes.length);
    for (int i = 0; i < 30; i++) {
      int cand = r.nextInt(hadithes.length);
      if (!hist.contains(cand)) { idx = cand; break; }
    }
    try {
      final item = hadithes[idx];
      String rawHadith = (item["hadith"] ?? body).toString().replaceAll(RegExp(r'\s+'), ' ').trim();
      if (rawHadith.length > 140) {
        String cut = rawHadith.substring(0, 140);
        int last = cut.lastIndexOf("،");
        if (last > 80) cut = cut.substring(0, last);
        body = cut + "…";
      } else body = rawHadith;
      final m = RegExp(r'الحديث ([\u0621-\u064A]+|\d+)').firstMatch(rawHadith);
      if (m != null) title = "الحديث ${m.group(1)}";
    } catch (_) {}
    try {
      hist.insert(0, idx);
      if (hist.length > 50) hist = hist.sublist(0, 50);
      await Hive.box("name").put("hadithHistory", hist);
    } catch (_) {}
  } catch (_) {}
  await _showNotification(_randId(), title, body, 'hadith_channel');
}

Future<void> _showRandomZikr() async {
  const azkar = ["سبحان الله والحمد لله","لا إله إلا الله والله أكبر","أستغفر الله العظيم","اللهم صلِ على محمد","لا حول ولا قوة إلا بالله","سبحان الله وبحمده سبحان الله العظيم","الحمد لله رب العالمين"];
  final r = Random();
  String picked = azkar[r.nextInt(azkar.length)];
  try {
    final last = Hive.box("name").get("lastZikrText")?.toString();
    if (picked == last) picked = azkar[(azkar.indexOf(picked)+1)%azkar.length];
    await Hive.box("name").put("lastZikrText", picked);
  } catch (_) {}
  await _showNotification(_randId(), "ذكر اليوم", picked, 'zikr_channel');
}

Future<void> _showNotification(int id, String title, String body, String channel) async {
  await flutterLocalNotificationsPlugin.show(id, title, body, NotificationDetails(android: AndroidNotificationDetails(channel, channel, importance: Importance.max, priority: Priority.high, styleInformation: BigTextStyleInformation(body))));
}
