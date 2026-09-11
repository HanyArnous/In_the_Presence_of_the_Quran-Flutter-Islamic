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
import 'package:nabd/core/QuranPages/widgets/bismallah.dart';
import 'package:nabd/core/QuranPages/widgets/header_widget.dart';
import 'package:nabd/core/QuranPages/widgets/details_page/quran_page_header.dart';
import 'package:quran/quran.dart' as quran;
import 'dart:async';

class QuranPageView extends StatefulWidget {
  final PageController pageController;
  final Function(int) onPageChanged;
  final Function() onBack;
  final Function() onSettings;
  final Function(int, int, int) onShowAyahOptions;
  final List bookmarks;
  final dynamic jsonData;
  final dynamic quarterJsonData;
  final bool shouldHighlightText;
  final dynamic highlightVerse;
  final int index;

  const QuranPageView({
    Key? key,
    required this.pageController,
    required this.onPageChanged,
    required this.onBack,
    required this.onSettings,
    required this.onShowAyahOptions,
    required this.bookmarks,
    required this.jsonData,
    required this.quarterJsonData,
    required this.shouldHighlightText,
    required this.highlightVerse,
    required this.index,
  }) : super(key: key);

  @override
  State<QuranPageView> createState() => _QuranPageViewState();
}

class _QuranPageViewState extends State<QuranPageView> {
  String selectedSpan = "";
  Timer? _readingTimer;
  int _lastRecordedPage = -1;
  List<GlobalKey> richTextKeys = List.generate(
    604,
    (_) => GlobalKey(),
  );
  final TransformationController _transformController =
      TransformationController();
  bool isZoomed = false;
  final Map<String, String> _qcfCache = {};
  final Map<int, TextSpan> _pageSpanCache = {};
  String? _settingsSignature;
  String? _lastHighlightKey;
  Set<String> _bookmarksCache = {};

  @override
  void initState() {
    super.initState();
    _updateBookmarksCache();
    widget.pageController.addListener(_pageControllerScrollListener);
    _transformController.addListener(_onTransformChanged);
    Future.microtask(() => _warmNextPrevPages(widget.index));
  }

  void _updateBookmarksCache() {
    _bookmarksCache = widget.bookmarks.map((e) {
      return "${e["suraNumber"]}-${e["verseNumber"]}";
    }).toSet();
  }

  String _getQcfText(int surah, int verse) {
    final key = "$surah-$verse";
    final cached = _qcfCache[key];
    if (cached != null) return cached;
    try {
      final s = quran.getVerseQCF(surah, verse).replaceAll(' ', '');
      _qcfCache[key] = s;
      return s;
    } catch (e) {
      debugPrint("QCF _getQcfText failed $surah:$verse - $e");
      return "";
    }
  }

  void _recordPageRead(int pageNumber) {
    final today = DateTime.now();
    final dateKey = DateFormat('yyyy-MM-dd').format(today);
    // تخزين الصفحات المقروءة كـ Set يومي لمنع العد عند المرور السريع وتكرار نفس الصفحة
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
      // الختمة: لا تسجل تلقائياً - فقط عبر زر التأكيد في وضع الختمة
    }
    _lastRecordedPage = pageNumber;
  }

  TextSpan _composePageSpan(int index) {
    final int colorIndex = ((getValue("quranPageolorsIndex") ?? 0) is int)
        ? (getValue("quranPageolorsIndex") ?? 0)
        : 0;
    final double baseFontSize =
        ((getValue("pageViewFontSize") ?? 22) as num).toDouble();
    final String baseFontFamily =
        (getValue("selectedFontFamily") ?? "UthmanicHafs13").toString();
    final int level = ((getValue("quranBoldLevel") ?? 0) is int)
        ? (getValue("quranBoldLevel") ?? 0)
        : 0;

    final List<InlineSpan> children = quran.getPageData(index).expand((e) {
      List<InlineSpan> spans = [];
      for (var i = e["start"]; i <= e["end"]; i++) {
        try {
          if (i == 1) {
            try {
              spans.add(WidgetSpan(
                child: HeaderWidget(e: e, jsonData: widget.jsonData),
              ));
            } catch (e2) {
              debugPrint("HeaderWidget failed ${e["surah"]}:$i - $e2");
            }
            if (index != 187 && index != 1) {
              try {
                spans.add(WidgetSpan(
                    child:
                        Basmallah(index: getValue("quranPageolorsIndex"))));
              } catch (e2) {
                debugPrint("Basmallah failed $index - $e2");
              }
            }
            if (index == 187) {
              spans.add(const WidgetSpan(child: SizedBox(height: 10)));
            }
          }

          final String s = _getQcfText(e["surah"], i);
          String text;
          if (i == e["start"]) {
            if (s.isEmpty) {
              text = "";
            } else if (s.length == 1) {
              text = s;
            } else {
              text = "${s.substring(0, 1)}\u200A${s.substring(1)}";
            }
          } else {
            text = s;
          }
          final bool isBookmarked =
              _bookmarksCache.contains("${e["surah"]}-$i");

          Color textColor;
          if (isBookmarked) {
            try {
              final match = widget.bookmarks.where((element) =>
                  element["suraNumber"] == e["surah"] &&
                  element["verseNumber"] == i);
              if (match.isNotEmpty) {
                textColor = Color(
                    int.parse("0x${match.first["color"]}"));
              } else {
                textColor = primaryColors[colorIndex];
              }
            } catch (_) {
              textColor = primaryColors[colorIndex];
            }
          } else {
            textColor = primaryColors[colorIndex];
          }

          Color bgColor;
          try {
            bgColor = widget.shouldHighlightText
                ? (quran.getVerse(e["surah"], i) == widget.highlightVerse
                    ? highlightColors[colorIndex].withValues(alpha: .28)
                    : (selectedSpan == "${e["surah"]}-$i"
                        ? highlightColors[colorIndex]
                            .withValues(alpha: .18)
                        : Colors.transparent))
                : (selectedSpan == "${e["surah"]}-$i"
                    ? highlightColors[colorIndex].withValues(alpha: .18)
                    : Colors.transparent);
          } catch (_) {
            bgColor = Colors.transparent;
          }

          spans.add(TextSpan(
            recognizer: LongPressGestureRecognizer()
              ..onLongPress = () {
                widget.onShowAyahOptions(index, e["surah"], i);
              }
              ..onLongPressDown = (details) {
                selectedSpan = "${e["surah"]}-$i";
                setState(() {});
              }
              ..onLongPressUp = () {
                selectedSpan = "";
                setState(() {});
              }
              ..onLongPressCancel = () {
                selectedSpan = "";
                setState(() {});
              },
            text: text,
            semanticsLabel: "${e["surah"]}-$i",
            style: TextStyle(
              color: textColor,
              height: (index == 1 || index == 2) ? 2.h : 1.95.h,
              letterSpacing: 0.w,
              wordSpacing: 0,
              fontFamily: "QCF_P${index.toString().padLeft(3, "0")}",
              fontSize: index == 1 || index == 2
                  ? 28.sp
                  : index == 145 || index == 201
                      ? index == 532 || index == 533
                          ? 22.5.sp
                          : 22.4.sp
                      : 22.9.sp,
              fontWeight: level <= 0 ? FontWeight.normal : FontWeight.w600,
              shadows: level <= 0 ? null : [Shadow(color: textColor.withOpacity(0.3), blurRadius: 0, offset: const Offset(0.5, 0.5))],
              backgroundColor: bgColor,
            ),
            children: const [],
          ));

          if (isBookmarked) {
            try {
              final match = widget.bookmarks.where((element) =>
                  element["suraNumber"] == e["surah"] &&
                  element["verseNumber"] == i);
              if (match.isNotEmpty) {
                spans.add(WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Icon(
                    Icons.bookmark,
                    color: Color(int.parse("0x${match.first["color"]}")),
                  ),
                ));
              }
            } catch (e2) {
              debugPrint("Bookmark icon failed ${e["surah"]}:$i - $e2");
            }
          }
        } catch (e2) {
          debugPrint("Ay ah ${e["surah"]}:$i page $index failed - $e2");
        }
      }
      return spans;
    }).toList();

    return TextSpan(
      style: TextStyle(
        color: primaryColors[colorIndex],
        fontSize: baseFontSize,
        fontFamily: baseFontFamily,
        fontWeight: level <= 0 ? FontWeight.normal : FontWeight.w600,
        shadows: level <= 0 ? null : [Shadow(color: primaryColors[colorIndex].withOpacity(0.25), blurRadius: 0, offset: const Offset(0.4, 0.4))],
      ),
      children: children,
    );
  }

  void _ensurePageSpanCached(int index) {
    if (index < 1 || index > quran.totalPagesCount) return;
    if (_pageSpanCache[index] != null) return;
    _pageSpanCache[index] = _composePageSpan(index);
  }

  TextSpan _applySelectedHighlight(TextSpan base, String? key, int colorIndex,
      {double alpha = .18}) {
    if (key == null || key.isEmpty) return base;
    final List<InlineSpan>? children = base.children;
    if (children == null || children.isEmpty) return base;
    final List<InlineSpan> updated = children.map((c) {
      if (c is TextSpan && c.semanticsLabel == key) {
        final TextStyle style = (c.style ?? const TextStyle()).copyWith(
          backgroundColor: highlightColors[colorIndex].withValues(alpha: alpha),
        );
        return TextSpan(
          text: c.text,
          style: style,
          children: c.children,
          recognizer: c.recognizer,
          semanticsLabel: c.semanticsLabel,
          locale: c.locale,
        );
      }
      return c;
    }).toList();
    return TextSpan(style: base.style, children: updated, locale: base.locale);
  }

  TextSpan _applyTwoHighlights(
    TextSpan base,
    String? keyA,
    double alphaA,
    String? keyB,
    double alphaB,
    int colorIndex,
  ) {
    final List<InlineSpan>? children = base.children;
    if (children == null || children.isEmpty) return base;
    final List<InlineSpan> updated = children.map((c) {
      if (c is! TextSpan) return c;
      final String? label = c.semanticsLabel;
      final bool matchA = keyA != null && keyA.isNotEmpty && label == keyA;
      final bool matchB = keyB != null && keyB.isNotEmpty && label == keyB;
      if (!matchA && !matchB) return c;
      final double alpha = matchA && matchB
          ? (alphaA >= alphaB ? alphaA : alphaB)
          : (matchA ? alphaA : alphaB);
      final TextStyle style = (c.style ?? const TextStyle()).copyWith(
        backgroundColor: highlightColors[colorIndex].withValues(alpha: alpha),
      );
      return TextSpan(
        text: c.text,
        style: style,
        children: c.children,
        recognizer: c.recognizer,
        semanticsLabel: c.semanticsLabel,
        locale: c.locale,
      );
    }).toList();
    return TextSpan(style: base.style, children: updated, locale: base.locale);
  }

  void _onTransformChanged() {
    final double scale = _transformController.value.storage[0];
    final bool newIsZoomed = scale > 1.01;
    if (newIsZoomed != isZoomed) {
      setState(() {
        isZoomed = newIsZoomed;
      });
    }
  }

  @override
  void didUpdateWidget(covariant QuranPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookmarks != widget.bookmarks) {
      _updateBookmarksCache();
      _pageSpanCache.clear();
    }
  }

  void _pageControllerScrollListener() {
    if (widget.pageController.position.isScrollingNotifier.value &&
        selectedSpan != "") {
      setState(() {
        selectedSpan = "";
      });
    }
  }

  void _warmNextPrevPages(int currentIndex) {
    // تسخين الصفحات المجاورة بشكل أوسع لأداء أفضل
    for (final neighbor in [currentIndex - 2, currentIndex - 1, currentIndex + 1, currentIndex + 2]) {
      if (neighbor < 1 || neighbor > quran.totalPagesCount) continue;
      final data = quran.getPageData(neighbor);
      for (final e in data) {
        for (var i = e["start"]; i <= e["end"]; i++) {
          try {
            _getQcfText(e["surah"], i);
          } catch (_) {}
        }
      }
      _ensurePageSpanCached(neighbor);
    }
  }

  void _evictFarPages(int center) {
    // زيادة نطاق الحفظ في الذاكرة لأداء أفضل
    final int min = center - 8;
    final int max = center + 8;
    _pageSpanCache.removeWhere((key, value) => key < min || key > max);
  }

  @override
  void dispose() {
    _readingTimer?.cancel();
    widget.pageController.removeListener(_pageControllerScrollListener);
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int colorIndex = ((getValue("quranPageolorsIndex") ?? 0) is int)
        ? (getValue("quranPageolorsIndex") ?? 0)
        : 0;
    final double baseFontSize =
        ((getValue("pageViewFontSize") ?? 22) as num).toDouble();
    final String baseFontFamily =
        (getValue("selectedFontFamily") ?? "UthmanicHafs13").toString();
    final int boldLevel = ((getValue("quranBoldLevel") ?? 0) is int)
        ? (getValue("quranBoldLevel") ?? 0)
        : 0;
    final String signature =
        "$colorIndex|$baseFontSize|$baseFontFamily|$boldLevel";
    if (_settingsSignature != signature) {
      _settingsSignature = signature;
      _pageSpanCache.clear();
    }
    return PageView.builder(
      scrollDirection: Axis.horizontal,
      allowImplicitScrolling: true,
      pageSnapping: true,
      physics: isZoomed
          ? const NeverScrollableScrollPhysics()
          : const PageScrollPhysics(parent: ClampingScrollPhysics()),
      onPageChanged: (a) {
        setState(() {
          selectedSpan = "";
        });
        widget.onPageChanged(a);
        _warmNextPrevPages(a);
        _evictFarPages(a);
        
        _readingTimer?.cancel();
        _readingTimer = Timer(const Duration(seconds: 3), () {
          _recordPageRead(a);
        });
      },
      controller: widget.pageController,
      reverse: context.locale.languageCode == "ar" ? false : true,
      itemCount: quran.totalPagesCount + 1,
      itemBuilder: (context, index) {
        bool isEvenPage = index.isEven;

        if (index == 0) {
          return Container(
            color: const Color(0xffFFFCE7),
            child: Image.asset(
              "assets/images/quran.jpg",
              fit: BoxFit.fill,
            ),
          );
        }

        return Container(
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
              color: backgroundColors[colorIndex],
              border: Border.fromBorderSide(BorderSide(
                  color: primaryColors[colorIndex].withValues(alpha: .05)))),
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Padding(
                padding: EdgeInsets.only(right: 12.0.w, left: 12.w),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      QuranPageHeader(
                        index: index,
                        jsonData: widget.jsonData,
                        quarterJsonData: widget.quarterJsonData,
                        onBack: widget.onBack,
                        onSettings: widget.onSettings,
                      ),
                      SizedBox(height: 8.h),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Container(
                          decoration: BoxDecoration(
                            color: secondaryColors[colorIndex]
                                .withValues(alpha: .25),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: primaryColors[colorIndex]
                                  .withValues(alpha: .35),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: .1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.symmetric(
                              horizontal: 6.w, vertical: 4.h),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: primaryColors[colorIndex]
                                      .withValues(alpha: .1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: IconButton(
                                  onPressed: () {
                                    final scale =
                                        _transformController.value.storage[0];
                                    final target = (scale * 1.15).clamp(1.0, 4.0);
                                    _transformController.value =
                                        Matrix4.identity()..scale(target, target, target);
                                  },
                                  icon: const Icon(Icons.zoom_in),
                                  color: primaryColors[colorIndex],
                                  iconSize: 22.sp,
                                  padding: EdgeInsets.all(4.w),
                                ),
                              ),
                              SizedBox(width: 4.w),
                              Container(
                                decoration: BoxDecoration(
                                  color: primaryColors[colorIndex]
                                      .withValues(alpha: .1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: IconButton(
                                  onPressed: () {
                                    final scale =
                                        _transformController.value.storage[0];
                                    final target = (scale / 1.15).clamp(1.0, 4.0);
                                    _transformController.value =
                                        Matrix4.identity()..scale(target, target, target);
                                  },
                                  icon: const Icon(Icons.zoom_out),
                                  color: primaryColors[colorIndex],
                                  iconSize: 22.sp,
                                  padding: EdgeInsets.all(4.w),
                                ),
                              ),
                              SizedBox(width: 4.w),
                              Container(
                                decoration: BoxDecoration(
                                  color: primaryColors[colorIndex]
                                      .withValues(alpha: .1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: IconButton(
                                  onPressed: () {
                                    _transformController.value =
                                        Matrix4.identity();
                                  },
                                  icon: const Icon(Icons.refresh),
                                  color: primaryColors[colorIndex],
                                  iconSize: 22.sp,
                                  padding: EdgeInsets.all(4.w),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      BlocBuilder<QuranPagePlayerBloc, QuranPagePlayerState>(
                        bloc: qurapPagePlayerBloc,
                        builder: (context, state) {
                          if (state is QuranPagePlayerPlaying) {
                            return Directionality(
                              textDirection: m.TextDirection.rtl,
                              child: StreamBuilder<int?>(
                                stream: state.audioIndexStream.distinct(),
                                builder: (context, snapshot) {
                                  final currentIndex =
                                      snapshot.data ?? state.initialIndex;
                                  final currentVerseNumber = currentIndex + 1;

                                  // Update last highlight key for fallback
                                  _lastHighlightKey =
                                      "${state.suraNumber}-$currentVerseNumber";
                                
                                  return Padding(
                                    padding: const EdgeInsets.all(0.0),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: RepaintBoundary(
                                        child: InteractiveViewer(
                                          transformationController:
                                              _transformController,
                                          minScale: 1.0,
                                          maxScale: 4.0,
                                          // حصر الحركة داخل حدود الصفحة المكبرة فقط
                                          boundaryMargin: EdgeInsets.zero,
                                          clipBehavior: Clip.hardEdge,
                                          panEnabled: true,
                                          scaleEnabled: true,
                                          onInteractionEnd: (details) {
                                            if (_transformController.value.getMaxScaleOnAxis() <= 1.01) {
                                              setState(() => isZoomed = false);
                                            }
                                          },
                                          child: RichText(
                                            key: richTextKeys[index - 1],
                                            textDirection: m.TextDirection.rtl,
                                            textAlign: (index == 1 ||
                                                    index == 2 ||
                                                    index > 570)
                                                ? TextAlign.center
                                                : TextAlign.center,
                                            softWrap: true,
                                            locale: const Locale("ar"),
                                            text: (() {
                                              final composed =
                                                  _pageSpanCache[index] ??
                                                      _composePageSpan(index);
                                              _pageSpanCache[index] = composed;
                                              final String currentKey =
                                                  "${state.suraNumber}-$currentVerseNumber";
                                              return _applyTwoHighlights(
                                                composed,
                                                currentKey,
                                                .28,
                                                selectedSpan,
                                                .18,
                                                colorIndex,
                                              );
                                            })(),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          }

                          return Directionality(
                            textDirection: m.TextDirection.rtl,
                            child: Padding(
                              padding: const EdgeInsets.all(0.0),
                              child: SizedBox(
                                width: double.infinity,
                                child: RepaintBoundary(
                                  child: InteractiveViewer(
                                    transformationController:
                                        _transformController,
                                    minScale: 1.0,
                                    maxScale: 4.0,
                                    // حصر الحركة داخل حدود الصفحة المكبرة فقط
                                    boundaryMargin: EdgeInsets.zero,
                                    clipBehavior: Clip.hardEdge,
                                    panEnabled: true,
                                    scaleEnabled: true,
                                    onInteractionEnd: (details) {
                                      if (_transformController.value.getMaxScaleOnAxis() <= 1.01) {
                                        setState(() => isZoomed = false);
                                      }
                                    },
                                    child: RichText(
                                      key: richTextKeys[index - 1],
                                      textDirection: m.TextDirection.rtl,
                                      textAlign: (index == 1 ||
                                              index == 2 ||
                                              index > 570)
                                          ? TextAlign.center
                                          : TextAlign.center,
                                      softWrap: true,
                                      locale: const Locale("ar"),
                                      text: () {
                                        final cached = _pageSpanCache[index];
                                        final composed = cached ??
                                            (() {
                                              final s = _composePageSpan(index);
                                              _pageSpanCache[index] = s;
                                              return s;
                                            })();
                                        return _applyTwoHighlights(
                                          composed,
                                          _lastHighlightKey,
                                          .28,
                                          selectedSpan,
                                          .18,
                                          colorIndex,
                                        );
                                      }(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
