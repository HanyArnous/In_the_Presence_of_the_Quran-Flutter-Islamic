import 'dart:io';
import 'dart:async';
import 'package:easy_localization/easy_localization.dart';

import 'package:dio/dio.dart';
import 'package:easy_container/easy_container.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as m;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttericon/font_awesome_icons.dart';
import 'package:fluttericon/mfg_labs_icons.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:nabd/GlobalHelpers/constants.dart';
import 'package:nabd/GlobalHelpers/hive_helper.dart';
import 'package:nabd/blocs/bloc/quran_page_player_bloc.dart';
import 'package:nabd/core/home.dart';
import 'package:nabd/core/QuranPages/helpers/convertNumberToAr.dart';
import 'package:nabd/core/QuranPages/helpers/translation/get_translation_data.dart'
    as get_translation_data;
import 'package:nabd/core/QuranPages/widgets/bismallah.dart';
import 'package:nabd/core/QuranPages/widgets/header_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quran/quran.dart' as quran;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:visibility_detector/visibility_detector.dart';

class QuranVerseByVerseView extends StatefulWidget {
  final ItemScrollController itemScrollController;
  final ItemPositionsListener itemPositionsListener;
  final Function(int) onPageChanged;
  final List bookmarks;
  final dynamic jsonData;
  final bool shouldHighlightText;
  final dynamic highlightVerse;
  final Function(int, int, int) onShowAyahOptions;
  final List translationDataList;
  final Map dataOfCurrentTranslation;
  final bool Function(int, int) isVerseStarred;
  final VoidCallback onBack;

  const QuranVerseByVerseView({
    Key? key,
    required this.itemScrollController,
    required this.itemPositionsListener,
    required this.onPageChanged,
    required this.bookmarks,
    required this.jsonData,
    required this.shouldHighlightText,
    required this.highlightVerse,
    required this.onShowAyahOptions,
    required this.translationDataList,
    required this.dataOfCurrentTranslation,
    required this.isVerseStarred,
    required this.onBack,
  }) : super(key: key);

  @override
  State<QuranVerseByVerseView> createState() => _QuranVerseByVerseViewState();
}

class _QuranVerseByVerseViewState extends State<QuranVerseByVerseView> {
  String selectedSpan = "";
  List<GlobalKey> richTextKeys = List.generate(
    604,
    (_) => GlobalKey(),
  );

  var isDownloading; // Can be bool or url string based on legacy code
  Directory? appDir;
  
  Timer? _readingTimer;
  int _lastRecordedPage = -1;
  
  void _recordPageRead(int pageNumber) {
    final today = DateTime.now();
    final dateKey = DateFormat('yyyy-MM-dd').format(today);
    List<dynamic> existing = getValue("$dateKey-quran_reading-pages") ?? [];
    Set<int> pagesSet = existing.map((e) => int.tryParse(e.toString()) ?? -1).where((e) => e > 0).toSet();
    bool isNewForToday = !pagesSet.contains(pageNumber);
    if (!isNewForToday && _lastRecordedPage == pageNumber) return;
    if (isNewForToday) {
      pagesSet.add(pageNumber);
      updateValue("$dateKey-quran_reading-pages", pagesSet.toList());
      updateValue("$dateKey-quran_reading-count", pagesSet.length);
      final totalCount = getValue("quran_reading-totalCount") ?? 0;
      updateValue("quran_reading-totalCount", (totalCount as num) + 1);
      final goal = getValue("khatma_goal");
      if (goal is Map) {
        int startPage = (goal['startPage'] as int?) ?? 1;
        if (pageNumber >= startPage) {
          List<dynamic> khatmaPages = getValue("khatma_pages_read") ?? [];
          Set<int> khatmaSet = khatmaPages.map((e) => int.tryParse(e.toString()) ?? -1).where((e) => e >= startPage).toSet();
          if (!khatmaSet.contains(pageNumber)) {
            khatmaSet.add(pageNumber);
            updateValue("khatma_pages_read", khatmaSet.toList());
          }
        }
      }
    }
    _lastRecordedPage = pageNumber;
  }

  @override
  void initState() {
    super.initState();
    _initDir();
  }

  _initDir() async {
    appDir = await getTemporaryDirectory();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: backgroundColors[getValue("quranPageolorsIndex")],
      body: Stack(
        children: [
          ScrollablePositionedList.separated(
            itemCount: quran.totalPagesCount + 1,
            separatorBuilder: (context, index) {
              return Container();
            },
            itemScrollController: widget.itemScrollController,
            initialScrollIndex: getValue("lastRead"),
            itemPositionsListener: widget.itemPositionsListener,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Container(height: 0);
              }

              return BlocBuilder<QuranPagePlayerBloc, QuranPagePlayerState>(
                bloc: qurapPagePlayerBloc,
                builder: (context, state) {
                  // Common logic for rendering text spans
                  List<InlineSpan> buildSpans(
                      Map e, bool isPlaying, Map? currentVersePlaying) {
                    List<InlineSpan> spans = [];
                    for (var i = e["start"]; i <= e["end"]; i++) {
                      try {
                      if (i == 1) {
                        try {
                          spans.add(WidgetSpan(
                              child:
                                  HeaderWidget(e: e, jsonData: widget.jsonData)));
                        } catch (e2) {
                          debugPrint("Header failed ${e["surah"]}:$i - $e2");
                        }
                        if (index != 187 && index != 1) {
                          try {
                            spans.add(WidgetSpan(
                                child: Basmallah(
                                    index: getValue("quranPageolorsIndex"))));
                          } catch (e2) {
                            debugPrint("Basmallah failed $index - $e2");
                          }
                        }
                        if (index == 187 || index == 1) {
                          spans.add(WidgetSpan(child: Container(height: 10.h)));
                        }
                      }

                      bool isHighlighted = isPlaying &&
                          (currentVersePlaying != null &&
                              i == currentVersePlaying["verseNumber"] &&
                              e["surah"] ==
                                  (state is QuranPagePlayerPlaying
                                      ? state.suraNumber
                                      : -1));

                      spans.add(TextSpan(
                          recognizer: LongPressGestureRecognizer()
                            ..onLongPress = () {
                              widget.onShowAyahOptions(index, e["surah"], i);
                            }
                            ..onLongPressDown = (_) {
                              setState(() {
                                selectedSpan = " ${e["surah"]}$i";
                              });
                            }
                            ..onLongPressUp = () {
                              setState(() {
                                selectedSpan = "";
                              });
                            }
                            ..onLongPressCancel = () => setState(() {
                                  selectedSpan = "";
                                }),
                          text: (() {
                            try {
                              return quran.getVerse(e["surah"], i);
                            } catch (e2) {
                              debugPrint("getVerse failed ${e["surah"]}:$i - $e2");
                              return "";
                            }
                          })(),
                          style: TextStyle(
                              color: primaryColors[
                                  getValue("quranPageolorsIndex")],
                              fontSize:
                                  getValue("verseByVerseFontSize").toDouble(),
                              fontFamily: getValue("selectedFontFamily"),
                              fontWeight: (getValue("quranBoldLevel") ?? 0) == 1 ? FontWeight.w600 : FontWeight.normal,
                                                shadows: (getValue("quranBoldLevel") ?? 0) == 1 ? [Shadow(color: primaryColors[getValue("quranPageolorsIndex")].withOpacity(0.3), blurRadius: 0, offset: const Offset(0.4, 0.4))] : null,
                              backgroundColor: isHighlighted
                                  ? highlightColors[getValue("quranPageolorsIndex")]
                                      .withValues(alpha: .28)
                                  : (widget.bookmarks.any((b) =>
                                          b["suraNumber"] == e["surah"] &&
                                          b["verseNumber"] == i)
                                      ? Color(int.parse("0x${widget.bookmarks.firstWhere((b) => b["suraNumber"] == e["surah"] && b["verseNumber"] == i)["color"]}"))
                                          .withValues(alpha: .19)
                                      : widget.shouldHighlightText &&
                                              (() { try { return quran.getVerse(e["surah"], i) == widget.highlightVerse; } catch (_) { return false; } })()
                                          ? highlightColors[getValue(
                                                  "quranPageolorsIndex")]
                                              .withValues(alpha: .25)
                                          : selectedSpan == " ${e["surah"]}$i"
                                              ? highlightColors[getValue(
                                                      "quranPageolorsIndex")]
                                                  .withValues(alpha: .25)
                                              : Colors.transparent))));

                      spans.add(TextSpan(
                          text: " ${convertToArabicNumber((i).toString())} ",
                          style: TextStyle(
                              fontSize: 24.sp,
                              color: widget.isVerseStarred(e["surah"], i)
                                  ? Colors.amber
                                  : secondaryColors[
                                      getValue("quranPageolorsIndex")],
                              fontFamily:
                                  "KFGQPC Uthmanic Script HAFS Regular")));

                      if (widget.bookmarks.any((b) =>
                          b["suraNumber"] == e["surah"] &&
                          b["verseNumber"] == i)) {
                        try {
                          spans.add(WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Icon(Icons.bookmark,
                                  color: Color(int.parse(
                                      "0x${widget.bookmarks.firstWhere((b) => b["suraNumber"] == e["surah"] && b["verseNumber"] == i)["color"]}")))));
                        } catch (e2) {
                          debugPrint("Bookmark icon failed ${e["surah"]}:$i - $e2");
                        }
                      }

                      try {
                        spans.add(WidgetSpan(
                            child: Divider(
                                color: Colors.grey.withValues(alpha: .2))));

                        spans.add(WidgetSpan(
                            child: SizedBox(
                                width: double.infinity,
                                child: Directionality(
                                    textDirection: widget
                                                .translationDataList[getValue(
                                                    "indexOfTranslationInVerseByVerse")]
                                                .typeInNativeLanguage ==
                                            "العربية"
                                        ? m.TextDirection.rtl
                                        : m.TextDirection.ltr,
                                    child: Builder(builder: (context) {
                                      try {
                                        String translation = get_translation_data
                                            .getVerseTranslationForVerseByVerse(
                                                widget.dataOfCurrentTranslation,
                                                e["surah"],
                                                i,
                                                widget.translationDataList[getValue(
                                                    "indexOfTranslationInVerseByVerse")]);
                                        if (translation.contains(">")) {
                                          try {
                                            return Html(data: translation, style: {
                                              '*': Style(
                                                  fontFamily: 'cairo',
                                                  fontSize: FontSize(14.sp),
                                                  lineHeight: LineHeight(1.7.sp))
                                            });
                                          } catch (e2) {
                                            debugPrint("Html failed ${e["surah"]}:$i - $e2");
                                            return Text(translation,
                                                style: TextStyle(
                                                    color: primaryColors[getValue("quranPageolorsIndex")],
                                                    fontSize: 14.sp));
                                          }
                                        } else {
                                          return Text(translation,
                                              style: TextStyle(
                                                  color: primaryColors[getValue(
                                                      "quranPageolorsIndex")],
                                                  fontFamily: widget
                                                              .translationDataList[
                                                                  getValue(
                                                                          "indexOfTranslationInVerseByVerse") ??
                                                                      0]
                                                              .typeInNativeLanguage ==
                                                          "العربية"
                                                      ? "cairo"
                                                      : "roboto",
                                                  fontSize: 14.sp));
                                        }
                                      } catch (e2) {
                                        debugPrint("Translation failed ${e["surah"]}:$i - $e2");
                                        return const SizedBox.shrink();
                                      }
                                    })))));
                      } catch (e2) {
                        debugPrint("Translation block failed ${e["surah"]}:$i - $e2");
                      }

                      spans.add(WidgetSpan(
                          child: Divider(
                              height: 15.h,
                              color:
                                  primaryColors[getValue("quranPageolorsIndex")]
                                      .withValues(alpha: .3))));
                      } catch (e2) {
                        debugPrint("Ayah ${e["surah"]}:$i failed - $e2");
                      }
                    }
                    return spans;
                  }

                  Widget buildContent(
                      int? currentVerseNumber, int? currentSura) {
                    return VisibilityDetector(
                      key: Key(index.toString()),
                      onVisibilityChanged: (info) {
                        if (info.visibleFraction == 1) {
                          widget.onPageChanged(index);
                          
                          // --- إضافة التتبع الجديدة ---
                          _readingTimer?.cancel(); // إلغاء عداد الصفحة السابقة فوراً
                          _readingTimer = Timer(const Duration(seconds: 3), () {
                            _recordPageRead(index);
                          });
                        }
                      },
                      child: Column(
                        children: [
                          Directionality(
                              textDirection: m.TextDirection.rtl,
                              child: Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 20.0.w, vertical: 26.h),
                                  child: SizedBox(
                                      width: double.infinity,
                                      child: RichText(
                                          key: richTextKeys[index - 1],
                                          textDirection: m.TextDirection.rtl,
                                          textAlign: TextAlign.right,
                                          text: TextSpan(
                                              locale: const Locale("ar"),
                                              children: quran
                                                  .getPageData(index)
                                                  .expand((e) {
                                                final isPlaying =
                                                    currentVerseNumber !=
                                                            null &&
                                                        currentSura != null;
                                                final current = isPlaying
                                                    ? {
                                                        "verseNumber":
                                                            currentVerseNumber,
                                                        "surah": currentSura
                                                      }
                                                    : null;
                                                return buildSpans(
                                                  e,
                                                  isPlaying,
                                                  current,
                                                );
                                              }).toList()))))),
                          const SizedBox(height: 20),
                          _buildTranslationSelector(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    );
                  }

                  if (state is QuranPagePlayerPlaying) {
                    return StreamBuilder<int?>(
                      stream: state.audioIndexStream,
                      builder: (context, snapshot) {
                        final currentIndex =
                            snapshot.data ?? state.initialIndex;
                        final currentVerseNumber = currentIndex + 1;
                        return buildContent(
                          currentVerseNumber,
                          state.suraNumber,
                        );
                      },
                    );
                  }

                  return buildContent(null, null);
                },
              );
            },
          ),
          Padding(
            padding: EdgeInsets.only(top: 28.0.h),
            child: Container(
              height: 45.h,
              color: Colors.transparent,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: (screenSize.width * .27).w,
                    child: Row(
                      children: [
                        IconButton(
                            onPressed: widget.onBack,
                            icon: Icon(Icons.arrow_back_ios,
                                size: 24.sp,
                                color: primaryColors[
                                    getValue("quranPageolorsIndex")]))
                      ],
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTranslationSelector() {
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.0.w),
        child: EasyContainer(
            color: Colors.transparent,
            elevation: 0,
            onTap: () {
              showMaterialModalBottomSheet(
                  enableDrag: true,
                  backgroundColor:
                      backgroundColors[getValue("quranPageolorsIndex")],
                  context: context,
                  builder: (context) {
                    return SizedBox(
                        height: MediaQuery.of(context).size.height * .7,
                        child: SingleChildScrollView(
                            child: Column(children: [
                          Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text("Select Translation",
                                  style: TextStyle(
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColors[
                                          getValue("quranPageolorsIndex")]))),
                          SizedBox(
                              height: MediaQuery.of(context).size.height * .65,
                              child: ListView.builder(
                                  itemCount: widget.translationDataList.length,
                                  itemBuilder: (context, i) {
                                    return Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: EasyContainer(
                                            color: secondaryColors[getValue(
                                                    "quranPageolorsIndex")]
                                                .withValues(alpha: .1),
                                            onTap: () async {
                                              if (widget.translationDataList[i]
                                                      .url ==
                                                  null) {
                                                updateValue(
                                                    "indexOfTranslationInVerseByVerse",
                                                    i);
                                                setstatter(() {});
                                                Navigator.pop(context);
                                              } else {
                                                // Check if file exists
                                                bool exists = File(
                                                        "${appDir!.path}/${widget.translationDataList[i].typeText}.json")
                                                    .existsSync();
                                                if (exists) {
                                                  updateValue(
                                                      "indexOfTranslationInVerseByVerse",
                                                      i);
                                                  setstatter(() {});
                                                  Navigator.pop(context);
                                                } else {
                                                  // Download logic
                                                  setState(() {
                                                    isDownloading = widget
                                                        .translationDataList[i]
                                                        .url;
                                                  });
                                                  try {
                                                    await Dio().download(
                                                        widget
                                                            .translationDataList[
                                                                i]
                                                            .url,
                                                        "${appDir!.path}/${widget.translationDataList[i].typeText}.json");
                                                    setState(() {
                                                      isDownloading = false;
                                                      updateValue(
                                                          "indexOfTranslationInVerseByVerse",
                                                          i);
                                                    });
                                                    Navigator.pop(context);
                                                  } catch (e) {
                                                    setState(() {
                                                      isDownloading = false;
                                                    });
                                                  }
                                                }
                                              }
                                            },
                                            child: Padding(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 18.0.w,
                                                    vertical: 2.h),
                                                child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                          widget
                                                              .translationDataList[
                                                                  i]
                                                              .typeTextInRelatedLanguage,
                                                          style: TextStyle(
                                                              color: primaryColors[
                                                                      getValue(
                                                                          "quranPageolorsIndex")]
                                                                  .withValues(
                                                                      alpha:
                                                                          .9),
                                                              fontSize: 14.sp)),
                                                      isDownloading !=
                                                              widget
                                                                  .translationDataList[
                                                                      i]
                                                                  .url
                                                          ? Icon(
                                                              (i == 0 || i == 1)
                                                                  ? MfgLabs.hdd
                                                                  : File("${appDir!.path}/${widget.translationDataList[i].typeText}.json")
                                                                          .existsSync()
                                                                      ? Icons
                                                                          .done
                                                                      : Icons
                                                                          .cloud_download,
                                                              color: Colors
                                                                  .blueAccent,
                                                              size: 18.sp)
                                                          : const CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              color: Colors
                                                                  .blueAccent)
                                                    ]))));
                                  }))
                        ])));
                  });
            },
            child: Container(
                width: MediaQuery.of(context).size.width,
                height: 40.h,
                decoration: BoxDecoration(
                    color: Colors.blueGrey.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14.0.w),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              widget
                                  .translationDataList[getValue(
                                          "indexOfTranslationInVerseByVerse") ??
                                      0]
                                  .typeTextInRelatedLanguage,
                              style: TextStyle(
                                  color: Colors.black,
                                  fontFamily: widget
                                              .translationDataList[getValue(
                                                      "indexOfTranslationInVerseByVerse") ??
                                                  0]
                                              .typeInNativeLanguage ==
                                          "العربية"
                                      ? "cairo"
                                      : "roboto")),
                          Icon(FontAwesome.ellipsis,
                              size: 24.sp,
                              color: secondaryColors[
                                  getValue("quranPageolorsIndex")])
                        ])))));
  }

  void setstatter(VoidCallback fn) {
    if (mounted) setState(fn);
  }
}
