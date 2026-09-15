import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:adhan/adhan.dart';
import 'package:nabd/GlobalHelpers/hive_helper.dart';
import 'package:nabd/core/prayer/prayer_service.dart';
import 'package:intl/intl.dart';

class CityInfo {
  final String name;
  final double lat;
  final double lng;
  const CityInfo(this.name, this.lat, this.lng);
}

const Map<String, List<CityInfo>> countryCities = {
  "مصر": [
    CityInfo("القاهرة", 30.0444, 31.2357),
    CityInfo("الجيزة", 30.0131, 31.2089),
    CityInfo("الإسكندرية", 31.2001, 29.9187),
    CityInfo("الدقهلية - المنصورة", 31.0364, 31.3807),
    CityInfo("البحر الأحمر - الغردقة", 27.2579, 33.8116),
    CityInfo("البحيرة - دمنهور", 31.0340, 30.4682),
    CityInfo("الفيوم", 29.3084, 30.8428),
    CityInfo("الغربية - طنطا", 30.7865, 31.0004),
    CityInfo("الإسماعيلية", 30.6043, 32.2723),
    CityInfo("المنوفية - شبين الكوم", 30.5594, 31.0125),
    CityInfo("المنيا", 28.1099, 30.7503),
    CityInfo("القليوبية - بنها", 30.4649, 31.1849),
    CityInfo("الوادي الجديد - الخارجة", 25.4455, 30.5467),
    CityInfo("السويس", 29.9668, 32.5498),
    CityInfo("أسوان", 24.0889, 32.8998),
    CityInfo("أسيوط", 27.1783, 31.1859),
    CityInfo("بني سويف", 29.0661, 31.0840),
    CityInfo("بورسعيد", 31.2243, 32.2900),
    CityInfo("دمياط", 31.4175, 31.8144),
    CityInfo("الشرقية - الزقازيق", 30.5877, 31.5025),
    CityInfo("جنوب سيناء - الطور", 28.2410, 33.6222),
    CityInfo("كفر الشيخ", 31.1117, 30.9407),
    CityInfo("مطروح", 31.3525, 27.2453),
    CityInfo("الأقصر", 25.6872, 32.6396),
    CityInfo("قنا", 26.1551, 32.7160),
    CityInfo("شمال سيناء - العريش", 31.1317, 33.7983),
    CityInfo("سوهاج", 26.5591, 31.6948),
  ],
  "السعودية": [
    CityInfo("الرياض", 24.7136, 46.6753),
    CityInfo("جدة", 21.3891, 39.8579),
    CityInfo("مكة المكرمة", 21.3891, 39.8579),
    CityInfo("المدينة المنورة", 24.4672, 39.6111),
    CityInfo("الدمام", 26.4207, 50.0888),
    CityInfo("تبوك", 28.3838, 36.5550),
  ],
  "الإمارات": [
    CityInfo("دبي", 25.2048, 55.2708),
    CityInfo("أبوظبي", 24.4539, 54.3773),
    CityInfo("الشارقة", 25.3463, 55.4209),
    CityInfo("العين", 24.2075, 55.7447),
  ],
  "الكويت": [
    CityInfo("مدينة الكويت", 29.3759, 47.9774),
  ],
  "قطر": [
    CityInfo("الدوحة", 25.2854, 51.5310),
  ],
  "البحرين": [
    CityInfo("المنامة", 26.2235, 50.5876),
  ],
  "عمان": [
    CityInfo("مسقط", 23.5880, 58.3829),
    CityInfo("صلالة", 17.0151, 54.0924),
  ],
  "الأردن": [
    CityInfo("عمان", 31.9454, 35.9284),
    CityInfo("إربد", 32.5560, 35.8470),
    CityInfo("الزرقاء", 32.0833, 36.1000),
  ],
  "لبنان": [
    CityInfo("بيروت", 33.8938, 35.5018),
    CityInfo("طرابلس", 34.4367, 35.8497),
  ],
  "سوريا": [
    CityInfo("دمشق", 33.5138, 36.2765),
    CityInfo("حلب", 36.2021, 37.1343),
    CityInfo("حمص", 34.7308, 36.7096),
  ],
  "العراق": [
    CityInfo("بغداد", 33.3152, 44.3661),
    CityInfo("البصرة", 30.5085, 47.7835),
    CityInfo("الموصل", 36.3400, 43.1300),
    CityInfo("أربيل", 36.1910, 44.0092),
  ],
  "اليمن": [
    CityInfo("صنعاء", 15.3694, 44.1910),
    CityInfo("عدن", 12.7794, 45.0367),
  ],
  "فلسطين": [
    CityInfo("القدس", 31.7683, 35.2137),
    CityInfo("غزة", 31.5017, 34.4668),
    CityInfo("رام الله", 31.9038, 35.2034),
  ],
  "المغرب": [
    CityInfo("الرباط", 34.0209, -6.8417),
    CityInfo("الدار البيضاء", 33.5731, -7.5898),
    CityInfo("مراكش", 31.6295, -7.9811),
    CityInfo("فاس", 34.0181, -5.0078),
  ],
  "الجزائر": [
    CityInfo("الجزائر العاصمة", 36.7538, 3.0588),
    CityInfo("وهران", 35.6987, -0.6349),
    CityInfo("قسنطينة", 36.3600, 6.6400),
  ],
  "تونس": [
    CityInfo("تونس العاصمة", 36.8065, 10.1815),
    CityInfo("صفاقس", 34.7390, 10.7603),
  ],
  "ليبيا": [
    CityInfo("طرابلس", 32.8872, 13.1913),
    CityInfo("بنغازي", 32.0948, 20.1879),
  ],
  "السودان": [
    CityInfo("الخرطوم", 15.5007, 32.5599),
    CityInfo("أم درمان", 15.6445, 32.4772),
  ],
  "تركيا": [
    CityInfo("إسطنبول", 41.0082, 28.9784),
    CityInfo("أنقرة", 39.9334, 32.8597),
    CityInfo("بورصة", 40.1826, 29.0665),
  ],
  "ألمانيا": [
    CityInfo("برلين", 52.5200, 13.4050),
    CityInfo("ميونخ", 48.1351, 11.5820),
    CityInfo("هامبورغ", 53.5511, 9.9937),
  ],
  "فرنسا": [
    CityInfo("باريس", 48.8566, 2.3522),
    CityInfo("ليون", 45.7640, 4.8357),
  ],
  "بريطانيا": [
    CityInfo("لندن", 51.5072, -0.1276),
    CityInfo("مانشستر", 53.4808, -2.2426),
  ],
  "أمريكا": [
    CityInfo("نيويورك", 40.7128, -74.0060),
    CityInfo("واشنطن", 38.9072, -77.0369),
    CityInfo("شيكاغو", 41.8781, -87.6298),
  ],
};

class PrayerManualTablePage extends StatefulWidget {
  const PrayerManualTablePage({super.key});

  @override
  State<PrayerManualTablePage> createState() => _PrayerManualTablePageState();
}

class _PrayerManualTablePageState extends State<PrayerManualTablePage> {
  late String selectedCountry;
  late CityInfo selectedCity;
  String method = "egyptian";
  String madhab = "shafi";
  int daysToShow = 7; // 7 أو 30

  @override
  void initState() {
    super.initState();
    method = getValue("prayer_method") ?? "egyptian";
    madhab = getValue("prayer_madhab") ?? "shafi";
    final savedCountry = getValue("manual_prayer_country")?.toString();
    final savedCityName = getValue("manual_prayer_city")?.toString();
    if (savedCountry != null && countryCities.containsKey(savedCountry)) {
      selectedCountry = savedCountry;
      final list = countryCities[savedCountry]!;
      final match = list.where((c) => c.name == savedCityName).toList();
      selectedCity = match.isNotEmpty ? match.first : list.first;
    } else {
      // افتراضي: حاول استخدام الموقع الحالي إن وُجد
      final lat = getValue("prayer_lat");
      final lng = getValue("prayer_lng");
      final cityName = getValue("prayer_city")?.toString() ?? "";
      if (cityName.isNotEmpty) {
        // حاول مطابقة المدينة في القوائم
        String? foundCountry;
        CityInfo? foundCity;
        outer:
        for (final entry in countryCities.entries) {
          for (final c in entry.value) {
            if (c.name.contains(cityName) || cityName.contains(c.name)) {
              foundCountry = entry.key;
              foundCity = c;
              break outer;
            }
          }
        }
        if (foundCountry != null && foundCity != null) {
          selectedCountry = foundCountry;
          selectedCity = foundCity;
        } else {
          selectedCountry = "مصر";
          selectedCity = countryCities["مصر"]!.first;
        }
      } else {
        selectedCountry = "مصر";
        selectedCity = countryCities["مصر"]!.first;
      }
      // إن كان هناك إحداثيات محفوظة بدون مطابقة، اعتبرها موقعاً مخصصاً
      if (lat is num && lng is num && savedCountry == null) {
        // اترك كما هو لكن لا نغير الإحداثيات - العرض سيكون للقاهرة افتراضياً
      }
    }
  }

  CalculationParameters _getParams() {
    CalculationMethod m;
    switch (method) {
      case "ummAlQura":
        m = CalculationMethod.umm_al_qura;
        break;
      case "muslimWorldLeague":
        m = CalculationMethod.muslim_world_league;
        break;
      case "dubai":
        m = CalculationMethod.dubai;
        break;
      case "qatar":
        m = CalculationMethod.qatar;
        break;
      case "kuwait":
        m = CalculationMethod.kuwait;
        break;
      default:
        m = CalculationMethod.egyptian;
    }
    final p = m.getParameters();
    p.madhab = madhab == "hanafi" ? Madhab.hanafi : Madhab.shafi;
    return p;
  }

  PrayerTimes? _getPrayerTimesFor(DateTime date, Coordinates coords) {
    final params = _getParams();
    final components = DateComponents(date.year, date.month, date.day);
    return PrayerTimes(coords, components, params);
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return "--:--";
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  void _saveSelection() {
    updateValue("manual_prayer_country", selectedCountry);
    updateValue("manual_prayer_city", selectedCity.name);
    updateValue("manual_prayer_lat", selectedCity.lat);
    updateValue("manual_prayer_lng", selectedCity.lng);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("تم حفظ: $selectedCountry - ${selectedCity.name}", style: const TextStyle(fontFamily: "cairo"))));
  }

  Future<void> _setAsPrimaryLocation() async {
    updateValue("prayer_lat", selectedCity.lat);
    updateValue("prayer_lng", selectedCity.lng);
    updateValue("prayer_city", selectedCity.name);
    updateValue("prayer_country", selectedCountry);
    updateValue("prayer_method", method);
    updateValue("prayer_madhab", madhab);
    await PrayerService.scheduleAllPrayers();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("تم تعيين ${selectedCity.name} كموقع أساسي وجدولة الأذان ✓", style: const TextStyle(fontFamily: "cairo"))));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final coords = Coordinates(selectedCity.lat, selectedCity.lng);
    final todayTimes = _getPrayerTimesFor(DateTime.now(), coords);
    final dateFormatter = DateFormat('yyyy/MM/dd - EEEE', 'ar');
    return Scaffold(
      appBar: AppBar(
        title: const Text("جدول مواقيت الصلاة", style: TextStyle(fontFamily: "cairo")),
        backgroundColor: const Color(0xff6B8E4E),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(12.w, 12.w, 12.w, 24.h + MediaQuery.of(context).padding.bottom),
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(12.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("اختر البلد والمحافظة / المدينة يدوياً", style: TextStyle(fontFamily: "cairo", fontWeight: FontWeight.bold)),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedCountry,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: "البلد",
                            labelStyle: const TextStyle(fontFamily: "cairo"),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                          ),
                          items: countryCities.keys.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontFamily: "cairo")))).toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() {
                              selectedCountry = v;
                              selectedCity = countryCities[v]!.first;
                            });
                            _saveSelection();
                          },
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: DropdownButtonFormField<CityInfo>(
                          value: selectedCity,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: "المحافظة / المدينة",
                            labelStyle: const TextStyle(fontFamily: "cairo"),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                          ),
                          items: countryCities[selectedCountry]!.map((c) => DropdownMenuItem(value: c, child: Text(c.name, style: const TextStyle(fontFamily: "cairo"), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => selectedCity = v);
                            _saveSelection();
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: method,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: "طريقة الحساب",
                            labelStyle: const TextStyle(fontFamily: "cairo", fontSize: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
                          ),
                          items: const [
                            DropdownMenuItem(value: "egyptian", child: Text("مصرية", style: TextStyle(fontFamily: "cairo", fontSize: 12))),
                            DropdownMenuItem(value: "ummAlQura", child: Text("أم القرى", style: TextStyle(fontFamily: "cairo", fontSize: 12))),
                            DropdownMenuItem(value: "muslimWorldLeague", child: Text("رابطة العالم", style: TextStyle(fontFamily: "cairo", fontSize: 12))),
                            DropdownMenuItem(value: "dubai", child: Text("دبي", style: TextStyle(fontFamily: "cairo", fontSize: 12))),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => method = v);
                            updateValue("prayer_method", v);
                            PrayerService.scheduleAllPrayers();
                          },
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: madhab,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: "المذهب",
                            labelStyle: const TextStyle(fontFamily: "cairo", fontSize: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
                          ),
                          items: const [
                            DropdownMenuItem(value: "shafi", child: Text("شافعي", style: TextStyle(fontFamily: "cairo", fontSize: 12))),
                            DropdownMenuItem(value: "hanafi", child: Text("حنفي", style: TextStyle(fontFamily: "cairo", fontSize: 12))),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => madhab = v);
                            updateValue("prayer_madhab", v);
                            PrayerService.scheduleAllPrayers();
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton.icon(onPressed: _saveSelection, icon: const Icon(Icons.save, size: 18), label: const Text("حفظ الاختيار", style: TextStyle(fontFamily: "cairo", fontSize: 12)))),
                      SizedBox(width: 8.w),
                      Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff6B8E4E), foregroundColor: Colors.white), onPressed: _setAsPrimaryLocation, icon: const Icon(Icons.my_location, size: 18), label: const Text("تعيين كموقع أساسي", style: TextStyle(fontFamily: "cairo", fontSize: 12)))),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 12.h),
          Card(
            color: const Color(0xff6B8E4E).withOpacity(0.08),
            child: Padding(
              padding: EdgeInsets.all(12.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Color(0xff6B8E4E), size: 20),
                      SizedBox(width: 6.w),
                      Expanded(child: Text("$selectedCountry - ${selectedCity.name}", style: TextStyle(fontFamily: "cairo", fontWeight: FontWeight.bold, fontSize: 14.sp))),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(color: const Color(0xff6B8E4E), borderRadius: BorderRadius.circular(6.r)),
                        child: Text(dateFormatter.format(DateTime.now()), style: TextStyle(fontFamily: "cairo", fontSize: 10.sp, color: Colors.white)),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  if (todayTimes != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildTimeChip("الفجر", _formatTime(todayTimes.fajr), Icons.nights_stay),
                        _buildTimeChip("الظهر", _formatTime(todayTimes.dhuhr), Icons.wb_sunny),
                        _buildTimeChip("العصر", _formatTime(todayTimes.asr), Icons.wb_twilight),
                        _buildTimeChip("المغرب", _formatTime(todayTimes.maghrib), Icons.brightness_3),
                        _buildTimeChip("العشاء", _formatTime(todayTimes.isha), Icons.nightlight_round),
                      ],
                    )
                  else
                    const Text("تعذر حساب المواقيت", style: TextStyle(fontFamily: "cairo")),
                ],
              ),
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              const Text("جدول الأيام القادمة", style: TextStyle(fontFamily: "cairo", fontWeight: FontWeight.bold)),
              const Spacer(),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 7, label: Text("7 أيام", style: TextStyle(fontFamily: "cairo", fontSize: 12))),
                  ButtonSegment(value: 30, label: Text("30 يوم", style: TextStyle(fontFamily: "cairo", fontSize: 12))),
                ],
                selected: {daysToShow},
                onSelectionChanged: (s) => setState(() => daysToShow = s.first),
                style: ButtonStyle(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(const Color(0xff6B8E4E).withOpacity(0.12)),
                columnSpacing: 16.w,
                headingTextStyle: TextStyle(fontFamily: "cairo", fontWeight: FontWeight.bold, fontSize: 11.sp, color: const Color(0xff6B8E4E)),
                dataTextStyle: TextStyle(fontFamily: "roboto", fontSize: 11.sp),
                columns: const [
                  DataColumn(label: Text("التاريخ", style: TextStyle(fontFamily: "cairo"))),
                  DataColumn(label: Text("الفجر")),
                  DataColumn(label: Text("الظهر")),
                  DataColumn(label: Text("العصر")),
                  DataColumn(label: Text("المغرب")),
                  DataColumn(label: Text("العشاء")),
                ],
                rows: List.generate(daysToShow, (i) {
                  final date = DateTime.now().add(Duration(days: i));
                  final pt = _getPrayerTimesFor(date, coords);
                  final isToday = i == 0;
                  final dateStr = DateFormat('MM/dd (E)', 'ar').format(date);
                  TextStyle rowStyle = TextStyle(
                    fontFamily: "roboto",
                    fontSize: 11.sp,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    color: isToday ? const Color(0xff6B8E4E) : Colors.black87,
                  );
                  TextStyle dateStyle = TextStyle(
                    fontFamily: "cairo",
                    fontSize: 11.sp,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    color: isToday ? const Color(0xff6B8E4E) : Colors.black87,
                  );
                  return DataRow(
                    color: isToday ? MaterialStateProperty.all(const Color(0xff6B8E4E).withOpacity(0.07)) : null,
                    cells: [
                      DataCell(Text(dateStr, style: dateStyle)),
                      DataCell(Text(_formatTime(pt?.fajr), style: rowStyle)),
                      DataCell(Text(_formatTime(pt?.dhuhr), style: rowStyle)),
                      DataCell(Text(_formatTime(pt?.asr), style: rowStyle)),
                      DataCell(Text(_formatTime(pt?.maghrib), style: rowStyle)),
                      DataCell(Text(_formatTime(pt?.isha), style: rowStyle)),
                    ],
                  );
                }),
              ),
            ),
          ),
          SizedBox(height: 12.h),
          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: EdgeInsets.all(10.w),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  SizedBox(width: 8.w),
                  Expanded(child: Text("يتم حساب المواقيت محلياً على الجهاز حسب الإحداثيات وطريقة الحساب المختارة، بدون حاجة للإنترنت.", style: TextStyle(fontFamily: "cairo", fontSize: 11.sp, color: Colors.brown[700]))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeChip(String label, String time, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 18.sp, color: const Color(0xff6B8E4E)),
        SizedBox(height: 4.h),
        Text(label, style: TextStyle(fontFamily: "cairo", fontSize: 10.sp, color: Colors.black54)),
        Text(time, style: TextStyle(fontFamily: "roboto", fontSize: 12.sp, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
