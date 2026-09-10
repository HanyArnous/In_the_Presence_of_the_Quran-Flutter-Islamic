import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:nabd/GlobalHelpers/hive_helper.dart';
import 'package:nabd/core/khatma/khatma_service.dart';
import 'package:nabd/core/QuranPages/views/quranDetailsPage.dart';
import 'package:quran/quran.dart' as quran;

class KhatmaPage extends StatefulWidget {
  const KhatmaPage({super.key});

  @override
  State<KhatmaPage> createState() => _KhatmaPageState();
}

class _KhatmaPageState extends State<KhatmaPage> {
  final List<Map<String, dynamic>> presets = [
    {'label': 'أسبوع', 'days': 7},
    {'label': '15 يوم', 'days': 15},
    {'label': '30 يوم', 'days': 30},
    {'label': '60 يوم', 'days': 60},
    {'label': '90 يوم', 'days': 90},
  ];

  @override
  Widget build(BuildContext context) {
    final goal = KhatmaService.getActiveGoal();
    return Scaffold(
      appBar: AppBar(
        title: const Text("هدف الختمة", style: TextStyle(fontFamily: "cairo")),
        backgroundColor: const Color(0xff6B8E4E),
        foregroundColor: Colors.white,
      ),
      body: goal == null ? _buildCreateView() : _buildProgressView(goal),
    );
  }

  Widget _buildCreateView() {
    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(color: const Color(0xff6B8E4E).withOpacity(0.08), borderRadius: BorderRadius.circular(12.r), border: Border.all(color: const Color(0xff6B8E4E).withOpacity(0.2))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("ابدأ ختمة جديدة", style: TextStyle(fontFamily: "cairo", fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 8.h),
              const Text("اختر مدة لإتمام قراءة القرآن الكريم (604 صفحات) وسيتم حساب هدف يومي لك.", style: TextStyle(fontFamily: "cairo", fontSize: 13)),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        const Text("اختر المدة", style: TextStyle(fontFamily: "cairo", fontWeight: FontWeight.bold)),
        SizedBox(height: 12.h),
        Wrap(
          spacing: 10.w,
          runSpacing: 10.h,
          children: presets.map((p) {
            final days = p['days'] as int;
            final daily = (KhatmaService.totalPages / days).ceil();
            return InkWell(
              onTap: () => _createGoal(days),
              child: Container(
                width: (MediaQuery.of(context).size.width - 48.w) / 2,
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: Colors.grey[300]!), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
                child: Column(
                  children: [
                    Text(p['label'], style: const TextStyle(fontFamily: "cairo", fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 6.h),
                    Text("$daily صفحة/يوم", style: TextStyle(fontFamily: "cairo", fontSize: 12, color: Colors.grey[600])),
                    SizedBox(height: 4.h),
                    Text("$days يوم", style: TextStyle(fontFamily: "cairo", fontSize: 11, color: const Color(0xff6B8E4E))),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        SizedBox(height: 16.h),
        OutlinedButton.icon(
          onPressed: _pickCustom,
          icon: const Icon(Icons.calendar_today),
          label: const Text("مدة مخصصة", style: TextStyle(fontFamily: "cairo")),
        ),
      ],
    );
  }

  Widget _buildProgressView(Map<String, dynamic> goal) {
    final start = DateTime.parse(goal['startDate']);
    final end = DateTime.parse(goal['endDate']);
    final dailyGoal = goal['dailyGoal'] as int;
    final progress = KhatmaService.getProgressPages();
    final total = goal['totalPages'] as int;
    final percent = KhatmaService.getProgressPercent();
    final daysRemaining = KhatmaService.getDaysRemaining();
    final todayRead = KhatmaService.getTodayRead();
    final todayRemaining = (dailyGoal - todayRead).clamp(0, dailyGoal);
    final streak = KhatmaService.getStreak();

    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xff6B8E4E), Color(0xff8FB996)], begin: Alignment.topRight, end: Alignment.bottomLeft), borderRadius: BorderRadius.circular(16.r)),
          child: Column(
            children: [
              Text("${(percent*100).toStringAsFixed(1)}%", style: TextStyle(color: Colors.white, fontSize: 32.sp, fontWeight: FontWeight.bold, fontFamily: "roboto")),
              SizedBox(height: 8.h),
              LinearProgressIndicator(value: percent, backgroundColor: Colors.white24, color: Colors.white, minHeight: 8.h),
              SizedBox(height: 12.h),
              Text("$progress / $total صفحة", style: TextStyle(color: Colors.white.withOpacity(0.9), fontFamily: "cairo")),
              SizedBox(height: 4.h),
              Text("من ${DateFormat('yyyy-MM-dd').format(start)} إلى ${DateFormat('yyyy-MM-dd').format(end)}", style: TextStyle(color: Colors.white70, fontSize: 11.sp, fontFamily: "cairo")),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        Row(
          children: [
            Expanded(child: _statCard("هدف اليوم", "$todayRemaining / $dailyGoal", Icons.today, todayRemaining==0 ? Colors.green : Colors.orange)),
            SizedBox(width: 12.w),
            Expanded(child: _statCard("متبقي", "$daysRemaining يوم", Icons.calendar_month, Colors.blue)),
          ],
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(child: _statCard("مقروء اليوم", "$todayRead صفحة", Icons.menu_book, Colors.purple)),
            SizedBox(width: 12.w),
            Expanded(child: _statCard("متتالية", "$streak يوم", Icons.local_fire_department, Colors.deepOrange)),
          ],
        ),
        SizedBox(height: 16.h),
        if (todayRemaining > 0)
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(12.r), border: Border.all(color: Colors.orange[200]!)),
            child: Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.orange[700]),
                SizedBox(width: 10.w),
                Expanded(child: Text("اقرأ $todayRemaining صفحات اليوم لتحقق هدفك", style: TextStyle(fontFamily: "cairo", color: Colors.orange[900]))),
              ],
            ),
          )
        else
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(12.r), border: Border.all(color: Colors.green[200]!)),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[700]),
                SizedBox(width: 10.w),
                const Expanded(child: Text("أحسنت! حققت هدف اليوم", style: TextStyle(fontFamily: "cairo", color: Colors.green))),
              ],
            ),
          ),
        SizedBox(height: 16.h),
        ElevatedButton.icon(
          onPressed: () async {
            final lastRead = getValue("lastRead");
            int page = 1;
            if (lastRead is int && lastRead >=1 && lastRead <=604) page = lastRead;
            // تحميل البيانات المطلوبة للصفحة
            dynamic jData;
            dynamic qData;
            try {
              final cached = getValue("surahs_json_cache");
              if (cached != null) jData = cached;
            } catch (_) {}
            try {
              final cachedQ = getValue("quarters_json_cache");
              if (cachedQ != null) qData = cachedQ;
            } catch (_) {}
            if (!mounted) return;
            Navigator.push(context, MaterialPageRoute(builder: (_) => QuranDetailsPage(pageNumber: page, jsonData: jData ?? [], quarterJsonData: qData ?? [], shouldHighlightText: false, highlightVerse: null, shouldHighlightSura: false)));
          },
          icon: const Icon(Icons.auto_stories),
          label: const Text("متابعة القراءة", style: TextStyle(fontFamily: "cairo")),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff6B8E4E), foregroundColor: Colors.white, minimumSize: Size(double.infinity, 48.h)),
        ),
        SizedBox(height: 12.h),
        OutlinedButton.icon(
          onPressed: () async {
            final ok = await showDialog<bool>(context: context, builder: (c)=> AlertDialog(title: const Text("إلغاء الهدف", style: TextStyle(fontFamily: "cairo")), content: const Text("هل تريد إلغاء هدف الختمة الحالي؟", style: TextStyle(fontFamily: "cairo")), actions: [TextButton(onPressed: ()=> Navigator.pop(c,false), child: const Text("إلغاء")), TextButton(onPressed: ()=> Navigator.pop(c,true), child: const Text("نعم"))]));
            if (ok==true) { KhatmaService.deleteGoal(); setState(() {}); }
          },
          icon: const Icon(Icons.delete_outline),
          label: const Text("إلغاء الهدف", style: TextStyle(fontFamily: "cairo")),
        ),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: Colors.grey[200]!), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)]),
      child: Column(
        children: [
          Icon(icon, color: color, size: 26.sp),
          SizedBox(height: 6.h),
          Text(value, style: TextStyle(fontFamily: "cairo", fontWeight: FontWeight.bold, fontSize: 14.sp, color: color)),
          SizedBox(height: 2.h),
          Text(title, style: TextStyle(fontFamily: "cairo", fontSize: 11.sp, color: Colors.grey[600])),
        ],
      ),
    );
  }

  void _createGoal(int days) {
    final start = DateTime.now();
    final end = start.add(Duration(days: days -1));
    KhatmaService.createGoal(startDate: start, endDate: end);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("تم إنشاء هدف $days يوم - ${ (KhatmaService.totalPages/days).ceil()} صفحة/يوم", style: const TextStyle(fontFamily: "cairo"))));
  }

  Future<void> _pickCustom() async {
    final pickedEnd = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 30)), firstDate: DateTime.now().add(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 365)), locale: const Locale("ar"));
    if (pickedEnd != null) {
      final start = DateTime.now();
      if (pickedEnd.isAfter(start)) {
        KhatmaService.createGoal(startDate: start, endDate: pickedEnd);
        setState(() {});
      }
    }
  }
}
