import 'dart:async';
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
import 'package:nabd/core/prayer/azan_alert_page.dart';
import 'package:nabd/core/prayer/azan_native_bridge.dart';

/// يعالج الضغط على أزرار الإشعار عندما يكون التطبيق في الخلفية/مقتولاً.
/// ملاحظة: إيقاف الخدمة الأصلية يتم أساساً عبر زر الإيقاف الخاص بإشعار
/// الخدمة الأمامية نفسها (يعمل native دائماً)؛ هنا نحاول أيضاً كأفضل جهد.
@pragma('vm:entry-point')
void azanBackgroundTap(NotificationResponse details) {
  try {
    if (details.actionId == 'stop_azan') {
      AzanNativeBridge.stop();
    }
  } catch (_) {}
}

class PrayerService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static final AudioPlayer _azanPlayer = AudioPlayer();
  // v2: ترحيل من prayer_channel القديمة التي قد تكون عالقة صامتة على
  // الأجهزة (إعدادات القناة ثابتة بعد أول إنشاء ولا تتغير بتحديث التطبيق).
  static const String kPrayerChannelId = 'prayer_channel_v2';
  static const String kPrayerTestChannelId = 'prayer_test_v2';
  static const List<String> kObsoletePrayerChannels = [
    'prayer_channel',
    'prayer_test',
  ];

  /// بديل Dart (غير Android): يشغّل الملف كاملاً بدون مؤقت إيقاف.
  static AudioPlayer get azanPlayer => _azanPlayer;
  static bool _tzInitialized = false;

  /// مفتاح ملاح يُربط بـ MaterialApp في main.dart للتنقل من callbacks الإشعارات.
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// مدة بقاء إشعار الأذان (5 دقائق) حتى لا يُقطع الملف الكامل مبكراً.
  static const int azanTimeoutMillis = 5 * 60 * 1000;

  static Future<void> initNotifications() async {
    const AndroidInitializationSettings initAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: initAndroid),
      onDidReceiveNotificationResponse: _onNotificationTap,
      onDidReceiveBackgroundNotificationResponse: azanBackgroundTap,
    );
    await _createChannels();
  }

  static Future<void> _createChannels() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      // قناة الصلوات: صوت الأذان + أولوية قصوى + FullScreen
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        kPrayerChannelId,
        'Prayer Notifications',
        description: 'Prayer time notifications - full azan',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('azan'),
        enableVibration: true,
      ));
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        kPrayerTestChannelId,
        'Test',
        description: 'Azan test channel',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('azan'),
      ));
      // احذف القنوات القديمة الصامتة المحتملة
      for (final old in kObsoletePrayerChannels) {
        try {
          await android?.deleteNotificationChannel(old);
        } catch (_) {}
      }
    } catch (_) {}
  }

  static void _onNotificationTap(NotificationResponse details) async {
    try {
      if (details.actionId == 'stop_azan') {
        // زر إيقاف: يوقف التشغيل الحالي فقط ولا يلغي مواقيت المستقبل
        await stopCurrentAzan();
        return;
      }
      final payload = details.payload ?? '';
      if (payload.startsWith('azan|')) {
        final parts = payload.split('|');
        final en = parts.length > 1 ? parts[1] : '';
        final ar = parts.length > 2 ? parts[2] : getArabicName(en);
        // التشغيل الكامل بدأ غالباً عبر الخدمة الأمامية؛ نضمنه هنا أيضاً
        await AzanNativeBridge.playNow(prayerName: ar, prayerEn: en);
        openAzanAlert(en, ar);
      }
    } catch (_) {}
  }

  /// فتح شاشة الأذان بملء الشاشة (تعمل على التشغيل الكامل + زر إيقاف).
  static void openAzanAlert(String englishName, String arabicName) {
    try {
      final nav = navigatorKey.currentState;
      if (nav == null) {
        _pendingAlert = {'en': englishName, 'ar': arabicName};
        return;
      }
      nav.push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => AzanAlertPage(
            englishName: englishName,
            arabicName: arabicName,
          ),
        ),
      );
    } catch (_) {
      _pendingAlert = {'en': englishName, 'ar': arabicName};
    }
  }

  static Map<String, String>? _pendingAlert;
  static bool _coldStartHandled = false;

  /// تُستدعى بعد أول إطار من التطبيق لمعالجة:
  /// (1) فتح التطبيق عبر الضغط على إشعار أذان، (2) أذان معلّق native،
  /// (3) إعادة الجدولة بعد إعادة تشغيل الجهاز.
  static Future<void> handleColdStart() async {
    if (_coldStartHandled) return;
    _coldStartHandled = true;
    try {
      // 0) إعادة جدولة بعد reboot أولاً دائماً (قبل أي return مبكر)
      // لأن منبهات AlarmManager تُمسح بالإغلاق الكامل/إعادة التشغيل
      // وBootReceiver يكتفي بوضع علامة needs_reschedule.
      try {
        if (await AzanNativeBridge.needsReschedule()) {
          await scheduleAllPrayers();
        } else {
          // أمان: إعادة جدولة يومية حتى لو لم يُضبط العلم
          // (Force-Stop لا يرسل BOOT، والجدولة 7 أيام قد تنتهي)
          final last = getValue("prayer_last_schedule") as int? ?? 0;
          final dayAgo =
              DateTime.now().millisecondsSinceEpoch - 24 * 3600 * 1000;
          if (last < dayAgo) {
            await scheduleAllPrayers();
          }
        }
      } catch (_) {}
      // 1) فتح عبر إشعار
      try {
        final launch =
            await _plugin.getNotificationAppLaunchDetails();
        final payload = launch?.notificationResponse?.payload ?? '';
        if ((launch?.didNotificationLaunchApp ?? false) &&
            payload.startsWith('azan|')) {
          final parts = payload.split('|');
          final en = parts.length > 1 ? parts[1] : '';
          final ar = parts.length > 2 ? parts[2] : getArabicName(en);
          openAzanAlert(en, ar);
          await AzanNativeBridge.clearPendingAzan();
          return;
        }
      } catch (_) {}
      // 2) تنبيه معلّق من الخدمة الأصلية (رنّ أثناء الإغلاق)
      final pending = await AzanNativeBridge.getPendingAzan();
      if (pending != null) {
        openAzanAlert(pending['prayerEn'] ?? '', pending['prayerName'] ?? 'الصلاة');
        return;
      }
      // 3) تنبيه معلّق من ضغطة زر والتطبيق لم يكن جاهزاً
      if (_pendingAlert != null) {
        final p = _pendingAlert!;
        _pendingAlert = null;
        openAzanAlert(p['en'] ?? '', p['ar'] ?? 'الصلاة');
        return;
      }
    } catch (_) {}
  }

  /// إيقاف تشغيل الأذان الحالي فقط (لا يلغي مواقيت المستقبل).
  static Future<void> stopCurrentAzan() async {
    try { await _azanPlayer.stop(); } catch (_) {}
    try { await AzanNativeBridge.stop(); } catch (_) {}
    await dismissAzanNotification();
    try { await AzanNativeBridge.clearPendingAzan(); } catch (_) {}
  }

  /// للتوافق مع الكود القديم: زر الإيقاف كان يلغي كل المواقيت بالخطأ —
  /// الآن يوقف الحالي فقط ويُبقي الجدولة.
  static Future<void> stopAzan() async {
    await stopCurrentAzan();
  }

  /// إخفاء إشعار الاختبار/التنبيه الحالي فقط.
  static Future<void> dismissAzanNotification() async {
    try { await _plugin.cancel(9999); } catch (_) {}
  }

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
        if (open == true) {
          await Geolocator.openLocationSettings();
          // أعد الفحص بعد عودة المستخدم من الإعدادات بدل رفض فوري
          serviceEnabled = await Geolocator.isLocationServiceEnabled();
        }
      }
      if (!serviceEnabled) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("خدمة الموقع متوقفة — فعّل GPS ثم اضغط تحديث مجدداً",
                  style: TextStyle(fontFamily: "cairo"))));
        }
        return false;
      }
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

  /// أذونات الأذان الكامل: إشعارات + منبه دقيق + ملء الشاشة (Android 14+).
  static Future<bool> ensureAzanPermissions() async {
    try {
      final notif = await Permission.notification.request();
      if (!notif.isGranted) return false;
      try {
        final exact = await Permission.scheduleExactAlarm.request();
        if (!exact.isGranted) {
          // نكمل رغم ذلك: المنبه سيعمل بتوقيت تقريبي كاحتياطي
          debugPrint('Exact alarm not granted - using inexact fallback');
        }
      } catch (_) {}
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<Coordinates?> fetchAndSaveLocation(BuildContext context) async {
    final granted = await ensureLocationPermission(context);
    if (!granted) return null;
    // Android 12+: الدقة التقريبية وحدها قد تفشل — اطلب الكاملة المؤقتة
    try {
      final acc = await Geolocator.getLocationAccuracy();
      if (acc == LocationAccuracyStatus.reduced) {
        await Geolocator.requestTemporaryFullAccuracy(
            purposeKey: "PrayerTimes");
      }
    } catch (_) {}
    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 10)),
      );
    } on TimeoutException {
      // GPS بارد داخل المباني يتجاوز 10 ثوانٍ — جرّب آخر موقع معروف (كافٍ للمواقيت)
      try {
        pos = await Geolocator.getLastKnownPosition();
      } catch (_) {}
      if (pos == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("انتهت مهلة GPS — جرّب في مكان مفتوح أو أعد المحاولة",
                  style: TextStyle(fontFamily: "cairo"))));
        }
        return null;
      }
    } catch (e) {
      debugPrint("Location fetch failed: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("تعذّر تحديد الموقع — تحقق من GPS وحاول مجدداً",
                style: TextStyle(fontFamily: "cairo"))));
      }
      return null;
    }
    if (pos == null) return null;
    updateValue("prayer_lat", pos.latitude);
    updateValue("prayer_lng", pos.longitude);
    bool citySaved = false;
    try {
      final placemarks =
          await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        // في مصر غالباً locality فارغ — تدرّج: حي/مركز ← محافظة ← اسم ← طريق
        final cityCandidates = [
          p.locality,
          p.subAdministrativeArea,
          p.administrativeArea,
          p.name,
          p.thoroughfare,
        ];
        String city = "";
        for (final c in cityCandidates) {
          if (c != null && c.trim().isNotEmpty) {
            city = c.trim();
            break;
          }
        }
        final country = (p.country ?? "").trim();
        // آخر ملاذ: اعرض البلد كمدينة بدل "غير محدد" (مثلاً: مصر)
        if (city.isNotEmpty) {
          updateValue("prayer_city", city);
          citySaved = true;
        } else if (country.isNotEmpty) {
          updateValue("prayer_city", country);
          citySaved = true;
        }
        if (country.isNotEmpty) updateValue("prayer_country", country);
      }
    } catch (_) {}
    // الترجمة الجغرافية قد تفشل (أوفلاين/بدون خدمات جوجل) رغم حفظ الإحداثيات —
    // ثبّت label افتراضي حتى لا يبقى الموقع "غير محدد" والتوقيت صحيح.
    if (!citySaved &&
        (getValue("prayer_city")?.toString().trim().isEmpty ?? true)) {
      updateValue("prayer_city", "موقعي الحالي");
    }
    return Coordinates(pos.latitude, pos.longitude);
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
    final List<Map<String, dynamic>> nativeItems = [];
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
        nativeItems.add({
          'id': id,
          'timeMillis': time.millisecondsSinceEpoch,
          'prayerName': getArabicName(name),
          'prayerEn': name,
        });
      }
    }
    // منبهات native تشغّل الخدمة الأمامية بالملف الكامل حتى لو التطبيق مقتول
    try {
      final n = await AzanNativeBridge.scheduleAzan(nativeItems);
      debugPrint('Scheduled $n native azan alarms (full playback)');
    } catch (e) {
      debugPrint('Native azan schedule failed: $e');
    }
    // طابع آخر جدولة ناجحة لأمان إعادة الجدولة اليومية عند الفتح
    try {
      updateValue(
          "prayer_last_schedule", DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  static int _prayerId(String name, DateTime date) {
    const ids = {'Fajr': 1, 'Dhuhr': 2, 'Asr': 3, 'Maghrib': 4, 'Isha': 5};
    final base = ids[name] ?? 0;
    return base * 10000 + date.month * 100 + date.day;
  }

  /// جدولة مفردة للأذان عبر Native فقط (إشعار واحد).
  /// أُزيلت جدولة FLN هنا عمداً: كانت تعرض إشعاراً ثانياً مع إشعار
  /// الخدمة الأمامية (1001) في نفس اللحظة. الضغط على إشعار الخدمة
  /// يفتح التطبيق ويعرض شاشة الأذان عبر pending-azan.
  static Future<void> _scheduleSingle(int id, String englishName, DateTime time) async {
    // لا حاجة لأي إجراء هنا — nativeItems تُجمع في scheduleAllPrayers.
    // أُبقيت الدالة للتوافق، مع إلغاء أي FLN قديم بنفس المعرف (من إصدارات سابقة).
    try {
      await _plugin.cancel(id);
    } catch (_) {}
  }

  static Future<void> cancelAllPrayers() async {
    for (int i = 0; i < 7; i++) {
      final date = DateTime.now().add(Duration(days: i));
      for (final name in ['Fajr','Dhuhr','Asr','Maghrib','Isha']) {
        try {
          await _plugin.cancel(_prayerId(name, date));
        } catch (_) {}
      }
    }
    try {
      await AzanNativeBridge.cancelAzan();
    } catch (_) {}
  }

  static Future<void> testNextPrayer() async {
    final next = getNextPrayer();
    String en = next['name'] ?? '';
    if (en.isEmpty) {
      en = 'Fajr';
    }
    final arabic = getArabicName(en);
    // إشعار واحد فقط: الخدمة الأمامية native تعرض إشعارها الخاص (1001).
    // عرض FLN هنا معها كان ينتج إشعارين متراكبين — أُزيل عمداً.
    try {
      await _plugin.cancel(9999);
    } catch (_) {}
    // تشغيل كامل: native أولاً ثم بديل Dart بدون مؤقت إيقاف
    final nativeOk = await AzanNativeBridge.playNow(prayerName: arabic, prayerEn: en);
    if (!nativeOk) {
      try {
        await _azanPlayer.stop();
        await _azanPlayer.setReleaseMode(ReleaseMode.stop);
        await _azanPlayer.setVolume(1.0);
        await _azanPlayer.play(AssetSource('audio/azan.mp3'));
      } catch (e) {
        debugPrint("Azan audio play failed: $e");
      }
    }
  }

  /// تشغيل الأذان كاملاً الآن (بدون أي إيقاف تلقائي مبكر).
  static Future<void> playAzanNow({String englishName = 'Fajr'}) async {
    final arabic = getArabicName(englishName);
    final nativeOk = await AzanNativeBridge.playNow(prayerName: arabic, prayerEn: englishName);
    if (!nativeOk) {
      try {
        await _azanPlayer.stop();
        await _azanPlayer.setReleaseMode(ReleaseMode.stop);
        await _azanPlayer.setVolume(1.0);
        await _azanPlayer.play(AssetSource('audio/azan.mp3'));
      } catch (e) {
        debugPrint("playAzanNow failed: $e");
      }
    }
  }
}
