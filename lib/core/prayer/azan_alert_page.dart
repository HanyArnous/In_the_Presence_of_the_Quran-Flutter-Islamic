import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'azan_native_bridge.dart';
import 'prayer_service.dart';

/// شاشة تنبيه الأذان بملء الشاشة.
///
/// التشغيل الأساسي عبر الخدمة الأمامية native (الملف كاملاً على مسار
/// المنبه حتى لو التطبيق كان مغلقاً). مشغّل [AudioPlayer] هنا بديل فقط
/// للمنصات غير Android أو عند فشل القناة الأصلية — وبدون أي إيقاف
/// تلقائي مبكر: يتوقف فقط عند انتهاء الملف أو زر الإيقاف.
class AzanAlertPage extends StatefulWidget {
  final String englishName;
  final String arabicName;

  const AzanAlertPage({
    super.key,
    this.englishName = '',
    this.arabicName = 'الصلاة',
  });

  @override
  State<AzanAlertPage> createState() => _AzanAlertPageState();
}

class _AzanAlertPageState extends State<AzanAlertPage> {
  AudioPlayer? _fallbackPlayer;
  bool _playing = true;
  bool _usedNative = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _startFullAzan();
  }

  Future<void> _startFullAzan() async {
    // 1) الخدمة الأمامية native (كامل الملف)
    _usedNative = await AzanNativeBridge.playNow(
      prayerName: widget.arabicName,
      prayerEn: widget.englishName,
    );
    if (_usedNative) {
      setState(() => _playing = true);
      return;
    }
    // 2) بديل Dart للمنصات الأخرى: تشغيل كامل بدون مؤقت إيقاف
    try {
      final player = AudioPlayer();
      _fallbackPlayer = player;
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(1.0);
      player.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _playing = false);
      });
      await player.play(AssetSource('audio/azan.mp3'));
      if (mounted) setState(() => _playing = true);
    } catch (e) {
      debugPrint('AzanAlert fallback play failed: $e');
      if (mounted) setState(() => _playing = false);
    }
  }

  Future<void> _stopAndClose() async {
    try {
      await AzanNativeBridge.stop();
    } catch (_) {}
    try {
      await _fallbackPlayer?.stop();
    } catch (_) {}
    try {
      await PrayerService.dismissAzanNotification();
    } catch (_) {}
    await AzanNativeBridge.clearPendingAzan();
    if (mounted) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _fallbackPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // زر الرجوع يوقف الأذان بدل تركه يعمل في الخلفية مفاجأة للمستخدم
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        AzanNativeBridge.stop();
        _fallbackPlayer?.stop();
        PrayerService.dismissAzanNotification();
        AzanNativeBridge.clearPendingAzan();
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xff1B3A2B), Color(0xff6B8E4E)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mosque, size: 90.sp, color: Colors.white),
                  SizedBox(height: 16.h),
                  Text(
                    'حان وقت ${widget.arabicName}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 28.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    _playing ? 'جاري تشغيل الأذان كاملاً' : 'انتهى الأذان - تقبّل الله',
                    style: TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 15.sp,
                      color: Colors.white70,
                    ),
                  ),
                  SizedBox(height: 24.h),
                  if (_playing)
                    const CircularProgressIndicator(color: Colors.white)
                  else
                    Icon(Icons.check_circle,
                        size: 48.sp, color: Colors.white),
                  SizedBox(height: 32.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _stopAndClose,
                      icon: const Icon(Icons.stop),
                      label: const Text('إيقاف الأذان',
                          style: TextStyle(fontFamily: 'cairo', fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xff1B3A2B),
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
