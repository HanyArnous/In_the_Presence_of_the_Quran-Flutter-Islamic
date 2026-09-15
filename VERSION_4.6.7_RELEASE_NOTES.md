# Version 4.6.7 Release Notes - Google Play Store

**Developer:** HANY_ARNOUS
**GitHub:** https://github.com/HanyArnous
**Release Date:** 16 سبتمبر 2026
**Version:** 4.6.7+467 (Previous: 4.6.6+466)

---

## 🇸🇦 ملاحظات الإصدار للمتجر (العربية) — انسخ كما هي في Play Console

```
• إصلاح تعليق مكتبة الحديث: كانت الصفحة تفتح فارغة مع علامة تحميل لا تنتهي، الآن تظهر التصنيفات فوراً مع زر إعادة المحاولة ومكتبة بديلة دون اتصال.
• إصلاح تجاوز النص في قائمة التفسير والترجمة (RIGHT OVERFLOWED) للنصوص الطويلة مثل Tafheem-ul-Quran.
• تثبيت العرض حتى حافة الشاشة على Android 15/16 بدون عناصر مخفية خلف الأزرار.
• توافق Play الجديد: رفع targetSdk إلى 36 (كان 35) حسب متطلبات أغسطس 2025+.
```

## 🇬🇧 Play Store Release Notes (English) — paste as-is

```
• Fixed Hadith library stuck on endless loading: categories now load immediately with retry on offline and a local fallback library.
• Fixed translation picker text overflow (RIGHT OVERFLOWED) for long names like Tafheem-ul-Quran.
• Edge-to-edge display stabilization on Android 15/16.
• Play compliance: bumped targetSdk to 36 (was 35) per Aug 2025+ requirement.
```

---

## 📋 Technical Details (للمطور — لا تُرفع للمتجر)

- **Play blocking error fixed:** `targetSdk 35 → 36` في `android/app/build.gradle.kts:24` + تعليق `API 36` في `android/app/build.gradle.kts:16`. كان يسبب رفض Play: "يجب أن يستهدف 36 على الأقل". `compileSdk` بقي `36`، `AGP 8.11.1` + `Gradle 8.14` + `Kotlin 2.2.20` تدعم 36 بدون ترقية.
- **Warning غير حاجب تم تجاهله (الخيار A):** `App Bundle لا يحتوي ملف إزالة تشويش` — صحيح لأن `isMinifyEnabled=false` و `isShrinkResources=false` في `build.gradle.kts:70` (التشويش معطل عمداً). لا حاجة لـ mapping/reTrace. التفعيل (R8) مؤجل لإصدار لاحق لاختباره.
- **يتضمن كل إصلاحات 4.6.6:** Hadith spinner (`widget.locale` + `postFrameCallback` + `Category int→String` + fallback محلي) و Tafseer overflow (`Expanded ellipsis`) — انظر `VERSION_4.6.6_RELEASE_NOTES.md`.
- **Version bump:** `pubspec.yaml:24` 4.6.6+466 → 4.6.7+467.
- **Test:** `flutter analyze` — 0 errors، ثم `aapt dump badging` يظهر `targetSdkVersion:'36'`.

---

*Prepared for Play Store submission — 4.6.7 (467 replaces rejected 466)*
