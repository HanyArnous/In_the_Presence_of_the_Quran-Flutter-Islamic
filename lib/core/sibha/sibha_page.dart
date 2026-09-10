import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nabd/GlobalHelpers/constants.dart';
import 'package:nabd/GlobalHelpers/hive_helper.dart';
import 'package:nabd/core/sibha/models/tasbeh.dart';
import 'package:nabd/core/sibha/widgets/add_tasbeeh_dialog.dart';

class SibhaPage extends StatefulWidget {
  const SibhaPage({super.key});

  @override
  State<SibhaPage> createState() => _SibhaPageState();
}

class _SibhaPageState extends State<SibhaPage> {
  int? currentMax;
  TextEditingController maxController = TextEditingController();
  late AudioPlayer _audioPlayer;
  bool _audioPlayerInitialized = false;
  bool _tapSoundEnabled = true; // حالة صوت النقرة
  List<Tasbeeh> tasbeehList = [
    Tasbeeh(
      id: 0,
      arabic: 'الحمد لله',
      translation: 'Praise be to Allah',
      pronunciation: 'Al-ham-du li-lah',
      defaultCount: 33,
    ),
    Tasbeeh(
      id: 1,
      arabic: 'الله اكبر',
      translation: 'Allah is the Greatest',
      pronunciation: 'Al-lah-hu Ak-bar',
      defaultCount: 33,
    ),
    Tasbeeh(
      id: 2,
      arabic: 'استغفر الله',
      translation: 'I seek forgiveness from Allah',
      pronunciation: 'As-tag-fir-ul-lah',
      defaultCount: 33,
    ),
    Tasbeeh(
      id: 3,
      arabic: 'لا اله الا الله',
      translation: 'There is no god but Allah',
      pronunciation: 'La ila-ha ill-al-lah',
      defaultCount: 33,
    ),
    Tasbeeh(
      id: 4,
      arabic: 'سبحان الله',
      translation: 'Glory be to Allah',
      pronunciation: 'Sub-han Allah',
      defaultCount: 33,
    ),
    Tasbeeh(
      id: 5,
      arabic: 'سبحان الله وبحمده سبحان الله العظيم',
      translation:
          'Glory be to Allah, and praise is due to Him, glory be to Allah the Great',
      pronunciation: 'Sub-han Allah wa bi-ham-di-hi Sub-han Allah al-a-zeem',
      defaultCount: 33,
    ),
    Tasbeeh(
      id: 6,
      arabic: 'سبحان الله والحمد لله ولا اله الا الله والله اكبر',
      translation:
          'Glory be to Allah, and praise be due to Allah, and there is no god but Allah, and Allah is the Greatest',
      pronunciation:
          'Sub-han Allah wa al-ham-du li-lah wa la ila-ha ill-al-lah wa Al-lah Ak-bar',
      defaultCount: 33,
    ),
    Tasbeeh(
      id: 7,
      arabic: 'لا إله إلا أنت سبحانك إني كنت من الظالمين',
      translation:
          'There is no god but You, glory be to You; surely I am of those who are unjust',
      pronunciation:
          'La ila-ha ill-a an-ta Sub-ha-na-ka in-ni ku-n-tu min az-zal-li-meen',
      defaultCount: 100,
    ),
    Tasbeeh(
      id: 8,
      arabic: 'اللهم أنت السلام ومنك السلام تباركت يا ذا الجلال والإكرام',
      translation:
          'O Allah, You are the Peace, and from You comes peace; Blessed are You, O Possessor of Majesty and Honor',
      pronunciation:
          'Al-lah-ma an-ta as-Sa-laam wa min-ka as-Sa-laam ta-ba-ra-kat ya dha al-ja-la-li wal-i-kraam',
      defaultCount: 100,
    ),
    Tasbeeh(
      id: 9,
      arabic: 'اللهم صل وسلم وبارك على سيدنا محمد',
      translation: 'O Allah, send peace and blessings upon our Master Muhammad',
      pronunciation:
          'Al-lah-ma sal-li wa sal-lim wa ba-rik ala sa-yi-di-na Mu-ham-mad',
      defaultCount: 100,
    ),
    Tasbeeh(
      id: 10,
      arabic: 'الله أكبر كبيرا  والحمد لله كثيرا  وسبحان الله بكرة وأصيلا',
      translation:
          'Allah is the Greatest, greatly, and praise be to Allah abundantly, and glory be to Allah in the morning and the evening',
      pronunciation:
          'Al-lah Ak-bar kabee-ra wa al-ham-du li-lah ka-thee-ra wa Sub-han Al-lah bu-ka-ra wa a-shee-la',
      defaultCount: 100,
    ),
    Tasbeeh(
      id: 11,
      arabic:
          'لا إله إلا الله وحده لا شريك له له الملك وله الحمد وهو على كل شيء قدير',
      translation:
          'There is no god but Allah alone, He has no partner, His is the sovereignty, and His is the praise, and He has power over everything',
      pronunciation:
          'La ila-ha ill-a al-lah wa-hda-hu la shar-ee-ka la-hu la-hu al-mul-ku wa la-hu al-ham-du wa hu-wa ala ku-l-lee shay-in qa-deer',
      defaultCount: 100,
    ),
    Tasbeeh(
      id: 12,
      arabic: 'سبحان الله وبحمده  سبحان الله العظيم',
      translation:
          'Glory be to Allah, and praise be to Him; glory be to Allah the Great',
      pronunciation: 'Sub-han Al-lah wa bi-ham-di-hi  Sub-han Al-lah al-a-zeem',
      defaultCount: 33,
    ),
  ];

  @override
  void initState() {
    _audioPlayer = AudioPlayer();
    _audioPlayer.setPlayerMode(PlayerMode.lowLatency);
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
    _audioPlayerInitialized = true;
    _tapSoundEnabled = getValue("tap_sound_enabled") ?? true;
    loadAllTasbeehs();
    customTasbeehFetcher();
    _initializeCurrentMax();
    _setupDailyReset();
    super.initState();
  }

  void _initializeCurrentMax() {
    final lastIndex = getValue("tasbeehLastIndex") ?? 0;
    currentMax = getValue("${lastIndex}max");

    // التأكد من تحديث currentMax بشكل صحيح
    if (currentMax == null) {
      // إذا لم يوجد max محفوظ، استخدم القيمة الافتراضية
      currentMax = tasbeehList[lastIndex].defaultCount;
    }

    // فرض تحديث الواجهة لضمان عمل السبحات
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _setupDailyReset() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final durationUntilMidnight = tomorrow.difference(now);

    Future.delayed(durationUntilMidnight, () {
      _dailyReset();
      _setupDailyReset(); // Schedule next day's reset
    });
  }

  void _dailyReset() {
    for (int i = 0; i < tasbeehList.length; i++) {
      updateValue("${i}number", 0);
    }
    updateValue("tasbeehLastIndex", 0);
    tasbeehScrollController.animateToPage(0,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    setState(() {});
  }

  void loadAllTasbeehs() {
    final saved = getValue("tasbeehAll");
    if (saved != null) {
      try {
        final list = json.decode(saved);
        tasbeehList = (list as List).map((t) => Tasbeeh.fromJson(t)).toList();
        setState(() {});
      } catch (_) {}
    }
  }

  void persistAllTasbeehs() {
    final list = tasbeehList.map((t) => t.toJson()).toList();
    updateValue("tasbeehAll", json.encode(list));
  }

  customTasbeehFetcher() {
    var customTasbeehs = getValue("customTasbeehs");
    debugPrint(customTasbeehs);
    if (customTasbeehs != null) {
      json.decode(customTasbeehs).forEach((t) {
        tasbeehList.add(Tasbeeh(
          id: t["id"],
          arabic: t["arabic"],
          translation: "",
          pronunciation: "",
          defaultCount: t["defaultCount"],
          enableSound: t["enableSound"] ?? true,
        ));
      });
      setState(() {});
    }
  }

  addCustomTasbeeh(arabic, {int? defaultCount, bool enableSound = true}) async {
    var customTasbeehs = getValue("customTasbeehs");
    final newId = Random().nextInt(665656);

    if (customTasbeehs != null) {
      var tasbeehs = json.decode(customTasbeehs);
      tasbeehs.add({
        "id": newId,
        "arabic": arabic,
        "defaultCount": defaultCount,
        "enableSound": enableSound,
      });
      tasbeehList.add(Tasbeeh(
          id: newId,
          arabic: arabic,
          translation: "",
          pronunciation: "",
          defaultCount: defaultCount,
          enableSound: enableSound));
      updateValue("customTasbeehs", json.encode(tasbeehs));
    } else {
      List tasbeehs = [];
      tasbeehs.add({
        "id": newId,
        "arabic": arabic,
        "defaultCount": defaultCount,
        "enableSound": enableSound,
      });
      setState(() {});
      tasbeehList.add(Tasbeeh(
          id: newId,
          arabic: arabic,
          translation: "",
          pronunciation: "",
          defaultCount: defaultCount,
          enableSound: enableSound));
      setState(() {});
      updateValue("customTasbeehs", json.encode(tasbeehs));
    }
    persistAllTasbeehs();
    Navigator.pop(context);
    await Future.delayed(const Duration(milliseconds: 150));
    tasbeehScrollController.animateToPage(tasbeehList.length - 1,
        duration: const Duration(milliseconds: 300), curve: Curves.bounceInOut);
  }

  // removeTasbeeh(arabic) {
  //   var customTasbeehs = getValue("customTasbeehs");
  //   if (customTasbeehs != null) {
  //     var tasbeehs = json.decode(customTasbeehs);
  //     tasbeehs.add({
  //       "id": Random().nextInt(665656),
  //       "arabic": arabic,
  //     });
  //     tasbeehList.add(
  //       Tasbeeh(id: tasbeehs[tasbeehs.length]["id"], arabic: tasbeehs[tasbeehs.length]["arabic"], translation: "", pronunciation: "")
  //     );
  //     updateValue("customTasbeehs", json.encode(tasbeehs));
  //   }

  // }
  PageController tasbeehScrollController =
      PageController(initialPage: getValue("tasbeehLastIndex") ?? 0);

  void _moveToNextTasbeeh() {
    final currentIndex = getValue("tasbeehLastIndex") ?? 0;
    final nextIndex = currentIndex + 1;

    if (nextIndex < tasbeehList.length) {
      // الانتقال للذكر التالي
      tasbeehScrollController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      updateValue("tasbeehLastIndex", nextIndex);
      _initializeCurrentMax();

      // إعادة تعيين عداد الذكر الجديد
      updateValue("${nextIndex}number", 0);
    } else {
      // إذا كان هذا آخر ذكر، ارجع للأول
      tasbeehScrollController.animateToPage(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      updateValue("tasbeehLastIndex", 0);
      _initializeCurrentMax();
      updateValue("0number", 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    bool isCurrentCustom() {
      return true; // Allow editing all tasbeeh
    }

    Future<void> editCurrentTasbeeh() async {
      final idx = getValue("tasbeehLastIndex") ?? 0;
      if (idx < 0 || idx >= tasbeehList.length) return;
      final t = tasbeehList[idx];
      final controller = TextEditingController(text: t.arabic);
      await showDialog(
          context: context,
          builder: (c) {
            return AlertDialog(
              title: const Text("تعديل الذكر",
                  style: TextStyle(fontFamily: "cairo")),
              content: TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: "أدخل نص الذكر"),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text("إلغاء")),
                TextButton(
                    onPressed: () {
                      final newText = controller.text.trim();
                      if (newText.isNotEmpty) {
                        tasbeehList[idx] = Tasbeeh(
                          id: t.id,
                          arabic: newText,
                          translation: t.translation,
                          pronunciation: t.pronunciation,
                          defaultCount: t.defaultCount,
                          enableSound: t.enableSound,
                        );
                        var customTasbeehs = getValue("customTasbeehs");
                        if (customTasbeehs != null) {
                          final list = json.decode(customTasbeehs);
                          for (var i = 0; i < list.length; i++) {
                            if (list[i]["id"] == t.id) {
                              list[i]["arabic"] = newText;
                              break;
                            }
                          }
                          updateValue("customTasbeehs", json.encode(list));
                        }
                        persistAllTasbeehs();
                        setState(() {});
                      }
                      Navigator.pop(c);
                    },
                    child: const Text("حفظ")),
              ],
            );
          });
    }

    Future<void> deleteCurrentTasbeeh() async {
      final idx = getValue("tasbeehLastIndex") ?? 0;
      if (idx < 0 || idx >= tasbeehList.length) return;
      final t = tasbeehList[idx];
      final confirmed = await showDialog<bool>(
              context: context,
              builder: (c) {
                return AlertDialog(
                  title: const Text("حذف الذكر",
                      style: TextStyle(fontFamily: "cairo")),
                  content: const Text("هل تريد حذف هذا الذكر؟",
                      style: TextStyle(fontFamily: "cairo")),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text("إلغاء")),
                    TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text("حذف")),
                  ],
                );
              }) ??
          false;
      if (!confirmed) return;
      var customTasbeehs = getValue("customTasbeehs");
      if (customTasbeehs != null) {
        final list = json.decode(customTasbeehs);
        list.removeWhere((e) => e["id"] == t.id);
        updateValue("customTasbeehs", json.encode(list));
      }
      tasbeehList.removeAt(idx);
      persistAllTasbeehs();
      final newIdx = idx >= tasbeehList.length ? tasbeehList.length - 1 : idx;
      updateValue("tasbeehLastIndex", newIdx);
      if (newIdx >= 0) {
        tasbeehScrollController.animateToPage(newIdx,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
      setState(() {});
    }

    return Container(
      decoration: const BoxDecoration(
          color: darkPrimaryColor,
          image: DecorationImage(
              image: AssetImage(
                "assets/images/tasbeehbackground.png",
              ),
              opacity: .03,
              fit: BoxFit.cover)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          actions: [
            // أيقونة التحكم في صوت النقرة
            IconButton(
                onPressed: _toggleTapSound,
                icon: Icon(
                  _tapSoundEnabled ? Icons.volume_up : Icons.volume_off,
                  color: _tapSoundEnabled ? Colors.white : Colors.grey,
                )),
            IconButton(
                onPressed: () {
                  showDialog(
                      context: context,
                      builder: (c) => AlertDialog(
                            title: const Text("تصفير العدادات",
                                style: TextStyle(fontFamily: "cairo")),
                            content: const Text(
                                "هل تريد تصفير جميع العدادات والعودة إلى أول ذكر؟",
                                style: TextStyle(fontFamily: "cairo")),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(c),
                                  child: const Text("إلغاء")),
                              TextButton(
                                  onPressed: () {
                                    _dailyReset();
                                    Navigator.pop(c);
                                  },
                                  child: const Text("نعم")),
                            ],
                          ));
                },
                icon: const Icon(Icons.refresh, color: Colors.white)),
            IconButton(
                onPressed: () {
                  showDialog(
                      // alignment: Alignment.center,
                      // animationType: DialogTransitionType.,
                      context: context,
                      builder: (c) => AddTasbeehDialog(
                            function: addCustomTasbeeh,
                          ));
                },
                icon: const Icon(Icons.add, color: Colors.white)),
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == "edit") {
                  await editCurrentTasbeeh();
                } else if (v == "delete") {
                  await deleteCurrentTasbeeh();
                }
              },
              itemBuilder: (c) => [
                PopupMenuItem<String>(
                  value: "edit",
                  enabled: isCurrentCustom(),
                  child: const Text("تعديل",
                      style: TextStyle(fontFamily: "cairo")),
                ),
                PopupMenuItem<String>(
                  value: "delete",
                  enabled: isCurrentCustom(),
                  child:
                      const Text("حذف", style: TextStyle(fontFamily: "cairo")),
                ),
              ],
              icon: const Icon(Icons.more_vert, color: Colors.white),
            )
          ],
          title: Text(
            "sibha".tr(),
            style: const TextStyle(fontFamily: 'cairo'),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          bottom: true,
          child: Column(
            children: [
              SizedBox(
                height: screenSize.height * .04,
              ),
              Expanded(
                // height: screenSize.height * .2,
                // width: screenSize.width,
                child: PageView.builder(
                  onPageChanged: ((value) {
                    updateValue("tasbeehLastIndex", value);
                    _initializeCurrentMax();
                    setState(() {});
                  }),
                  itemBuilder: (itemBuilder, i) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: backgroundColor.withValues(alpha: .75),
                          borderRadius: BorderRadius.circular(18.r),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(tasbeehList[i].arabic,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.black,
                                    fontFamily: "cairo",
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.bold)),
                            if (tasbeehList[i].pronunciation != "")
                              const Divider(),
                            if (tasbeehList[i].pronunciation != "")
                              Text(tasbeehList[i].pronunciation,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.black.withValues(alpha: .6),
                                      fontFamily: "roboto",
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.bold)),
                            if (tasbeehList[i].translation != "")
                              const Divider(),
                            if (tasbeehList[i].translation != "")
                              Text(tasbeehList[i].translation,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.black.withValues(alpha: .5),
                                      fontFamily: "roboto",
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.bold))
                          ],
                        ),
                      ),
                    );
                  },
                  itemCount: tasbeehList.length,
                  scrollDirection: Axis.horizontal,
                  controller: tasbeehScrollController,
                ),
              ),
              SizedBox(
                height: 20.h,
              ),
              SizedBox(
                width: screenSize.width,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      onTap: () {
                        debugPrint("object");
                        if (getValue("tasbeehLastIndex") != 0) {
                          tasbeehScrollController.animateToPage(
                              getValue("tasbeehLastIndex") - 1,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.decelerate);
                        }
                        setState(() {});
                      },
                      child: SizedBox(
                        width: screenSize.width * .3,
                        height: screenSize.height * .062,
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.only(left: 40.w),
                            child: Icon(
                              Icons.arrow_back_ios,
                              color: Colors.white.withValues(alpha: .8),
                            ),
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      onTap: () {
                        updateValue(
                            "${getValue("tasbeehLastIndex")}number", (0));
                        setState(() {});
                      },
                      child: SizedBox(
                        width: screenSize.width * .3,
                        height: screenSize.height * .062,
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.only(left: 0.w),
                            child: Icon(
                              Icons.replay_outlined,
                              color: Colors.white.withValues(alpha: .8),
                            ),
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      onTap: () {
                        if (getValue("tasbeehLastIndex") !=
                            tasbeehList.length - 1) {
                          tasbeehScrollController.animateToPage(
                              getValue("tasbeehLastIndex") + 1,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.decelerate);
                          setState(() {});
                        }
                      },
                      child: SizedBox(
                        height: screenSize.height * .062,
                        width: screenSize.width * .3,
                        child: Padding(
                          padding: EdgeInsets.only(right: 40.w),
                          child: Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white.withValues(alpha: .8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                child: InkWell(
                  onTap: () async {
                    maxController.text =
                        (getValue("${getValue("tasbeehLastIndex")}max") ?? "")
                            .toString();
                    await showDialog(
                        context: context,
                        builder: (c) {
                          return AlertDialog(
                            title: const Text(
                              "تحديد العدد الأقصى",
                              style: TextStyle(fontFamily: "cairo"),
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(
                                  controller: maxController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText:
                                        "أدخل العدد الأقصى (اتركه فارغاً لغير محدود)",
                                  ),
                                ),
                                SizedBox(height: 10.h),
                                if (tasbeehList[
                                            getValue("tasbeehLastIndex") ?? 0]
                                        .defaultCount !=
                                    null)
                                  Row(
                                    children: [
                                      TextButton(
                                        onPressed: () {
                                          maxController.text = tasbeehList[
                                                  getValue(
                                                          "tasbeehLastIndex") ??
                                                      0]
                                              .defaultCount
                                              .toString();
                                        },
                                        child: Text(
                                            "استخدام العدد الافتراضي (${tasbeehList[getValue("tasbeehLastIndex") ?? 0].defaultCount})"),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                  onPressed: () {
                                    Navigator.pop(c);
                                  },
                                  child: const Text("إلغاء")),
                              TextButton(
                                  onPressed: () {
                                    final parsed =
                                        int.tryParse(maxController.text.trim());
                                    if (parsed != null && parsed >= 0) {
                                      updateValue(
                                          "${getValue("tasbeehLastIndex")}max",
                                          parsed);
                                      currentMax = parsed;
                                    } else {
                                      updateValue(
                                          "${getValue("tasbeehLastIndex")}max",
                                          null);
                                      currentMax = null;
                                    }
                                    setState(() {});
                                    Navigator.pop(c);
                                  },
                                  child: const Text("حفظ"))
                            ],
                          );
                        });
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.settings,
                          color: Colors.white.withValues(alpha: .8)),
                      SizedBox(width: 8.w),
                      Text(
                        currentMax != null
                            ? "الحد الأقصى: $currentMax"
                            : "غير محدود",
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: .9),
                            fontFamily: "cairo"),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                    overlayColor: WidgetStatePropertyAll(
                        Colors.white.withValues(alpha: .2)),
                    splashColor: Colors.white.withValues(alpha: .1),
                    focusColor: Colors.white.withValues(alpha: .1),
                    hoverColor: Colors.white.withValues(alpha: .1),
                    highlightColor: Colors.white.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(200),
                    onTap: () async {
                      final idx = getValue("tasbeehLastIndex");
                      final current = (getValue("${idx}number") ?? 0) as int;
                      final maxVal = getValue("${idx}max");
                      final currentTasbeeh = tasbeehList[idx];

                      HapticFeedback.selectionClick();

                      // Play sound if enabled
                      if (_tapSoundEnabled) {
                        _playTapSound();
                      }

                      int maxInt;
                      if (maxVal != null) {
                        maxInt = maxVal as int;
                      } else {
                        maxInt = currentTasbeeh.defaultCount ?? 33;
                        updateValue("${idx}max", maxInt);
                      }

                      if (current >= maxInt) {
                        HapticFeedback.heavyImpact();
                        if (_tapSoundEnabled) _playTapSound();
                        if (tasbeehList.length <= 1) {
                          HapticFeedback.vibrate();
                          setState(() {});
                          return;
                        }
                        _moveToNextTasbeeh();
                        setState(() {});
                        return;
                      }
                      final next = current + 1;
                      updateValue("${idx}number", next);

                      final dateKey =
                          DateFormat('yyyy-MM-dd').format(DateTime.now());
                      int daily = getValue("$dateKey-tasbeeh-count") ?? 0;
                      updateValue("$dateKey-tasbeeh-count", daily + 1);
                      int total = getValue("tasbeeh-totalCount") ?? 0;
                      updateValue("tasbeeh-totalCount", total + 1);

                      if (next == maxInt) {
                        HapticFeedback.mediumImpact();
                        if (_tapSoundEnabled) {
                          _playTapSound();
                          Future.delayed(const Duration(milliseconds: 100), () => _playTapSound());
                        }
                        if (tasbeehList.length == 1) {
                          HapticFeedback.heavyImpact();
                        } else {
                          Future.delayed(const Duration(milliseconds: 300), () {
                            if (mounted) _moveToNextTasbeeh();
                          });
                        }
                      }
                      setState(() {});
                    },
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                              "${getValue("${getValue("tasbeehLastIndex")}number") ?? 0}${currentMax != null ? " / $currentMax" : ""}",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 50.sp,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: "roboto")),
                        ],
                      ),
                    )),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayerInitialized = false;
    _audioPlayer.dispose();
    super.dispose();
  }

  void _playTapSound() async {
    try {
      if (!_audioPlayerInitialized) return;
      // إيقاف فوري ثم تشغيل لضمان الصوت مع كل ضغطة حتى السريعة
      try { await _audioPlayer.stop(); } catch (_) {}
      await _audioPlayer.play(AssetSource('click.mp3'));
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  // دالة تبديل حالة صوت النقرة
  void _toggleTapSound() {
    setState(() {
      _tapSoundEnabled = !_tapSoundEnabled;
      updateValue("tap_sound_enabled", _tapSoundEnabled);
    });
  }
}
