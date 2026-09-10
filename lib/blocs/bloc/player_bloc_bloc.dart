import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nabd/Core/audiopage/models/reciter.dart';
import 'package:nabd/GlobalHelpers/hive_helper.dart';
import 'package:nabd/core/home.dart';
import 'package:nabd/main.dart' show audioPlayer, playerbarBloc;
import 'package:easy_localization/easy_localization.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:bloc/bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:nabd/blocs/bloc/bloc/player_bar_bloc.dart';
import 'package:audio_session/audio_session.dart';
import 'package:quran/quran.dart';
import 'package:fluttertoast/fluttertoast.dart';

part 'player_bloc_event.dart';
part 'player_bloc_state.dart';

class PlayerBlocBloc extends Bloc<PlayerBlocEvent, PlayerBlocState> {
  PlayerBlocBloc() : super(PlayerBlocInitial()) {
    on<PlayerBlocEvent>((event, emit) async {
      if (event is StartPlaying) {
        // 1. إيقاف أي تشغيل جاري
        try {
          if (audioPlayer.playing) {
            await audioPlayer.stop();
          }
        } catch (e) {
          debugPrint("Stop current playback error: $e");
        }

        List<String> surahNumbers = event.moshaf.surahList.split(',');

        // تغيير مسار مجلد التحميل ليستخدم اسم Quran
        final appDir = Directory("/storage/emulated/0/Download/quran/");
        final legacyDir = Directory("/storage/emulated/0/Download/In_the_Presence_of_the_Quran/");
        final arnousDir = Directory("/storage/emulated/0/Download/arnous/");
        if (!await appDir.exists()) {
          await appDir.create(recursive: true);
        }
        if (!await arnousDir.exists()) {
          await arnousDir.create(recursive: true);
        }

        // 2. طلب الصلاحيات بشكل سليم لأندرويد 13+ و 14
        await _requestPermissions();

        // 3. بناء روابط السور (تصحيح بناء الروابط)
        List reciterLinks = surahNumbers.map((e) {
          String suraName = getSurahNameArabic(int.parse(e));
          String pathQuran =
              "${appDir.path}${event.reciter.name}-${event.moshaf.id}-$suraName.mp3";
          String pathLegacy =
              "${legacyDir.path}${event.reciter.name}-${event.moshaf.id}-$suraName.mp3";
          String pathArnous =
              "${arnousDir.path}${event.reciter.name}-${event.moshaf.id}-$suraName.mp3";

          String localPath = File(pathQuran).existsSync()
              ? pathQuran
              : (File(pathLegacy).existsSync()
                  ? pathLegacy
                  : (File(pathArnous).existsSync() ? pathArnous : ""));

          if (localPath.isNotEmpty && File(localPath).existsSync()) {
            return {
              "link": Uri.file(localPath),
              "suraNumber": e,
              "isLocal": true
            };
          } else {
            // ✅ التأكد من أن الرابط يعمل بشكل صحيح
            String remoteUrl =
                "${event.moshaf.server}/${e.toString().padLeft(3, "0")}.mp3";
            return {
              "link": Uri.parse(remoteUrl),
              "suraNumber": e,
              "isLocal": false
            };
          }
        }).toList();

        // 4. تجهيز قائمة التشغيل (Playlist) مع إضافة MediaItem كامل البيانات
        var playList = reciterLinks.map((e) {
          String sId = e["suraNumber"].toString();
          String sName = event.jsonData
              .firstWhere((element) => element["id"].toString() == sId,
                  orElse: () => {"name": "سورة"})["name"]
              .toString();

          return AudioSource.uri(
            e["link"],
            tag: MediaItem(
              // ✅ يجب أن يكون الـ ID فريداً لكل سورة ليعمل الـ Background Service
              id: 'arnous_${event.moshaf.id}_${e["suraNumber"]}',
              album: "${event.reciter.name}",
              title: sName,
              // أضف صورة افتراضية أو صورة القارئ إن وجدت
              artUri: Uri.parse(
                  "https://raw.githubusercontent.com/quran-muslim-app/assets/main/logo.png"),
            ),
          );
        }).toList();

        // 5. تهيئة جلسة الصوت
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration.speech());

        // 6. التحميل والتشغيل
        try {
          await audioPlayer.setAudioSource(
            ConcatenatingAudioSource(children: playList),
            initialIndex: event.initialIndex,
          );
          await audioPlayer.setSpeed(1.0);
          audioPlayer.play();

          // تحديد مصدر الاستماع: صوتيات (بث) أو تحميلات (ملفات محلية)
          try {
            final bool isLocalFirst =
                (reciterLinks[event.initialIndex]["isLocal"] == true);
            updateValue(
                "listening_source", isLocalFirst ? "downloads" : "audio");
          } catch (_) {}

          // --- التعديل المطلوب لضبط دقة الوقت ومنع التكرار ---
          DateTime startTime = DateTime.now();
          bool isProcessing = false;

          audioPlayer.playerStateStream.listen((state) async {
            // ✅ تم تعديل الشرط: نحسب فقط عند التوقف الحقيقي (Pause) أو انتهاء السورة
            // استبعدنا حالة Loading أو Buffering لضمان دقة الحساب
            bool shouldCalculate = !state.playing ||
                state.processingState == ProcessingState.completed;

            if (shouldCalculate && !isProcessing) {
              isProcessing = true;

              final now = DateTime.now();
              final seconds = now.difference(startTime).inSeconds;

              // ✅ الحماية القصوى: لا نسجل إلا إذا استمع المستخدم لأكثر من 3 ثوانٍ حقيقية
              // هذا يمنع تسجيل "الثواني الوهمية" الناتجة عن أخطاء الـ Stream
              final src = (getValue("listening_source") ?? "").toString();
              if (seconds > 3 && (src == "audio" || src == "downloads")) {
                final dateKey = DateFormat('yyyy-MM-dd').format(now);

                // جلب القيم الحالية
                int currentTotal = int.tryParse(
                        getValue("quran_listening-totalSeconds")?.toString() ??
                            "0") ??
                    0;
                int currentDay = int.tryParse(
                        getValue("$dateKey-quran_listening-seconds")
                                ?.toString() ??
                            "0") ??
                    0;

                // التحديث
                updateValue(
                    "quran_listening-totalSeconds", currentTotal + seconds);
                updateValue(
                    "$dateKey-quran_listening-seconds", currentDay + seconds);

                debugPrint("📊 تم تسجيل: $seconds ثانية استماع حقيقية");
              }

              // أهم سطرين: تصفير العداد فوراً بعد الحساب لمنع التراكم
              startTime = DateTime.now();
              await Future.delayed(const Duration(milliseconds: 500));
              isProcessing = false;
            } else if (state.playing) {
              // إذا عاد للتشغيل، نبدأ الحساب من جديد من هذه اللحظة
              startTime = DateTime.now();
            }
          });
          // --------------------------------------------------

          playerbarBloc.add(ShowBarEvent());
          emit(PlayerBlocPlaying(
              moshaf: event.moshaf,
              reciter: event.reciter,
              suraNumber: event.suraNumber == -1
                  ? int.parse(surahNumbers[0])
                  : event.suraNumber,
              jsonData: event.jsonData,
              audioPlayer: audioPlayer,
              surahNumbers: surahNumbers,
              playList: playList));
        } catch (e) {
          debugPrint("❌ Fatal Playback Error: $e");
          // هنا يمكن إضافة محاولات إعادة التشغيل التي كنت تستخدمها
        }
      } else if (event is DownloadSurah) {
        await _requestPermissions();
        final arnousDir = Directory("/storage/emulated/0/Download/arnous/");
        if (!await arnousDir.exists()) {
          await arnousDir.create(recursive: true);
        }
        final dio = Dio();
        String suraName = getSurahNameArabic(int.parse(event.suraNumber));
        String filePath =
            "${arnousDir.path}${event.reciter.name}-${event.moshaf.id}-$suraName.mp3";
        if (File(filePath).existsSync()) {
          Fluttertoast.showToast(msg: "هذه السورة محملة بالفعل");
          return;
        }
        try {
          await dio.download(event.url, filePath);
          final file = File(filePath);
          int fileSize = await file.length();
          await _addDownloadedSurahEntry(
            reciterName: event.reciter.name.toString(),
            surahNumber: int.parse(event.suraNumber),
            suraNameArabic: suraName,
            filePath: filePath,
            fileSize: fileSize,
            source: "audio_moshaf",
            extra: {"moshafId": event.moshaf.id},
          );
          Fluttertoast.showToast(msg: "تم تحميل السورة بنجاح");
        } catch (e) {
          debugPrint("DownloadSurah error: $e");
          Fluttertoast.showToast(msg: "فشل تحميل السورة");
        }
      } else if (event is DownloadAllSurahs) {
        await _requestPermissions();
        final arnousDir = Directory("/storage/emulated/0/Download/arnous/");
        if (!await arnousDir.exists()) {
          await arnousDir.create(recursive: true);
        }
        final dio = Dio();
        List<String> surahNumbers = event.moshaf.surahList.split(',');
        int total = surahNumbers.length;
        int completed = 0;
        for (final s in surahNumbers) {
          String suraName = getSurahNameArabic(int.parse(s));
          String filePath =
              "${arnousDir.path}${event.reciter.name}-${event.moshaf.id}-$suraName.mp3";
          if (File(filePath).existsSync()) {
            completed++;
            Fluttertoast.showToast(
                msg: "تم تحميل $completed/$total سورة",
                toastLength: Toast.LENGTH_SHORT);
            continue;
          }
          String url =
              "${event.moshaf.server}/${s.toString().padLeft(3, "0")}.mp3";
          try {
            await dio.download(url, filePath);
            final file = File(filePath);
            int fileSize = await file.length();
            await _addDownloadedSurahEntry(
              reciterName: event.reciter.name.toString(),
              surahNumber: int.parse(s),
              suraNameArabic: suraName,
              filePath: filePath,
              fileSize: fileSize,
              source: "audio_moshaf",
              extra: {"moshafId": event.moshaf.id},
            );
            completed++;
            Fluttertoast.showToast(
                msg: "تم تحميل $completed/$total سورة",
                toastLength: Toast.LENGTH_SHORT);
          } catch (e) {
            debugPrint("DownloadAllSurahs error on $s: $e");
          }
        }
        Fluttertoast.showToast(msg: "اكتمل تحميل المصحف");
      }
    });
  }

  // طلب صلاحيات التخزين بطريقة متوافقة مع Scoped Storage
  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      // نطلب كلاهما ويتعامل النظام مع المتاح حسب إصدار الأندرويد
      await [Permission.storage, Permission.audio].request();
    }
  }

  Future<void> _addDownloadedSurahEntry({
    required String reciterName,
    required int surahNumber,
    required String suraNameArabic,
    required String filePath,
    required int fileSize,
    required String source,
    Map<String, dynamic>? extra,
  }) async {
    try {
      dynamic raw = getValue("downloadedSurahs");
      List list;
      if (raw is String && raw.isNotEmpty) {
        list = json.decode(raw) as List;
      } else {
        list = [];
      }
      bool exists = list.any((e) =>
          e is Map && e["filePath"] != null && e["filePath"] == filePath);
      if (exists) {
        return;
      }
      final entry = {
        "reciterName": reciterName,
        "surahNumber": surahNumber,
        "suraNameArabic": suraNameArabic,
        "filePath": filePath,
        "fileSize": fileSize,
        "source": source,
        "extra": extra ?? {},
      };
      list.add(entry);
      updateValue("downloadedSurahs", json.encode(list));
    } catch (e) {
      debugPrint("addDownloadedSurahEntry error: $e");
    }
  }
}
