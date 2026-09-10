import 'dart:io';
import 'package:adhan/adhan.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzData;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:nabd/GlobalHelpers/hive_helper.dart';
import 'package:quran/quran.dart' as quran;

class PrayerService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _tzInitialized = false;

  static Future<void> initTimezone() async {
    if (_tzInitialized) return;
    tzData.initializeTimeZones();
    try {
      final String tzName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Africa/Cairo'));
    }
    _tzInitialized = true;
  }

  static CalculationParameters _getParams() {
    final methodStr = getValue("prayer_method") ?? "egyptian";
    final madhabStr = getValue("prayer_madhab") ?? "shafi";
    CalculationMethod method;
    switch (methodStr) {
      case "ummAlQura": method = CalculationMethod.umm_al_qura; break;
      case "muslimWorldLeague": method = CalculationMethod.muslim_world_league; break;
      case "dubai": method = CalculationMethod.dubai; break;
      case "qatar": method = CalculationMethod.qatar; break;
      case "kuwait": method = CalculationMethod.kuwait; break;
      default: method = CalculationMethod.egyptian;
    }
    final params = method.getParameters();
    params.madhab = madhabStr == "hanafi" ? Madhab.hanafi : Madhab.shafi;
    return params;
  }

  static Coordinates? _getCoordinates() {
    final lat = getValue("prayer_lat");
    final lng = getValue("prayer_lng");
    if (lat is num && lng is num) {
      return Coordinates(lat.toDouble(), lng.toDouble());
    }
    return null;
  }

  static Future<bool> ensureLocationPermission(BuildContext context) async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        final open = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text("تفعيل الموقع", style: TextStyle(fontFamily: "cairo")),
            content: const Text("نحتاج موقعك لحساب مواقيت الصلاة بدقة. سيتم إرسال الإحداثيات فقط لحساب الوقت ولن تُشارك.", style: TextStyle(fontFamily: "cairo")),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("إلغاء")),
              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("فتح الإعدادات")),
            ],
          ),
        );
        if (open == true) await Geolocator.openLocationSettings();
      }
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      if (context.mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text("إذن الموقع", style: TextStyle(fontFamily: "cairo")),
            content: const Text("نستخدم موقعك فقط لتحديد القبلة ومواقيت الصلاة. لن يتم تخزين موقعك خارج جهازك.", style: TextStyle(fontFamily: "cairo")),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("لاحقاً")),
              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("موافق")),
            ],
          ),
        );
        if (proceed != true) return false;
      }
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى تفعيل إذن الموقع من الإعدادات")));
        await openAppSettings();
      }
      return false;
    }
    return permission == LocationPermission.whileInUse || permission == LocationPermission.always;
  }

  static Future<Coordinates?> fetchAndSaveLocation(BuildContext context) async {
    final granted = await ensureLocationPermission(context);
    if (!granted) return null;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 10)),
      );
      updateValue("prayer_lat", pos.latitude);
      updateValue("prayer_lng", pos.longitude);
      try {
        final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          updateValue("prayer_city", p.locality ?? p.subAdministrativeArea ?? "");
          updateValue("prayer_country", p.country ?? "");
        }
      } catch (_) {}
      return Coordinates(pos.latitude, pos.longitude);
    } catch (e) {
      debugPrint("Location fetch failed: $e");
      return null;
    }
  }

  static PrayerTimes? getPrayerTimesForDate(DateTime date, Coordinates coords) {
    final params = _getParams();
    final components = DateComponents(date.year, date.month, date.day);
    return PrayerTimes(coords, components, params);
  }

  static Map<String, DateTime> getTodayPrayerTimesMap() {
    final coords = _getCoordinates();
    if (coords == null) return {};
    final now = DateTime.now();
    final pt = getPrayerTimesForDate(now, coords);
    if (pt == null) return {};
    return {
      'Fajr': pt.fajr,
      'Sunrise': pt.sunrise,
      'Dhuhr': pt.dhuhr,
      'Asr': pt.asr,
      'Maghrib': pt.maghrib,
      'Isha': pt.isha,
    };
  }

  static Map<String, String> getNextPrayer() {
    final map = getTodayPrayerTimesMap();
    if (map.isEmpty) return {'name': '', 'time': ''};
    final now = DateTime.now();
    const order = ['Fajr','Sunrise','Dhuhr','Asr','Maghrib','Isha'];
    for (final name in order) {
      final t = map[name];
      if (t != null && now.isBefore(t)) {
        return {'name': name, 'time': _formatTime(t), 'iso': t.toIso8601String()};
      }
    }
    // After Isha, next is Fajr tomorrow
    final coords = _getCoordinates();
    if (coords != null) {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final pt = getPrayerTimesForDate(tomorrow, coords);
      if (pt != null) {
        return {'name': 'Fajr', 'time': _formatTime(pt.fajr), 'iso': pt.fajr.toIso8601String()};
      }
    }
    return {'name': 'Fajr', 'time': map['Fajr'] != null ? _formatTime(map['Fajr']!) : ''};
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return "$h:$m";
  }

  static String getArabicName(String english) {
    const map = {
      'Fajr': 'الفجر',
      'Sunrise': 'الشروق',
      'Dhuhr': 'الظهر',
      'Asr': 'العصر',
      'Maghrib': 'المغرب',
      'Isha': 'العشاء',
    };
    return map[english] ?? english;
  }

  static Future<void> scheduleAllPrayers() async {
    await initTimezone();
    await cancelAllPrayers();
    final coords = _getCoordinates();
    if (coords == null) return;
    final enabled = getValue("prayer_enabled") as Map? ?? {"Fajr":true,"Dhuhr":true,"Asr":true,"Maghrib":true,"Isha":true};
    // جدولة 7 أيام قادمة
    for (int d = 0; d < 7; d++) {
      final date = DateTime.now().add(Duration(days: d));
      final pt = getPrayerTimesForDate(date, coords);
      if (pt == null) continue;
      final prayers = {'Fajr': pt.fajr, 'Dhuhr': pt.dhuhr, 'Asr': pt.asr, 'Maghrib': pt.maghrib, 'Isha': pt.isha};
      for (final entry in prayers.entries) {
        final name = entry.key;
        final time = entry.value;
        if (enabled[name] == false) continue;
        if (time.isBefore(DateTime.now())) continue;
        final id = _prayerId(name, date);
        await _scheduleSingle(id, name, time);
      }
    }
  }

  static int _prayerId(String name, DateTime date) {
    const ids = {'Fajr': 1, 'Dhuhr': 2, 'Asr': 3, 'Maghrib': 4, 'Isha': 5};
    final base = ids[name] ?? 0;
    return base * 10000 + date.month * 100 + date.day;
  }

  static Future<void> _scheduleSingle(int id, String englishName, DateTime time) async {
    final arabic = getArabicName(englishName);
    final city = getValue("prayer_city")?.toString() ?? "";
    final body = city.isNotEmpty ? "حان الآن وقت صلاة $arabic في $city" : "حان الآن وقت صلاة $arabic";
    // استخدم صوت مختلف لكل صلاة (ملفات azan_fajr.. في res/raw)
    final soundName = 'azan_${englishName.toLowerCase()}';
    try {
      await _plugin.zonedSchedule(
        id,
        'حان وقت $arabic',
        body,
        tz.TZDateTime.from(time, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'prayer_$englishName',
            'Prayer $arabic',
            channelDescription: 'Prayer $arabic notifications',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            sound: RawResourceAndroidNotificationSound(soundName),
            category: AndroidNotificationCategory.alarm,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      // fallback بدون صوت مخصص
      try {
        await _plugin.zonedSchedule(
          id,
          'حان وقت $arabic',
          body,
          tz.TZDateTime.from(time, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'prayer_channel',
              'Prayer Notifications',
              channelDescription: 'Prayer time notifications',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
              category: AndroidNotificationCategory.alarm,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      } catch (_) {
        debugPrint("Schedule $englishName failed: $e");
      }
    }
  }

  static Future<void> cancelAllPrayers() async {
    for (int i = 0; i < 7; i++) {
      final date = DateTime.now().add(Duration(days: i));
      for (final name in ['Fajr','Dhuhr','Asr','Maghrib','Isha']) {
        await _plugin.cancel(_prayerId(name, date));
      }
    }
  }

  static Future<void> testNextPrayer() async {
    final next = getNextPrayer();
    String title;
    String body;
    if (next['name']!.isEmpty) {
      title = 'اختبار الأذان';
      body = 'سيتم تشغيل صوت الأذان الآن (offline)';
    } else {
      title = 'اختبار - ${getArabicName(next['name']!)}';
      body = 'الوقت: ${next['time']} - سيتم تشغيل الأذان';
    }
    // 1) إظهار إشعار فوراً
    await _plugin.show(
      9999,
      title,
      body,
      const NotificationDetails(android: AndroidNotificationDetails('prayer_test', 'Test', importance: Importance.max, priority: Priority.high, playSound: true, sound: RawResourceAndroidNotificationSound('azan'))),
    );
    // 2) تشغيل صوت الأذان فعلياً offline عبر AudioPlayer
    try {
      final player = AudioPlayer();
      await player.play(AssetSource('audio/azan.mp3'));
      // إيقاف بعد 20 ثانية (لمنع التشغيل الطويل في الاختبار)
      Future.delayed(const Duration(seconds: 20), () {
        player.stop();
        player.dispose();
      });
    } catch (e) {
      debugPrint("Azan audio play failed: $e");
    }
  }

  static Future<void> playAzanNow() async {
    try {
      final player = AudioPlayer();
      await player.play(AssetSource('audio/azan.mp3'));
      Future.delayed(const Duration(seconds: 30), () {
        player.stop();
        player.dispose();
      });
    } catch (e) {
      debugPrint("playAzanNow failed: $e");
    }
  }
}
