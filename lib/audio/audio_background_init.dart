import 'package:just_audio_background/just_audio_background.dart';

Future<void> initAudioBackground() async {
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.hanyarnous.quranpresence.channel.audio',
    androidNotificationChannelName: 'في رحاب الرحمن',
    androidNotificationOngoing: true,
    androidNotificationIcon: 'mipmap/ic_launcher',
  );
}
