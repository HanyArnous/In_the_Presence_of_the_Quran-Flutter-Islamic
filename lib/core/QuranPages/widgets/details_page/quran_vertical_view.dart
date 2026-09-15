import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as m;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nabd/core/home.dart';
import 'package:nabd/GlobalHelpers/constants.dart';
import 'package:nabd/GlobalHelpers/hive_helper.dart';
import 'package:nabd/blocs/bloc/quran_page_player_bloc.dart';
import 'package:nabd/core/QuranPages/helpers/convertNumberToAr.dart';
import 'package:nabd/core/QuranPages/helpers/quran_page_utils.dart';
import 'package:nabd/core/QuranPages/widgets/bismallah.dart';
import 'package:nabd/core/QuranPages/widgets/header_widget.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran/quran.dart'; // For getJuzNumber
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'dart:async';

class QuranVerticalView extends StatefulWidget {
  final ItemScrollController itemScrollController;
  final ItemPositionsListener itemPositionsListener;
  final Function(int) onPageChanged;
  final List bookmarks;
  final dynamic jsonData;
  final dynamic quarterJsonData;
  final bool shouldHighlightText;
  final dynamic highlightVerse;
  final Function(int, int, int) onShowAyahOptions;
  final VoidCallback? onBack;
  final VoidCallback? onSettings;

  const QuranVerticalView({
    Key? key,
    required this.itemScrollController,
    required this.itemPositionsListener,
    required this.onPageChanged,
    required this.bookmarks,
    required this.jsonData,
    required this.quarterJsonData,
    required this.shouldHighlightText,
    required this.highlightVerse,
    required this.onShowAyahOptions,
    this.onBack,
    this.onSettings,
  }) : super(key: key);

  @override
  State<QuranVerticalView> createState() => _QuranVerticalViewState();
}

class _QuranVerticalViewState extends State<QuranVerticalView> {
  String selectedSpan = "";
  List<GlobalKey> richTextKeys = List.generate(
    604,
    (index) => GlobalKey(),
  );

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
    }
    _lastRecordedPage = pageNumber;
  }

  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _currentPage = (getValue("lastRead") is int ? getValue("lastRead") : 1);
    widget.itemPositionsListener.itemPositions.addListener(_onPositionsChanged);
  }

  @override
  void dispose() {
    try {
      widget.itemPositionsListener.itemPositions.removeListener(_onPositionsChanged);
    } catch (_) {}
    _readingTimer?.cancel();
    super.dispose();
  }

  void _onPositionsChanged() {
    try {
      final positions = widget.itemPositionsListener.itemPositions.value;
      if (positions.isEmpty) return;
      int min = positions.map((e) => e.index).reduce((a, b) => a < b ? a : b);
      if (min < 1) min = 1;
      if (min != _currentPage) {
        if (mounted) setState(() => _currentPage = min);
      }
    } catch (_) {}
  }

  Widget _buildVerticalHeader() {
    final int colorIndex = ((getValue("quranPageolorsIndex") ?? 0) is int) ? (getValue("quranPageolorsIndex") ?? 0) : 0;
    String surahName = "";
    try {
      if (widget.jsonData != null && _currentPage >= 1 && _currentPage <= quran.totalPagesCount) {
        final pd = quran.getPageData(_currentPage);
        final sn = pd[0]["surah"] as int;
        surahName = widget.jsonData[sn - 1]["name"].toString();
      }
    } catch (_) {}
    return Container(
      color: backgroundColors[colorIndex].withOpacity(0.97),
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: widget.onBack ?? () { if (Navigator.canPop(context)) Navigator.pop(context); },
              icon: Icon(Icons.arrow_back_ios, size: 20.sp, color: secondaryColors[colorIndex]),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (surahName.isNotEmpty)
                    Text(surahName, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(color: secondaryColors[colorIndex], fontFamily: "Taha", fontSize: 12.sp)),
                  Text("صفحة $_currentPage", style: TextStyle(color: secondaryColors[colorIndex].withOpacity(0.7), fontFamily: "cairo", fontSize: 9.sp)),
                ],
              ),
            ),
            IconButton(
              onPressed: widget.onSettings ?? () {},
              icon: Icon(Icons.settings, size: 22.sp, color: secondaryColors[colorIndex]),
              tooltip: "إعدادات",
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: backgroundColors[getValue("quranPageolorsIndex")],
      body: Stack(
        children: [
          ScrollablePositionedList.separated(
            itemCount: quran.totalPagesCount + 1,
            separatorBuilder: (context, index) {
              if (index == 0) return Container();
              return Container(
                color: secondaryColors[getValue("quranPageolorsIndex")]
                    .withValues(alpha: .45),
                width: double.infinity,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 77.0.w),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        QuranPageUtils.checkIfPageIncludesQuarterAndQuarterIndex(
                                        widget.quarterJsonData,
                                        quran.getPageData(index),
                                        indexes)
                                    .includesQuarter ==
                                true
                            ? "${"page".tr()} ${(index).toString()} | ${(QuranPageUtils.checkIfPageIncludesQuarterAndQuarterIndex(widget.quarterJsonData, quran.getPageData(index), indexes).quarterIndex + 1) == 1 ? "" : "${(QuranPageUtils.checkIfPageIncludesQuarterAndQuarterIndex(widget.quarterJsonData, quran.getPageData(index), indexes).quarterIndex).toString()}/${4.toString()}"} ${"hizb".tr()} ${(QuranPageUtils.checkIfPageIncludesQuarterAndQuarterIndex(widget.quarterJsonData, quran.getPageData(index), indexes).hizbIndex + 1).toString()} | ${"juz".tr()}: ${getJuzNumber(quran.getPageData(index)[0]["surah"], quran.getPageData(index)[0]["start"])} "
                            : "${"page".tr()} $index | ${"juz".tr()}: ${getJuzNumber(quran.getPageData(index)[0]["surah"], quran.getPageData(index)[0]["start"])}",
                        style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: backgroundColors[
                                getValue("quranPageolorsIndex")]),
                      ),
                      Text(
                        widget.jsonData[
                            quran.getPageData(index)[0]["surah"] - 1]["name"],
                        style: TextStyle(
                            fontSize: 12.sp,
                            fontFamily: "taha",
                            fontWeight: FontWeight.bold,
                            color: backgroundColors[
                                getValue("quranPageolorsIndex")]),
                      )
                    ],
                  ),
                ),
              );
            },
            itemScrollController: widget.itemScrollController,
            initialScrollIndex: getValue("lastRead"),
            itemPositionsListener: widget.itemPositionsListener,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Container(
                  color: const Color(0xffFFFCE7),
                  child: Image.asset(
                    "assets/images/quran.jpg",
                    fit: BoxFit.fill,
                  ),
                );
              }

              return BlocBuilder<QuranPagePlayerBloc, QuranPagePlayerState>(
                bloc: qurapPagePlayerBloc,
                builder: (context, state) {
                  if (state is QuranPagePlayerPlaying) {
                    return Column(
                      children: [
                        StreamBuilder<int?>(
                          stream: state.audioIndexStream,
                          builder: (context, snapshot) {
                            final currentIndex =
                                snapshot.data ?? state.initialIndex;
                            final currentVerseNumber = currentIndex + 1;

                            return Directionality(
                              textDirection: m.TextDirection.rtl,
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 20.0.w, vertical: 26.h),
                                child: VisibilityDetector(
                                  key: Key(index.toString()),
                                  onVisibilityChanged: (VisibilityInfo info) {
                                    if (info.visibleFraction == 1) {
                                      widget.onPageChanged(index);
                                      
                                      // --- إضافة التتبع الجديدة ---
                                      _readingTimer?.cancel(); // إلغاء عداد الصفحة السابقة فوراً
                                      _readingTimer = Timer(const Duration(seconds: 3), () {
                                        _recordPageRead(index);
                                      });
                                    }
                                  },
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: RichText(
                                      key: richTextKeys[index - 1],
                                      textDirection: m.TextDirection.rtl,
                                      textAlign: TextAlign.center,
                                      softWrap: true,
                                      text: TextSpan(
                                        locale: const Locale("ar"),
                                        children: quran
                                            .getPageData(index)
                                            .expand((e) {
                                          List<InlineSpan> spans = [];
                                          for (var i = e["start"];
                                              i <= e["end"];
                                              i++) {
                                            try {
                                            if (i == 1) {
                                              spans.add(WidgetSpan(
                                                child: HeaderWidget(
                                                    e: e,
                                                    jsonData: widget.jsonData),
                                              ));

                                              if (index != 187 && index != 1) {
                                                spans.add(WidgetSpan(
                                                    child: Basmallah(
                                                  index: getValue(
                                                      "quranPageolorsIndex"),
                                                )));
                                              }
                                              if (index == 187 || index == 1) {
                                                spans.add(WidgetSpan(
                                                    child: Container(
                                                  height: 10.h,
                                                )));
                                              }
                                            }

                                            spans.add(TextSpan(
                                              locale: const Locale("ar"),
                                              recognizer:
                                                  LongPressGestureRecognizer()
                                                    ..onLongPress = () {
                                                      widget.onShowAyahOptions(
                                                          index, e["surah"], i);
                                                    }
                                                    ..onLongPressDown =
                                                        (details) {
                                                      setState(() {
                                                        selectedSpan =
                                                            " ${e["surah"]}$i";
                                                      });
                                                    }
                                                    ..onLongPressUp = () {
                                                      setState(() {
                                                        selectedSpan = "";
                                                      });
                                                    }
                                                    ..onLongPressCancel =
                                                        () => setState(() {
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
                                                color: primaryColors[getValue(
                                                    "quranPageolorsIndex")],
                                                fontSize: getValue(
                                                        "verticalViewFontSize")
                                                    .toDouble(),
                                                fontFamily: getValue(
                                                    "selectedFontFamily"),
                                                fontWeight: (getValue("quranBoldLevel") ?? 0) == 1 ? FontWeight.w600 : FontWeight.normal,
                                                shadows: (getValue("quranBoldLevel") ?? 0) == 1 ? [Shadow(color: primaryColors[getValue("quranPageolorsIndex")].withOpacity(0.3), blurRadius: 0, offset: const Offset(0.4, 0.4))] : null,
                                                backgroundColor: widget.bookmarks
                                                        .where((element) =>
                                                            element["suraNumber"] ==
                                                                e["surah"] &&
                                                            element["verseNumber"] ==
                                                                i)
                                                        .isNotEmpty
                                                    ? Color(int.parse("0x${widget.bookmarks.where((element) => element["suraNumber"] == e["surah"] && element["verseNumber"] == i).first["color"]}"))
                                                        .withValues(alpha: .19)
                                                    : (i == currentVerseNumber &&
                                                            e["surah"] ==
                                                                state
                                                                    .suraNumber)
                                                        ? highlightColors[getValue("quranPageolorsIndex")]
                                                            .withValues(
                                                                alpha: .28)
                                                        : widget
                                                                .shouldHighlightText
                                                            ? (() { try { return quran.getVerse(e["surah"], i) == widget.highlightVerse; } catch (_) { return false; } })()
                                                                ? highlightColors[getValue("quranPageolorsIndex")]
                                                                    .withValues(
                                                                        alpha:
                                                                            .25)
                                                                : selectedSpan == " ${e["surah"]}$i"
                                                                    ? highlightColors[getValue("quranPageolorsIndex")].withValues(alpha: .25)
                                                                    : Colors.transparent
                                                            : selectedSpan == " ${e["surah"]}$i"
                                                                ? highlightColors[getValue("quranPageolorsIndex")].withValues(alpha: .25)
                                                                : Colors.transparent,
                                              ),
                                              children: [
                                                TextSpan(
                                                  text:
                                                      " ${convertToArabicNumber((i).toString())} ",
                                                  style: TextStyle(
                                                    color: secondaryColors[getValue(
                                                        "quranPageolorsIndex")],
                                                    fontFamily:
                                                        "KFGQPC Uthmanic Script HAFS Regular",
                                                  ),
                                                ),
                                              ],
                                            ));
                                            if (widget.bookmarks
                                                .where((element) =>
                                                    element["suraNumber"] ==
                                                        e["surah"] &&
                                                    element["verseNumber"] == i)
                                                .isNotEmpty) {
                                              spans.add(WidgetSpan(
                                                  alignment:
                                                      PlaceholderAlignment
                                                          .middle,
                                                  child: Icon(
                                                    Icons.bookmark,
                                                    color: Color(int.parse(
                                                        "0x${widget.bookmarks.where((element) => element["suraNumber"] == e["surah"] && element["verseNumber"] == i).first["color"]}")),
                                                  )));
                                            }
                                            } catch (e2) {
                                              debugPrint("Ayah iteration failed");
                                            }
                                          }
                                          return spans;
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  }

                  return VisibilityDetector(
                    key: Key(index.toString()),
                    onVisibilityChanged: (VisibilityInfo info) {
                      if (info.visibleFraction == 1) {
                        widget.onPageChanged(index);
                        
                        // --- إضافة التتبع الجديدة ---
                        _readingTimer?.cancel(); // إلغاء عداد الصفحة السابقة فوراً
                        _readingTimer = Timer(const Duration(seconds: 3), () {
                          _recordPageRead(index);
                        });
                      }
                    },
                    child: Directionality(
                      textDirection: m.TextDirection.rtl,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.0.w,
                          vertical: 26.h,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: RichText(
                            key: richTextKeys[index - 1],
                            textDirection: m.TextDirection.rtl,
                            textAlign: TextAlign.center,
                            softWrap: true,
                            text: TextSpan(
                              locale: const Locale("ar"),
                              children: quran.getPageData(index).expand((e) {
                                List<InlineSpan> spans = [];
                                for (var i = e["start"]; i <= e["end"]; i++) {
                                  try {
                                  if (i == 1) {
                                    try {
                                      spans.add(WidgetSpan(
                                        child: HeaderWidget(
                                          e: e,
                                          jsonData: widget.jsonData,
                                        ),
                                      ));
                                    } catch (e2) {
                                      debugPrint("Header failed ${e["surah"]}:$i - $e2");
                                    }

                                    if (index != 187 && index != 1) {
                                      try {
                                        spans.add(WidgetSpan(
                                            child: Basmallah(
                                          index: getValue("quranPageolorsIndex"),
                                        )));
                                      } catch (e2) {
                                        debugPrint("Basmallah failed $index - $e2");
                                      }
                                    }
                                    if (index == 187 || index == 1) {
                                      spans.add(WidgetSpan(
                                          child: Container(
                                        height: 10.h,
                                      )));
                                    }
                                  }

                                  spans.add(TextSpan(
                                    locale: const Locale("ar"),
                                    recognizer: LongPressGestureRecognizer()
                                      ..onLongPress = () {
                                        widget.onShowAyahOptions(
                                            index, e["surah"], i);
                                      }
                                      ..onLongPressDown = (details) {
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
                                      fontSize: getValue("verticalViewFontSize")
                                          .toDouble(),
                                      fontFamily:
                                          getValue("selectedFontFamily"),
                                      fontWeight: (getValue("quranBoldLevel") ?? 0) == 1 ? FontWeight.w600 : FontWeight.normal,
                                                shadows: (getValue("quranBoldLevel") ?? 0) == 1 ? [Shadow(color: primaryColors[getValue("quranPageolorsIndex")].withOpacity(0.3), blurRadius: 0, offset: const Offset(0.4, 0.4))] : null,
                                      backgroundColor: widget.bookmarks
                                              .where((element) =>
                                                  element["suraNumber"] == e["surah"] &&
                                                  element["verseNumber"] == i)
                                              .isNotEmpty
                                          ? Color(int.parse("0x${widget.bookmarks.where((element) => element["suraNumber"] == e["surah"] && element["verseNumber"] == i).first["color"]}"))
                                              .withValues(alpha: .19)
                                          : widget.shouldHighlightText
                                              ? (() { try { return quran.getVerse(e["surah"], i) == widget.highlightVerse; } catch (_) { return false; } })()
                                                  ? highlightColors[getValue("quranPageolorsIndex")]
                                                      .withValues(alpha: .25)
                                                  : selectedSpan ==
                                                          " ${e["surah"]}$i"
                                                      ? highlightColors[getValue("quranPageolorsIndex")]
                                                          .withValues(
                                                              alpha: .25)
                                                      : Colors.transparent
                                              : selectedSpan ==
                                                      " ${e["surah"]}$i"
                                                  ? highlightColors[getValue(
                                                          "quranPageolorsIndex")]
                                                      .withValues(alpha: .25)
                                                  : Colors.transparent,
                                    ),
                                    children: [
                                      TextSpan(
                                        text:
                                            " ${convertToArabicNumber((i).toString())} ",
                                        style: TextStyle(
                                          color: secondaryColors[
                                              getValue("quranPageolorsIndex")],
                                          fontFamily:
                                              "KFGQPC Uthmanic Script HAFS Regular",
                                        ),
                                      ),
                                    ],
                                  ));
                                  if (widget.bookmarks
                                      .where((element) =>
                                          element["suraNumber"] == e["surah"] &&
                                          element["verseNumber"] == i)
                                      .isNotEmpty) {
                                    try {
                                      spans.add(WidgetSpan(
                                          alignment: PlaceholderAlignment.middle,
                                          child: Icon(
                                            Icons.bookmark,
                                            color: Color(int.parse(
                                                "0x${widget.bookmarks.where((element) => element["suraNumber"] == e["surah"] && element["verseNumber"] == i).first["color"]}")),
                                          )));
                                    } catch (e2) {
                                      debugPrint("Bookmark icon failed ${e["surah"]}:$i - $e2");
                                    }
                                  }
                                  } catch (e2) {
                                    debugPrint("Ayah ${e["surah"]}:$i failed - $e2");
                                  }
                                }
                                return spans;
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildVerticalHeader(),
          ),
        ],
      ),
    );
  }
}
