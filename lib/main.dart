import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:just_audio/just_audio.dart';
import 'package:nabd/blocs/bloc/bloc/player_bar_bloc.dart';
import 'package:nabd/blocs/bloc/observer.dart';
import 'package:nabd/GlobalHelpers/hive_helper.dart';
import 'package:hive/hive.dart';
import 'package:easy_localization/easy_localization.dart' as ez;
import 'package:nabd/core/home.dart';
import 'package:nabd/audio/audio_background_init.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nabd/core/audiopage/player/player_bar.dart';
import 'package:nabd/core/prayer/prayer_service.dart';
import 'package:workmanager/workmanager.dart';
import 'package:nabd/GlobalHelpers/messaging_helper.dart';

// تعريفات عالمية
final PlayerBarBloc playerbarBloc = PlayerBarBloc();
final AudioPlayer audioPlayer = AudioPlayer();

void main() async {
  // 1. تأمين المحرك
  WidgetsFlutterBinding.ensureInitialized();

  // 2. تهيئة الترجمة (الأساس)
  await ez.EasyLocalization.ensureInitialized();
  await initializeDateFormatting('ar', null);

  // 3. تهيئة مشغّل الصوت في الخلفية للتحكم من الإشعارات وقفل الشاشة
  await initAudioBackground();

  // 4. تهيئة Hive (لا تعتمد على Activity)
  await initializeHive();
  // 5. تهيئة إشعارات الأذان (قنوات + صلاحيات الاستقبال) قبل أي جدولة
  try {
    await PrayerService.initNotifications();
  } catch (_) {}
  // 6. تهيئة مهام الخلفية لعرض الإشعارات للجميع
  Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

  Bloc.observer = SimpleBlocObserver();

  runApp(
    ez.EasyLocalization(
      supportedLocales: const [
        Locale("ar"),
        Locale('en'),
        Locale('de'),
        Locale("am"),
        Locale("ms"),
        Locale("pt"),
        Locale("tr"),
        Locale("ru")
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('ar'),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // بعد أول إطار: افتح شاشة الأذان لو رنّ أثناء الإغلاق + أعد الجدولة بعد reboot
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PrayerService.handleColdStart();
    });
    return ScreenUtilInit(
      designSize: const Size(392.7, 800.7),
      minTextAdapt: true,
      // ✅ نستخدم builder لضمان بناء الـ Context بشكل متسلسل
      builder: (context, child) {
        return BlocProvider<PlayerBarBloc>.value(
          value: playerbarBloc,
          child: StreamBuilder<BoxEvent>(
            stream: Hive.box("name").watch(key: "darkMode"),
            builder: (context, snapshot) {
              final isDark = Hive.box("name").get("darkMode") == true;
              return MaterialApp(
                debugShowCheckedModeBanner: false,
                title: 'في رحاب الرحمن',
                navigatorKey: PrayerService.navigatorKey,
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
                theme: ThemeData(
                  brightness: Brightness.light,
                  fontFamily:
                      context.locale.languageCode == "ar" ? "cairo" : "roboto",
                  primarySwatch: Colors.blue,
                ),
                darkTheme: ThemeData(
                  brightness: Brightness.dark,
                  fontFamily:
                      context.locale.languageCode == "ar" ? "cairo" : "roboto",
                ),
                builder: (ctx, child) {
                  return Stack(
                    children: [
                      if (child != null) child,
                      BlocBuilder<PlayerBarBloc, PlayerBarState>(
                        bloc: playerbarBloc,
                        builder: (context, state) {
                          if (state is PlayerBarClosed) {
                            return const SizedBox.shrink();
                          }
                          return PlayerBar();
                        },
                      ),
                    ],
                  );
                },
                home: const Home(),
              );
            },
          ),
        );
      },
    );
  }
}
