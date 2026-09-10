import 'package:just_audio_background/just_audio_background.dart';

Future<void> initAudioBackground() async {
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.quran.muslim.channel.audio',
    androidNotificationChannelName: 'في رحاب القرآن',
    androidNotificationOngoing: true,
    androidNotificationIcon: 'mipmap/ic_launcher',
  );
}
