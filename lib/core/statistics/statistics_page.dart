import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:nabd/GlobalHelpers/hive_helper.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  String _selectedPeriod = 'all';
  DateTime? _startDate;
  DateTime? _endDate;
  Map<String, int> _cachedStats = {};
  Map<String, Map<String, int>> _cachedComparison = {};
  List<Map<String, dynamic>> _cachedChartData = [];
  bool _isLoading = false;
  Timer? _autoRefreshTimer;

  final List<Map<String, String>> _periods = [
    {'value': 'today', 'label': 'اليوم'},
    {'value': 'week', 'label': 'أسبوع'},
    {'value': 'month', 'label': 'شهر'},
    {'value': 'all', 'label': 'الكل'},
    {'value': 'custom', 'label': 'مخصص'},
  ];

  @override
  void initState() {
    super.initState();
    _refreshStats();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) _refreshStats();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _refreshStats() {
    setState(() {
      _isLoading = true;
      _cachedStats = _getStatisticsData();
      _cachedComparison = _getComparisonData();
      _cachedChartData = _getChartData();
      _isLoading = false;
    });
  }

  // ===== Helpers =====
  int _getDaily(String dateKey, String type) {
    return int.tryParse(getValue("$dateKey-$type-count")?.toString() ?? "0") ?? 0;
  }

  int _getListeningMinutes(String dateKey) {
    final sec = int.tryParse(getValue("$dateKey-quran_listening-seconds")?.toString() ?? "0") ?? 0;
    final minFallback = int.tryParse(getValue("$dateKey-quran_listening-count")?.toString() ?? "0") ?? 0;
    if (sec > 0) return sec ~/ 60;
    return minFallback;
  }

  int _getTotal(String key) {
    return int.tryParse(getValue(key)?.toString() ?? "0") ?? 0;
  }

  int _getListeningTotalMinutes() {
    final sec = _getTotal("quran_listening-totalSeconds");
    final fallback = _getTotal("quran_listening-totalCount");
    if (sec > 0) return sec ~/ 60;
    return fallback;
  }

  // ===== Statistics Data =====
  Map<String, int> _getStatisticsData() {
    // Custom range: sum daily
    if (_selectedPeriod == 'custom' && _startDate != null && _endDate != null) {
      int sumTasbeeh = 0, sumAzkar = 0, sumReading = 0, sumListening = 0;
      DateTime d = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
      final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
      while (!d.isAfter(end)) {
        final key = DateFormat('yyyy-MM-dd').format(d);
        sumTasbeeh += _getDaily(key, "tasbeeh");
        sumAzkar += _getDaily(key, "azkar");
        sumReading += _getDaily(key, "quran_reading");
        sumListening += _getListeningMinutes(key);
        d = d.add(const Duration(days: 1));
      }
      return {
        'tasbeeh': sumTasbeeh,
        'azkar': sumAzkar,
        'quranReading': sumReading,
        'quranListening': sumListening,
      };
    }

    if (_selectedPeriod == 'today') {
      final key = DateFormat('yyyy-MM-dd').format(DateTime.now());
      return {
        'tasbeeh': _getDaily(key, "tasbeeh"),
        'azkar': _getDaily(key, "azkar"),
        'quranReading': _getDaily(key, "quran_reading"),
        'quranListening': _getListeningMinutes(key),
      };
    }

    if (_selectedPeriod == 'week' || _selectedPeriod == 'month') {
      final days = _selectedPeriod == 'week' ? 7 : 30;
      int sumTasbeeh = 0, sumAzkar = 0, sumReading = 0, sumListening = 0;
      final now = DateTime.now();
      for (int i = 0; i < days; i++) {
        final d = now.subtract(Duration(days: i));
        final key = DateFormat('yyyy-MM-dd').format(d);
        sumTasbeeh += _getDaily(key, "tasbeeh");
        sumAzkar += _getDaily(key, "azkar");
        sumReading += _getDaily(key, "quran_reading");
        sumListening += _getListeningMinutes(key);
      }
      return {
        'tasbeeh': sumTasbeeh,
        'azkar': sumAzkar,
        'quranReading': sumReading,
        'quranListening': sumListening,
      };
    }

    // all
    return {
      'tasbeeh': _getTotal("tasbeeh-totalCount"),
      'azkar': _getTotal("azkar-totalCount"),
      'quranReading': _getTotal("quran_reading-totalCount"),
      'quranListening': _getListeningTotalMinutes(),
    };
  }

  Map<String, Map<String, int>> _getComparisonData() {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final tKey = DateFormat('yyyy-MM-dd').format(today);
    final yKey = DateFormat('yyyy-MM-dd').format(yesterday);
    return {
      'tasbeeh': {'yesterday': _getDaily(yKey, "tasbeeh"), 'today': _getDaily(tKey, "tasbeeh")},
      'azkar': {'yesterday': _getDaily(yKey, "azkar"), 'today': _getDaily(tKey, "azkar")},
      'quranReading': {'yesterday': _getDaily(yKey, "quran_reading"), 'today': _getDaily(tKey, "quran_reading")},
      'quranListening': {'yesterday': _getListeningMinutes(yKey), 'today': _getListeningMinutes(tKey)},
    };
  }

  List<Map<String, dynamic>> _getChartData() {
    final List<Map<String, dynamic>> chartData = [];
    if (_selectedPeriod == 'custom' && _startDate != null && _endDate != null) {
      DateTime d = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
      final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
      while (!d.isAfter(end)) {
        final key = DateFormat('yyyy-MM-dd').format(d);
        chartData.add({
          'day': DateFormat('MM/dd', 'ar').format(d),
          'fullDate': key,
          'tasbeeh': _getDaily(key, "tasbeeh"),
          'azkar': _getDaily(key, "azkar"),
          'quranReading': _getDaily(key, "quran_reading"),
          'quranListening': _getListeningMinutes(key),
        });
        d = d.add(const Duration(days: 1));
      }
      return chartData;
    }

    // For week/month/all/today - show last 7 or 30 days
    int days = 7;
    if (_selectedPeriod == 'month') days = 30;
    if (_selectedPeriod == 'today') days = 7; // show week context for today
    if (_selectedPeriod == 'all') days = 7;

    final now = DateTime.now();
    for (int i = days - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(date);
      String label;
      try {
        label = DateFormat('E', 'ar').format(date);
      } catch (_) {
        label = DateFormat('MM/dd').format(date);
      }
      chartData.add({
        'day': label,
        'fullDate': key,
        'tasbeeh': _getDaily(key, "tasbeeh"),
        'azkar': _getDaily(key, "azkar"),
        'quranReading': _getDaily(key, "quran_reading"),
        'quranListening': _getListeningMinutes(key),
      });
    }
    return chartData;
  }

  Future<void> _selectDate(bool isStartDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale("ar"),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          if (_startDate != null && _startDate!.isAfter(_endDate!)) {
            _startDate = _endDate;
          }
        }
        if (_startDate != null && _endDate != null) {
          _selectedPeriod = 'custom';
        }
        _refreshStats();
      });
    }
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    final isDark = getValue("darkMode") == true;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff1a1a1a) : const Color(0xffF5EFE8),
        image: DecorationImage(
          fit: BoxFit.cover,
          image: AssetImage(isDark ? "assets/images/darkbg.png" : "assets/images/try6.png"),
          opacity: 0.3,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text("statistics".tr(), style: TextStyle(color: Colors.white, fontSize: 18.sp, fontFamily: "cairo")),
          backgroundColor: isDark ? const Color(0xff2C2C2C) : const Color(0xff6B8E4E),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              onPressed: _refreshStats,
              icon: const Icon(Icons.refresh, color: Colors.white),
              tooltip: "تحديث",
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async => _refreshStats(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPeriodSelector(),
                SizedBox(height: 16.h),
                if (_selectedPeriod == 'custom') _buildCustomRangePicker(),
                SizedBox(height: 12.h),
                _buildSummaryCards(),
                SizedBox(height: 16.h),
                _buildChartsSection(),
                SizedBox(height: 16.h),
                _buildComparisonSection(),
                SizedBox(height: 16.h),
                _buildTotalsInfo(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("الفترة", style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, fontFamily: "cairo")),
          SizedBox(height: 8.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _periods.map((p) {
                final isSelected = _selectedPeriod == p['value'];
                return Padding(
                  padding: EdgeInsets.only(left: 8.w),
                  child: ChoiceChip(
                    label: Text(p['label']!, style: TextStyle(fontFamily: "cairo", fontSize: 12.sp, color: isSelected ? Colors.white : Colors.black87)),
                    selected: isSelected,
                    selectedColor: const Color(0xff6B8E4E),
                    backgroundColor: Colors.grey[200],
                    onSelected: (_) {
                      setState(() {
                        _selectedPeriod = p['value']!;
                        if (_selectedPeriod != 'custom') {
                          _refreshStats();
                        }
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomRangePicker() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(12.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("نطاق مخصص", style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, fontFamily: "cairo")),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _selectDate(true),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(_startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : "من", style: const TextStyle(fontFamily: "cairo")),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _selectDate(false),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(_endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : "إلى", style: const TextStyle(fontFamily: "cairo")),
                ),
              ),
            ],
          ),
          if (_startDate != null && _endDate != null)
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Text(
                "من ${DateFormat('yyyy-MM-dd').format(_startDate!)} إلى ${DateFormat('yyyy-MM-dd').format(_endDate!)}",
                style: TextStyle(fontSize: 11.sp, color: Colors.grey[600], fontFamily: "cairo"),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    if (_cachedStats.values.every((v) => v == 0)) {
      return _buildEmptyState();
    }
    final s = _cachedStats;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildStatCard("السبحة", s['tasbeeh'] ?? 0, Icons.toll, const Color(0xff4A90E2), "مرة")),
            SizedBox(width: 10.w),
            Expanded(child: _buildStatCard("الأذكار", s['azkar'] ?? 0, Icons.menu_book, const Color(0xff7ED321), "مرة")),
          ],
        ),
        SizedBox(height: 10.h),
        Row(
          children: [
            Expanded(child: _buildStatCard("القراءة", s['quranReading'] ?? 0, Icons.auto_stories, const Color(0xff9013FE), "صفحة")),
            SizedBox(width: 10.w),
            Expanded(child: _buildStatCard("الاستماع", s['quranListening'] ?? 0, Icons.headphones, const Color(0xffF5A623), "دقيقة")),
          ],
        ),
        if (_selectedPeriod != 'all')
          Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: Text(
              _periodLabel(),
              style: TextStyle(fontSize: 11.sp, color: Colors.grey[600], fontFamily: "cairo"),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  String _periodLabel() {
    switch (_selectedPeriod) {
      case 'today': return "إحصائيات اليوم";
      case 'week': return "آخر 7 أيام";
      case 'month': return "آخر 30 يوم";
      case 'custom': return "نطاق مخصص";
      default: return "الإجمالي الكلي";
    }
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.all(32.w),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(12.r)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, size: 64.sp, color: Colors.grey[400]),
          SizedBox(height: 16.h),
          Text("لا توجد بيانات بعد", textAlign: TextAlign.center, style: TextStyle(fontSize: 16.sp, fontFamily: "cairo", color: Colors.grey[700])),
          SizedBox(height: 8.h),
          Text("ابدأ التسبيح وقراءة القرآن لتظهر إحصائياتك", textAlign: TextAlign.center, style: TextStyle(fontSize: 13.sp, fontFamily: "cairo", color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int value, IconData icon, Color color, String unit) {
    final isDark = getValue("darkMode") == true;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
        boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10.r)),
                child: Icon(icon, color: color, size: 22.sp),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(value.toString(), style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold, color: color, fontFamily: "roboto")),
                  Text(unit, style: TextStyle(fontSize: 11.sp, color: color.withOpacity(0.7), fontFamily: "cairo")),
                ],
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(title, style: TextStyle(fontSize: 13.sp, color: isDark ? Colors.grey[300] : Colors.grey[700], fontFamily: "cairo", fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildChartsSection() {
    if (_cachedChartData.isEmpty) return const SizedBox.shrink();
    final hasData = _cachedChartData.any((d) => (d['tasbeeh'] ?? 0) > 0 || (d['azkar'] ?? 0) > 0 || (d['quranReading'] ?? 0) > 0 || (d['quranListening'] ?? 0) > 0);
    if (!hasData) {
      return Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(12.r)),
        child: Column(
          children: [
            Text("التقدم اليومي", style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, fontFamily: "cairo")),
            SizedBox(height: 20.h),
            Text("لا يوجد نشاط في هذه الفترة", style: TextStyle(color: Colors.grey[500], fontFamily: "cairo")),
          ],
        ),
      );
    }
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(12.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text("التقدم اليومي", style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, fontFamily: "cairo")),
              const Spacer(),
              Text("${_cachedChartData.length} يوم", style: TextStyle(fontSize: 11.sp, color: Colors.grey[500], fontFamily: "cairo")),
            ],
          ),
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8.r)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegendItem("تسبيح", const Color(0xff4A90E2)),
                _buildLegendItem("أذكار", const Color(0xff7ED321)),
                _buildLegendItem("قراءة", const Color(0xff9013FE)),
                _buildLegendItem("استماع", const Color(0xffF5A623)),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          SizedBox(height: 260.h, child: LineChart(_buildLineChartData())),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14.w, height: 3.h, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2.r))),
        SizedBox(width: 4.w),
        Text(label, style: TextStyle(fontSize: 10.sp, fontFamily: "cairo", color: Colors.grey[700])),
      ],
    );
  }

  Widget _buildComparisonSection() {
    if (_cachedComparison.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(12.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("مقارنة اليوم بالأمس", style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, fontFamily: "cairo")),
          SizedBox(height: 4.h),
          Text("تابع تطورك اليومي", style: TextStyle(fontSize: 11.sp, color: Colors.grey[500], fontFamily: "cairo")),
          SizedBox(height: 16.h),
          _buildComparisonItem("السبحة", _cachedComparison['tasbeeh'] ?? {'yesterday': 0, 'today': 0}),
          _buildComparisonItem("الأذكار", _cachedComparison['azkar'] ?? {'yesterday': 0, 'today': 0}),
          _buildComparisonItem("القراءة", _cachedComparison['quranReading'] ?? {'yesterday': 0, 'today': 0}),
          _buildComparisonItem("الاستماع", _cachedComparison['quranListening'] ?? {'yesterday': 0, 'today': 0}),
        ],
      ),
    );
  }

  Widget _buildComparisonItem(String title, Map<String, int> data) {
    final yesterday = data['yesterday'] ?? 0;
    final today = data['today'] ?? 0;
    final change = today - yesterday;
    int percentage;
    String percentageText;
    if (yesterday == 0) {
      if (today == 0) {
        percentage = 0;
        percentageText = "0%";
      } else {
        percentage = 100;
        percentageText = "+100%";
      }
    } else {
      percentage = ((change / yesterday) * 100).round();
      percentageText = "${percentage > 0 ? "+" : ""}$percentage%";
    }
    final isPositive = change >= 0;
    final isZero = change == 0;
    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(title, style: TextStyle(fontSize: 13.sp, fontFamily: "cairo"))),
          Expanded(child: Text(yesterday.toString(), style: TextStyle(fontSize: 13.sp, color: Colors.grey[500], fontFamily: "roboto"), textAlign: TextAlign.center)),
          Expanded(child: Text(today.toString(), style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, fontFamily: "roboto"), textAlign: TextAlign.center)),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: isZero ? Colors.grey[100] : (isPositive ? Colors.green[50] : Colors.red[50]),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isZero ? Icons.horizontal_rule : (isPositive ? Icons.trending_up : Icons.trending_down),
                    color: isZero ? Colors.grey : (isPositive ? Colors.green[700] : Colors.red[700]),
                    size: 14.sp,
                  ),
                  SizedBox(width: 2.w),
                  Text(percentageText, style: TextStyle(fontSize: 11.sp, color: isZero ? Colors.grey[600] : (isPositive ? Colors.green[700] : Colors.red[700]), fontWeight: FontWeight.bold, fontFamily: "roboto")),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  LineChartData _buildLineChartData() {
    final data = _cachedChartData;
    // حماية من القيم خارج النطاق
    double maxY = 1;
    for (final d in data) {
      maxY = [
        maxY,
        (d['tasbeeh'] as int).toDouble(),
        (d['azkar'] as int).toDouble(),
        (d['quranReading'] as int).toDouble(),
        (d['quranListening'] as int).toDouble(),
      ].reduce((a, b) => a > b ? a : b);
    }
    maxY = (maxY * 1.2).ceilToDouble();
    if (maxY < 5) maxY = 5;

    return LineChartData(
      minY: 0,
      maxY: maxY,
      gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxY / 4, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey[200]!, strokeWidth: 1, dashArray: [5, 5])),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 32,
            interval: maxY / 4,
            getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: TextStyle(fontSize: 9.sp, color: Colors.grey[600])),
          ),
        ),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final idx = value.toInt();
              if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
              // إظهار كل تسمية ثانية إذا كان العدد كبير
              if (data.length > 14 && idx % 2 != 0) return const SizedBox.shrink();
              if (data.length > 20 && idx % 3 != 0) return const SizedBox.shrink();
              return Padding(
                padding: EdgeInsets.only(top: 6.h),
                child: Text(data[idx]['day'] ?? '', style: TextStyle(fontSize: 9.sp, color: Colors.grey[700], fontFamily: "cairo")),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        _lineBar(data, 'tasbeeh', const Color(0xff4A90E2)),
        _lineBar(data, 'azkar', const Color(0xff7ED321)),
        _lineBar(data, 'quranReading', const Color(0xff9013FE)),
        _lineBar(data, 'quranListening', const Color(0xffF5A623)),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          tooltipPadding: EdgeInsets.all(10.w),
          getTooltipItems: (spots) {
            return spots.map((spot) {
              final idx = spot.x.toInt();
              if (idx < 0 || idx >= data.length) return null;
              final d = data[idx];
              return LineTooltipItem(
                '${d['fullDate'] ?? d['day']}\nتسبيح: ${d['tasbeeh']}  أذكار: ${d['azkar']}\nقراءة: ${d['quranReading']}  استماع: ${d['quranListening']}',
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10.sp, fontFamily: "cairo"),
              );
            }).whereType<LineTooltipItem>().toList();
          },
        ),
      ),
    );
  }

  LineChartBarData _lineBar(List<Map<String, dynamic>> data, String key, Color color) {
    return LineChartBarData(
      spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value[key] as int).toDouble())).toList(),
      isCurved: true,
      curveSmoothness: 0.3,
      color: color,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: FlDotData(show: true, getDotPainter: (spot, percent, bar, idx) => FlDotCirclePainter(radius: 3, color: color, strokeWidth: 1, strokeColor: Colors.white)),
      belowBarData: BarAreaData(show: true, color: color.withOpacity(0.08)),
    );
  }

  Widget _buildTotalsInfo() {
    final s = _cachedStats;
    final totalActions = (s['tasbeeh'] ?? 0) + (s['azkar'] ?? 0) + (s['quranReading'] ?? 0) + (s['quranListening'] ?? 0);
    if (totalActions == 0) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(color: const Color(0xff6B8E4E).withOpacity(0.08), borderRadius: BorderRadius.circular(12.r), border: Border.all(color: const Color(0xff6B8E4E).withOpacity(0.15))),
      child: Row(
        children: [
          Icon(Icons.insights, color: const Color(0xff6B8E4E), size: 20.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("ملخص الفترة", style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, fontFamily: "cairo", color: const Color(0xff6B8E4E))),
                Text("إجمالي النشاط: $totalActions • ${_periodLabel()}", style: TextStyle(fontSize: 11.sp, color: Colors.grey[700], fontFamily: "cairo")),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
