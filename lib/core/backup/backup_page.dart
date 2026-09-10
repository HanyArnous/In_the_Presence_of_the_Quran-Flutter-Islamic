import 'dart:io';
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

  Future<void> _export() async {
    setState(() => _isLoading = true);
    try {
      await BackupService.shareBackup();
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
      setState(() => _isLoading = true);
      final count = await BackupService.importFromFile(file);
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
        title: const Text("نسخ احتياطي", style: TextStyle(fontFamily: "cairo")),
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
                            const Text("النسخ الاحتياطي", style: TextStyle(fontFamily: "cairo", fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        const Text(
                          "يتم حفظ جميع إعدادات التسبيح والأذكار المخصصة، العدادات، والمفضلة. يمكنك نقلها لهاتف آخر عبر مشاركة الملف.",
                          style: TextStyle(fontFamily: "cairo", fontSize: 13, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                ElevatedButton.icon(
                  onPressed: _export,
                  icon: const Icon(Icons.upload),
                  label: const Text("تصدير ومشاركة", style: TextStyle(fontFamily: "cairo")),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff6B8E4E), foregroundColor: Colors.white, minimumSize: Size(double.infinity, 48.h)),
                ),
                SizedBox(height: 12.h),
                OutlinedButton.icon(
                  onPressed: _import,
                  icon: const Icon(Icons.download),
                  label: const Text("استيراد من ملف", style: TextStyle(fontFamily: "cairo")),
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
                      const Expanded(child: Text("بعد الاستيراد، أعد تشغيل التطبيق لتظهر البيانات.", style: TextStyle(fontFamily: "cairo", fontSize: 11))),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
