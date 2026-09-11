import 'dart:convert';

import 'package:animations/animations.dart';
import 'package:azlistview/azlistview.dart';
import 'package:dio/dio.dart';
import 'package:easy_container/easy_container.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttericon/entypo_icons.dart';
import 'package:fluttericon/font_awesome_icons.dart';
import 'package:nabd/Core/audiopage/models/reciter.dart';
import 'package:nabd/blocs/bloc/player_bloc_bloc.dart';
import 'package:nabd/GlobalHelpers/constants.dart';
import 'package:nabd/GlobalHelpers/hive_helper.dart';
import 'package:nabd/blocs/bloc/quran_page_player_bloc.dart';
import 'package:nabd/core/audiopage/views/reciter_all_surahs_page.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nabd/core/home.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_annimated_staggered/simple_annimated_staggered.dart'; // import this

class RecitersPage extends StatefulWidget {
  RecitersPage({super.key, required this.jsonData});
  var jsonData;

  @override
  _RecitersPageState createState() => _RecitersPageState();
}

class _RecitersPageState extends State<RecitersPage> {
  late List<Reciter> reciters;
  bool isLoading = true;
  late Dio dio;
  late List<Reciter> favoriteRecitersList;

  @override
  void initState() {
    super.initState();
    reciters = [];
    dio = Dio();
    getFavoriteList();
    fetchReciters();
  }

  List<String>? getLettersForLocale(String locale) {
    for (var language in languagesLetters) {
      if (language.containsKey(locale)) {
        return language[locale];
      }
    }
    // Return an empty list or handle the case where the locale is not found.
    return [];
  }

  getFavoriteList() {
    var jsonData = getValue("favoriteRecitersList");
    if (jsonData != null) {
      final data = json.decode(jsonData) as List<dynamic>;
      favoriteRecitersList = data
          .map((reciterJson) =>
              Reciter.fromJson(reciterJson as Map<String, dynamic>))
          .toList();
    } else {
      favoriteRecitersList = [];
    }
  }

  final ContainerTransitionType _transitionType =
      ContainerTransitionType.fadeThrough;
  List<Reciter> filteredReciters = []; // Store the filtered list
  List<Moshaf> rewayat = [];
  List suwar = []; // Store

  getAndStoreRecitersData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    try {
      final langCode = context.locale.languageCode == "en"
          ? "eng"
          : context.locale.languageCode;

      final response = await Dio()
          .get('https://www.mp3quran.net/api/v3/reciters?language=$langCode');
      final response2 = await Dio()
          .get('https://www.mp3quran.net/api/v3/moshaf?language=$langCode');
      final response3 = await Dio()
          .get('https://www.mp3quran.net/api/v3/suwar?language=$langCode');

      if (response.data != null) {
        final jsonData = json.encode(response.data['reciters']);
        prefs.setString("reciters-$langCode", jsonData);
      }
      if (response2.data != null) {
        final jsonData2 = json.encode(response2.data);
        prefs.setString("moshaf-$langCode", jsonData2);
      }
      if (response3.data != null) {
        final jsonData3 = json.encode(response3.data['suwar']);
        prefs.setString("suwar-$langCode", jsonData3);
      }
    } catch (error) {
      print('Error while storing data: $error');
    }
  }

  Future<void> fetchReciters() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final langCode = context.locale.languageCode == "en"
          ? "eng"
          : context.locale.languageCode;
      final recitersKey = "reciters-$langCode";
      final moshafKey = "moshaf-$langCode";
      final suwarKey = "suwar-$langCode";

      if (prefs.getString(recitersKey) == null ||
          prefs.getString(moshafKey) == null ||
          prefs.getString(suwarKey) == null) {
        await getAndStoreRecitersData();
      }

      final jsonData = prefs.getString(recitersKey);
      final jsonData2 = prefs.getString(moshafKey);
      final jsonData3 = prefs.getString(suwarKey);

      if (jsonData != null && jsonData2 != null && jsonData3 != null) {
        final data = json.decode(jsonData) as List<dynamic>;
        final data2 = json.decode(jsonData2)["riwayat"] as List<dynamic>;
        final data3 = json.decode(jsonData3) as List<dynamic>;

        reciters = data.map((reciter) => Reciter.fromJson(reciter)).toList();
        reciters.sort((a, b) => a.name
            .toString()
            .toLowerCase()
            .compareTo(b.name.toString().toLowerCase()));
        
        rewayat = data2.map((reciter) => Moshaf.fromJson(reciter)).toList();
        // تنقية كاش أسماء السور: إزالة الألف الخنجرية U+0670 لتوافق خط qaloon
        // (42 الشورى، 55 الرحمن، 87 الأعلى، 93 الضحى كانت تظهر بمسافة/حرف مخفي)
        suwar = (data3).map((e) {
          if (e is Map) {
            final id = e["id"].toString();
            const fixedNames = {
              "42": "الشُّورَى",
              "55": "الرَّحْمَن",
              "87": "الْأَعْلَى",
              "93": "الضُّحَى",
            };
            if (fixedNames.containsKey(id)) {
              final fixed = Map<String, dynamic>.from(e);
              fixed["name"] = fixedNames[id];
              return fixed;
            }
          }
          return e;
        }).toList();
        
        // تطبيق الفلتر المحفوظ تلقائياً بعد تحميل جميع البيانات
        _applyStoredFilter();

        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      }
    } catch (error) {
      print('Error while fetching data: $error');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void filterReciters(String query) {
    setState(() {
      filteredReciters = reciters.where((reciter) {
        // You can define your filtering logic here.
        // For example, check if the reciter's name contains the query (case-insensitive).
        return reciter.name.toLowerCase().contains(query.toLowerCase());
      }).toList()
        ..sort((a, b) => a.name
            .toString()
            .toLowerCase()
            .compareTo(b.name.toString().toLowerCase()));
    });

    itemScrollController.scrollTo(
        index: 0, duration: const Duration(seconds: 1));
  }

  // دالة موحدة للفلترة (توحيد المنطق)
  // ملاحظة API: العلاقة معكوسة — reciter.moshaf.moshaf_type == riwayat.id
  // (مثال: قراء المعلم يحملون moshaf_type=213 ويقابلهم riwayat id=213)
  // لذلك نطابق بنوع مصحف القارئ مع id المصحف المختار، لا بـ instance id.
  void _applyFilterByMoshafType(String moshafType, String moshafId) {
    setState(() {
      selectedMode = moshafType;
      selectedMoshafId = moshafId;

      // تصفية القراء حسب القراءات المتوفرة لهذا المصحف (لا اسم القارئ)
      filteredReciters = reciters.where((reciter) {
        return reciter.moshaf.any((m) => m.moshafType.toString() == moshafId);
      }).toList();
      
      // ترتيب القائمة أبجدياً (ضروري جداً لـ AzListView)
      filteredReciters.sort((a, b) => a.name.toString().toLowerCase()
          .compareTo(b.name.toString().toLowerCase()));
      
      // تحديث المفتاح في Hive لضمان ظهور النوع في شاشة الإحصائيات
      // نخزن النوع + id المصحف معاً حتى نسترجع نفس المصحف لا أول مصحف من نفس النوع
      updateValue("audioRecitersMode", selectedMode);
      updateValue("audioRecitersModeId", selectedMoshafId);
    });
    
    // نقل القائمة للأعلى لرؤية النتائج الجديدة
    if (itemScrollController.isAttached) {
       itemScrollController.jumpTo(index: 0);
    }
  }

  // تطبيق الفلتر المحفوظ تلقائياً عند التحميل
  void _applyStoredFilter() {
    final storedMode = getValue("audioRecitersMode") ?? "all";
    final storedId = getValue("audioRecitersModeId")?.toString();

    if (storedMode == "all") {
      filteredReciters = List.from(reciters); // عرض الكل
      selectedMode = "all";
      selectedMoshafId = "";
    } else if (storedMode == "favorite") { // 👈 معالجة حالة المفضلة عند الفتح
      filteredReciters = List.from(favoriteRecitersList);
      selectedMode = "favorite";
      selectedMoshafId = "";
    } else if (storedMode == "search") {
      // حالة البحث لحظية ولا تُستعاد — نرجع للكل بدل اختيار خاطئ
      filteredReciters = List.from(reciters);
      selectedMode = "all";
      selectedMoshafId = "";
      updateValue("audioRecitersMode", "all");
    } else {
      // معالجة أنواع المصاحف الأخرى (مرتل، مجود...)
      if (rewayat.isNotEmpty) {
        // أولوية الاسترجاع بـ id المصحف المحفوظ، ثم النوع كاحتياط
        Moshaf? matchingMoshaf;
        if (storedId != null && storedId.isNotEmpty) {
          try {
            matchingMoshaf = rewayat.firstWhere(
              (m) => m.id.toString() == storedId,
            );
          } catch (_) {
            matchingMoshaf = null;
          }
        }
        matchingMoshaf ??= rewayat.firstWhere(
          (moshaf) => moshaf.moshafType.toString() == storedMode,
          orElse: () => rewayat.first,
        );

        _applyFilterByMoshafType(
            matchingMoshaf.moshafType.toString(), matchingMoshaf.id.toString());
      } else {
        // إذا كانت rewayat فارغة، اعرض كل القراء كحالة افتراضية
        filteredReciters = List.from(reciters);
        selectedMode = "all";
      }
    }

    // ترتيب أبجدي دائماً لضمان عمل AzListView
    filteredReciters.sort((a, b) => a.name.toString().toLowerCase()
        .compareTo(b.name.toString().toLowerCase()));
  }

  void filterRecitersDownloaded(String query) {
    setState(() {
      if (query.isEmpty) {
        // إذا كان البحث فارغاً، أظهر كل القراء
        filteredReciters = reciters;
        selectedMode = "all";
        // حفظ الحالة في Hive
        updateValue("audioRecitersMode", "all");
      } else {
        // فلترة القراء حسب اسمهم
        filteredReciters = reciters.where((reciter) {
          return reciter.name.toLowerCase().contains(query.toLowerCase());
        }).toList()
          ..sort((a, b) => a.name
              .toString()
              .toLowerCase()
              .compareTo(b.name.toString().toLowerCase()));
        // حفظ حالة البحث
        // البحث لحظي فقط ولا يُخزن كفلتر دائم حتى لا يسترجع بشكل خاطئ
        selectedMode = "search";
        selectedMoshafId = "";
      }
    });

    itemScrollController.scrollTo(
        index: 0, duration: const Duration(seconds: 1));
  }

  getRewayaReciters(String id) {
    filteredReciters = [];
    for (var element in reciters) {
      // مطابقة بنوع المصحف مع id المصحف المختار (العلاقة المعكوسة في API)
      if (element.moshaf.any((m) => m.moshafType.toString() == id)) {
        filteredReciters.add(element);
      }
    }
    filteredReciters.sort((a, b) => a.name
        .toString()
        .toLowerCase()
        .compareTo(b.name.toString().toLowerCase()));
    // مزامنة الفلتر المختار مع الحالة المخزنة
    try {
      final m = rewayat.firstWhere((e) => e.id.toString() == id);
      selectedMode = m.moshafType.toString();
      selectedMoshafId = m.id.toString();
      updateValue("audioRecitersMode", selectedMode);
      updateValue("audioRecitersModeId", selectedMoshafId);
    } catch (_) {}
    setState(() {});
  }

  @override
  void dispose() {
    // SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
    //     overlays: SystemUiOverlay.values); // TODO: implement dispose
    super.dispose();
  }

  ItemScrollController itemScrollController = ItemScrollController();
  TextEditingController textEditingController = TextEditingController();
  var searchQuery = "";
  var selectedMode = (getValue("audioRecitersMode") ?? "all").toString();
  var selectedMoshafId =
      (getValue("audioRecitersModeId") ?? "").toString();
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor:
          getValue("darkMode") ? quranPagesColorDark : quranPagesColorLight,
      appBar: AppBar(
        backgroundColor: getValue("darkMode")
            ? darkModeSecondaryColor.withOpacity(.9)
            : blueColor,
        elevation: 0,
        title: Text(
          "allReciters".tr(),
          style: const TextStyle(color: Colors.white),
        ),
        automaticallyImplyLeading: false,
        leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(
              Entypo.logout,
              color: Colors.white,
            )),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        bottom: PreferredSize(
          preferredSize: Size(screenSize.width, screenSize.height * .1),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0.w),
                    child: Container(
                      decoration: BoxDecoration(
                          color: const Color(0xffF6F6F6),
                          borderRadius: BorderRadius.circular(5.r)),
                      child: Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12.0.w),
                              child: TextField(
                                controller: textEditingController,
                                onChanged: (value) {
                                  setState(() {
                                    searchQuery = value;
                                  });
                                  filterReciters(
                                      value); // Call the filter method when the text changes
                                },
                                decoration: InputDecoration(
                                  hintText: "searchreciters".tr(),
                                  hintStyle: TextStyle(
                                      fontFamily: "cairo",
                                      fontSize: 14.sp,
                                      color: const Color.fromARGB(73, 0, 0, 0)),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: GestureDetector(
                              onTap: () {
                                fetchReciters();
                                // textEditingController.text = "";
                                textEditingController.clear();
                                FocusManager.instance.primaryFocus?.unfocus();

                                setState(() {
                                  searchQuery = "";
                                });
                              },
                              child: Icon(
                                  searchQuery == ""
                                      ? FontAwesome.search
                                      : Icons.close,
                                  color: const Color.fromARGB(73, 0, 0, 0)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                    onPressed: () {
                      showModalBottomSheet(
                          enableDrag: true,
                          backgroundColor: Colors.white,
                          isDismissible: true,
                          showDragHandle: true,
                          // isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(14),
                                  topRight: Radius.circular(14))),
                          context: context,
                          builder: ((context) {
                            return StatefulBuilder(
                              builder: (context, s) {
                                return Container(
                                  child: ListView(
                                    children: [
                                      EasyContainer(
                                        elevation: 0,
                                        padding: 0,
                                        margin: 0,
                                        onTap: () async {
                                          if (selectedMode != "all") {
                                            fetchReciters();
                                            setState(() {
                                              selectedMode = "all";
                                            });
                                            updateValue(
                                                "audioRecitersMode", "all");

                                            // await Future.delayed(
                                            //     const Duration(milliseconds: 200));
                                            Navigator.pop(context);

                                            // print(favoriteRecitersList.length);

                                            itemScrollController.scrollTo(
                                                index: 0,
                                                duration:
                                                    const Duration(seconds: 1));
                                          }
                                        },
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                              vertical: 0.0.h),
                                          child: SizedBox(
                                            height: 45.h,
                                            // color: Colors.red,
                                            child: Row(
                                              children: [
                                                SizedBox(
                                                  width: 30.w,
                                                ),
                                                Icon(
                                                  Icons.all_inclusive_rounded,
                                                  color: selectedMode == "all"
                                                      ? getValue("darkMode")
                                                          ? quranPagesColorDark
                                                          : quranPagesColorLight
                                                      : Colors.grey,
                                                ),
                                                SizedBox(
                                                  width: 10.w,
                                                ),
                                                Text("all".tr()),
                                                Expanded(
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.end,
                                                    children: [
                                                      Icon(
                                                        selectedMode == "all"
                                                            ? FontAwesome
                                                                .dot_circled
                                                            : FontAwesome
                                                                .circle_empty,
                                                        color: selectedMode ==
                                                                "all"
                                                            ? getValue(
                                                                    "darkMode")
                                                                ? quranPagesColorDark
                                                                : quranPagesColorLight
                                                            : Colors.grey,
                                                        size: 20.sp,
                                                      ),
                                                      SizedBox(
                                                        width: 40.w,
                                                      )
                                                    ],
                                                  ),
                                                )
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      Divider(
                                        height: 15.h,
                                        color: Colors.grey,
                                      ),
                                      EasyContainer(
                                        elevation: 0,
                                        padding: 0,
                                        margin: 0,
                                        onTap: () async {
                                          setState(() {
                                            selectedMode = "favorite";
                                            filteredReciters = List.from(favoriteRecitersList);
                                            // حفظ الكلمة المفتاحية ليعرف التطبيق عند الفتح أننا في قسم المفضلة
                                            updateValue("audioRecitersMode", "favorite"); 
                                          });

                                          Navigator.pop(context);

                                          if (itemScrollController.isAttached) {
                                            itemScrollController.jumpTo(index: 0);
                                          }
                                        },
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                              vertical: 0.0.h),
                                          child: SizedBox(
                                            height: 45.h,
                                            child: Row(
                                              children: [
                                                SizedBox(
                                                  width: 30.w,
                                                ),
                                                Icon(
                                                  Icons.favorite,
                                                  color: selectedMode ==
                                                          "favorite"
                                                      ? getValue("darkMode")
                                                          ? quranPagesColorDark
                                                          : quranPagesColorLight
                                                      : Colors.grey,
                                                ),
                                                SizedBox(
                                                  width: 10.w,
                                                ),
                                                Text("favorites".tr()),
                                                Expanded(
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.end,
                                                    children: [
                                                      Icon(
                                                        selectedMode ==
                                                                "favorite"
                                                            ? FontAwesome
                                                                .dot_circled
                                                            : FontAwesome
                                                                .circle_empty,
                                                        color: selectedMode ==
                                                                "favorite"
                                                            ? getValue(
                                                                    "darkMode")
                                                                ? quranPagesColorDark
                                                                : quranPagesColorLight
                                                            : Colors.grey,
                                                        size: 20.sp,
                                                      ),
                                                      SizedBox(
                                                        width: 40.w,
                                                      )
                                                    ],
                                                  ),
                                                )
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      Divider(
                                        height: 15.h,
                                        color: Colors.grey,
                                      ),
                                      ListView(
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          shrinkWrap: true,
                                          children: rewayat
                                              .map((e) => Column(
                                                    children: [
                                                      EasyContainer(
                                                        elevation: 0,
                                                        padding: 0,
                                                        margin: 0,
                                                        onTap: () {
  _applyFilterByMoshafType(e.moshafType.toString(), e.id.toString());
  
  Navigator.pop(context);
  
  // العودة لأول القائمة لتجنب مشاكل التمرير
  if (itemScrollController.isAttached) {
    itemScrollController.jumpTo(index: 0);
  }
},
                                                        child: SizedBox(
                                                          child: Padding(
                                                            padding: EdgeInsets
                                                                .symmetric(
                                                                    vertical:
                                                                        10.0.h),
                                                            child: Row(
                                                              children: [
                                                                SizedBox(
                                                                  width: 30.w,
                                                                ),
                                                                Image(
                                                                    height:
                                                                        25.h,
                                                                    color: (selectedMoshafId.isNotEmpty
                                                                            ? selectedMoshafId ==
                                                                                e.id.toString()
                                                                            : selectedMode ==
                                                                                e.moshafType)
                                                                        ? null
                                                                        : Colors
                                                                            .grey,
                                                                    image: const AssetImage(
                                                                        "assets/images/reading.png")),
                                                                SizedBox(
                                                                  width: 10.w,
                                                                ),
                                                                Text(e.name),
                                                                Expanded(
                                                                  child: Row(
                                                                    mainAxisAlignment:
                                                                        MainAxisAlignment
                                                                            .end,
                                                                    children: [
                                                                      Icon(
                                                                        (selectedMoshafId.isNotEmpty
                                                                                ? selectedMoshafId ==
                                                                                    e.id.toString()
                                                                                : selectedMode ==
                                                                                    e.moshafType.toString())
                                                                            ? FontAwesome.dot_circled
                                                                            : FontAwesome.circle_empty,
                                                                        color: (selectedMoshafId.isNotEmpty
                                                                                ? selectedMoshafId ==
                                                                                    e.id.toString()
                                                                                : selectedMode ==
                                                                                    e.moshafType.toString())
                                                                            ? getValue("darkMode")
                                                                                ? quranPagesColorDark
                                                                                : quranPagesColorLight
                                                                            : Colors.grey,
                                                                        size: 20
                                                                            .sp,
                                                                      ),
                                                                      SizedBox(
                                                                        width:
                                                                            40.w,
                                                                      )
                                                                    ],
                                                                  ),
                                                                )
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      Divider(
                                                        height: 12.h,
                                                      ),
                                                    ],
                                                  ))
                                              .toList()),
                                    ],
                                  ),
                                );
                              },
                            );
                          }));
                    },
                    icon: const Icon(FontAwesome.filter, color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(bottom: true, child: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: darkPrimaryColor),
            )
          : (selectedMode == "favorite"
                  ? favoriteRecitersList.isEmpty
                  : filteredReciters.isEmpty)
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.w),
                    child: Text(
                      "لا يوجد قراء لهذا المصحف حالياً",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: "cairo",
                          fontSize: 16.sp,
                          color: getValue("darkMode")
                              ? Colors.white70
                              : Colors.black54),
                    ),
                  ),
                )
              : AnimationLimiter(
              child: AzListView(
                physics: const BouncingScrollPhysics(),
                indexBarData: getLettersForLocale(context.locale.languageCode)!,
                indexBarHeight: screenSize.height,
                itemScrollController: itemScrollController,
                hapticFeedback: true,
                indexBarItemHeight: 20,
                data: selectedMode == "favorite"
                    ? favoriteRecitersList
                    : filteredReciters,
                itemCount: selectedMode == "favorite"
                    ? favoriteRecitersList.length
                    : filteredReciters.length,
                itemBuilder: (context, index) {
                  final reciter = selectedMode == "favorite"
                      ? favoriteRecitersList[index]
                      : filteredReciters[index];
                  return AnimationConfiguration.staggeredList(
                      position: index,
                      duration: const Duration(milliseconds: 375),
                      child: SlideAnimation(
                        verticalOffset: 50,
                        child: FadeInAnimation(
                          child: Padding(
                            padding: EdgeInsets.only(right: 15.0.w),
                            child: Card(
                              elevation: .8,
                              color: getValue("darkMode")
                                  ? darkModeSecondaryColor.withOpacity(.9)
                                  : Colors.white,
                              margin: EdgeInsets.symmetric(
                                  horizontal: 16.w, vertical: 8.h),
                              child: Padding(
                                padding: const EdgeInsets.all(0.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(height: 8.h),

                                    Padding(
                                      padding: EdgeInsets.only(
                                          left: 14.0.w, right: 14.w),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          // const SizedBox(
                                          //   width: 10,
                                          // ),
                                          Text(
                                            reciter.name.toString(),
                                            style: TextStyle(
                                                fontSize: 14.sp,
                                                color: getValue("darkMode")
                                                    ? Colors.white
                                                    : Colors.black,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: 'cairo'),
                                          ),
                                          IconButton(
                                              onPressed: () {
                                                if (favoriteRecitersList
                                                    .contains(reciter)) {
                                                  print("removing favorites");
                                                  favoriteRecitersList
                                                      .remove(reciter);
                                                  updateValue(
                                                      "favoriteRecitersList",
                                                      json.encode(
                                                          favoriteRecitersList));
                                                } else {
                                                  print("adding favorites");

                                                  favoriteRecitersList
                                                      .add(reciter);
                                                  updateValue(
                                                      "favoriteRecitersList",
                                                      json.encode(
                                                          favoriteRecitersList));
                                                }
                                                setState(() {});
                                              },
                                              icon: Icon(
                                                size: 20,
                                                favoriteRecitersList
                                                        .contains(reciter)
                                                    ? FontAwesome.heart
                                                    : FontAwesome.heart_empty,
                                                color: Colors.redAccent
                                                    .withOpacity(.6),
                                              )),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: 8.h),
                                    // Text(
                                    //   'Letter: ${reciter.letter}',
                                    //   style: const TextStyle(fontSize: 16),
                                    // ),
                                    // Text(
                                    //   'ID: ${reciter.id}',
                                    //   style: const TextStyle(fontSize: 16),
                                    // ),

                                    // padding: EdgeInsets.all(8.0),

                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: reciter.moshaf
                                          .map((e) => Padding(
                                                padding:
                                                    const EdgeInsets.all(3.0),
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                              builder: (builder) =>
                                                                  BlocProvider(
                                                                    create: (context) =>
                                                                        playerPageBloc,
                                                                    child:
                                                                        RecitersSurahListPage(
                                                                      reciter:
                                                                          reciter,
                                                                      mushaf: e,
                                                                      jsonData:
                                                                          suwar,
                                                                    ),
                                                                  )));
                                                    },
                                                    child: Column(
                                                      children: [
                                                        Divider(height: 8.h),
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Row(
                                                              children: [
                                                                SizedBox(
                                                                  width: 10.w,
                                                                ),
                                                                Image(
                                                                    height:
                                                                        15.h,
                                                                    image: const AssetImage(
                                                                        "assets/images/reading.png")),
                                                                SizedBox(
                                                                  width: 10.w,
                                                                ),
                                                                SizedBox(
                                                                  width:
                                                                      (screenSize.width *
                                                                              .5)
                                                                          .w,
                                                                  child: Text(
                                                                    e.name,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                    style: TextStyle(
                                                                        color: getValue("darkMode")
                                                                            ? Colors.white.withOpacity(
                                                                                .87)
                                                                            : Colors
                                                                                .black87,
                                                                        fontSize: 12
                                                                            .sp,
                                                                        fontFamily:
                                                                            'cairo'),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            BlocProvider(
                                                              create: (context) =>
                                                                  PlayerBlocBloc(),
                                                              child: Row(
                                                                children: [
                                                                  IconButton(
                                                                      onPressed:
                                                                          () async {
                                                                        if (qurapPagePlayerBloc.state
                                                                            is QuranPagePlayerPlaying) {
                                                                          await showDialog(
                                                                              context: context,
                                                                              builder: (a) {
                                                                                return AlertDialog(
                                                                                  content: Text("closeplayer".tr()),
                                                                                  actions: [
                                                                                    TextButton(
                                                                                        onPressed: () {
                                                                                          Navigator.pop(context);
                                                                                        },
                                                                                        child: Text("cancel".tr())),
                                                                                    TextButton(
                                                                                        onPressed: () {
                                                                                          qurapPagePlayerBloc.add(KillPlayerEvent());
                                                                                          Navigator.pop(context);
                                                                                        },
                                                                                        child: Text("close".tr())),
                                                                                  ],
                                                                                );
                                                                              });
                                                                        }
                                                                        playerPageBloc.add(StartPlaying(
                                                                            initialIndex:
                                                                                0,
                                                                            moshaf:
                                                                                e,
                                                                            buildContext:
                                                                                context,
                                                                            reciter:
                                                                                reciter,
                                                                            suraNumber:
                                                                                -1,
                                                                            jsonData:
                                                                                suwar));
                                                                      },
                                                                      icon:
                                                                          Icon(
                                                                        size: 20
                                                                            .sp,
                                                                        Icons
                                                                            .play_circle_outline,
                                                                        color:
                                                                            orangeColor,
                                                                      )),
                                                                  IconButton(
                                                                      onPressed:
                                                                          () {
                                                                        playerPageBloc.add(DownloadAllSurahs(
                                                                            moshaf:
                                                                                e,
                                                                            reciter:
                                                                                reciter));
                                                                      },
                                                                      icon:
                                                                          Icon(
                                                                        size: 20
                                                                            .sp,
                                                                        Icons
                                                                            .download,
                                                                        color:
                                                                            blueColor,
                                                                      )),
                                                                  //  SizedBox(
                                                                  //   width:
                                                                  //       10.w,
                                                                  // ),
                                                                ],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ))
                                          .toList(),
                                    ),
                                    SizedBox(height: 8.h),

                                    // You can add more properties from the Reciter class here
                                    // For example:
                                    // Text('Other Property: ${reciter.otherProperty}'),
                                    // ...
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ));
                },
              ),
              ),
      ),
    );
  }
}
