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

  // 1. إضافة مؤقت للتحديث التلقائي لضمان "حيوية" البيانات
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshStats();
    // تحديث البيانات كل 30 ثانية تلقائياً لجلب وقت الاستماع الجديد من الـ BLoC
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

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.all(32.w),
      decoration: BoxDecoration(
        color: getValue("darkMode")
            ? Colors.grey[800]!.withOpacity(0.9)
            : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart,
            size: 64.sp,
            color: getValue("darkMode") ? Colors.grey[400] : Colors.grey[600],
          ),
          SizedBox(height: 16.h),
          Text(
            "ابدأ ذكرك اليوم لتظهر إحصائياتك هنا",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.sp,
              color: getValue("darkMode") ? Colors.grey[300] : Colors.grey[700],
              fontFamily: "cairo",
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            "قم بالتسبيح وقراءة القرآن لبدء تتبع تقدمك",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.sp,
              color: getValue("darkMode") ? Colors.grey[400] : Colors.grey[600],
              fontFamily: "cairo",
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height,
      decoration: BoxDecoration(
        color: getValue("darkMode")
            ? const Color(0xff1a1a1a)
            : const Color(0xffF5EFE8),
        image: DecorationImage(
          fit: BoxFit.cover,
          image: AssetImage(
            getValue("darkMode")
                ? "assets/images/darkbg.png"
                : "assets/images/try6.png",
          ),
          opacity: 0.3,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            "statistics".tr(),
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontFamily: "cairo",
            ),
          ),
          backgroundColor: getValue("darkMode")
              ? const Color(0xff2C2C2C)
              : const Color(0xff6B8E4E),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) {
                setState(() {
                  _selectedPeriod = value;
                  _refreshStats(); // ضروري جداً لتحديث البيانات بناءً على الفترة الجديدة
                });
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'all',
                  child: Text("all_time".tr()),
                ),
                PopupMenuItem(
                  value: 'custom',
                  child: Text("custom_range".tr()),
                ),
              ],
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFilterSection(),
              SizedBox(height: 20.h),
              _buildSummaryCards(),
              SizedBox(height: 20.h),
              _buildChartsSection(),
              SizedBox(height: 20.h),
              _buildComparisonSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    if (_selectedPeriod == 'custom') {
      return Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "select_date_range".tr(),
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10.h),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _selectDate(true),
                    child: Text(
                      _startDate != null
                          ? DateFormat('yyyy-MM-dd').format(_startDate!)
                          : "start_date".tr(),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _selectDate(false),
                    child: Text(
                      _endDate != null
                          ? DateFormat('yyyy-MM-dd').format(_endDate!)
                          : "end_date".tr(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildSummaryCards() {
    if (_cachedStats.isEmpty ||
        _cachedStats.values.every((v) => (v as int) == 0)) {
      return _buildEmptyState();
    }

    final stats = _cachedStats;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                "tasbeeh".tr(),
                stats['tasbeeh'].toString(),
                Icons.toll,
                Colors.blue,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: _buildStatCard(
                "azkar".tr(),
                stats['azkar'].toString(),
                Icons.mosque,
                Colors.green,
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                "quran_reading".tr(),
                stats['quranReading'].toString(),
                Icons.book,
                Colors.purple,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: _buildStatCard(
                "quran_listening".tr(),
                stats['quranListening'].toString(),
                Icons.headphones,
                Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    // تحديد الوحدة المناسبة بناءً على العنوان
    String unit = "";
    if (title.contains("tasbeeh".tr()) || title.contains("azkar".tr())) {
      unit = "ضغطة";
    } else if (title.contains("quran_reading".tr())) {
      unit = "صفحة";
    } else if (title.contains("quran_listening".tr())) {
      unit = "دقيقة";
    }

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24.sp),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  if (unit.isNotEmpty)
                    Text(
                      unit,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: color.withOpacity(0.7),
                      ),
                    ),
                ],
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "daily_progress".tr(),
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10.h),
          // وسيلة الإيضاح
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: getValue("darkMode") ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegendItem("التسبيح", Colors.blue),
                _buildLegendItem("الأذكار", Colors.green),
                _buildLegendItem("القراءة", Colors.purple),
                _buildLegendItem("الاستماع", Colors.orange),
              ],
            ),
          ),
          SizedBox(height: 20.h),
          SizedBox(
            height: 300.h, // زيادة الارتفاع لضمان مساحة كافية لللمسات
            child: LineChart(
              _buildLineChartData(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12.w,
          height: 3.h,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
        SizedBox(width: 4.w),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.sp,
            color: getValue("darkMode") ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonSection() {
    if (_cachedComparison.isEmpty) {
      return const SizedBox.shrink();
    }

    final comparison = _cachedComparison;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "day_comparison".tr(),
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 20.h),
          _buildComparisonItem("tasbeeh".tr(),
              comparison['tasbeeh'] ?? {'yesterday': 0, 'today': 0}),
          _buildComparisonItem("azkar".tr(),
              comparison['azkar'] ?? {'yesterday': 0, 'today': 0}),
          _buildComparisonItem("quran_reading".tr(),
              comparison['quranReading'] ?? {'yesterday': 0, 'today': 0}),
          _buildComparisonItem("quran_listening".tr(),
              comparison['quranListening'] ?? {'yesterday': 0, 'today': 0}),
        ],
      ),
    );
  }

  Widget _buildComparisonItem(String title, Map<String, int> data) {
    final yesterday = data['yesterday'] ?? 0;
    final today = data['today'] ?? 0;
    final change = today - yesterday;
    final percentage = yesterday > 0 ? ((change / yesterday) * 100).round() : 0;

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              title,
              style: TextStyle(fontSize: 14.sp),
            ),
          ),
          Expanded(
            child: Text(
              yesterday.toString(),
              style: TextStyle(fontSize: 14.sp, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              today.toString(),
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Icon(
                  change >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                  color: change >= 0 ? Colors.green : Colors.red,
                  size: 16.sp,
                ),
                SizedBox(width: 4.w),
                Text(
                  "$percentage%",
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: change >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  LineChartData _buildLineChartData() {
    final data = _getChartData();

    return LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              return Text(
                data[value.toInt()]['day'] ?? '',
                style: TextStyle(fontSize: 10.sp),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        // خط التسبيح (أزرق)
        LineChartBarData(
          spots: data.asMap().entries.map((entry) {
            return FlSpot(
                entry.key.toDouble(), entry.value['tasbeeh'].toDouble());
          }).toList(),
          isCurved: true,
          color: Colors.blue,
          barWidth: 2,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
        // خط الأذكار (أخضر)
        LineChartBarData(
          spots: data.asMap().entries.map((entry) {
            return FlSpot(
                entry.key.toDouble(), entry.value['azkar'].toDouble());
          }).toList(),
          isCurved: true,
          color: Colors.green,
          barWidth: 2,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
        // خط قراءة القرآن (بنفسجي)
        LineChartBarData(
          spots: data.asMap().entries.map((entry) {
            return FlSpot(
                entry.key.toDouble(), entry.value['quranReading'].toDouble());
          }).toList(),
          isCurved: true,
          color: Colors.purple,
          barWidth: 2,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
        // خط الاستماع للقرآن (برتقالي)
        LineChartBarData(
          spots: data.asMap().entries.map((entry) {
            return FlSpot(
                entry.key.toDouble(), entry.value['quranListening'].toDouble());
          }).toList(),
          isCurved: true,
          color: Colors.orange,
          barWidth: 2,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final index = spot.x.toInt();
              final dayData = data[index];
              return LineTooltipItem(
                '${dayData['day']}\n'
                'التسبيح: ${dayData['tasbeeh']}\n'
                'الأذكار: ${dayData['azkar']}\n'
                'قراءة: ${dayData['quranReading']}\n'
                'استماع: ${dayData['quranListening']}',
                TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10.sp),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  // 2. دالة جلب الإحصائيات (تستخدم المفاتيح التي حددناها في الـ BLoC والـ UI)
  Map<String, int> _getStatisticsData() {
    // عند اختيار نطاق مخصص: نجمع القيم اليومية بين التاريخين
    if (_selectedPeriod == 'custom' && _startDate != null && _endDate != null) {
      int sumTasbeeh = 0;
      int sumAzkar = 0;
      int sumReading = 0;
      int sumListening = 0;

      DateTime d = _startDate!;
      while (!d.isAfter(_endDate!)) {
        final key = DateFormat('yyyy-MM-dd').format(d);
        sumTasbeeh +=
            int.tryParse(getValue("$key-tasbeeh-count")?.toString() ?? "0") ??
                0;
        sumAzkar +=
            int.tryParse(getValue("$key-azkar-count")?.toString() ?? "0") ?? 0;
        sumReading += int.tryParse(
                getValue("$key-quran_reading-count")?.toString() ?? "0") ??
            0;
        final listenSec = int.tryParse(
                getValue("$key-quran_listening-seconds")?.toString() ?? "0") ??
            0;
        final listenMinFallback = int.tryParse(
                getValue("$key-quran_listening-count")?.toString() ?? "0") ??
            0;
        sumListening += listenSec > 0 ? (listenSec ~/ 60) : listenMinFallback;
        d = d.add(const Duration(days: 1));
      }

      return {
        'tasbeeh': sumTasbeeh,
        'azkar': sumAzkar,
        'quranReading': sumReading,
        'quranListening': sumListening,
      };
    }

    // الوضع الافتراضي: عرض الإجمالي العام
    int totalTasbeeh =
        int.tryParse(getValue("tasbeeh-totalCount")?.toString() ?? "0") ?? 0;
    int totalAzkar =
        int.tryParse(getValue("azkar-totalCount")?.toString() ?? "0") ?? 0;
    int totalReading =
        int.tryParse(getValue("quran_reading-totalCount")?.toString() ?? "0") ??
            0;
    if (totalReading == 0) {
      totalReading = int.tryParse(getValue("lastRead")?.toString() ?? "0") ?? 0;
    }
    int totalListeningSeconds = int.tryParse(
            getValue("quran_listening-totalSeconds")?.toString() ?? "0") ??
        0;
    int totalListeningMinutesFallback = int.tryParse(
            getValue("quran_listening-totalCount")?.toString() ?? "0") ??
        0;
    int totalListening = totalListeningSeconds > 0
        ? (totalListeningSeconds ~/ 60)
        : totalListeningMinutesFallback;

    return {
      'tasbeeh': totalTasbeeh,
      'azkar': totalAzkar,
      'quranReading': totalReading,
      'quranListening': totalListening,
    };
  }

  // دالة مساعدة لتحديد عدد الأيام بناءً على الفترة
  int _getDaysCountForPeriod() {
    switch (_selectedPeriod) {
      case 'week':
        return 7;
      case 'month':
        return 30;
      case 'custom':
        if (_startDate != null && _endDate != null) {
          return _endDate!.difference(_startDate!).inDays + 1;
        }
        return 7; // افتراضي
      default:
        return 7; // افتراضي لأسبوع
    }
  }

  // 4. دالة المقارنة (تستخدم المفاتيح اليومية)
  Map<String, Map<String, int>> _getComparisonData() {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    String tKey = DateFormat('yyyy-MM-dd').format(today);
    String yKey = DateFormat('yyyy-MM-dd').format(yesterday);

    int getVal(String dKey, String type) =>
        int.tryParse(getValue("$dKey-$type-count")?.toString() ?? "0") ?? 0;
    int getListeningMinutes(String dKey) {
      final sec = int.tryParse(
              getValue("$dKey-quran_listening-seconds")?.toString() ?? "0") ??
          0;
      final minFb = int.tryParse(
              getValue("$dKey-quran_listening-count")?.toString() ?? "0") ??
          0;
      return sec > 0 ? (sec ~/ 60) : minFb;
    }

    return {
      'tasbeeh': {
        'yesterday': getVal(yKey, "tasbeeh"),
        'today': getVal(tKey, "tasbeeh")
      },
      'azkar': {
        'yesterday': getVal(yKey, "azkar"),
        'today': getVal(tKey, "azkar")
      },
      'quranReading': {
        'yesterday': getVal(yKey, "quran_reading"),
        'today': getVal(tKey, "quran_reading")
      },
      'quranListening': {
        'yesterday': getListeningMinutes(yKey),
        'today': getListeningMinutes(tKey)
      },
    };
  }

  // 3. دالة الرسم البياني المحدثة (تعرض آخر 7 أيام بالعربي)
  List<Map<String, dynamic>> _getChartData() {
    final List<Map<String, dynamic>> chartData = [];

    // إذا كان النطاق مخصصًا: نعرض كل الأيام بين البداية والنهاية
    if (_selectedPeriod == 'custom' && _startDate != null && _endDate != null) {
      DateTime d = _startDate!;
      while (!d.isAfter(_endDate!)) {
        final dateKey = DateFormat('yyyy-MM-dd').format(d);
        chartData.add({
          'day': DateFormat('E', 'ar').format(d),
          'tasbeeh': int.tryParse(
                  getValue("$dateKey-tasbeeh-count")?.toString() ?? "0") ??
              0,
          'azkar': int.tryParse(
                  getValue("$dateKey-azkar-count")?.toString() ?? "0") ??
              0,
          'quranReading': int.tryParse(
                  getValue("$dateKey-quran_reading-count")?.toString() ??
                      "0") ??
              0,
          'quranListening': int.tryParse(
                  getValue("$dateKey-quran_listening-count")?.toString() ??
                      "0") ??
              0,
        });
        d = d.add(const Duration(days: 1));
      }
      return chartData;
    }

    // افتراضي: آخر 7 أيام
    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      chartData.add({
        'day': DateFormat('E', 'ar').format(date),
        'tasbeeh': int.tryParse(
                getValue("$dateKey-tasbeeh-count")?.toString() ?? "0") ??
            0,
        'azkar':
            int.tryParse(getValue("$dateKey-azkar-count")?.toString() ?? "0") ??
                0,
        'quranReading': int.tryParse(
                getValue("$dateKey-quran_reading-count")?.toString() ?? "0") ??
            0,
        'quranListening': (() {
          final sec = int.tryParse(
                  getValue("$dateKey-quran_listening-seconds")?.toString() ??
                      "0") ??
              0;
          final minFb = int.tryParse(
                  getValue("$dateKey-quran_listening-count")?.toString() ??
                      "0") ??
              0;
          return sec > 0 ? (sec ~/ 60) : minFb;
        })(),
      });
    }
    return chartData;
  }

  DateTime _getStartDate() {
    final now = DateTime.now();

    switch (_selectedPeriod) {
      case 'custom':
        return _startDate ??
            now.subtract(const Duration(days: 6)); // افتراضي 7 أيام
      case 'all':
        return DateTime(now.year, 1, 1); // بداية السنة
      default:
        return DateTime(now.year, 1, 1); // افتراضي للكل الوقت
    }
  }

  Future<void> _selectDate(bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
        // تحديث البيانات عند تغيير نطاق التاريخ
        _refreshStats();
      });
    }
  }
}
