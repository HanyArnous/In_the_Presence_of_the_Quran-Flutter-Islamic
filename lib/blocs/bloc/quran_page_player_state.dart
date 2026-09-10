part of 'quran_page_player_bloc.dart';

@immutable
class QuranPagePlayerState {}

class QuranPagePlayerInitial extends QuranPagePlayerState {}

class QuranPagePlayerPlaying extends QuranPagePlayerState {
  final Stream<int?> audioIndexStream;
  final AudioPlayer player;
  final int suraNumber;
  final int totalVerses;
  final int initialIndex;
  final dynamic reciter;

  QuranPagePlayerPlaying({
    required this.player,
    required this.audioIndexStream,
    required this.suraNumber,
    required this.totalVerses,
    required this.initialIndex,
    required this.reciter,
  });
}


class QuranPagePlayerStopped extends QuranPagePlayerState {}


class QuranPagePlayerIdle extends QuranPagePlayerState {}
