import 'dart:convert';

import 'package:animations/animations.dart';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttericon/entypo_icons.dart';
import 'package:nabd/GlobalHelpers/constants.dart';
import 'package:nabd/GlobalHelpers/hive_helper.dart';
import 'package:nabd/core/hadith/models/hadith_min.dart';
import 'package:nabd/core/hadith/views/hadithdetailspage.dart';
import 'package:quran/quran.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HadithList extends StatefulWidget {
  String locale;
  String id;
  String count;
  String title;
  HadithList(
      {super.key,
      required this.locale,
      required this.id,
      required this.title,
      required this.count});

  @override
  State<HadithList> createState() => _HadithListState();
}

class _HadithListState extends State<HadithList> {
  bool isLoading = true;
  List<HadithMin> hadithes = [];
  String? errorMessage;

  getHadithList() async {
    hadithes = [];
    errorMessage = null;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final key = "hadithlist-${widget.id}-${widget.locale}";
      bool loaded = false;
      // 1) الكاش أولاً — لكن الفارغ/التالف يُعامل كمفقود ويُعاد الجلب
      try {
        final jsonData = prefs.getString(key);
        if (jsonData != null) {
          final data = json.decode(jsonData) as List<dynamic>;
          if (data.isNotEmpty) {
            for (var hadith in data) {
              try {
                hadithes.add(HadithMin.fromJson(hadith));
              } catch (_) {}
            }
            loaded = hadithes.isNotEmpty;
          }
        }
      } catch (_) {
        loaded = false;
      }
      // 2) الشبكة عند غياب كاش صالح
      if (!loaded) {
        final dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 45),
          sendTimeout: const Duration(seconds: 15),
        ));
        final Response response = await dio.get(
            "https://hadeethenc.com/api/v1/hadeeths/list/?language=${widget.locale}&category_id=${widget.id}&per_page=699999");
        final dynamic payload =
            response.data is Map ? response.data["data"] : response.data;
        if (payload is List) {
          for (var hadith in payload) {
            try {
              hadithes.add(HadithMin.fromJson(hadith));
            } catch (_) {}
          }
          // لا تحفظ قائمة فارغة حتى لا تُجمّد الصفحة فارغة للأبد
          if (hadithes.isNotEmpty) {
            try {
              await prefs.setString(key, json.encode(payload));
            } catch (_) {}
          }
        }
      }
      if (hadithes.isEmpty) {
        errorMessage = "لا توجد أحاديث هنا بعد — تحقق من الإنترنت ثم أعد المحاولة";
      }
    } catch (_) {
      errorMessage = "تعذّر تحميل الأحاديث — تحقق من الإنترنت ثم أعد المحاولة";
    }
    tempHadithes = hadithes;
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _retry() {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    getHadithList();
  }

  @override
  void initState() {
    getHadithList(); // TODO: implement initState
    super.initState();
  }

  List<HadithMin> filteredHadithes = []; // TOD
  List<HadithMin> tempHadithes = []; // TOD
  searchFunction(searchwords) {
    filteredHadithes = tempHadithes
        .where(
            (element) => removeDiacritics(element.title).contains(searchwords))
        .toList();

    hadithes = filteredHadithes;
    if (searchwords == "") {
      hadithes = tempHadithes;
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor:  getValue("darkMode")?quranPagesColorDark:quranPagesColorLight,
        body: isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : (errorMessage != null && hadithes.isEmpty)
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
                : CustomScrollView(
                slivers: [
                  SliverAppBar(
                    floating: true,
                    pinned: true,
                    iconTheme:  IconThemeData(color: getValue("darkMode")?Colors.white.withOpacity(.87): Colors.black87),
                    backgroundColor: getValue("darkMode")?darkModeSecondaryColor: quranPagesColorLight,
                    elevation: 0, // No shadow
                    title: Text(
                      "${widget.title}- ${widget.count}",
                      style: TextStyle(color: getValue("darkMode")?Colors.white.withOpacity(.87): Colors.black87, fontSize: 16.sp),
                    ),
                    expandedHeight: 100.h,
                    collapsedHeight: kToolbarHeight,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        alignment: Alignment.bottomCenter,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: getValue("darkMode")?darkModeSecondaryColor: quranPagesColorLight.withOpacity(.3),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Row(
                          children: [
                             Icon(Icons.search, color: getValue("darkMode")?Colors.white60: Colors.black54),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(style: TextStyle(
                              color:   getValue("darkMode")?Colors.white:Colors.black
                              ),
                                onChanged: (val) {
                                  searchFunction(val);
                                },
                                decoration:  InputDecoration(
                                  hintText: 'SearchHadith'.tr(),
                                  border: InputBorder.none,hintStyle:  TextStyle(
                              color:   getValue("darkMode")?Colors.white:Colors.black
                              ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverList.builder(
                    itemCount: hadithes.length,
                    itemBuilder: (BuildContext context, int index) {
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: OpenContainer(
                          closedElevation: 0,closedColor: Colors.transparent,middleColor: getValue("darkMode")
              ? darkModeSecondaryColor
              :Colors.white,
                          transitionType: ContainerTransitionType.fadeThrough,
                          transitionDuration: const Duration(milliseconds: 500),
                          openBuilder: (context, action) => HadithDetailsPage(
                              title: hadithes[index].title,
                              locale: context.locale.languageCode,
                              id: hadithes[index].id),
                          closedBuilder: (context, action) => Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color:getValue("darkMode")?darkModeSecondaryColor: const Color(0xffF5EFE8).withOpacity(.4),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  children: [
                                    Text(
                                      hadithes[index].title,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 16.sp,fontFamily: "Taha",color: getValue("darkMode")?Colors.white.withOpacity(.87):Colors.black87),
                                    ),
                                     Icon(Entypo.down_open_mini,color: getValue("darkMode")?Colors.white.withOpacity(.87):Colors.black87)
                                  ],
                                ),
                              )),
                        ),
                      );
                    },
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(height: MediaQuery.of(context).padding.bottom + 16.h),
                  ),
                ],
              ));
  }
}
