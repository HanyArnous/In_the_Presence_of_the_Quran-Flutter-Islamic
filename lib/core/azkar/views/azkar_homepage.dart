import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nabd/GlobalHelpers/constants.dart';
import 'package:nabd/GlobalHelpers/hive_helper.dart';
import 'package:nabd/core/azkar/data/azkar.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nabd/core/azkar/model/dua_model.dart';
import 'package:nabd/core/azkar/views/zikr_detailspage.dart';
import 'package:quran/quran.dart';
import 'package:superellipse_shape/superellipse_shape.dart';

class AzkarHomePage extends StatefulWidget {
  const AzkarHomePage({super.key});

  @override
  State<AzkarHomePage> createState() => _AzkarHomePageState();
}

class _AzkarHomePageState extends State<AzkarHomePage> {
  int index = 0;
  List tempAzkar = azkar;
  List<Map<String, dynamic>> _mergedBase = [];
  List<Map<String, dynamic>> _customCategories = [];
  Map<String, String> _overrides = {};
  List<dynamic> _order = [];

  @override
  void initState() {
    super.initState();
    _loadCategoryData();
    _rebuildCategories();
  }

  void _loadCategoryData() {
    try {
      final custom = getValue("customAzkarCategories");
      if (custom != null) {
        final List list = jsonDecode(custom);
        _customCategories = list.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    try {
      final overrides = getValue("azkarCategoryOverrides");
      if (overrides != null) {
        _overrides = Map<String, String>.from(jsonDecode(overrides));
      }
    } catch (_) {}
    try {
      final order = getValue("azkarOrder");
      if (order != null) {
        _order = jsonDecode(order);
      }
    } catch (_) {}
  }

  void _persistCategoryData() {
    updateValue("customAzkarCategories", jsonEncode(_customCategories));
    updateValue("azkarCategoryOverrides", jsonEncode(_overrides));
    updateValue("azkarOrder", jsonEncode(_order));
  }

  List<Map<String, dynamic>> _mergedCategories() {
    final original = azkar.map<Map<String, dynamic>>((e) {
      final id = e["id"].toString();
      final overrideName = _overrides[id];
      if (overrideName != null && overrideName.isNotEmpty) {
        return {
          ...e,
          "category": overrideName,
        };
      }
      return e;
    }).toList();
    final merged = [...original, ..._customCategories];
    if (_order.isNotEmpty) {
      merged.sort((a, b) {
        final aId = a["id"].toString();
        final bId = b["id"].toString();
        final ia = _order.indexOf(aId);
        final ib = _order.indexOf(bId);
        final va = ia == -1 ? 99999 : ia;
        final vb = ib == -1 ? 99999 : ib;
        return va.compareTo(vb);
      });
    }
    return merged;
  }

  void _rebuildCategories() {
    _mergedBase = _mergedCategories();
    tempAzkar = List.from(_mergedBase);
    setState(() {});
  }

  void _addCategory() async {
    final controller = TextEditingController();
    await showDialog(
        context: context,
        builder: (c) {
          return AlertDialog(
            title: const Text("إضافة قسم جديد",
                style: TextStyle(fontFamily: "cairo")),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: "اسم القسم"),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text("إلغاء")),
              TextButton(
                  onPressed: () {
                    final name = controller.text.trim();
                    if (name.isNotEmpty) {
                      final id =
                          "custom_${DateTime.now().millisecondsSinceEpoch}";
                      _customCategories.add({
                        "id": id,
                        "category": name,
                        "audio": "",
                        "filename": "",
                        "array": [],
                      });
                      _order.add(id);
                      _persistCategoryData();
                      _rebuildCategories();
                    }
                    Navigator.pop(c);
                  },
                  child: const Text("حفظ")),
            ],
          );
        });
  }

  void _renameCategory(Map<String, dynamic> item) async {
    final isCustom = item["id"].toString().startsWith("custom_");
    final controller = TextEditingController(text: item["category"]);
    await showDialog(
        context: context,
        builder: (c) {
          return AlertDialog(
            title: const Text("إعادة تسمية القسم",
                style: TextStyle(fontFamily: "cairo")),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: "اسم القسم الجديد"),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text("إلغاء")),
              TextButton(
                  onPressed: () {
                    final name = controller.text.trim();
                    if (name.isNotEmpty) {
                      if (isCustom) {
                        final idx = _customCategories
                            .indexWhere((e) => e["id"] == item["id"]);
                        if (idx >= 0) {
                          _customCategories[idx]["category"] = name;
                        }
                      } else {
                        _overrides[item["id"].toString()] = name;
                      }
                      _persistCategoryData();
                      _rebuildCategories();
                    }
                    Navigator.pop(c);
                  },
                  child: const Text("حفظ")),
            ],
          );
        });
  }

  void _deleteCategory(Map<String, dynamic> item) {
    final isCustom = item["id"].toString().startsWith("custom_");
    if (!isCustom) return;
    _customCategories.removeWhere((e) => e["id"] == item["id"]);
    _order.remove(item["id"].toString());
    _persistCategoryData();
    _rebuildCategories();
  }

  void _manageOrder() async {
    var list = _mergedCategories();
    await showDialog(
        context: context,
        builder: (c) {
          return AlertDialog(
            title: const Text("إعادة ترتيب الأقسام",
                style: TextStyle(fontFamily: "cairo")),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.6,
              child: StatefulBuilder(
                builder: (context, setSt) {
                  return ReorderableListView.builder(
                    itemCount: list.length,
                    onReorder: (oldIndex, newIndex) {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final item = list.removeAt(oldIndex);
                      list.insert(newIndex, item);
                      setSt(() {});
                    },
                    itemBuilder: (ctx, i) {
                      final it = list[i];
                      return ListTile(
                        key: ValueKey(it["id"]),
                        title: Text(it["category"]),
                        trailing: const Icon(Icons.drag_handle),
                      );
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text("إلغاء")),
              TextButton(
                  onPressed: () {
                    _order = list.map((e) => e["id"].toString()).toList();
                    _persistCategoryData();
                    _rebuildCategories();
                    Navigator.pop(c);
                  },
                  child: const Text("حفظ")),
            ],
          );
        });
  }

  searchFunction(searchwords) {
    tempAzkar = _mergedBase
        .where((element) =>
            removeDiacritics(element["category"]).contains(searchwords))
        .toList();

    // hadithes = filteredHadithes;
    if (searchwords == "") {
      tempAzkar = List.from(_mergedBase);
    }

    setState(() {});
  }

  TextEditingController textEditingController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height,
      decoration: const BoxDecoration(
          image: DecorationImage(
              fit: BoxFit.cover,
              image: AssetImage(
                "assets/images/try6.png",
              ),
              alignment: Alignment.center,
              opacity: .6)),
      child: Scaffold(
        backgroundColor:
            getValue("darkMode") ? quranPagesColorDark : quranPagesColorLight,
        body: SafeArea(bottom: true, child: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
              floating: true,
              pinned: true,
              iconTheme: const IconThemeData(color: Colors.white),
              backgroundColor:
                  getValue("darkMode") ? darkModeSecondaryColor : blueColor,
              elevation: 0, // No shadow
              title: Text(
                "azkar".tr(),
                style: TextStyle(color: Colors.white, fontSize: 16.sp),
              ),
              expandedHeight: 100.h,
              collapsedHeight: kToolbarHeight,
              actions: [
                IconButton(
                  onPressed: _addCategory,
                  icon: const Icon(Icons.add, color: Colors.white),
                ),
                IconButton(
                  onPressed: _manageOrder,
                  icon: const Icon(Icons.unfold_more, color: Colors.white),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  alignment: Alignment.bottomCenter,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xffF5EFE8).withOpacity(.3),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          style: const TextStyle(color: Colors.white),
                          controller: textEditingController,
                          onChanged: (val) {
                            searchFunction(val);
                          },
                          decoration: InputDecoration(
                            hintText: 'SearchDua'.tr(),
                            hintStyle: const TextStyle(color: Colors.white),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      if (tempAzkar.length != azkar.length)
                        IconButton(
                            onPressed: () {
                              textEditingController.clear();
                              searchFunction("");
                            },
                            icon: const Icon(Icons.close, color: Colors.white))
                    ],
                  ),
                ),
              ),
            ),
            SliverList.builder(
                // shrinkWrap: true,
                itemCount: tempAzkar.length,
                // physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (f, i) {
                  return Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 4.0.w, vertical: 6.h),
                    child: Material(
                      color: getValue("darkMode")
                          ? darkModeSecondaryColor.withOpacity(.8)
                          : const Color.fromARGB(255, 255, 255, 255)
                              .withOpacity(.2),
                      shape: SuperellipseShape(
                        borderRadius: BorderRadius.circular(34.0.r),
                      ),
                      child:
                          // AnimatedOpacity(
                          // duration: const Duration(milliseconds: 500),
                          // opacity: dominantColor != null ? 1.0 : 0,
                          // child:
                          InkWell(
                        onLongPress: () async {
                          final item = tempAzkar[i] as Map<String, dynamic>;
                          await showModalBottomSheet(
                            context: context,
                            builder: (c) {
                              final isCustom =
                                  item["id"].toString().startsWith("custom_");
                              return SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.edit),
                                      title: const Text("إعادة تسمية"),
                                      onTap: () {
                                        Navigator.pop(c);
                                        _renameCategory(item);
                                      },
                                    ),
                                    if (isCustom)
                                      ListTile(
                                        leading: const Icon(Icons.delete,
                                            color: Colors.red),
                                        title: const Text("حذف القسم"),
                                        onTap: () {
                                          Navigator.pop(c);
                                          _deleteCategory(item);
                                        },
                                      ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                        onTap: () {
                          Navigator.push(
                              context,
                              CupertinoPageRoute(
                                  builder: (builder) => ZikrPage(
                                        zikr: DuaModel.fromJson(tempAzkar[i]),
                                      )));
                        },
                        splashColor: getValue("darkMode")
                            ? darkModeSecondaryColor.withOpacity(.5)
                            : blueColor.withOpacity(.2),
                        borderRadius: BorderRadius.circular(17.0.r),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: 12.h,
                              ),
                              Padding(
                                padding:
                                    EdgeInsets.symmetric(horizontal: 12.0.w),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      tempAzkar[i]["category"],
                                      style: TextStyle(
                                        color: getValue("darkMode")
                                            ? Colors.white.withOpacity(.9)
                                            : blueColor,
                                        fontSize: 18.sp,
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      color: orangeColor,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                height: 12.h,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
          ],
        ),
        ),
      ),
    );
  }
}
