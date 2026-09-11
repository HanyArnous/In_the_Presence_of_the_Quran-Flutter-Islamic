part of 'quran_page_player_bloc.dart';

@immutable
 class QuranPagePlayerEvent {}

class PlayFromVerse extends QuranPagePlayerEvent{
  final int verse;
  final String reciterIdentifier;
  final int surahNumber;
  final String suraName;
  // حدود الصفحة (أرقام آيات داخل نفس السورة) لوضع تكرار الصفحة — اختياري
  final int? pageStartVerse;
  final int? pageEndVerse;

  PlayFromVerse(this.verse, this.reciterIdentifier, this.surahNumber, this.suraName, {this.pageStartVerse, this.pageEndVerse});

}

class PausePlaying extends QuranPagePlayerEvent{

}

class StopPlaying extends QuranPagePlayerEvent{


}

class KillPlayerEvent extends QuranPagePlayerEvent{
  
}

class SetSpeed extends QuranPagePlayerEvent{
  final double speed;
  SetSpeed(this.speed);
}

// يطبّق وضع التكرار المخزن (continuous | ayah | page | none) على التشغيل الجاري
class SetQuranRepeatMode extends QuranPagePlayerEvent {
  final String mode;
  final int count;
  final int? pageStartVerse;
  final int? pageEndVerse;
  SetQuranRepeatMode({required this.mode, required this.count, this.pageStartVerse, this.pageEndVerse});
}
