import 'package:bloc/bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:meta/meta.dart';

// ✅ ملاحظة: استيراد المشغل العالمي من الـ main لضمان التحكم الموحد
import 'package:nabd/main.dart'; 

part 'player_bar_event.dart';
part 'player_bar_state.dart';

class PlayerBarBloc extends Bloc<PlayerBarEvent, PlayerBarState> {
  PlayerBarBloc() : super(const PlayerBarInitial(height: 60)) {
    
    /// 1. حدث تشغيل الصوت الرئيسي
    /// هذا الحدث هو المسؤول عن إرسال البيانات لنظام التشغيل لتظهر في شريط الإشعارات
    on<PlayAudioEvent>((event, emit) async {
      try {
        final source = AudioSource.uri(
          Uri.parse(event.url),
          // ✅ إضافة الـ MediaItem ضروري جداً للتحكم الخارجي (خارج التطبيق)
          tag: MediaItem(
            id: event.id,
            album: "سكون", 
            title: event.title,
            artist: event.artist,
            artUri: Uri.parse(event.image),
          ),
        );

        // تحميل الملف وتشغيله
        await audioPlayer.setAudioSource(source);
        await audioPlayer.setSpeed(1.0);
        await audioPlayer.play();
        
        // تحديث الواجهة لتصبح مرئية بارتفاع أكبر عند التشغيل
        emit(const PlayerBarVisible(height: 70)); 
      } catch (e) {
        print("خطأ في تشغيل المقطع الصوتي: $e");
      }
    });

    /// 2. حدث التبديل (Play/Pause)
    /// يُستخدم هذا الحدث لربط زر التشغيل في الواجهة مع المشغل العالمي
    on<TogglePlayPauseEvent>((event, emit) async {
      if (audioPlayer.playing) {
        await audioPlayer.pause();
      } else {
        await audioPlayer.play();
      }
    });

    /// 3. حدث إيقاف الصوت (Stop)
    on<StopAudioEvent>((event, emit) async {
      await audioPlayer.stop();
      emit(const PlayerBarInitial(height: 60));
    });

    /// 4. أحداث التحكم في مظهر شريط المشغل (UI height)
    on<HideBarEvent>((event, emit) => emit(const PlayerBarHidden()));
    
    on<ShowBarEvent>((event, emit) => emit(const PlayerBarVisible(height: 60)));
    
    on<MinimizeBarEvent>((event, emit) => emit(const PlayerBarVisible(height: 60)));
    
    on<ExtendBarEvent>((event, emit) => emit(const PlayerBarVisible(height: 70)));

    /// 5. حدث إغلاق الشريط تماماً
    on<CloseBarEvent>((event, emit) {
       audioPlayer.stop();
       emit(const PlayerBarClosed());
    });
  }
}