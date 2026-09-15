import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        title: Text("khatma".tr(), style: const TextStyle(fontFamily: "cairo")),
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

    return SafeArea(
      bottom: true,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16.w, 16.w, 16.w, 16.w + MediaQuery.of(context).padding.bottom + 24.h),
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
            if (jData == null || (jData is List && jData.isEmpty)) {
              try {
                final str = await rootBundle.loadString('assets/json/surahs.json');
                jData = json.decode(str);
              } catch (_) {}
            }
            if (qData == null || (qData is List && qData.isEmpty)) {
              try {
                final str = await rootBundle.loadString('assets/json/quarters.json');
                qData = json.decode(str);
              } catch (_) {}
            }
            jData ??= [];
            qData ??= [];
            if (!mounted) return;
            Navigator.push(context, MaterialPageRoute(builder: (_) => QuranDetailsPage(pageNumber: page, jsonData: jData, quarterJsonData: qData, shouldHighlightText: false, highlightVerse: null, shouldHighlightSura: false, fromKhatma: true)));
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
        SizedBox(height: 16.h),
        _buildReadSurahs(goal),
        SizedBox(height: 12.h),
        _buildPagesGrid(goal),
        SizedBox(height: 12.h),
        _buildDailyRecord(),
      ],
    ),
    );
  }

  Widget _buildReadSurahs(Map<String, dynamic> goal) {
    final completed = KhatmaService.getReadSurahs();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r), side: BorderSide(color: Colors.grey.shade200)),
      child: ExpansionTile(
        leading: Icon(Icons.check_circle, color: completed.isEmpty ? Colors.grey : const Color(0xff6B8E4E)),
        title: Text("السور المكتملة (${completed.length})", style: const TextStyle(fontFamily: "cairo", fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text(completed.isEmpty ? "لم تكتمل أي سورة بعد" : "اضغط لعرض السور المكتملة", style: TextStyle(fontFamily: "cairo", fontSize: 11, color: Colors.grey[600])),
        children: [
          if (completed.isEmpty)
            Padding(padding: EdgeInsets.all(12.w), child: Text("اقرأ صفحات سورة كاملة لتظهر هنا", style: TextStyle(fontFamily: "cairo", color: Colors.grey[500]))),
          if (completed.isNotEmpty)
            Padding(
              padding: EdgeInsets.all(12.w),
              child: Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: completed.map((s) => Chip(
                  label: Text(s["name"], style: const TextStyle(fontFamily: "cairo", fontSize: 11)),
                  backgroundColor: const Color(0xff6B8E4E).withOpacity(0.12),
                  side: const BorderSide(color: Color(0xff6B8E4E)),
                  avatar: const Icon(Icons.check, size: 14, color: Color(0xff6B8E4E)),
                )).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPagesGrid(Map<String, dynamic> goal) {
    final startPage = (goal['startPage'] as int?) ?? 1;
    final khatmaPages = getValue("khatma_pages_read");
    Set<int> readSet = {};
    if (khatmaPages is List) readSet = khatmaPages.map((e) => int.tryParse(e.toString()) ?? -1).where((e) => e >= startPage).toSet();
    final total = (goal['totalPages'] as int?) ?? KhatmaService.totalPages;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r), side: BorderSide(color: Colors.grey.shade200)),
      child: ExpansionTile(
        leading: const Icon(Icons.grid_view, color: Color(0xff6B8E4E)),
        title: Text("الصفحات المقروءة (${readSet.length}/$total)", style: const TextStyle(fontFamily: "cairo", fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text("من صفحة $startPage إلى 604 - اضغط على رقم للانتقال", style: TextStyle(fontFamily: "cairo", fontSize: 11, color: Colors.grey[600])),
        children: [
          Padding(
            padding: EdgeInsets.all(12.w),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 10, crossAxisSpacing: 6, mainAxisSpacing: 6, childAspectRatio: 1),
              itemCount: total,
              itemBuilder: (context, idx) {
                final pageNum = startPage + idx;
                final isRead = readSet.contains(pageNum);
                return InkWell(
                  onTap: () async {
                    dynamic jData; dynamic qData;
                    try {
                      final str = await rootBundle.loadString('assets/json/surahs.json');
                      jData = json.decode(str);
                    } catch (_) {}
                    try {
                      final str = await rootBundle.loadString('assets/json/quarters.json');
                      qData = json.decode(str);
                    } catch (_) {}
                    if (!mounted) return;
                    Navigator.push(context, MaterialPageRoute(builder: (_) => QuranDetailsPage(pageNumber: pageNum, jsonData: jData ?? [], quarterJsonData: qData ?? [], shouldHighlightText: false, highlightVerse: null, shouldHighlightSura: false, fromKhatma: true)));
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isRead ? const Color(0xff6B8E4E) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(color: isRead ? const Color(0xff6B8E4E) : Colors.grey[300]!),
                    ),
                    child: Center(
                      child: isRead
                          ? Icon(Icons.check, size: 14.sp, color: Colors.white)
                          : Text("$pageNum", style: TextStyle(fontSize: 9.sp, fontFamily: "roboto", color: Colors.grey[700])),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: 12.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 12.w, height: 12.w, decoration: const BoxDecoration(color: Color(0xff6B8E4E), shape: BoxShape.circle)),
                SizedBox(width: 4.w),
                Text("مقروءة", style: TextStyle(fontSize: 10.sp, fontFamily: "cairo")),
                SizedBox(width: 12.w),
                Container(width: 12.w, height: 12.w, decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle, border: Border.all(color: Colors.grey[300]!))),
                SizedBox(width: 4.w),
                Text("متبقية", style: TextStyle(fontSize: 10.sp, fontFamily: "cairo")),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyRecord() {
    final List<Map<String, dynamic>> last7 = [];
    for (int i = 6; i >= 0; i--) {
      final d = DateTime.now().subtract(Duration(days: i));
      final key = "${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}";
      final pages = KhatmaService.getPagesForDate(key);
      last7.add({"date": d, "key": key, "pages": pages});
    }
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r), side: BorderSide(color: Colors.grey.shade200)),
      child: ExpansionTile(
        leading: const Icon(Icons.calendar_today, color: Color(0xff6B8E4E)),
        title: const Text("سجل الأيام السبعة", style: TextStyle(fontFamily: "cairo", fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text("اضغط على يوم لعرض صفحاته", style: TextStyle(fontFamily: "cairo", fontSize: 11, color: Colors.grey[600])),
        children: last7.map((entry) {
          final d = entry["date"] as DateTime;
          final pages = entry["pages"] as List<int>;
          final label = DateFormat('yyyy-MM-dd').format(d);
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            child: Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(color: pages.isEmpty ? Colors.grey[50] : const Color(0xff6B8E4E).withOpacity(0.06), borderRadius: BorderRadius.circular(8.r), border: Border.all(color: pages.isEmpty ? Colors.grey[200]! : const Color(0xff6B8E4E).withOpacity(0.2))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(label, style: TextStyle(fontFamily: "roboto", fontWeight: FontWeight.bold, fontSize: 12.sp, color: pages.isEmpty ? Colors.grey[600] : const Color(0xff6B8E4E))),
                      const Spacer(),
                      Text("${pages.length} صفحة", style: TextStyle(fontFamily: "cairo", fontSize: 11.sp, color: Colors.grey[700])),
                    ],
                  ),
                  if (pages.isNotEmpty) SizedBox(height: 6.h),
                  if (pages.isNotEmpty)
                    Wrap(
                      spacing: 6.w,
                      runSpacing: 6.h,
                      children: pages.map((p) => InkWell(
                        onTap: () async {
                          dynamic jData; dynamic qData;
                          try { final str = await rootBundle.loadString('assets/json/surahs.json'); jData = json.decode(str); } catch (_) {}
                          try { final str = await rootBundle.loadString('assets/json/quarters.json'); qData = json.decode(str); } catch (_) {}
                          if (!mounted) return;
                          Navigator.push(context, MaterialPageRoute(builder: (_) => QuranDetailsPage(pageNumber: p, jsonData: jData ?? [], quarterJsonData: qData ?? [], shouldHighlightText: false, highlightVerse: null, shouldHighlightSura: false, fromKhatma: true)));
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                          decoration: BoxDecoration(color: const Color(0xff6B8E4E), borderRadius: BorderRadius.circular(6.r)),
                          child: Text("$p", style: TextStyle(color: Colors.white, fontSize: 11.sp, fontFamily: "roboto")),
                        ),
                      )).toList(),
                    ),
                  if (pages.isEmpty) Text("لا توجد قراءة", style: TextStyle(fontFamily: "cairo", fontSize: 11.sp, color: Colors.grey[500])),
                ],
              ),
            ),
          );
        }).toList(),
      ),
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
