import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttericon/entypo_icons.dart';
import 'package:fluttericon/mfg_labs_icons.dart';
import 'package:nabd/GlobalHelpers/constants.dart';
import 'package:nabd/GlobalHelpers/hive_helper.dart';
import 'package:nabd/core/hadith/models/category.dart';
import 'package:nabd/core/hadith/views/booklistpage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nabd/core/hadith/data/books.dart';
import 'package:nabd/core/hadith/logic/get_hadith_book.dart';

class HadithBooksPage extends StatefulWidget {
  String locale;
  HadithBooksPage({super.key, required this.locale});

  @override
  State<HadithBooksPage> createState() => _HadithBooksPageState();
}

class _HadithBooksPageState extends State<HadithBooksPage> {
  List<Category> categories = [];
  bool isLoading = true;
  bool downloadingAll = false;
  int downloadedCount = 0;
  String? errorMessage;
  getCategories() async {
    final lang = context.locale.languageCode;
    categories = [];
    errorMessage = null;
    categories.add(Category(
        id: "100000",
        title: "allHadith".tr(),
        hadeethsCount: "2000+",
        parentId: "parentId"));
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 15),
      ));
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      bool needFetch = false;
      List<dynamic> cached = [];
      final cachedStr = prefs.getString("categories-$lang");
      if (cachedStr == null) {
        needFetch = true;
      } else {
        try {
          cached = json.decode(cachedStr) as List<dynamic>;
          if (cached.isEmpty) needFetch = true;
        } catch (_) {
          needFetch = true;
        }
      }
      if (needFetch) {
        Response response = await dio.get(
            "https://hadeethenc.com/api/v1/categories/roots/?language=$lang");
        final items = response.data is List ? response.data : [];
        for (var cat in items) {
          try {
            categories.add(Category.fromJson(cat));
          } catch (_) {}
        }
        if (categories.length > 1) {
          await prefs.setString("categories-$lang", json.encode(items));
        } else {
          // fallback: حاول لغة ar إذا فشلت الحالية
          if (lang != "ar") {
            try {
              Response r2 = await dio.get(
                  "https://hadeethenc.com/api/v1/categories/roots/?language=ar");
              final items2 = r2.data is List ? r2.data : [];
              categories = [
                Category(
                    id: "100000",
                    title: "allHadith".tr(),
                    hadeethsCount: "2000+",
                    parentId: "parentId")
              ];
              for (var cat in items2) {
                try {
                  categories.add(Category.fromJson(cat));
                } catch (_) {}
              }
              if (categories.length > 1) {
                await prefs.setString("categories-ar", json.encode(items2));
              }
            } catch (_) {}
          }
        }
      } else {
        for (var cat in cached) {
          try {
            categories.add(Category.fromJson(cat));
          } catch (_) {}
        }
        if (lang == "ar") {
          final english = RegExp(r'[a-zA-Z]');
          final hasEnglishTitles =
              categories.any((c) => english.hasMatch(c.title));
          if (hasEnglishTitles) {
            Response response = await dio.get(
                "https://hadeethenc.com/api/v1/categories/roots/?language=ar");
            categories = [
              Category(
                  id: "100000",
                  title: "allHadith".tr(),
                  hadeethsCount: "2000+",
                  parentId: "parentId")
            ];
            final items =
                response.data is List ? response.data : [];
            for (var cat in items) {
              try {
                categories.add(Category.fromJson(cat));
              } catch (_) {}
            }
            if (categories.length > 1) {
              await prefs.setString(
                  "categories-$lang", json.encode(items));
            }
          }
        }
        // إذا الكاش فاسد (مثلاً [] أو عنصر واحد فقط) أعد الجلب مرة
        if (categories.length <= 1) {
          try {
            Response response = await dio.get(
                "https://hadeethenc.com/api/v1/categories/roots/?language=$lang");
            final items = response.data is List ? response.data : [];
            if (items.isNotEmpty) {
              categories = [
                Category(
                    id: "100000",
                    title: "allHadith".tr(),
                    hadeethsCount: "2000+",
                    parentId: "parentId")
              ];
              for (var cat in items) {
                try {
                  categories.add(Category.fromJson(cat));
                } catch (_) {}
              }
              if (categories.length > 1) {
                await prefs.setString("categories-$lang", json.encode(items));
              }
            }
          } catch (_) {}
        }
      }
      // أول عنصر هو "كل الأحاديث" — إن لم تُجلب تصنيفات حقيقية فالصفحة فارغة
      if (categories.length <= 1) {
        errorMessage = "تعذّر تحميل التصنيفات — تحقق من الإنترنت ثم أعد المحاولة";
      }
    } catch (_) {
      if (categories.length <= 1) {
        errorMessage = "تعذّر تحميل التصنيفات — تحقق من الإنترنت ثم أعد المحاولة";
      }
    } finally {
      isLoading = false;
    }

    if (mounted) setState(() {});
  }

  void _retry() {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    getCategories();
  }

  @override
  void initState() {
    getCategories(); // TODO: implement initState
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          getValue("darkMode") ? quranPagesColorDark : quranPagesColorLight,
      appBar: AppBar(
        backgroundColor: getValue("darkMode")
            ? darkModeSecondaryColor
            : quranPagesColorLight,
        elevation: 0,
        iconTheme: IconThemeData(
          color: getValue("darkMode")
              ? Colors.white.withOpacity(.87)
              : Colors.black87,
        ),
        title: Text(
          "Hadith".tr(),
          style: TextStyle(
            color: getValue("darkMode")
                ? Colors.white.withOpacity(.87)
                : Colors.black87,
            fontFamily: "cairo",
          ),
        ),
        actions: [
          IconButton(
              onPressed: () async {
                if (downloadingAll) return;
                setState(() {
                  downloadingAll = true;
                  downloadedCount = 0;
                });
                await showDialog(
                    barrierDismissible: false,
                    context: context,
                    builder: (c) {
                      return StatefulBuilder(builder: (ctx, setStateDialog) {
                        return AlertDialog(
                          title: const Text("تحميل جميع الأحاديث",
                              style: TextStyle(fontFamily: "cairo")),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                  "جاري التحميل: $downloadedCount/${books.length}",
                                  style: const TextStyle(fontFamily: "cairo")),
                              const SizedBox(height: 12),
                              LinearProgressIndicator(
                                  value: downloadedCount / books.length),
                            ],
                          ),
                        );
                      });
                    });
                for (final b in books) {
                  final file = b["file"];
                  if (file != null) {
                    await downloadBook(file);
                    downloadedCount++;
                    setState(() {});
                  }
                }
                setState(() {
                  downloadingAll = false;
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("تم تنزيل جميع الأحاديث",
                        style: TextStyle(fontFamily: "cairo"))));
              },
              icon: Icon(Icons.cloud_download,
                  color: getValue("darkMode")
                      ? Colors.white.withOpacity(.87)
                      : Colors.black87))
        ],
      ),
      body: SafeArea(bottom: true, child: isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: getValue("darkMode") ? Colors.white70 : blueColor,
              ),
            )
          : (errorMessage != null && categories.length <= 1)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off_outlined,
                            size: 56,
                            color: getValue("darkMode")
                                ? Colors.white54
                                : Colors.black45),
                        const SizedBox(height: 12),
                        Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontFamily: "cairo",
                              fontSize: 15,
                              color: getValue("darkMode")
                                  ? Colors.white70
                                  : Colors.black87),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _retry,
                          icon: const Icon(Icons.refresh),
                          label: const Text("إعادة المحاولة",
                              style: TextStyle(fontFamily: "cairo")),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
              itemCount: categories.length,
              itemBuilder: (BuildContext context, int index) {
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                          context,
                          CupertinoPageRoute(
                              builder: (builder) => HadithList(
                                  title: categories[index].title,
                                  count: categories[index].hadeethsCount,
                                  locale: context.locale.languageCode,
                                  id: categories[index].id)));
                    },
                    child: Container(
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: getValue("darkMode")
                                  ? darkModeSecondaryColor
                                  : const Color(0xffF5EFE8).withOpacity(.9),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(22),
                              child: Icon(
                                MfgLabs.folder_empty,
                                size: 30.sp,
                                color: getValue("darkMode")
                                    ? Colors.white.withOpacity(.87)
                                    : Colors.black87,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 15.w,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                categories[index].title,
                                style: TextStyle(
                                  color: getValue("darkMode")
                                      ? Colors.white
                                      : Colors.black,
                                  fontSize: 14.sp,
                                ),
                              ),
                              Text(
                                (context.locale.languageCode == "ar"
                                        ? "عدد الأحاديث"
                                        : "Hadith Count") +
                                    ": ${categories[index].hadeethsCount}",
                                style: TextStyle(
                                    color: getValue("darkMode")
                                        ? orangeColor.withOpacity(.9)
                                        : const Color(0xffA28858)
                                            .withOpacity(.9)),
                              )
                            ],
                          ),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Icon(
                                  context.locale.languageCode == "ar"
                                      ? Entypo.left_open
                                      : Entypo.right_open,
                                  color: getValue("darkMode")
                                      ? orangeColor.withOpacity(.87)
                                      : Colors.black87,
                                  size: 26.sp,
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                );
              },
              ),
      ),
    );
  }
}
