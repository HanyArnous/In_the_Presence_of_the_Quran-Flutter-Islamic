import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackupService {
  // مفاتيح ثابتة للسبحة
  static const List<String> _tasbeehKeys = [
    "tasbeehAll",
    "customTasbeehs",
    "tasbeehLastIndex",
  ];

  // تحديد هل المفتاح يتبع الأذكار (يشمل السبحة)
  static bool _isAzkarHiveKey(String k) {
    if (k == "customAzkarCategories" ||
        k == "azkarCategoryOverrides" ||
        k == "azkarOrder") return true;
    if (k.startsWith("customAzkar_")) return true;
    if (k.startsWith("favorites_")) return true;
    if (k.startsWith("favorites_filter_")) return true;
    if (k.startsWith("override_")) return true;
    if (k.endsWith("zikrIndex")) return true;
    final low = k.toLowerCase();
    if (low.contains("azkar") || low.contains("zikr")) return true;
    if (_tasbeehKeys.contains(k)) return true;
    if (k == "tap_sound_enabled") return true;
    if (RegExp(r'^\d+number$').hasMatch(k)) return true;
    if (RegExp(r'^\d+max$').hasMatch(k)) return true;
    if (RegExp(r'^\d+-\d+-count$').hasMatch(k)) return true;
    if (RegExp(r'^\d+-\d+-max$').hasMatch(k)) return true;
    // حالات id-based للأذكار: "123-0-count" حيث id رقمي كبير
    if (RegExp(r'^\d+-count$').hasMatch(k) || RegExp(r'^\d+-max$').hasMatch(k)) {
      // نميزها عن مفاتيح khatma التي تبدأ بـ khatma_
      return true;
    }
    return false;
  }

  static bool _isKhatmaHiveKey(String k) {
    return k.startsWith("khatma_");
  }

  static bool _isHadithPrefKey(String k) {
    return k.startsWith("categories-") ||
        k.startsWith("hadithlist-") ||
        k == "hadithHistory" ||
        k == "lastHadithIndex" ||
        k.startsWith("hadith_");
  }

  static List<String> _collectAzkarHiveKeys() {
    final box = Hive.box("name");
    final allKeys = box.keys.map((e) => e.toString()).toList();
    final filtered = <String>{};
    for (final k in allKeys) {
      if (_isAzkarHiveKey(k)) filtered.add(k);
    }
    // أيضاً أي مفتاح يحتوي tasbeeh/azkar/zikr بشكل عام
    for (final k in allKeys) {
      final low = k.toLowerCase();
      if ((low.contains("tasbeeh") || low.contains("azkar") || low.contains("zikr")) &&
          !filtered.contains(k)) {
        // استثناء مفاتيح الختمة التي قد تحتوي azkar كجزء من الإحصائيات؟ نتركها للأذكار
        filtered.add(k);
      }
    }
    return filtered.toList();
  }

  static List<String> _collectKhatmaHiveKeys() {
    final box = Hive.box("name");
    final allKeys = box.keys.map((e) => e.toString()).toList();
    return allKeys.where(_isKhatmaHiveKey).toList();
  }

  static Future<Map<String, dynamic>> _collectAzkarHive() async {
    final box = Hive.box("name");
    final keys = _collectAzkarHiveKeys();
    final map = <String, dynamic>{};
    for (final k in keys) {
      map[k] = box.get(k);
    }
    return map;
  }

  static Future<Map<String, dynamic>> _collectKhatmaHive() async {
    final box = Hive.box("name");
    final keys = _collectKhatmaHiveKeys();
    final map = <String, dynamic>{};
    for (final k in keys) {
      map[k] = box.get(k);
    }
    return map;
  }

  static Future<Map<String, dynamic>> _collectHadithPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, dynamic>{};
    for (final k in prefs.getKeys()) {
      if (_isHadithPrefKey(k)) {
        map[k] = prefs.get(k);
      }
    }
    return map;
  }

  // للتوافق القديم: يجمع الأذكار فقط كما كان
  static List<String> _collectKeys() {
    return _collectAzkarHiveKeys();
  }

  static Future<String> exportToJson() async {
    final box = Hive.box("name");
    final keys = _collectKeys();
    final Map<String, dynamic> data = {};
    for (final k in keys) {
      data[k] = box.get(k);
    }
    for (final k in box.keys) {
      final ks = k.toString();
      if ((ks.toLowerCase().contains("tasbeeh") ||
              ks.toLowerCase().contains("azkar") ||
              ks.toLowerCase().contains("zikr")) &&
          !data.containsKey(ks)) {
        data[ks] = box.get(k);
      }
    }
    data["_meta"] = {
      "app": "في رحاب الرحمن",
      "version": "4.6.5",
      "exportedAt": DateTime.now().toIso8601String(),
      "count": data.length,
    };
    return json.encode(data);
  }

  static Future<String> exportSelective({
    required bool azkar,
    required bool hadith,
    required bool khatma,
  }) async {
    final hiveMap = <String, dynamic>{};
    final prefsMap = <String, dynamic>{};
    final sections = <String>[];

    if (azkar) {
      final azkarHive = await _collectAzkarHive();
      hiveMap.addAll(azkarHive);
      sections.add("azkar");
    }
    if (khatma) {
      final khatmaHive = await _collectKhatmaHive();
      hiveMap.addAll(khatmaHive);
      sections.add("khatma");
    }
    if (hadith) {
      final hadithPrefs = await _collectHadithPrefs();
      prefsMap.addAll(hadithPrefs);
      sections.add("hadith");
    }

    final data = <String, dynamic>{
      "_meta": {
        "app": "في رحاب الرحمن",
        "version": "4.6.5",
        "exportedAt": DateTime.now().toIso8601String(),
        "sections": sections,
        "hiveCount": hiveMap.length,
        "prefsCount": prefsMap.length,
      },
      "hive": hiveMap,
      "prefs": prefsMap,
    };
    return json.encode(data);
  }

  static Future<File> exportToFile() async {
    final jsonStr = await exportToJson();
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
        "${dir.path}/backup_tasbeeh_azkar_${DateTime.now().millisecondsSinceEpoch}.json");
    await file.writeAsString(jsonStr);
    return file;
  }

  static Future<File> exportSelectiveToFile({
    required bool azkar,
    required bool hadith,
    required bool khatma,
  }) async {
    final jsonStr = await exportSelective(azkar: azkar, hadith: hadith, khatma: khatma);
    final dir = await getApplicationDocumentsDirectory();
    final suffix = [
      if (azkar) "azkar",
      if (hadith) "hadith",
      if (khatma) "khatma"
    ].join("_");
    final file = File(
        "${dir.path}/backup_${suffix}_${DateTime.now().millisecondsSinceEpoch}.json");
    await file.writeAsString(jsonStr);
    return file;
  }

  static Future<void> shareBackup() async {
    final file = await exportToFile();
    await Share.shareXFiles([XFile(file.path)],
        text: "نسخة احتياطية - التسبيح والأذكار - في رحاب الرحمن");
  }

  static Future<void> shareSelective({
    required bool azkar,
    required bool hadith,
    required bool khatma,
  }) async {
    final file = await exportSelectiveToFile(azkar: azkar, hadith: hadith, khatma: khatma);
    final names = [
      if (azkar) "الأذكار",
      if (hadith) "الأحاديث",
      if (khatma) "الختمة"
    ].join(" + ");
    await Share.shareXFiles([XFile(file.path)],
        text: "نسخة احتياطية - $names - في رحاب الرحمن");
  }

  static Future<int> importFromJson(String jsonStr) async {
    final Map<String, dynamic> data = json.decode(jsonStr);
    // دعم الصيغة الجديدة (hive/prefs) والقديمة (flat)
    if (data.containsKey("hive") || data.containsKey("prefs")) {
      return importSelectiveFromJson(jsonStr, azkar: true, hadith: true, khatma: true);
    }
    data.remove("_meta");
    final box = Hive.box("name");
    int count = 0;
    for (final entry in data.entries) {
      await box.put(entry.key, entry.value);
      count++;
    }
    return count;
  }

  static Future<int> importSelectiveFromJson(
    String jsonStr, {
    required bool azkar,
    required bool hadith,
    required bool khatma,
  }) async {
    final Map<String, dynamic> data = json.decode(jsonStr);
    // إذا كانت صيغة قديمة flat، نعتبر كل شيء hive
    if (!data.containsKey("hive") && !data.containsKey("prefs")) {
      // صيغة قديمة: كل المفاتيح هي hive
      data.remove("_meta");
      final box = Hive.box("name");
      int count = 0;
      // نحتاج لمعرفة هل المستخدم يريد الأذكار فقط؟ في الصيغة القديمة كلها أذكار
      if (azkar) {
        for (final entry in data.entries) {
          if (_isAzkarHiveKey(entry.key)) {
            await box.put(entry.key, entry.value);
            count++;
          }
        }
        // إذا لم يجد أي مفتاح أذكار، استورد الكل كاحتياط
        if (count == 0) {
          for (final entry in data.entries) {
            await box.put(entry.key, entry.value);
            count++;
          }
        }
      }
      return count;
    }

    int count = 0;
    final hiveData = data["hive"] is Map ? Map<String, dynamic>.from(data["hive"]) : <String, dynamic>{};
    final prefsData = data["prefs"] is Map ? Map<String, dynamic>.from(data["prefs"]) : <String, dynamic>{};

    if (azkar || khatma) {
      final box = Hive.box("name");
      for (final entry in hiveData.entries) {
        final k = entry.key;
        final isAzkar = _isAzkarHiveKey(k);
        final isKhatma = _isKhatmaHiveKey(k);
        if ((azkar && isAzkar) || (khatma && isKhatma)) {
          await box.put(k, entry.value);
          count++;
        } else if (azkar && khatma && !isAzkar && !isKhatma) {
          // مفاتيح غير مصنفة ضمن hiveFile الجديدة لكن قد تكون تسبيح
          if (k.toLowerCase().contains("tasbeeh") || k.toLowerCase().contains("azkar")) {
            await box.put(k, entry.value);
            count++;
          }
        }
      }
    }

    if (hadith) {
      final prefs = await SharedPreferences.getInstance();
      for (final entry in prefsData.entries) {
        final k = entry.key;
        final v = entry.value;
        if (v is String) {
          await prefs.setString(k, v);
        } else if (v is int) {
          await prefs.setInt(k, v);
        } else if (v is double) {
          await prefs.setDouble(k, v);
        } else if (v is bool) {
          await prefs.setBool(k, v);
        } else if (v is List) {
          await prefs.setString(k, json.encode(v));
        } else if (v != null) {
          await prefs.setString(k, v.toString());
        }
        count++;
      }
      // أيضاً بعض مفاتيح الأحاديث قد تكون في Hive (نادر) - نعالجها
      if (azkar == false && khatma == false) {
        // إذا المستخدم اختار حديث فقط لكن الملف يحتوي hive للأحاديث (قديم)
        // لا شيء إضافي
      }
    }

    return count;
  }

  static Future<int> importFromFile(File file) async {
    final str = await file.readAsString();
    return importFromJson(str);
  }

  static Future<int> importSelectiveFromFile(
    File file, {
    required bool azkar,
    required bool hadith,
    required bool khatma,
  }) async {
    final str = await file.readAsString();
    return importSelectiveFromJson(str, azkar: azkar, hadith: hadith, khatma: khatma);
  }

  // معلومات عن محتوى ملف النسخ للمعاينة قبل الاستيراد
  static Future<Map<String, dynamic>> inspectFile(File file) async {
    try {
      final str = await file.readAsString();
      final data = json.decode(str) as Map<String, dynamic>;
      if (data.containsKey("hive") || data.containsKey("prefs")) {
        final meta = data["_meta"] is Map ? Map<String, dynamic>.from(data["_meta"]) : {};
        final hive = data["hive"] is Map ? Map<String, dynamic>.from(data["hive"]) : {};
        final prefs = data["prefs"] is Map ? Map<String, dynamic>.from(data["prefs"]) : {};
        int azkarCount = hive.keys.where((k) => _isAzkarHiveKey(k.toString())).length;
        int khatmaCount = hive.keys.where((k) => _isKhatmaHiveKey(k.toString())).length;
        int hadithCount = prefs.keys.where((k) => _isHadithPrefKey(k.toString())).length;
        // إذا كانت hive تحتوي مفاتيح غير مصنفة لكنها أذكار، احسبها
        if (azkarCount == 0 && hive.isNotEmpty) {
          azkarCount = hive.length - khatmaCount;
        }
        return {
          "isNewFormat": true,
          "sections": meta["sections"],
          "azkarCount": azkarCount,
          "khatmaCount": khatmaCount,
          "hadithCount": hadithCount,
          "hiveTotal": hive.length,
          "prefsTotal": prefs.length,
          "exportedAt": meta["exportedAt"],
          "version": meta["version"],
        };
      } else {
        // صيغة قديمة
        final count = data.length - (data.containsKey("_meta") ? 1 : 0);
        int azkarCount = data.keys.where((k) => _isAzkarHiveKey(k.toString())).length;
        if (azkarCount == 0) azkarCount = count;
        return {
          "isNewFormat": false,
          "azkarCount": azkarCount,
          "khatmaCount": 0,
          "hadithCount": 0,
          "hiveTotal": count,
          "prefsTotal": 0,
          "exportedAt": (data["_meta"] is Map ? (data["_meta"] as Map)["exportedAt"] : null),
        };
      }
    } catch (e) {
      return {"error": e.toString()};
    }
  }
}
