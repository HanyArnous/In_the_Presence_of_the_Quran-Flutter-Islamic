# Version 4.6.5 Release Notes - Google Play Store

**Developer:** HANY_ARNOUS  
**GitHub:** https://github.com/HanyArnous  
**Release Date:** 15 سبتمبر 2026  
**Version:** 4.6.5+465 (Previous: 4.6.4+464)

---

## 🇸🇦 ملاحظات الإصدار للمتجر (العربية)

**ما الجديد في 4.6.5:**

**🔧 إصلاحات توافق Android 15 (SDK 35):**
- تفعيل العرض حتى حافة الشاشة (Edge-to-Edge) بشكل كامل عبر `enableEdgeToEdge()` و `WindowCompat.setDecorFitsSystemWindows` مع ألوان شريط حالة وتنقل شفافة. تمت معالجة جميع الـ insets عبر `SafeArea` لضمان عدم اختفاء المحتوى خلف الأشرطة على Android 15.
- استبدال جميع واجهات برمجة التطبيقات المتوقفة الخاصة بالـ Window (مثل `FLAG_TRANSLUCENT_STATUS` و `SYSTEM_UI_FLAG_*`) بالـ APIs الحديثة `WindowInsetsController` / `WindowCompat`.
- إصلاح تحذير "أنواع الخدمات المحظورة في المقدمة عبر BOOT_COMPLETED": مستقبل `AzanBootReceiver` لم يعد يطلق أي خدمة أمامية مباشرة عند الإقلاع، بل يضع علامة `needs_reschedule` ويستخدم `goAsync()` ويترك لـ Flutter إعادة جدولة منبهات الأذان عبر `AlarmManager` عند أول فتح للتطبيق، مع تصحيح `android:exported="true"` للمستقبلات التي تستمع لـ `BOOT_COMPLETED`.

**🔔 إصلاح الإشعارات:**
- مراجعة إشعار "الصلاة على النبي" الأول في شاشة الإشعارات: تم إزالة زر "إيقاف" الذي كان يظهر عن طريق الخطأ (كان يستخدم قناة `prayer_channel_v2` الخاصة بالأذان). الآن يستخدم قناة `zikr_channel_v2` بدون زر إيقاف وقابل للإزالة كأي ذكر عادي. إشعار الأذان الحقيقي فقط هو من يحتفظ بزر الإيقاف وخدمته الأمامية `mediaPlayback`.

**🎵 تحسينات المشغل والتحميل:**
- (من 4.6.4) شريط تقديم مصغر مع الوقت في البلاير السفلي، إظهار نسبة ومساحة التحميل أثناء التنزيل، جدول مواقيت الصلاة حسب البلد/المحافظة، تثبيت أيقونة الترس في الوضع العمودي للقرآن.

**⚙️ تحسينات تقنية:**
- رفع `compileSdk` و `targetSdk` إلى 35، إضافة `androidx.activity:activity-ktx:1.9.2` و `androidx.core:core-ktx:1.13.1`، تحديث `styles.xml` لدعم Edge-to-Edge، تحسين `MainActivity` ليتوافق مع Android 15 والإصدارات الأقدم.

**الجودة الفنية:** تم حل جميع تحذيرات Play Console الخاصة بـ "Forbidden foreground service types" و "Edge-to-Edge" و "Deprecated window APIs".

---

## 🇬🇧 Play Store Release Notes (English)

**What's new in 4.6.5:**

**Android 15 (SDK 35) Compliance:**
- Full Edge-to-Edge support via `enableEdgeToEdge()` and `WindowCompat.setDecorFitsSystemWindows(window, false)` with transparent status/navigation bars. All insets handled via Flutter `SafeArea` so content is never hidden behind system bars on Android 15.
- Replaced all deprecated Window APIs (`FLAG_TRANSLUCENT_STATUS`, `SYSTEM_UI_FLAG_*`, `setStatusBarColor` flags) with modern `WindowInsetsController` / `WindowCompat` APIs.
- Fixed "Forbidden foreground service types launched via BOOT_COMPLETED" warning: `AzanBootReceiver` no longer starts any foreground service on boot. It only sets `needs_reschedule` flag using `goAsync()` and lets Flutter reschedule exact alarms via `AlarmManager` on next cold start. Also corrected `android:exported="true"` for BOOT receivers and kept `AzanForegroundService` (`mediaPlayback`) triggered only from `AzanAlarmReceiver` (exact alarm) and user action, not from boot.

**Notifications Fix:**
- Reviewed first notification ("Salat ala Nabi") in Notifications screen: removed erroneous "Stop" button (was incorrectly using `prayer_channel_v2` Azan channel). Now uses `zikr_channel_v2` without stop action and is dismissible; only real Azan notifications keep the stop action and `mediaPlayback` foreground service.

**Technical:**
- Bumped `compileSdk`/`targetSdk` to 35, added `androidx.activity:activity-ktx:1.9.2` & `androidx.core:core-ktx:1.13.1`, updated `NormalTheme` for transparent bars and `windowOptOutEdgeToEdgeEnforcement=false`, enhanced `MainActivity.onCreate` and `QuranDetailsPage` immersive handling for edge-to-edge.

**Version:** 4.6.5 (465) — All Play Console pre-launch warnings resolved.

---

## 📋 Technical Details

- **Version bump:** `pubspec.yaml` 4.6.4+464 → 4.6.5+465
- **Android:** `android/app/build.gradle.kts` compileSdk/targetSdk 35, dependencies added
- **Manifest:** `AzanBootReceiver` & `ScheduledNotificationBootReceiver` exported=true, comment no FGS on boot, `AzanForegroundService` mediaPlayback unchanged
- **Kotlin:** `MainActivity.kt` enableEdgeToEdge, `AzanAlarm.kt` goAsync boot handling
- **Flutter:** `quranDetailsPage.dart` transparent overlay style, `messaging_helper.dart` & `workmanager_handler.dart` channel fix
- **Test:** `flutter analyze` — 0 errors, Play pre-launch warnings cleared

---

*Prepared for Play Store submission — 4.6.5*
