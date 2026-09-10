import 'dart:async';
import 'dart:convert';
// removed unused: dart:math
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';
// removed unused: constants.dart
import 'package:nabd/GlobalHelpers/initializeData.dart';
import 'package:nabd/GlobalHelpers/messaging_helper.dart';
import 'package:nabd/core/home.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart' as ez;
import 'package:flutter/foundation.dart';

final mediaStorePlugin = MediaStore();

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // ✅ طلب صلاحية الإشعارات بشكل آمن مع التعامل مع المنصات والخلفية
  Future<void> checkNotificationPermission() async {
    // نتجنب التنفيذ على الويب أو المنصات غير المدعومة
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }

    try {
      PermissionStatus status = await Permission.notification.request();
      debugPrint("--- [Arnous Trace] Splash Screen Started ---");

      if (status.isPermanentlyDenied) {
        await openAppSettings();
      }
    } on PlatformException catch (e) {
      // هذه هي الحالة التي يظهر فيها الخطأ:
      // PlatformException(PermissionHandler.PermissionManager, Unable to detect current Android Activity.)
      debugPrint(
          "Permission error (notification) - غالباً تم استدعاء الطلب بدون Activity نشطة: $e");
    } catch (e) {
      debugPrint(
          "Unexpected error while requesting notification permission: $e");
    }
  }

  // ✅ استخدام الـ context بحذر مع التأكد من بقاء الـ Widget (Mounted)
  navigateToHome() async {
    await Future.delayed(const Duration(seconds: 4));
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
        context,
        CupertinoPageRoute(builder: (builder) => const Home()),
        (route) => false);
  }

  Future<void> getAndStoreRecitersData(String lang) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String apiLang = lang == "en" ? "eng" : lang;
    final String storageLang = apiLang;

    if (prefs.getString("reciters-$storageLang") != null &&
        prefs.getString("moshaf-$storageLang") != null &&
        prefs.getString("suwar-$storageLang") != null) {
      return;
    }

    try {
      final responses = await Future.wait([
        Dio().get('https://mp3quran.net/api/v3/reciters?language=$apiLang'),
        Dio().get('https://mp3quran.net/api/v3/moshaf?language=$apiLang'),
        Dio().get('https://mp3quran.net/api/v3/suwar?language=$apiLang'),
      ]);

      final recitersResponse = responses[0];
      final moshafResponse = responses[1];
      final suwarResponse = responses[2];

      if (recitersResponse.data != null) {
        prefs.setString("reciters-$storageLang",
            json.encode(recitersResponse.data['reciters']));
      }
      if (moshafResponse.data != null) {
        prefs.setString(
            "moshaf-$storageLang", json.encode(moshafResponse.data));
      }
      if (suwarResponse.data != null) {
        prefs.setString(
            "suwar-$storageLang", json.encode(suwarResponse.data['suwar']));
      }

      prefs.setInt("zikrNotificationindex", 0);
    } catch (error) {
      debugPrint('Error while storing data: $error');
    }
  }

  Future<void> downloadAndStoreHadithData(String lang) async {
    await Future.delayed(const Duration(seconds: 1));
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    if (prefs.getString("hadithlist-100000-$lang") != null) {
      return;
    }

    try {
      Response response = await Dio().get(
          "https://hadeethenc.com/api/v1/categories/roots/?language=$lang");

      if (response.data != null) {
        final jsonData = json.encode(response.data);
        prefs.setString("categories-$lang", jsonData);

        for (var category in response.data) {
          Response response2 = await Dio().get(
              "https://hadeethenc.com/api/v1/hadeeths/list/?language=$lang&category_id=${category["id"]}&per_page=699999");

          if (response2.data != null) {
            final categoryJson = json.encode(response2.data["data"]);
            prefs.setString("hadithlist-${category["id"]}-$lang", categoryJson);

            final key = "hadithlist-100000-$lang";
            if (prefs.getString(key) == null) {
              prefs.setString(key, categoryJson);
            } else {
              final oldData =
                  json.decode(prefs.getString(key)!) as List<dynamic>;
              oldData.addAll(json.decode(categoryJson));
              prefs.setString(key, json.encode(oldData));
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Hadith Download Error: $e");
    }
  }

  initStoragePermission() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }

    try {
      // لا نطلب أذونات التخزين عند البداية — نطلبها فقط عند الحاجة (عند التحميل)
      // إزالة طلب الموقع من البداية (يُطلب فقط عند تفعيل أوقات الصلاة/القبلة مع حوار تفسير)
      if ((await mediaStorePlugin.getPlatformSDKInt()) >= 33) {
        // لا نطلب photos/audio/location عند Splash — سيتم طلبها في سياقها
      }
    } on PlatformException catch (e) {
      debugPrint(
          "Permission error (storage/media) - غالباً تم استدعاء الطلب بدون Activity نشطة: $e");
    } catch (e) {
      debugPrint(
          "Unexpected error while requesting storage/media permission: $e");
    }

    MediaStore.appFolder = "Arnous";
    initMessaging();
  }

  // ✅ توحيد الإطلاق في دالة مُنظمة لضمان جودة الـ Lifecycle
  Future<void> _initializeAsyncTasks() async {
    final String lang = ez.EasyLocalization.of(context)!.locale.languageCode;

    await initHiveValues();

    if (!mounted) return;

    getAndStoreRecitersData(lang);
    downloadAndStoreHadithData(lang);

    navigateToHome();
  }

  @override
  void initState() {
    super.initState();
    // تنفيذ المهام التمهيدية بعد أول Frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAsyncTasks();
    });
  }

  final List<String> zikrNotifs = [
    "ﷺ  صلي علي محمد",
    "اللَّهُمَّ اهْدِنِي وَسَدِّدْنِي",
    "لا حول ولا قوة الا بالله",
    "لا اله الا الله, محمد رسول الله",
    "لا اله الا انت سبحانك اني كنت من الظالمين",
    "استغفر الله",
    "سبحان الله",
    "الحمدلله",
    "لا اله الا الله",
    "الله اكبر"
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xfffff9de),
        body: SizedBox(
          width: MediaQuery.of(context).size.width,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "في رحاب القرآن\nرفيقك اليومي للتلاوة والتدبر",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 30.sp,
                      fontFamily: "UthmanicHafs13"),
                ),
                SizedBox(height: 20.h),
                LottieBuilder.asset("assets/images/loading.json",
                    repeat: true, height: 80.h)
              ],
            ),
          ),
        ),
      ),
    );
  }
}
