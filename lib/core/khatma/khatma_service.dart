import 'package:nabd/GlobalHelpers/hive_helper.dart';
import 'package:quran/quran.dart' as quran;

class KhatmaService {
  static const int totalPages = 604;

  static Map<String, dynamic>? getActiveGoal() {
    final raw = getValue("khatma_goal");
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.isNotEmpty) {
      try {
        // fallback if stored as string? not needed
      } catch (_) {}
    }
    return null;
  }

  static void createGoal({required DateTime startDate, required DateTime endDate, int? startPage}) {
    // إذا لم يحدد startPage، ابدأ من lastRead الحالي أو 1 (حسب طلب المستخدم: من تاريخ التفعيل)
    int effectiveStart = startPage ?? 1;
    if (startPage == null) {
      final lastRead = getValue("lastRead");
      if (lastRead is int && lastRead >= 1 && lastRead <= 604) {
        effectiveStart = lastRead;
      } else if (lastRead is String) {
        final parsed = int.tryParse(lastRead);
        if (parsed != null && parsed >= 1 && parsed <= 604) effectiveStart = parsed;
      }
    }
    final days = endDate.difference(DateTime(startDate.year, startDate.month, startDate.day)).inDays + 1;
    final remaining = totalPages - effectiveStart + 1;
    final daily = (remaining / days).ceil();
    final map = {
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'startPage': effectiveStart,
      'totalPages': remaining,
      'dailyGoal': daily,
      'createdAt': DateTime.now().toIso8601String(),
    };
    updateValue("khatma_goal", map);
    updateValue("khatma_pages_read", <int>[]);
    updateValue("khatma_lastStreakDate", null);
  }

  static void deleteGoal() {
    updateValue("khatma_goal", null);
    updateValue("khatma_pages_read", <int>[]);
  }

  static int getTodayRead() {
    final key = _dateKey(DateTime.now());
    return int.tryParse(getValue("$key-quran_reading-count")?.toString() ?? "0") ?? 0;
  }

  static int getProgressPages() {
    final goal = getActiveGoal();
    if (goal == null) return 0;
    // أولوية للصفحات المسجلة فعلياً (أدق من lastRead)
    final khatmaPages = getValue("khatma_pages_read");
    if (khatmaPages is List && khatmaPages.isNotEmpty) {
      final startPage = (goal['startPage'] as int?) ?? 1;
      final set = khatmaPages.map((e) => int.tryParse(e.toString()) ?? -1).where((e) => e >= startPage).toSet();
      return set.length;
    }
    final startPage = (goal['startPage'] as int?) ?? 1;
    final lastRead = getValue("lastRead");
    int currentPage = 0;
    if (lastRead is int) currentPage = lastRead;
    if (lastRead is String) currentPage = int.tryParse(lastRead) ?? 0;
    if (currentPage < startPage) return 0;
    return (currentPage - startPage + 1).clamp(0, totalPages);
  }

  static double getProgressPercent() {
    final goal = getActiveGoal();
    if (goal == null) return 0;
    final total = (goal['totalPages'] as int?) ?? totalPages;
    final progress = getProgressPages();
    return (progress / total).clamp(0.0, 1.0);
  }

  static int getDaysRemaining() {
    final goal = getActiveGoal();
    if (goal == null) return 0;
    final end = DateTime.tryParse(goal['endDate'].toString());
    if (end == null) return 0;
    final now = DateTime.now();
    final diff = DateTime(end.year, end.month, end.day).difference(DateTime(now.year, now.month, now.day)).inDays + 1;
    return diff < 0 ? 0 : diff;
  }

  static int getDaysPassed() {
    final goal = getActiveGoal();
    if (goal == null) return 0;
    final start = DateTime.tryParse(goal['startDate'].toString());
    if (start == null) return 0;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).difference(DateTime(start.year, start.month, start.day)).inDays + 1;
  }

  static bool isGoalAchieved() {
    return getProgressPercent() >= 1.0;
  }

  static String _dateKey(DateTime d) {
    final y = d.year.toString().padLeft(4,'0');
    final m = d.month.toString().padLeft(2,'0');
    final day = d.day.toString().padLeft(2,'0');
    return "$y-$m-$day";
  }

  static int getStreak() {
    int streak = 0;
    DateTime d = DateTime.now();
    while (true) {
      final key = _dateKey(d);
      final cnt = int.tryParse(getValue("$key-quran_reading-count")?.toString() ?? "0") ?? 0;
      if (cnt > 0) {
        streak++;
        d = d.subtract(const Duration(days: 1));
        if (streak > 365) break;
      } else {
        if (streak == 0 && d.day == DateTime.now().day) {
          d = d.subtract(const Duration(days: 1));
          continue;
        }
        break;
      }
    }
    return streak;
  }

  static List<int> getPagesForSurah(int surahNumber) {
    final List<int> pages = [];
    for (int p = 1; p <= totalPages; p++) {
      try {
        final data = quran.getPageData(p);
        for (final e in data) {
          if (e["surah"] == surahNumber) {
            pages.add(p);
            break;
          }
          // صفحات تحتوي سور متعددة: تحقق إذا السورة ضمن النطاق
          final start = e["start"] as int?;
          final end = e["end"] as int?;
          if (start != null && end != null && e["surah"] == surahNumber) {
            pages.add(p);
            break;
          }
        }
      } catch (_) {}
    }
    return pages;
  }

  static List<Map<String, dynamic>> getReadSurahs() {
    final goal = getActiveGoal();
    if (goal == null) return [];
    final khatmaPages = getValue("khatma_pages_read");
    Set<int> readSet = {};
    if (khatmaPages is List) {
      readSet = khatmaPages.map((e) => int.tryParse(e.toString()) ?? -1).where((e) => e > 0).toSet();
    }
    final List<Map<String, dynamic>> result = [];
    for (int s = 1; s <= 114; s++) {
      final pages = getPagesForSurah(s);
      if (pages.isEmpty) continue;
      int readCount = pages.where((p) => readSet.contains(p)).length;
      if (readCount == 0) continue;
      double percent = readCount / pages.length;
      // فقط المكتملة كما طلب المستخدم (الخيار 3)
      if (percent >= 1.0) {
        String name;
        try { name = quran.getSurahNameArabic(s); } catch (_) { name = "سورة $s"; }
        result.add({"surah": s, "name": name, "read": readCount, "total": pages.length, "percent": percent});
      }
    }
    return result;
  }

  static List<int> getPagesForDate(String dateKey) {
    final raw = getValue("$dateKey-quran_reading-pages");
    if (raw is List) {
      return raw.map((e) => int.tryParse(e.toString()) ?? -1).where((e) => e > 0).toList()..sort();
    }
    return [];
  }
}
