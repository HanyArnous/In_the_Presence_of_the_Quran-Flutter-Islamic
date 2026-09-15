# Version 4.6.6 Release Notes - Google Play Store

**Developer:** HANY_ARNOUS
**GitHub:** https://github.com/HanyArnous
**Release Date:** 16 سبتمبر 2026
**Version:** 4.6.6+466 (Previous: 4.6.5+465)

---

## 🇸🇦 ملاحظات الإصدار للمتجر (العربية) — انسخ كما هي في Play Console

```
• إصلاح تعليق مكتبة الحديث: كانت الصفحة تفتح فارغة مع علامة تحميل لا تنتهي، الآن تظهر التصنيفات فوراً مع زر إعادة المحاولة عند انقطاع الإنترنت ومكتبة بديلة دون اتصال.
• إصلاح تجاوز النص في قائمة التفسير والترجمة (RIGHT OVERFLOWED) للنصوص الطويلة مثل Tafheem-ul-Quran.
• تثبيت العرض حتى حافة الشاشة على Android 15 بدون items مخفية خلف الأزرار.
```

## 🇬🇧 Play Store Release Notes (English) — paste as-is

```
• Fixed Hadith library stuck on endless loading: categories now load immediately with retry on offline and a local fallback library.
• Fixed translation picker text overflow (RIGHT OVERFLOWED) for long names like Tafheem-ul-Quran.
• Edge-to-edge display stabilization on Android 15.
```

---

## 📋 Technical Details (للمطور — لا تُرفع للمتجر)

- **Hadith infinite spinner root cause:** `getCategories()` قرأ `context.locale` خارج `try` وقبل `super.initState()` — أي استثناء كان يمنع `isLoading=false` للأبد.
  - الإصلاح في `lib/core/hadith/views/hadithbookspage.dart`:
    - `initState()` يستدعي `super.initState()` أولاً ثم `addPostFrameCallback` قبل `getCategories()`.
    - اللغة من `widget.locale` مع fallback آمن لـ `context.locale` داخل `try`.
    - عنوان "كل الأحاديث" مع fallback نصي بدل `.tr()` المباشر.
    - `Category.fromJson` يقبل `int` عبر `?.toString()` (API يرجع أرقاماً).
    - عند تعذر API تُعرض الكتب المحلية التسعة من `books.dart` عبر `LocalHadithBookPage` (تحميل/عرض دون اتصال) بدل صفحة فارغة.
    - التنقل: `parentId=="local"` يفتح العارض المحلي، وغيره يفتح `HadithList` كالمعتاد.
- **Tafseer overflow:** صفا `tafseer_and_translation_sheet.dart` (قائمة الكتب + الشريط المحدد) أصبحا `Row[Expanded(Text ellipsis maxLines 1-2) + Icon]` بدل `spaceBetween` غير المقيد.
- **Version bump:** `pubspec.yaml` 4.6.5+465 → 4.6.6+466.
- **Test:** `flutter analyze` — 0 errors.

---

*Prepared for Play Store submission — 4.6.6*
