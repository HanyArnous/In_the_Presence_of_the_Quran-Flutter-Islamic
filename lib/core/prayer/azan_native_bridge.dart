import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// جسر Dart للخدمة الأمامية native التي تشغّل الأذان كاملاً.
///
/// على Android: يضبط منبهات دقيقة عبر AlarmManager تشغّل
/// [AzanForegroundService] التي تلعب ملف res/raw/azan.mp3 كاملاً
/// على مسار المنبه (USAGE_ALARM) حتى لو التطبيق مقتول.
/// على باقي المنصات: يعيد false ويُستخدم مشغّل AudioPlayer كبديل.
class AzanNativeBridge {
  static const MethodChannel _channel =
      MethodChannel('com.hanyarnous.quranpresence/azan');

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  /// جدولة قائمة منبهات: كل عنصر {id, timeMillis, prayerName, prayerEn}
  static Future<int> scheduleAzan(
      List<Map<String, dynamic>> items) async {
    if (!isSupported || items.isEmpty) return 0;
    try {
      final ok = await _channel.invokeMethod<int>(
        'scheduleAzan',
        {'items': items},
      );
      return ok ?? 0;
    } on MissingPluginException {
      return 0;
    } catch (e) {
      debugPrint('AzanBridge.scheduleAzan failed: $e');
      return 0;
    }
  }

  static Future<void> cancelAzan({List<int>? ids}) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('cancelAzan', {'ids': ids});
    } catch (e) {
      debugPrint('AzanBridge.cancelAzan failed: $e');
    }
  }

  /// تشغيل الأذان كاملاً الآن عبر الخدمة الأمامية.
  /// يعيد true لو بدأت الخدمة native، و false لو يجب استخدام بديل Dart.
  static Future<bool> playNow({String prayerName = 'الصلاة', String prayerEn = ''}) async {
    if (!isSupported) return false;
    try {
      await _channel.invokeMethod('playAzan', {
        'prayerName': prayerName,
        'prayerEn': prayerEn,
      });
      return true;
    } on MissingPluginException {
      return false;
    } catch (e) {
      debugPrint('AzanBridge.playNow failed: $e');
      return false;
    }
  }

  static Future<void> stop() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('stopAzan');
    } catch (e) {
      debugPrint('AzanBridge.stop failed: $e');
    }
  }

  /// أذان معلّق (رنّ والجهاز كان مغلقاً) صالح لمدة 10 دقائق.
  static Future<Map<String, String>?> getPendingAzan() async {
    if (!isSupported) return null;
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('getPendingAzan');
      if (res == null) return null;
      final name = res['prayerName']?.toString();
      if (name == null || name.isEmpty) return null;
      return {'prayerName': name, 'prayerEn': res['prayerEn']?.toString() ?? ''};
    } catch (e) {
      debugPrint('AzanBridge.getPendingAzan failed: $e');
      return null;
    }
  }

  static Future<void> clearPendingAzan() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('clearPendingAzan');
    } catch (_) {}
  }

  /// هل أعاد الجهاز التشغيل وتحتاج المواقيت إعادة جدولة؟
  static Future<bool> needsReschedule() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('needsReschedule') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// هل يملك التطبيق إذن المنبه الدقيق؟ (مطلوب لعمل الأذان والتطبيق مغلق)
  static Future<bool> canScheduleExact() async {
    if (!isSupported) return true;
    try {
      return await _channel.invokeMethod<bool>('canScheduleExact') ?? true;
    } catch (_) {
      return true;
    }
  }

  /// فتح شاشة إعدادات إذن المنبه الدقيق ليمنحه المستخدم يدوياً.
  static Future<void> openExactAlarmSettings() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('openExactAlarmSettings');
    } catch (_) {}
  }
}
