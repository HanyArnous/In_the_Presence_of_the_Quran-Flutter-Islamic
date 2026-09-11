import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nabd/GlobalHelpers/hive_helper.dart';
import 'package:nabd/core/prayer/azan_alert_page.dart';
import 'package:nabd/core/prayer/azan_native_bridge.dart';
import 'package:nabd/core/prayer/prayer_service.dart';

class PrayerSettingsPage extends StatefulWidget {
  const PrayerSettingsPage({super.key});

  @override
  State<PrayerSettingsPage> createState() => _PrayerSettingsPageState();
}

class _PrayerSettingsPageState extends State<PrayerSettingsPage> {
  late Map<String, bool> enabled;
  String method = "egyptian";
  String madhab = "shafi";
  bool? _exactGranted;

  @override
  void initState() {
    super.initState();
    enabled = Map<String, bool>.from(getValue("prayer_enabled") ?? {"Fajr":true,"Dhuhr":true,"Asr":true,"Maghrib":true,"Isha":true});
    method = getValue("prayer_method") ?? "egyptian";
    madhab = getValue("prayer_madhab") ?? "shafi";
    // إصلاح رجعي: إحداثيات محفوظة بدون اسم مدينة (فشل ترجمة سابق)
    // ← ثبّت "موقعي الحالي" بدل بقاء "غير محدد".
    final lat = getValue("prayer_lat");
    final lng = getValue("prayer_lng");
    if (lat is num && lng is num &&
        (getValue("prayer_city")?.toString().trim().isEmpty ?? true)) {
      updateValue("prayer_city", "موقعي الحالي");
    }
    _checkExact();
  }

  Future<void> _checkExact() async {
    try {
      final v = await AzanNativeBridge.canScheduleExact();
      if (mounted) setState(() => _exactGranted = v);
    } catch (_) {}
  }

  void _save() {
    updateValue("prayer_enabled", enabled);
    updateValue("prayer_method", method);
    updateValue("prayer_madhab", madhab);
    PrayerService.scheduleAllPrayers();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم حفظ إعدادات الأذان", style: TextStyle(fontFamily: "cairo"))));
  }

  String _formatPrayerTime(DateTime? dt) {
    if (dt == null) return "غير متوفر";
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return "$h:$m";
  }

  @override
  Widget build(BuildContext context) {
    final coords = PrayerService.getTodayPrayerTimesMap();
    final next = PrayerService.getNextPrayer();
    // إن لم يُحفظ اسم مدينة لكن توجد إحداثيات (موقع مأخوذ فعلاً) اعرض
    // "موقعي الحالي" بدل "غير محدد" المضلل.
    final lat = getValue("prayer_lat");
    final lng = getValue("prayer_lng");
    final hasCoords = lat is num && lng is num;
    final savedCity = getValue("prayer_city")?.toString().trim() ?? "";
    final city = savedCity.isNotEmpty
        ? savedCity
        : (hasCoords ? "موقعي الحالي" : "غير محدد");
    return Scaffold(
      appBar: AppBar(
        title: const Text("إعدادات الأذان", style: TextStyle(fontFamily: "cairo")),
        backgroundColor: const Color(0xff6B8E4E),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        bottom: true,
        child: ListView(
        padding: EdgeInsets.fromLTRB(16.w, 16.w, 16.w, 16.w + MediaQuery.of(context).padding.bottom + 16.h),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.location_on, color: Color(0xff6B8E4E)),
              title: Text("الموقع: $city", style: const TextStyle(fontFamily: "cairo")),
              subtitle: Text(getValue("prayer_country")?.toString() ?? "", style: const TextStyle(fontFamily: "cairo")),
              trailing: TextButton(onPressed: () async {
                final coords =
                    await PrayerService.fetchAndSaveLocation(context);
                if (!context.mounted) return;
                if (coords != null) {
                  await PrayerService.scheduleAllPrayers();
                  final city =
                      getValue("prayer_city")?.toString() ?? "";
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          city.isNotEmpty
                              ? "تم حفظ الموقع: $city ✓"
                              : "تم حفظ الموقع وحساب المواقيت ✓",
                          style:
                              const TextStyle(fontFamily: "cairo"))));
                }
                // عند الفشل يعرض fetchAndSaveLocation سبباً محدداً — لا نعيد الجدولة
                setState(() {});
              }, child: const Text("تحديث")),
            ),
          ),
          SizedBox(height: 12.h),
          // تنبيه إذن المنبه الدقيق: بدونه يعمل الأذان بتأخير والتطبيق مغلق
          if (_exactGranted == false)
            Card(
              color: Colors.orange.shade50,
              child: ListTile(
                leading: const Icon(Icons.alarm_off, color: Colors.orange),
                title: const Text("المنبه الدقيق غير مفعّل",
                    style: TextStyle(fontFamily: "cairo", fontWeight: FontWeight.bold)),
                subtitle: const Text(
                    "فعّله من الإعدادات ليعمل الأذان بدقة والتطبيق مغلق",
                    style: TextStyle(fontFamily: "cairo")),
                trailing: TextButton(
                    onPressed: () async {
                      await AzanNativeBridge.openExactAlarmSettings();
                      await Future.delayed(const Duration(seconds: 1));
                      _checkExact();
                    },
                    child: const Text("فتح الإعدادات")),
              ),
            ),
          if (_exactGranted == false) SizedBox(height: 12.h),
          Card(
            child: Padding(
              padding: EdgeInsets.all(12.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("الصلوات المفعلة", style: TextStyle(fontFamily: "cairo", fontWeight: FontWeight.bold)),
                  ...["Fajr","Dhuhr","Asr","Maghrib","Isha"].map((e) => SwitchListTile(
                    title: Text(PrayerService.getArabicName(e), style: const TextStyle(fontFamily: "cairo")),
                    subtitle: Text(_formatPrayerTime(coords[e]), style: const TextStyle(fontSize: 11, fontFamily: "roboto")),
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
                if (await PrayerService.ensureAzanPermissions()) {
                  await PrayerService.scheduleAllPrayers();
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم جدولة الأذان كاملاً لـ 7 أيام")));
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى السماح بالإشعارات ليعمل الأذان")));
                }
              }, icon: const Icon(Icons.notifications_active), label: const Text("تفعيل الأذان", style: TextStyle(fontFamily: "cairo")))),
              SizedBox(width: 12.w),
              Expanded(child: OutlinedButton.icon(onPressed: () async {
                await PrayerService.testNextPrayer();
                if (!mounted) return;
                final nextName = PrayerService.getNextPrayer()['name'] ?? '';
                Navigator.push(context, MaterialPageRoute(builder: (_) => AzanAlertPage(
                  englishName: nextName.isEmpty ? 'Fajr' : nextName,
                  arabicName: PrayerService.getArabicName(nextName.isEmpty ? 'Fajr' : nextName),
                )));
              }, icon: const Icon(Icons.play_arrow), label: const Text("اختبار كامل", style: TextStyle(fontFamily: "cairo")))),
            ],
          ),
          SizedBox(height: 12.h),
          OutlinedButton.icon(onPressed: () async {
            await PrayerService.stopCurrentAzan();
          }, icon: const Icon(Icons.stop), label: const Text("إيقاف الصوت الحالي", style: TextStyle(fontFamily: "cairo"))),
          SizedBox(height: 12.h),
          OutlinedButton.icon(onPressed: () async {
            await PrayerService.cancelAllPrayers();
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم إلغاء جميع تنبيهات الأذان")));
          }, icon: const Icon(Icons.cancel), label: const Text("إلغاء الكل", style: TextStyle(fontFamily: "cairo"))),
          SizedBox(height: 24.h),
        ],
      ),
      ),
    );
  }
}
