import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nabd/Core/audiopage/models/reciter.dart';
import 'package:nabd/GlobalHelpers/constants.dart';
import 'package:nabd/GlobalHelpers/hive_helper.dart';
import 'package:nabd/core/home.dart';
import 'package:nabd/blocs/bloc/player_bloc_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  List<Map<String, dynamic>> items = [];
  int totalSizeBytes = 0;
  List<Reciter> _reciters = [];
  List _suwar = [];
  bool _isScanning = false;
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    _loadDownloads();
  }

  // دالة لمسح مجلد التحميلات واكتشاف الملفات الموجودة
  Future<void> _scanDownloadDirectory() async {
    if (_isScanning) return;
    
    setState(() {
      _isScanning = true;
    });

    try {
      // قائمة بالمسارات الإضافية للبحث
      List<Directory> searchPaths = [
        await getTemporaryDirectory(),
        Directory("/storage/emulated/0/Download/"),
        Directory("/storage/emulated/0/Download/arnous/"),
        Directory("/storage/emulated/0/Download/skoon/"),
        Directory("/storage/emulated/0/Download/quran/"),
        Directory("/storage/emulated/0/Android/data/${(await getTemporaryDirectory()).path.split('/').last}/files/"),
      ];
      
      List<File> allFiles = [];
      
      // البحث في جميع المسارات الممكنة
      for (Directory dir in searchPaths) {
        try {
          if (await dir.exists()) {
            final files = await dir.list().where((entity) => 
              entity is File && entity.path.endsWith('.mp3')).cast<File>().toList();
            allFiles.addAll(files);
          }
        } catch (e) {
          // تجاهل المسارات التي لا يمكن الوصول إليها
          continue;
        }
      }
      
      if (allFiles.isEmpty) {
        setState(() {
          _isScanning = false;
          _hasScanned = true;
        });
        return;
      }

      // الحصول على قائمة التحميلات الحالية من قاعدة البيانات
      dynamic raw = getValue("downloadedSurahs");
      List existingDownloads = [];
      if (raw is String && raw.isNotEmpty) {
        existingDownloads = json.decode(raw) as List;
      }

      // إنشاء مجموعة من مسارات الملفات الموجودة في قاعدة البيانات
      final Set<String> existingPaths = existingDownloads
          .where((e) => e is Map && e["filePath"] != null)
          .map((e) => e["filePath"].toString())
          .toSet();

      int newFilesFound = 0;
      List<Map<String, dynamic>> newEntries = [];

      // معالجة كل ملف تم اكتشافه
      for (File file in allFiles) {
        final filePath = file.path;
        
        // تجاهل الملفات الموجودة بالفعل في قاعدة البيانات
        if (existingPaths.contains(filePath)) {
          continue;
        }

        // تحليل اسم الملف لاستخلاص المعلومات
        final fileName = file.path.split('/').last;
        final fileData = _parseAudioFileName(fileName);
        
        if (fileData != null) {
          final fileSize = await file.length();
          
          // إنشاء سجل جديد للملف المكتشف
          final newEntry = {
            "reciterName": fileData["reciterName"],
            "reciterIdentifier": fileData["reciterIdentifier"],
            "surahNumber": fileData["surahNumber"],
            "suraNameArabic": fileData["suraNameArabic"],
            "filePath": filePath,
            "fileSize": fileSize,
            "source": "scanned",
            "extra": fileData["extra"] ?? {},
          };
          
          newEntries.add(newEntry);
          newFilesFound++;
        }
      }

      // إضافة الملفات الجديدة إلى قاعدة البيانات
      if (newEntries.isNotEmpty) {
        existingDownloads.addAll(newEntries);
        updateValue("downloadedSurahs", json.encode(existingDownloads));
        
        // إعادة تحميل قائمة التحميلات
        await _loadDownloads();
        
        // إظهار رسالة للمستخدم
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("تم اكتشاف $newFilesFound ملف صوتي جديد"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("لا توجد ملفات جديدة للاكتشاف"),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("حدث خطأ أثناء البحث: $e"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _isScanning = false;
        _hasScanned = true;
      });
    }
  }

  // دالة لتحليل اسم الملف الصوتي واستخلاص المعلومات
  Map<String, dynamic>? _parseAudioFileName(String fileName) {
    try {
      // دعم أنماط متعددة من أسماء الملفات:
      // 1. reciterIdentifier-suraName.mp3 (ملف السورة الكامل)
      // 2. reciterIdentifier-suraName-verseNumber.mp3 (ملفات الآيات)
      // 3. reciterName-moshafId-suraName.mp3 (نمط التطبيق)
      // 4. أي نمط يحتوي على معلومات السورة والقارئ
      
      if (!fileName.endsWith('.mp3')) return null;
      
      final nameWithoutExt = fileName.substring(0, fileName.length - 4);
      final parts = nameWithoutExt.split('-');
      
      if (parts.length < 2) return null;
      
      String reciterIdentifier = "";
      String suraNameWithSpaces = "";
      String? reciterName;
      
      // البحث عن نمط التطبيق: reciterName-moshafId-suraName
      if (parts.length >= 3) {
        // محاولة استخراج رقم السورة من الأجزاء المختلفة
        for (int i = 1; i < parts.length; i++) {
          final surahNumber = _getSurahNumberFromName(parts[i]);
          if (surahNumber != null) {
            reciterIdentifier = parts[0];
            suraNameWithSpaces = parts[i];
            reciterName = _getReciterNameFromIdentifier(parts[0]);
            break;
          }
        }
      }
      
      // إذا لم يتم العثور على نمط التطبيق، جرب النمط القياسي
      if (suraNameWithSpaces.isEmpty) {
        reciterIdentifier = parts[0];
        suraNameWithSpaces = parts[1];
        reciterName = _getReciterNameFromIdentifier(parts[0]);
      }
      
      // البحث عن رقم السورة من اسم السورة
      final surahNumber = _getSurahNumberFromName(suraNameWithSpaces);
      
      if (surahNumber == null) return null;
      
      // محاولة الحصول على اسم القارئ من المعرف
      if (reciterName == null) {
        reciterName = _getReciterNameFromIdentifier(reciterIdentifier);
      }
      
      return {
        "reciterIdentifier": reciterIdentifier,
        "reciterName": reciterName,
        "surahNumber": surahNumber,
        "suraNameArabic": suraNameWithSpaces,
        "extra": {
          "isFullSura": parts.length == 2 || (parts.length == 3 && _getSurahNumberFromName(parts[2]) == null),
          "verseNumber": parts.length > 2 ? int.tryParse(parts[2]) : null,
        }
      };
      
    } catch (e) {
      return null;
    }
  }

  // دالة للحصول على رقم السورة من اسمها
  int? _getSurahNumberFromName(String suraName) {
    // قائمة بأسماء السور الشائعة (يمكن توسيعها)
    final Map<String, int> surahNames = {
      "الفاتحة": 1,
      "البقرة": 2,
      "آل عمران": 3,
      "النساء": 4,
      "المائدة": 5,
      "الأنعام": 6,
      "الأعراف": 7,
      "الأنفال": 8,
      "التوبة": 9,
      "يونس": 10,
      "هود": 11,
      "يوسف": 12,
      "الرعد": 13,
      "إبراهيم": 14,
      "الحجر": 15,
      "النحل": 16,
      "الإسراء": 17,
      "الكهف": 18,
      "مريم": 19,
      "طه": 20,
      "الأنبياء": 21,
      "الحج": 22,
      "المؤمنون": 23,
      "النور": 24,
      "الفرقان": 25,
      "الشعراء": 26,
      "النمل": 27,
      "القصص": 28,
      "العنكبوت": 29,
      "الروم": 30,
      "لقمان": 31,
      "السجدة": 32,
      "الأحزاب": 33,
      "سبأ": 34,
      "فاطر": 35,
      "يس": 36,
      "الصافات": 37,
      "ص": 38,
      "الزمر": 39,
      "غافر": 40,
      "فصلت": 41,
      "الشورى": 42,
      "الزخرف": 43,
      "الدخان": 44,
      "الجاثية": 45,
      "الأحقاف": 46,
      "محمد": 47,
      "الفتح": 48,
      "الحجرات": 49,
      "ق": 50,
      "الذاريات": 51,
      "الطور": 52,
      "النجم": 53,
      "القمر": 54,
      "الرحمن": 55,
      "الواقعة": 56,
      "الحديد": 57,
      "المجادلة": 58,
      "الحشر": 59,
      "الممتحنة": 60,
      "الصف": 61,
      "الجمعة": 62,
      "المنافقون": 63,
      "التغابن": 64,
      "الطلاق": 65,
      "التحريم": 66,
      "الملك": 67,
      "القلم": 68,
      "الحاقة": 69,
      "المعارج": 70,
      "نوح": 71,
      "الجن": 72,
      "المزمل": 73,
      "المدثر": 74,
      "القيامة": 75,
      "الإنسان": 76,
      "المرسلات": 77,
      "النبأ": 78,
      "النازعات": 79,
      "عبس": 80,
      "التكوير": 81,
      "الانفطار": 82,
      "المطففين": 83,
      "الانشقاق": 84,
      "البروج": 85,
      "الطارق": 86,
      "الأعلى": 87,
      "الغاشية": 88,
      "الفجر": 89,
      "البلد": 90,
      "الشمس": 91,
      "الليل": 92,
      "الضحى": 93,
      "الشرح": 94,
      "التين": 95,
      "العلق": 96,
      "القدر": 97,
      "البينة": 98,
      "الزلزلة": 99,
      "العاديات": 100,
      "القارعة": 101,
      "التكاثر": 102,
      "العصر": 103,
      "الهمزة": 104,
      "الفيل": 105,
      "قريش": 106,
      "الماعون": 107,
      "الكوثر": 108,
      "الكافرون": 109,
      "النصر": 110,
      "المسد": 111,
      "الإخلاص": 112,
      "الفلق": 113,
      "الناس": 114,
    };
    
    return surahNames[suraName];
  }

  // دالة للحصول على اسم القارئ من المعرف
  String _getReciterNameFromIdentifier(String identifier) {
    // قائمة بالقراء الشائعة (تم توسيعها لتشمل المزيد من المعرفات)
    final Map<String, String> reciterNames = {
      // القراء المشهورين
      "abdul_basit": "عبد الباسط عبد الصمد",
      "sudais": "عبد الرحمن السديس",
      "shuraim": "سعود الشريم",
      "mahmoud_khalil": "محمود خليل الحصري",
      "mishari": "مشاري راشد العفاسي",
      "saad_ghamdi": "سعد الغامدي",
      "ahmad_nafe": "أحمد نعينع العفاسي",
      "ali_jaber": "علي جابر",
      "yasser_dossari": "ياسر الدوسري",
      "hani_rifai": "هاني الرفاعي",
      
      // معرفات إضافية شائعة
      "In_the_Presence_of_the_Quran": "In the Presence of the Quran",
      "quran": "قرآن كريم",
      "arnous": "أرنوس",
      "abdulrahman_sudais": "عبد الرحمن السديس",
      "saud_alshuraim": "سعود الشريم",
      "maher_al_muaiqly": "ماهر المعيقلي",
      "fares_abbad": "فارس عباد",
      "bandar_baleela": "بندر بليلة",
      "khalid_al_juhani": "خالد الجهني",
      "ayman_sweid": "أيمن سويد",
      "ahmed_al_ajamy": "أحمد العجمي",
      "mohamed_al_tablawi": "محمد الطبلاوي",
      "ibrahim_al_akhdar": "إبراهيم الأخضر",
      "salah_al_budair": "صلاح البدير",
      "mohamed_jibreel": "محمد جبريل",
      
      // معرفات باللغة العربية
      "عبد_الباسط": "عبد الباسط عبد الصمد",
      "السديس": "عبد الرحمن السديس",
      "الشريم": "سعود الشريم",
      "العفاسي": "مشاري راشد العفاسي",
      "الغامدي": "سعد الغامدي",
      "الدوسري": "ياسر الدوسري",
    };
    
    // البحث عن تطابق كامل أولاً
    if (reciterNames.containsKey(identifier)) {
      return reciterNames[identifier]!;
    }
    
    // البحث عن تطابق جزئي
    for (String key in reciterNames.keys) {
      if (identifier.toLowerCase().contains(key.toLowerCase()) || 
          key.toLowerCase().contains(identifier.toLowerCase())) {
        return reciterNames[key]!;
      }
    }
    
    // إذا لم يتم العثور على تطابق، أرجع المعرف الأصلي
    return identifier;
  }

  Future<void> _loadDownloads() async {
    dynamic raw = getValue("downloadedSurahs");
    List list;
    if (raw is String && raw.isNotEmpty) {
      list = json.decode(raw) as List;
    } else {
      list = [];
    }
    List<Map<String, dynamic>> mapped = [];
    int total = 0;
    for (var e in list) {
      if (e is Map && e["filePath"] != null) {
        String path = e["filePath"].toString();
        File f = File(path);
        if (await f.exists()) {
          int size =
              e["fileSize"] is int ? e["fileSize"] as int : await f.length();
          total += size;
          mapped.add({
            "reciterName":
                e["reciterName"] ?? e["reciterIdentifier"] ?? "Reciter",
            "surahNumber": e["surahNumber"],
            "suraNameArabic": e["suraNameArabic"] ?? "",
            "filePath": path,
            "fileSize": size,
            "source": e["source"] ?? "",
            "extra": e["extra"] ?? {},
          });
        }
      }
    }
    mapped.sort(
        (a, b) => (a["surahNumber"] as int).compareTo(b["surahNumber"] as int));
    setState(() {
      items = mapped;
      totalSizeBytes = total;
    });
  }

  Future<void> _ensureAudioMetaLoaded() async {
    if (_reciters.isNotEmpty && _suwar.isNotEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final lang = context.locale.languageCode;
    final storageLang = lang == "en" ? "eng" : lang;
    final recitersJson = prefs.getString("reciters-$storageLang");
    final suwarJson = prefs.getString("suwar-$storageLang");
    if (recitersJson != null) {
      final data = json.decode(recitersJson) as List<dynamic>;
      _reciters =
          data.map((e) => Reciter.fromJson(e as Map<String, dynamic>)).toList();
    }
    if (suwarJson != null) {
      _suwar = json.decode(suwarJson) as List<dynamic>;
    }
    setState(() {});
  }

  String _formatSize(int bytes) {
    double mb = bytes / (1024 * 1024);
    return "${mb.toStringAsFixed(1)} MB";
  }

  Future<void> _playItem(int index) async {
    await _ensureAudioMetaLoaded();
    if (_reciters.isEmpty || _suwar.isEmpty) {
      return;
    }
    final item = items[index];
    final reciterName = item["reciterName"].toString();
    final surahNumber = item["surahNumber"] as int;
    final extra = (item["extra"] as Map?) ?? {};
    final moshafId = extra["moshafId"];

    Reciter? reciter;
    for (final r in _reciters) {
      if (r.name.toString() == reciterName) {
        reciter = r;
        break;
      }
    }
    if (reciter == null || reciter.moshaf.isEmpty) {
      return;
    }

    Moshaf moshaf;
    if (moshafId != null) {
      try {
        moshaf = reciter.moshaf
            .firstWhere((m) => m.id.toString() == moshafId.toString());
      } catch (_) {
        moshaf = reciter.moshaf.first;
      }
    } else {
      moshaf = reciter.moshaf.first;
    }

    final surahList = moshaf.surahList.toString().split(',');
    int initialIndex = surahList.indexWhere((s) => s == surahNumber.toString());
    if (initialIndex < 0) {
      initialIndex = 0;
    }

    playerPageBloc.add(StartPlaying(
        buildContext: context,
        moshaf: moshaf,
        reciter: reciter,
        suraNumber: surahNumber,
        initialIndex: initialIndex,
        jsonData: _suwar));
  }

  Future<void> _deleteItem(int index) async {
    String path = items[index]["filePath"] as String;
    File f = File(path);
    if (await f.exists()) {
      await f.delete();
    }
    dynamic raw = getValue("downloadedSurahs");
    List list;
    if (raw is String && raw.isNotEmpty) {
      list = json.decode(raw) as List;
    } else {
      list = [];
    }
    list.removeWhere(
        (e) => e is Map && e["filePath"] != null && e["filePath"] == path);
    updateValue("downloadedSurahs", json.encode(list));
    await _loadDownloads();
  }

  Future<void> _deleteAll() async {
    for (var e in items) {
      String path = e["filePath"] as String;
      File f = File(path);
      if (await f.exists()) {
        await f.delete();
      }
    }
    updateValue("downloadedSurahs", json.encode([]));
    await _loadDownloads();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          getValue("darkMode") ? quranPagesColorDark : quranPagesColorLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor:
            getValue("darkMode") ? darkModeSecondaryColor : blueColor,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "downloaded".tr(),
          style: const TextStyle(
            fontFamily: "cairo",
            color: Colors.white,
          ),
        ),
        actions: [
          // زر المسح للكشف عن الملفات الموجودة
          IconButton(
            onPressed: _isScanning ? null : _scanDownloadDirectory,
            icon: _isScanning 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.search),
            tooltip: "مسح الملفات الموجودة",
          ),
          if (items.isNotEmpty)
            IconButton(
              onPressed: () async {
                bool? confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      content: const Text(
                        "هل تريد حذف كل السور المحملة؟",
                        style: TextStyle(fontFamily: "cairo"),
                      ),
                      actions: [
                        TextButton(
                            onPressed: () {
                              Navigator.pop(context, false);
                            },
                            child: Text("cancel".tr())),
                        TextButton(
                            onPressed: () {
                              Navigator.pop(context, true);
                            },
                            child: Text("delete".tr())),
                      ],
                    );
                  },
                );
                if (confirm == true) {
                  await _deleteAll();
                }
              },
              icon: const Icon(Icons.delete_forever),
            ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  "المساحة المستخدمة: ${_formatSize(totalSizeBytes)}",
                  style: TextStyle(
                    fontFamily: "cairo",
                    fontSize: 16.sp,
                    color: getValue("darkMode") ? Colors.white70 : Colors.black87,
                  ),
                ),
                const Spacer(),
                if (!_hasScanned && items.isEmpty)
                  TextButton.icon(
                    onPressed: _scanDownloadDirectory,
                    icon: const Icon(Icons.search, size: 16),
                    label: Text(
                      "مسح الملفات",
                      style: TextStyle(
                        fontFamily: "cairo",
                        fontSize: 12.sp,
                        color: Colors.blue,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 16.h),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "لا توجد سور محملة حالياً",
                            style: TextStyle(
                              fontFamily: "cairo",
                              fontSize: 16.sp,
                              color: getValue("darkMode")
                                  ? Colors.white70
                                  : Colors.black54,
                            ),
                          ),
                          if (!_hasScanned) ...[
                            SizedBox(height: 8.h),
                            Text(
                              "إذا كانت لديك ملفات صوتية محملة مسبقاً، اضغط على زر المسح لاكتشافها",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: "cairo",
                                fontSize: 12.sp,
                                color: getValue("darkMode")
                                    ? Colors.white54
                                    : Colors.black38,
                              ),
                            ),
                            SizedBox(height: 16.h),
                            ElevatedButton.icon(
                              onPressed: _isScanning ? null : _scanDownloadDirectory,
                              icon: _isScanning 
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.search),
                              label: Text(_isScanning ? "جاري المسح..." : "مسح الملفات الموجودة"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return ListTile(
                          onTap: () {
                            _playItem(index);
                          },
                          title: Text(
                            "سورة ${item["suraNameArabic"]}",
                            style: TextStyle(
                              fontFamily: "cairo",
                              fontSize: 16.sp,
                              color: getValue("darkMode")
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            "${item["reciterName"]} - ${_formatSize(item["fileSize"] as int)}",
                            style: TextStyle(
                              fontFamily: "cairo",
                              fontSize: 13.sp,
                              color: getValue("darkMode")
                                  ? Colors.white70
                                  : Colors.black54,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.play_arrow,
                                  color: Colors.green,
                                ),
                                onPressed: () {
                                  _playItem(index);
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () {
                                  _deleteItem(index);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
