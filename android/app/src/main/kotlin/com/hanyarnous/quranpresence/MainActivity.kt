package com.hanyarnous.quranpresence

import com.ryanheise.audioservice.AudioServiceActivity

// ✅ هذه الـ Activity يجب أن ترث من AudioServiceActivity عند استخدام just_audio_background/audio_service
//   حتى يتمكن الـ plugin من الحصول على FlutterEngine الصحيح للتحكم في مشغّل الصوت بالخلفية.
class MainActivity : AudioServiceActivity() {
}