part of 'player_bloc_bloc.dart';

@immutable
class PlayerBlocEvent {}

class StartPlaying extends PlayerBlocEvent {
  Moshaf moshaf;
  Reciter reciter;
  int suraNumber;
  BuildContext buildContext;
  // String suraName;
  List jsonData;
  var audioPlayer;
  int initialIndex;

  StartPlaying({
    required this.moshaf,
    required this.reciter,
    required this.suraNumber,
    required this.initialIndex,required this.buildContext,
    // required this.suraName,
    required this.jsonData,
  });
}

class DownloadSurah extends PlayerBlocEvent {
   Moshaf moshaf;
  Reciter reciter;
  String suraNumber;
  String url;
  DownloadSurah({
    required this.reciter,
    required this.moshaf,
    required this.suraNumber,
    required this.url,// required String surahName,
  });
}


class DownloadAllSurahs extends PlayerBlocEvent {
 Moshaf moshaf;
  Reciter reciter;
  DownloadAllSurahs({
    required this.moshaf,
    required this.reciter,
  });

}

class CancelDownload extends PlayerBlocEvent {
  final String key;
  CancelDownload(this.key);
}

class ClosePlayerEvent extends PlayerBlocEvent {}
class PausePlayer extends PlayerBlocEvent {}

/// مزامنة شريط المشغل مع تشغيل صفحات القرآن (QuranPagePlayerBloc).
/// يعرض الاسم فقط دون المساس بالمشغّل — التشغيل الفعلي يديره بلوك الصفحات.
class SyncQuranPagePlaying extends PlayerBlocEvent {
  final String reciterName;
  final int suraNumber;
  SyncQuranPagePlaying({required this.reciterName, required this.suraNumber});
}
