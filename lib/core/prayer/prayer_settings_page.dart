import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nabd/GlobalHelpers/hive_helper.dart';
import 'package:nabd/core/prayer/prayer_service.dart';
import 'package:permission_handler/permission_handler.dart';

class PrayerSettingsPage extends StatefulWidget {
  const PrayerSettingsPage({super.key});

  @override
  State<PrayerSettingsPage> createState() => _PrayerSettingsPageState();
}

class _PrayerSettingsPageState extends State<PrayerSettingsPage> {
  late Map<String, bool> enabled;
  String method = "egyptian";
  String madhab = "shafi";

  @override
  void initState() {
    super.initState();
    enabled = Map<String, bool>.from(getValue("prayer_enabled") ?? {"Fajr":true,"Dhuhr":true,"Asr":true,"Maghrib":true,"Isha":true});
    method = getValue("prayer_method") ?? "egyptian";
    madhab = getValue("prayer_madhab") ?? "shafi";
  }

  void _save() {
    updateValue("prayer_enabled", enabled);
    updateValue("prayer_method", method);
    updateValue("prayer_madhab", madhab);
    PrayerService.scheduleAllPrayers();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم حفظ إعدادات الأذان", style: TextStyle(fontFamily: "cairo"))));
  }

  @override
  Widget build(BuildContext context) {
    final coords = PrayerService.getTodayPrayerTimesMap();
    final next = PrayerService.getNextPrayer();
    final city = getValue("prayer_city")?.toString() ?? "غير محدد";
    return Scaffold(
      appBar: AppBar(
        title: const Text("إعدادات الأذان", style: TextStyle(fontFamily: "cairo")),
        backgroundColor: const Color(0xff6B8E4E),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.location_on, color: Color(0xff6B8E4E)),
              title: Text("الموقع: $city", style: const TextStyle(fontFamily: "cairo")),
              subtitle: Text(getValue("prayer_country")?.toString() ?? "", style: const TextStyle(fontFamily: "cairo")),
              trailing: TextButton(onPressed: () async {
                await PrayerService.fetchAndSaveLocation(context);
                await PrayerService.scheduleAllPrayers();
                setState(() {});
              }, child: const Text("تحديث")),
            ),
          ),
          SizedBox(height: 12.h),
          Card(
            child: Padding(
              padding: EdgeInsets.all(12.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("الصلوات المفعلة", style: TextStyle(fontFamily: "cairo", fontWeight: FontWeight.bold)),
                  ...["Fajr","Dhuhr","Asr","Maghrib","Isha"].map((e) => SwitchListTile(
                    title: Text(PrayerService.getArabicName(e), style: const TextStyle(fontFamily: "cairo")),
                    subtitle: Text(coords[e] != null ? PrayerService.getNextPrayer()['time'] ?? "" : "", style: const TextStyle(fontSize: 11)),
                    value: enabled[e] ?? true,
                    onChanged: (v) { setState(() => enabled[e]=v); _save(); },
                  )),
                ],
              ),
            ),
          ),
          SizedBox(height: 12.h),
          Card(
            child: Padding(
              padding: EdgeInsets.all(12.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("طريقة الحساب", style: TextStyle(fontFamily: "cairo", fontWeight: FontWeight.bold)),
                  DropdownButton<String>(
                    value: method,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: "egyptian", child: Text("مصرية - الهيئة المصرية")),
                      DropdownMenuItem(value: "ummAlQura", child: Text("أم القرى")),
                      DropdownMenuItem(value: "muslimWorldLeague", child: Text("رابطة العالم الإسلامي")),
                      DropdownMenuItem(value: "dubai", child: Text("دبي")),
                    ],
                    onChanged: (v) { if(v!=null){ method=v; _save(); }},
                  ),
                  SizedBox(height: 12.h),
                  const Text("المذهب", style: TextStyle(fontFamily: "cairo", fontWeight: FontWeight.bold)),
                  DropdownButton<String>(
                    value: madhab,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: "shafi", child: Text("شافعي / مالكي / حنبلي")),
                      DropdownMenuItem(value: "hanafi", child: Text("حنفي")),
                    ],
                    onChanged: (v) { if(v!=null){ madhab=v; _save(); }},
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 12.h),
          if (next['name']!.isNotEmpty)
            Card(
              color: const Color(0xff6B8E4E).withOpacity(0.1),
              child: ListTile(
                leading: const Icon(Icons.access_time, color: Color(0xff6B8E4E)),
                title: Text("القادمة: ${PrayerService.getArabicName(next['name']!)}", style: const TextStyle(fontFamily: "cairo", fontWeight: FontWeight.bold)),
                subtitle: Text(next['time']!, style: const TextStyle(fontFamily: "roboto")),
              ),
            ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(child: ElevatedButton.icon(onPressed: () async {
                if (await Permission.notification.request().isGranted) {
                  await PrayerService.scheduleAllPrayers();
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم جدولة الأذان لـ 7 أيام")));
                }
              }, icon: const Icon(Icons.notifications_active), label: const Text("تفعيل الأذان", style: TextStyle(fontFamily: "cairo")))),
              SizedBox(width: 12.w),
              Expanded(child: OutlinedButton.icon(onPressed: () async {
                await PrayerService.testNextPrayer();
              }, icon: const Icon(Icons.play_arrow), label: const Text("اختبار", style: TextStyle(fontFamily: "cairo")))),
            ],
          ),
          SizedBox(height: 12.h),
          OutlinedButton.icon(onPressed: () async {
            await PrayerService.cancelAllPrayers();
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم إلغاء جميع تنبيهات الأذان")));
          }, icon: const Icon(Icons.cancel), label: const Text("إلغاء الكل", style: TextStyle(fontFamily: "cairo"))),
        ],
      ),
    );
  }
}
