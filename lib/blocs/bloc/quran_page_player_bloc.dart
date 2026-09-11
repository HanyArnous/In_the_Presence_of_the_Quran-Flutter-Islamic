import 'dart:async';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:bloc/bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:meta/meta.dart';
import 'package:nabd/main.dart';
import 'package:nabd/GlobalHelpers/hive_helper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran/reciters.dart';
import 'package:nabd/blocs/bloc/bloc/player_bar_bloc.dart';

part 'quran_page_player_event.dart';
part 'quran_page_player_state.dart';

class QuranPagePlayerBloc
    extends Bloc<QuranPagePlayerEvent, QuranPagePlayerState> {
  // --- تكرار الآيات/الصفحات (وضع الحفظ) ---
  StreamSubscription<int?>? _repeatIndexSub;
  StreamSubscription<Duration>? _repeatPosSub;
  int _repeatLeft = 0; // مرات الإعادة المتبقية بعد التشغيلة الجارية
  int _anchorIndex = 0; // فهرس الآية/بداية الصفحة في قائمة السورة
  int _pageEndIndex = -1; // فهرس آخر آية في الصفحة (وضع page فقط)
  Duration? _lastRepeatPos;

  QuranPagePlayerBloc() : super(QuranPagePlayerInitial()) {
    on<QuranPagePlayerEvent>((event, emit) async {
      if (event is PlayFromVerse) {
        final reciterMatch = reciters.firstWhere(
          (element) => element["identifier"] == event.reciterIdentifier,
          orElse: () => null,
        );
        if (reciterMatch == null) {
          return;
        }

        final totalVerses = quran.getVerseCount(event.surahNumber);
        final initialIndex = event.verse - 1;

        final children = <AudioSource>[];
        final appDir = await getTemporaryDirectory();
        final suraName =
            quran.getSurahNameArabic(event.surahNumber).replaceAll(" ", "");

        for (var verse = 1; verse <= totalVerses; verse++) {
          final audioUrl = quran.getAudioURLByVerse(
            event.surahNumber,
            verse,
            event.reciterIdentifier,
          );

          final localFilePath =
              '${appDir.path}/${event.reciterIdentifier}-$suraName-$verse.mp3';
          final uri = File(localFilePath).existsSync()
              ? Uri.file(localFilePath)
              : Uri.parse(audioUrl);

          children.add(
            AudioSource.uri(
              uri,
              tag: MediaItem(
                id: "${event.surahNumber}:$verse",
                album: reciterMatch["englishName"],
                title: quran.getSurahNameArabic(event.surahNumber),
                artUri: Uri.parse(
                  "https://images.pexels.com/photos/318451/pexels-photo-318451.jpeg",
                ),
              ),
            ),
          );
        }

        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration.speech());

        try {
          await audioPlayer.setAudioSource(
            ConcatenatingAudioSource(
              children: children,
            ),
            initialIndex: initialIndex,
          );
          final speed =
              ((getValue("quranAudioSpeed") ?? 1.0) as num).toDouble();
          await audioPlayer.setSpeed(speed.clamp(0.5, 2.0));
        } catch (e) {
          final fullPath =
              '${appDir.path}-${event.reciterIdentifier}-$suraName.mp3';
          if (File(fullPath).existsSync()) {
            await audioPlayer.setAudioSource(
              AudioSource.uri(
                Uri.file(fullPath),
                tag: MediaItem(
                  id: "${event.surahNumber}:full",
                  album: reciterMatch["englishName"],
                  title: quran.getSurahNameArabic(event.surahNumber),
                  artUri: Uri.parse(
                    "https://images.pexels.com/photos/318451/pexels-photo-318451.jpeg",
                  ),
                ),
              ),
            );
            final speed =
                ((getValue("quranAudioSpeed") ?? 1.0) as num).toDouble();
            await audioPlayer.setSpeed(speed.clamp(0.5, 2.0));
            // ملف السورة الكامل لا يدعم التكرار الجزئي — تأكد من إطفاء أي Loop سابق
            // (المشغّل مشترك مع مشغّل السور) ثم شغّل طبيعياً.
            try {
              await audioPlayer.setLoopMode(LoopMode.off);
            } catch (_) {}
            _cancelRepeat();
            await audioPlayer.play();
            emit(
              QuranPagePlayerPlaying(
                player: audioPlayer,
                audioIndexStream: audioPlayer.currentIndexStream,
                suraNumber: event.surahNumber,
                totalVerses: totalVerses,
                initialIndex: 0,
                reciter: reciterMatch,
              ),
            );
            return;
          } else {
            return;
          }
        }

        audioPlayer.play();
        playerbarBloc.add(ShowBarEvent());

        // طبّق وضع التكرار المختار من الشيت على هذا التشغيل
        await _startRepeatEnforcement(
          startIndex: initialIndex,
          totalVerses: totalVerses,
          pageStartVerse: event.pageStartVerse,
          pageEndVerse: event.pageEndVerse,
        );

        emit(
          QuranPagePlayerPlaying(
            player: audioPlayer,
            audioIndexStream: audioPlayer.currentIndexStream,
            suraNumber: event.surahNumber,
            totalVerses: totalVerses,
            initialIndex: initialIndex,
            reciter: reciterMatch,
          ),
        );
      } else if (event is PausePlaying) {
        if (audioPlayer.playing) {
          await audioPlayer.pause();
          emit(QuranPagePlayerIdle());
        } else {
          await audioPlayer.play();
          if (state is QuranPagePlayerPlaying) {
            emit(
              QuranPagePlayerPlaying(
                player: audioPlayer,
                audioIndexStream: audioPlayer.currentIndexStream,
                suraNumber: (state as QuranPagePlayerPlaying).suraNumber,
                totalVerses: (state as QuranPagePlayerPlaying).totalVerses,
                initialIndex: (state as QuranPagePlayerPlaying).initialIndex,
                reciter: (state as QuranPagePlayerPlaying).reciter,
              ),
            );
          } else {
            emit(QuranPagePlayerInitial());
          }
        }
      } else if (event is StopPlaying) {
        _cancelRepeat();
        try {
          await audioPlayer.setLoopMode(LoopMode.off);
        } catch (_) {}
        await audioPlayer.stop();
        emit(QuranPagePlayerInitial());
      } else if (event is KillPlayerEvent) {
        _cancelRepeat();
        try {
          await audioPlayer.setLoopMode(LoopMode.off);
        } catch (_) {}
        await audioPlayer.stop();
        emit(QuranPagePlayerInitial());
      } else if (event is SetSpeed) {
        final newSpeed = event.speed.clamp(0.5, 2.0);
        await audioPlayer.setSpeed(newSpeed);
        if (state is QuranPagePlayerPlaying) {
          emit(
            QuranPagePlayerPlaying(
              player: audioPlayer,
              audioIndexStream: audioPlayer.currentIndexStream,
              suraNumber: (state as QuranPagePlayerPlaying).suraNumber,
              totalVerses: (state as QuranPagePlayerPlaying).totalVerses,
              initialIndex: (state as QuranPagePlayerPlaying).initialIndex,
              reciter: (state as QuranPagePlayerPlaying).reciter,
            ),
          );
        } else {
          emit(QuranPagePlayerInitial());
        }
      } else if (event is SetQuranRepeatMode) {
        updateValue("quran_repeatMode", event.mode);
        updateValue("quran_repeatCount", event.count);
        if (state is QuranPagePlayerPlaying) {
          final playing = state as QuranPagePlayerPlaying;
          final currentIdx =
              audioPlayer.currentIndex ?? playing.initialIndex;
          _startRepeatEnforcement(
            startIndex: currentIdx,
            totalVerses: playing.totalVerses,
            pageStartVerse: event.pageStartVerse,
            pageEndVerse: event.pageEndVerse,
          );
        }
      }
    });
  }

  @override
  Future<void> close() {
    _cancelRepeat();
    return super.close();
  }

  void _cancelRepeat() {
    try {
      _repeatIndexSub?.cancel();
    } catch (_) {}
    try {
      _repeatPosSub?.cancel();
    } catch (_) {}
    _repeatIndexSub = null;
    _repeatPosSub = null;
    _repeatLeft = 0;
    _pageEndIndex = -1;
    _lastRepeatPos = null;
  }

  String _storedRepeatMode() {
    try {
      final m = getValue("quran_repeatMode")?.toString() ?? "continuous";
      if (m == "ayah" || m == "page" || m == "none") return m;
      return "continuous";
    } catch (_) {
      return "continuous";
    }
  }

  int _storedRepeatCount() {
    try {
      final c = (getValue("quran_repeatCount") ?? 3) as num;
      return c.toInt().clamp(1, 20);
    } catch (_) {
      return 3;
    }
  }

  /// يطبّق وضع التكرار المخزن على التشغيل الجاري بدءاً من [startIndex]
  /// (فهرس داخل قائمة آيات السورة). آمن الاستدعاء المتكرر: يلغي القديم أولاً.
  Future<void> _startRepeatEnforcement({
    required int startIndex,
    required int totalVerses,
    int? pageStartVerse,
    int? pageEndVerse,
  }) async {
    _cancelRepeat();
    final mode = _storedRepeatMode();
    final count = _storedRepeatCount();
    _anchorIndex = startIndex.clamp(0, totalVerses > 0 ? totalVerses - 1 : 0);
    try {
      if (mode == "continuous") {
        await audioPlayer.setLoopMode(LoopMode.off);
        return;
      }
      if (mode == "ayah") {
        // تكرار الآية الحالية N مرات ثم المتابعة للآية التالية
        _repeatLeft = count - 1;
        await audioPlayer.setLoopMode(LoopMode.one);
        _repeatPosSub = audioPlayer.positionStream.listen((pos) async {
          try {
            final dur = audioPlayer.duration;
            final last = _lastRepeatPos;
            _lastRepeatPos = pos;
            if (dur == null || dur.inMilliseconds <= 0 || last == null) return;
            final nearEnd =
                last.inMilliseconds >= (dur.inMilliseconds * 0.8).toInt();
            final wrapped = pos.inMilliseconds < last.inMilliseconds - 500;
            if (nearEnd && wrapped) {
              if (_repeatLeft > 0) {
                _repeatLeft--;
              } else {
                await audioPlayer.setLoopMode(LoopMode.off);
                try {
                  await _repeatPosSub?.cancel();
                } catch (_) {}
                _repeatPosSub = null;
                await audioPlayer.seekToNext();
              }
            }
          } catch (_) {}
        });
        return;
      }
      if (mode == "page") {
        // تكرار نطاق الصفحة N مرات ثم المتابعة
        int s = ((pageStartVerse ?? (startIndex + 1)) - 1)
            .clamp(0, totalVerses > 0 ? totalVerses - 1 : 0);
        int e = ((pageEndVerse ?? totalVerses) - 1)
            .clamp(s, totalVerses > 0 ? totalVerses - 1 : 0);
        _anchorIndex = s;
        _pageEndIndex = e;
        _repeatLeft = count - 1;
        await audioPlayer.setLoopMode(LoopMode.off);
        _repeatIndexSub =
            audioPlayer.currentIndexStream.listen((idx) async {
          try {
            if (idx == null || !audioPlayer.playing) return;
            if (idx > _pageEndIndex) {
              if (_repeatLeft > 0) {
                _repeatLeft--;
                await audioPlayer.seek(Duration.zero, index: _anchorIndex);
              } else {
                // انتهت الإعادات — أكمل طبيعياً
                try {
                  await _repeatIndexSub?.cancel();
                } catch (_) {}
                _repeatIndexSub = null;
              }
            }
          } catch (_) {}
        });
        return;
      }
      // none = مرة واحدة: أوقف عند مغادرة الآية
      await audioPlayer.setLoopMode(LoopMode.off);
      _repeatIndexSub = audioPlayer.currentIndexStream.listen((idx) async {
        try {
          if (idx == null || !audioPlayer.playing) return;
          if (idx != _anchorIndex) {
            try {
              await _repeatIndexSub?.cancel();
            } catch (_) {}
            _repeatIndexSub = null;
            await audioPlayer.pause();
          }
        } catch (_) {}
      });
    } catch (_) {}
  }
}
