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
        await audioPlayer.stop();
        emit(QuranPagePlayerInitial());
      } else if (event is KillPlayerEvent) {
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
      }
    });
  }
}
