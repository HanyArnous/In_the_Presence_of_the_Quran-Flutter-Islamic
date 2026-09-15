import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:file_picker/file_picker.dart';
import 'package:nabd/core/backup/backup_service.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _isLoading = false;
  bool _includeAzkar = true;
  bool _includeHadith = true;
  bool _includeKhatma = true;

  Future<void> _export() async {
    if (!_includeAzkar && !_includeHadith && !_includeKhatma) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("اختر قسماً واحداً على الأقل", style: TextStyle(fontFamily: "cairo"))));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await BackupService.shareSelective(azkar: _includeAzkar, hadith: _includeHadith, khatma: _includeKhatma);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم إنشاء النسخة الاحتياطية ومشاركتها", style: TextStyle(fontFamily: "cairo"))));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("فشل التصدير: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _import() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      if (result == null || result.files.single.path == null) return;
      final file = File(result.files.single.path!);
      // معاينة محتوى الملف
      final info = await BackupService.inspectFile(file);
      if (info.containsKey("error")) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("ملف غير صالح: ${info["error"]}")));
        return;
      }
      final isNew = info["isNewFormat"] == true;
      int azkarCount = (info["azkarCount"] ?? 0) as int;
      int hadithCount = (info["hadithCount"] ?? 0) as int;
      int khatmaCount = (info["khatmaCount"] ?? 0) as int;

      bool impAzkar = isNew ? azkarCount > 0 : true;
      bool impHadith = isNew ? hadithCount > 0 : false;
      bool impKhatma = isNew ? khatmaCount > 0 : false;

      // إذا الصيغة قديمة، كلها أذكار
      if (!isNew) {
        impAzkar = true;
        impHadith = false;
        impKhatma = false;
      }

      // إظهار حوار اختيار الأقسام
      final selected = await showDialog<Map<String, bool>>(
        context: context,
        builder: (c) {
          bool a = impAzkar;
          bool h = impHadith;
          bool k = impKhatma;
          return StatefulBuilder(builder: (context, setSt) {
            return AlertDialog(
              title: const Text("اختر ما تريد استعادته", style: TextStyle(fontFamily: "cairo")),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isNew) ...[
                    CheckboxListTile(
                      value: a,
                      title: Text("الأذكار والسبحة ($azkarCount عنصر)", style: const TextStyle(fontFamily: "cairo", fontSize: 13)),
                      subtitle: const Text("الأقسام، الأذكار المخصصة، المفضلة، العدادات", style: TextStyle(fontFamily: "cairo", fontSize: 11)),
                      onChanged: azkarCount > 0 ? (v) => setSt(() => a = v ?? false) : null,
                    ),
                    CheckboxListTile(
                      value: h,
                      title: Text("الأحاديث ($hadithCount عنصر)", style: const TextStyle(fontFamily: "cairo", fontSize: 13)),
                      subtitle: const Text("التصنيفات والمفضلة", style: TextStyle(fontFamily: "cairo", fontSize: 11)),
                      onChanged: hadithCount > 0 ? (v) => setSt(() => h = v ?? false) : null,
                    ),
                    CheckboxListTile(
                      value: k,
                      title: Text("الختمة ($khatmaCount عنصر)", style: const TextStyle(fontFamily: "cairo", fontSize: 13)),
                      subtitle: const Text("الهدف، الصفحات المقروءة، السجل", style: TextStyle(fontFamily: "cairo", fontSize: 11)),
                      onChanged: khatmaCount > 0 ? (v) => setSt(() => k = v ?? false) : null,
                    ),
                  ] else ...[
                    CheckboxListTile(
                      value: a,
                      title: Text("الأذكار ($azkarCount عنصر)", style: const TextStyle(fontFamily: "cairo", fontSize: 13)),
                      onChanged: (v) => setSt(() => a = v ?? false),
                    ),
                    const Text("ملف قديم - يحتوي الأذكار فقط", style: TextStyle(fontFamily: "cairo", fontSize: 11, color: Colors.grey)),
                  ],
                  if (!a && !h && !k) const Padding(padding: EdgeInsets.only(top: 8), child: Text("اختر قسماً واحداً على الأقل", style: TextStyle(color: Colors.red, fontFamily: "cairo", fontSize: 12))),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, null), child: const Text("إلغاء")),
                ElevatedButton(onPressed: (!a && !h && !k) ? null : () => Navigator.pop(c, {"azkar": a, "hadith": h, "khatma": k}), child: const Text("استعادة")),
              ],
            );
          });
        },
      );

      if (selected == null) return;
      impAzkar = selected["azkar"] ?? false;
      impHadith = selected["hadith"] ?? false;
      impKhatma = selected["khatma"] ?? false;
      if (!impAzkar && !impHadith && !impKhatma) return;

      setState(() => _isLoading = true);
      final count = await BackupService.importSelectiveFromFile(file, azkar: impAzkar, hadith: impHadith, khatma: impKhatma);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("تم استعادة $count عنصر بنجاح - أعد تشغيل التطبيق", style: const TextStyle(fontFamily: "cairo"))));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("فشل الاستيراد: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("backup".tr(), style: const TextStyle(fontFamily: "cairo")),
        backgroundColor: const Color(0xff6B8E4E),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.all(16.w),
              children: [
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.backup, color: const Color(0xff6B8E4E), size: 28.sp),
                            SizedBox(width: 10.w),
                            Text("backup".tr(), style: const TextStyle(fontFamily: "cairo", fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        const Text(
                          "اختر الأقسام التي تريد نسخها. يمكنك نقل كل قسم على حدة لهاتف آخر عبر مشاركة الملف.",
                          style: TextStyle(fontFamily: "cairo", fontSize: 13, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(12.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("اختر الأقسام للنسخ", style: TextStyle(fontFamily: "cairo", fontWeight: FontWeight.bold, fontSize: 14)),
                        SizedBox(height: 8.h),
                        CheckboxListTile(
                          value: _includeAzkar,
                          title: Text("azkar".tr() + " + " + "sibha".tr(), style: const TextStyle(fontFamily: "cairo", fontSize: 14)),
                          subtitle: const Text("الأقسام، الأذكار المخصصة، الترتيب، المفضلة، العدادات والسبحة", style: TextStyle(fontFamily: "cairo", fontSize: 11)),
                          secondary: const Icon(Icons.menu_book, color: Color(0xff6B8E4E)),
                          onChanged: (v) => setState(() => _includeAzkar = v ?? false),
                        ),
                        CheckboxListTile(
                          value: _includeHadith,
                          title: Text("Hadith".tr(), style: const TextStyle(fontFamily: "cairo", fontSize: 14)),
                          subtitle: const Text("التصنيفات والمفضلة والسجل", style: TextStyle(fontFamily: "cairo", fontSize: 11)),
                          secondary: const Icon(Icons.auto_stories, color: Color(0xff6B8E4E)),
                          onChanged: (v) => setState(() => _includeHadith = v ?? false),
                        ),
                        CheckboxListTile(
                          value: _includeKhatma,
                          title: Text("khatma".tr(), style: const TextStyle(fontFamily: "cairo", fontSize: 14)),
                          subtitle: const Text("الهدف، التقدم، الصفحات والسجل اليومي", style: TextStyle(fontFamily: "cairo", fontSize: 11)),
                          secondary: const Icon(Icons.checklist, color: Color(0xff6B8E4E)),
                          onChanged: (v) => setState(() => _includeKhatma = v ?? false),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                ElevatedButton.icon(
                  onPressed: _export,
                  icon: const Icon(Icons.upload),
                  label: Text("تصدير ومشاركة (${[
                    if (_includeAzkar) "azkar".tr(),
                    if (_includeHadith) "Hadith".tr(),
                    if (_includeKhatma) "khatma".tr()
                  ].join(" + ")})", style: const TextStyle(fontFamily: "cairo"), overflow: TextOverflow.ellipsis),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff6B8E4E), foregroundColor: Colors.white, minimumSize: Size(double.infinity, 48.h)),
                ),
                SizedBox(height: 12.h),
                OutlinedButton.icon(
                  onPressed: _import,
                  icon: const Icon(Icons.download),
                  label: const Text("استيراد من ملف (اختياري)", style: TextStyle(fontFamily: "cairo")),
                  style: OutlinedButton.styleFrom(minimumSize: Size(double.infinity, 48.h)),
                ),
                SizedBox(height: 16.h),
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8.r), border: Border.all(color: Colors.orange[200]!)),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange[700], size: 20.sp),
                      SizedBox(width: 8.w),
                      const Expanded(child: Text("بعد الاستيراد، أعد تشغيل التطبيق لتظهر البيانات. يمكنك اختيار قسم واحد فقط عند التصدير أو الاستيراد.", style: TextStyle(fontFamily: "cairo", fontSize: 11))),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
