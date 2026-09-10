part of 'player_bar_bloc.dart';

@immutable
abstract class PlayerBarEvent {}

/// ✅ حدث التشغيل الرئيسي (Play)
/// هذا الحدث يرسل البيانات لـ JustAudioBackground لتظهر في شريط إشعارات الهاتف
class PlayAudioEvent extends PlayerBarEvent {
  final String id;      // معرف فريد للمقطع البرمجي
  final String url;     // رابط الملف الصوتي MP3
  final String title;   // العنوان الذي يظهر للمستخدم في الإشعارات
  final String artist;  // اسم القارئ أو المنشد الظاهر في الإشعارات
  final String image;   // رابط صورة الغلاف التي تظهر في الخلفية

  PlayAudioEvent({
    required this.id,
    required this.url,
    required this.title,
    required this.artist,
    required this.image,
  });
}

/// ✅ حدث التبديل بين التشغيل والإيقاف المؤقت (Toggle Play/Pause)
/// يربط زر الواجهة بحالة المشغل الحقيقية
class TogglePlayPauseEvent extends PlayerBarEvent {}

/// ✅ حدث إيقاف الصوت تماماً (Stop)
class StopAudioEvent extends PlayerBarEvent {}

/// 🔹 أحداث التحكم في شكل واجهة المستخدم (UI Appearance)
/// تستخدم لتغيير ارتفاع الشريط أو إخفائه بناءً على حركة المستخدم
class HideBarEvent extends PlayerBarEvent {}

class ShowBarEvent extends PlayerBarEvent {}

class ExtendBarEvent extends PlayerBarEvent {}

class MinimizeBarEvent extends PlayerBarEvent {}

class CloseBarEvent extends PlayerBarEvent {}