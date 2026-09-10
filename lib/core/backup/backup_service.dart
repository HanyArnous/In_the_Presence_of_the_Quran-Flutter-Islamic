import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class BackupService {
  static const List<String> _tasbeehKeys = [
    "tasbeehAll",
    "customTasbeehs",
    "tasbeehLastIndex",
  ];

  static List<String> _collectKeys() {
    final box = Hive.box("name");
    final allKeys = box.keys.map((e) => e.toString()).toList();
    final filtered = <String>[];
    for (final k in allKeys) {
      if (k.contains("tasbeeh") ||
          k.contains("Tasbeeh") ||
          k.contains("customAzkar") ||
          k.contains("favorites_") ||
          k.contains("favorites-") ||
          k.contains("override_") ||
          k.contains("azkar") ||
          k.contains("Azkar") ||
          k.contains("zikr") ||
          k.contains("Zikr") ||
          k.contains("-count") && (k.contains("tasbeeh") || k.contains("azkar")) ||
          k.contains("-max") && (k.contains("tasbeeh") || k.contains("azkar")) ||
          k.contains("zikrIndex")) {
        filtered.add(k);
      }
      // More precise: collect all tasbeeh/azkar related
      if (k.startsWith("customAzkar_") ||
          k.startsWith("favorites_") ||
          k.startsWith("override_") ||
          k == "tasbeehAll" ||
          k == "customTasbeehs" ||
          k == "tasbeehLastIndex" ||
          RegExp(r'^\d+number$').hasMatch(k) ||
          RegExp(r'^\d+max$').hasMatch(k) ||
          RegExp(r'.+-count$').hasMatch(k) && (k.contains("tasbeeh") || k.contains("azkar") || k.contains("zikr")) ||
          RegExp(r'.+-max$').hasMatch(k) && (k.contains("tasbeeh") || k.contains("azkar") || k.contains("zikr"))) {
        if (!filtered.contains(k)) filtered.add(k);
      }
    }
    // Also collect all keys that look like tasbeeh/azkar
    for (final k in allKeys) {
      if (k.toLowerCase().contains("tasbeeh") || k.toLowerCase().contains("azkar") || k.toLowerCase().contains("zikr")) {
        if (!filtered.contains(k)) filtered.add(k);
      }
    }
    return filtered.toSet().toList();
  }

  static Future<String> exportToJson() async {
    final box = Hive.box("name");
    final keys = _collectKeys();
    // Fallback: if no keys matched, export all tasbeeh/azkar related via scanning
    final Map<String, dynamic> data = {};
    for (final k in keys) {
      data[k] = box.get(k);
    }
    // Also include broader scan for any key containing tasbeeh/azkar
    for (final k in box.keys) {
      final ks = k.toString();
      if ((ks.toLowerCase().contains("tasbeeh") || ks.toLowerCase().contains("azkar") || ks.toLowerCase().contains("zikr")) && !data.containsKey(ks)) {
        data[ks] = box.get(k);
      }
    }
    data["_meta"] = {
      "app": "في رحاب الرحمن",
      "version": "4.6.1",
      "exportedAt": DateTime.now().toIso8601String(),
      "count": data.length,
    };
    return json.encode(data);
  }

  static Future<File> exportToFile() async {
    final jsonStr = await exportToJson();
    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/backup_tasbeeh_azkar_${DateTime.now().millisecondsSinceEpoch}.json");
    await file.writeAsString(jsonStr);
    return file;
  }

  static Future<void> shareBackup() async {
    final file = await exportToFile();
    await Share.shareXFiles([XFile(file.path)], text: "نسخة احتياطية - التسبيح والأذكار - في رحاب الرحمن");
  }

  static Future<int> importFromJson(String jsonStr) async {
    final Map<String, dynamic> data = json.decode(jsonStr);
    // Remove meta
    data.remove("_meta");
    final box = Hive.box("name");
    int count = 0;
    for (final entry in data.entries) {
      await box.put(entry.key, entry.value);
      count++;
    }
    return count;
  }

  static Future<int> importFromFile(File file) async {
    final str = await file.readAsString();
    return importFromJson(str);
  }
}
