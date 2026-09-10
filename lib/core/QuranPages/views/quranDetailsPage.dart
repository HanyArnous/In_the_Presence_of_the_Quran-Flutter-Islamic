import 'dart:async';
import 'dart:convert';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:nabd/core/QuranPages/helpers/translation/translationdata.dart';
import 'package:nabd/core/QuranPages/helpers/quran_page_utils.dart';
import 'package:nabd/core/QuranPages/widgets/details_page/quran_page_view.dart';
import 'package:nabd/core/QuranPages/widgets/details_page/quran_vertical_view.dart';
import 'package:nabd/core/QuranPages/widgets/details_page/quran_verse_by_verse_view.dart';
import 'package:nabd/core/QuranPages/helpers/quran_data.dart';
import 'package:path_provider/path_provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nabd/GlobalHelpers/constants.dart';
import 'package:nabd/GlobalHelpers/hive_helper.dart';

import 'package:nabd/core/QuranPages/widgets/details_page/ayah_options_sheet.dart';

import 'package:screenshot/screenshot.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:nabd/blocs/bloc/quran_page_player_bloc.dart';
import 'package:nabd/core/home.dart';
import 'package:quran/quran.dart' as quran;

class QuranReadingPage extends StatefulWidget {
  const QuranReadingPage({super.key});

  @override
  State<QuranReadingPage> createState() => _QuranReadingPageState();
}

class _QuranReadingPageState extends State<QuranReadingPage> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class QuranDetailsPage extends StatefulWidget {
  int pageNumber;
  var jsonData;
  var quarterJsonData;
  var shouldHighlightText;
  var highlightVerse;
  var shouldHighlightSura;
  // var highlighSurah;
  QuranDetailsPage(
      {super.key,
      required this.pageNumber,
      required this.jsonData,
      required this.shouldHighlightText,
      required this.highlightVerse,
      required this.quarterJsonData,
      required this.shouldHighlightSura});

  @override
  State<QuranDetailsPage> createState() => QuranDetailsPageState();
}

class QuranDetailsPageState extends State<QuranDetailsPage> {
  final ScrollController _scrollController = ScrollController();
  // var controller;
  final ItemScrollController itemScrollController = ItemScrollController();
  final ItemPositionsListener itemPositionsListener =
      ItemPositionsListener.create();

  // final bool _isScrolling = false;

  // List bookmarks = [
  //   getValue("greenBookmark"),
  //   getValue("redBookmark"),
  //   getValue("blueBookmark"),
  // ];

  // reloadBookmarks() {
  //   setState(() {
  //     bookmarks = [
  //       getValue("greenBookmark"),
  //       getValue("redBookmark"),
  //       getValue("blueBookmark"),
  //     ];
  //   });
  // }
  List bookmarks = [];
  fetchBookmarks() {
    bookmarks = json.decode(getValue("bookmarks"));
    setState(() {});
    // print(bookmarks);
  }

  var dataOfCurrentTranslation;
  getTranslationData() async {
    if (getValue("indexOfTranslationInVerseByVerse") > 1) {
      File file = File(
          "${appDir!.path}/${translationDataList[getValue("indexOfTranslationInVerseByVerse")].typeText}.json");

      String jsonData = await file.readAsString();
      dataOfCurrentTranslation = json.decode(jsonData);
    }
    setState(() {});
  }

  var currentVersePlaying;
  // late final ScrollController _controller;
  int index = 0;
  setIndex() {
    setState(() {
      index = widget.pageNumber;
    });
  }

  double valueOfSlider = 0;

  Directory? appDir;
  StreamSubscription<int?>? _audioIndexSubscription;
  initialize() async {
    appDir = await getTemporaryDirectory();
    getTranslationData();
    if (mounted) {
      setState(() {});
    }
  }

  int playIndexPage = 0;

  @override
  void initState() {
    fetchBookmarks();
    //var formatter = NumberFormat('', 'ar');print("ننتاا");
    initialize();
    // reloadBookmarks();
    // verticalScrollController.addListener((event) {
    //   _handleCallbackEvent(event.direction, event.success);
    // });
    setIndex();

    changeHighlightSurah();
    // _model = ScrollListener.initialise(controller);

    highlightVerseFunction();
    _scrollController.addListener(_scrollListener);

    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _pageController = PageController(initialPage: index);
    _pageController.addListener(_pagecontroller_scrollListner);
    // assignPageNumberToIndex+1();
    // addTextSpans(); // TODO: implement initState
    WakelockPlus.enable();
    updateValue("lastRead", widget.pageNumber);
    addReciters(); // addValueToFontSize();
    _loadStarredVerses();
    // updateValue("quranPageolorsIndex", 0);
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        precacheImage(const AssetImage('assets/images/Basmala.png'), context);
        precacheImage(const AssetImage('assets/images/888-02.png'), context);
        final String baseFontFamily =
            (getValue("selectedFontFamily") ?? "UthmanicHafs13").toString();
        final double baseFontSize =
            ((getValue("pageViewFontSize") ?? 22) as num).toDouble();
        final tp = TextPainter(
          textDirection: TextDirection.rtl,
          text: TextSpan(
            text: "بِسْمِ اللّٰهِ الرَّحْمٰنِ الرَّحِيمِ",
            style:
                TextStyle(fontFamily: baseFontFamily, fontSize: baseFontSize),
          ),
        );
        tp.layout();
      } catch (_) {}
    });
  }

  void _scrollListener() {
    if (_scrollController.position.isScrollingNotifier.value &&
        selectedSpan != "") {
      setState(() {
        selectedSpan = "";
      });
    } else {}
  }

  void _pagecontroller_scrollListner() {
    if (_pageController.position.isScrollingNotifier.value &&
        selectedSpan != "") {
      setState(() {
        selectedSpan = "";
      });
    } else {}
  }

  var highlightVerse;
  var shouldHighlightText;
  changeHighlightSurah() async {
    await Future.delayed(const Duration(seconds: 2));
    widget.shouldHighlightSura = false;
  }

  highlightVerseFunction() {
    setState(() {
      shouldHighlightText = widget.shouldHighlightText;
    });
    if (widget.shouldHighlightText) {
      setState(() {
        highlightVerse = widget.highlightVerse;
      });

      Timer.periodic(const Duration(milliseconds: 400), (timer) {
        if (mounted) {
          setState(() {
            shouldHighlightText = false;
          });
        }
        Timer(const Duration(milliseconds: 200), () {
          if (mounted) {
            setState(() {
              shouldHighlightText = true;
            });
          }
          if (timer.tick == 4) {
            if (mounted) {
              setState(() {
                highlightVerse = "";

                shouldHighlightText = false;
              });
            }
            timer.cancel();
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _audioIndexSubscription?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    super.dispose();
  }

  int total = 0;
  int total1 = 0;
  int total3 = 0;
  int getTotalCharacters(List<String> stringList) {
    return QuranPageUtils.getTotalCharacters(stringList);
  }

  checkIfAyahIsAStartOfSura() {}
  String? swipeDirection;
  late PageController _pageController;
  Duration get _pageTransitionDuration {
    return const Duration(milliseconds: 140);
  }

  var english = RegExp(r'[a-zA-Z]');

  String selectedSpan = "";

  ScreenshotController screenshotController = ScreenshotController();

  double currentHeight = 2.0;
  // double currentWordSpacing = 0.0;
  double currentLetterSpacing = 0.0;

  List<GlobalKey> richTextKeys = List.generate(
    604, // Replace with the number of pages in your PageView
    (_) => GlobalKey(),
  );
  GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final double baseFontSize =
        ((getValue("pageViewFontSize") ?? 22) as num).toDouble();
    final int currentThemeIndex = (getValue("quranPageolorsIndex") ?? 0) is int
        ? (getValue("quranPageolorsIndex") ?? 0)
        : 0;
    return BlocListener<QuranPagePlayerBloc, QuranPagePlayerState>(
      bloc: qurapPagePlayerBloc,
      listener: (context, state) {
        _audioIndexSubscription?.cancel();
        if (state is QuranPagePlayerPlaying &&
            getValue("alignmentType") == "pageview") {
          _audioIndexSubscription =
              state.audioIndexStream.listen((currentIndex) {
            if (currentIndex == null) {
              return;
            }
            final verseNumber = currentIndex + 1;
            final targetPage = quran.getPageNumber(
              state.suraNumber,
              verseNumber,
            );
            if (targetPage < 1 || targetPage > quran.totalPagesCount) {
              return;
            }
            if (!_pageController.hasClients) {
              return;
            }
            final currentPage = _pageController.page?.round() ?? index;
            if (currentPage == targetPage) {
              return;
            }
            _pageController.animateToPage(
              targetPage,
              duration: _pageTransitionDuration,
              curve: Curves.easeOutCubic,
            );
          });
        }
      },
      child: WillPopScope(
        onWillPop: () async {
          if (scaffoldKey.currentState?.isEndDrawerOpen == true) {
            Navigator.of(context).pop();
            return false;
          }
          return true;
        },
        child: Scaffold(
          key: scaffoldKey,
          endDrawer: SafeArea(
            child: Container(
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width * .7,
              color: getValue("darkMode") == true
                  ? quranPagesColorDark
                  : quranPagesColorLight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      "إعدادات صفحة المصحف",
                      style: TextStyle(
                        fontFamily: "cairo",
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ListView(
                        children: [
                          const SizedBox(height: 0),
                          const Text(
                            "ألوان الصفحة",
                            style: TextStyle(
                              fontFamily: "cairo",
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 70,
                            width: MediaQuery.of(context).size.width,
                            child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: backgroundColors.length,
                                itemBuilder: (a, i) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4.0),
                                    child: GestureDetector(
                                      onTap: () {
                                        updateValue("quranPageolorsIndex", i);
                                        setState(() {});
                                      },
                                      child: SizedBox(
                                        width: 90,
                                        height: 40,
                                        child: Stack(
                                          children: [
                                            Center(
                                              child: Container(
                                                width: 90,
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  boxShadow: [
                                                    BoxShadow(
                                                        blurRadius: 1,
                                                        color: Colors.grey
                                                            .withOpacity(.5))
                                                  ],
                                                  shape: BoxShape.rectangle,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  color: backgroundColors[i],
                                                ),
                                              ),
                                            ),
                                            Center(
                                              child: Container(
                                                width: 22,
                                                height: 22,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: primaryColors[i],
                                                  border: Border.all(
                                                    color: currentThemeIndex ==
                                                            i
                                                        ? Colors.black
                                                            .withValues(
                                                                alpha: .3)
                                                        : Colors.transparent,
                                                    width: 2,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            "سُمك الخط",
                            style: TextStyle(
                              fontFamily: "cairo",
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "شكل العرض",
                                style: TextStyle(
                                  fontFamily: "cairo",
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        updateValue("alignmentType", "pageview");
                                        setState(() {});
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: getValue("alignmentType") == "pageview"
                                              ? primaryColors[getValue("quranPageolorsIndex") ?? 0]
                                              : Colors.grey[100],
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: getValue("alignmentType") == "pageview"
                                                ? primaryColors[getValue("quranPageolorsIndex") ?? 0]
                                                : Colors.grey[300]!,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Icon(
                                              Icons.auto_stories,
                                              color: getValue("alignmentType") == "pageview"
                                                  ? Colors.white
                                                  : Colors.grey[600],
                                              size: 24,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              "صفحة",
                                              style: TextStyle(
                                                fontFamily: "cairo",
                                                fontSize: 12,
                                                color: getValue("alignmentType") == "pageview"
                                                    ? Colors.white
                                                    : Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        updateValue("alignmentType", "verticalview");
                                        setState(() {});
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: getValue("alignmentType") == "verticalview"
                                              ? primaryColors[getValue("quranPageolorsIndex") ?? 0]
                                              : Colors.grey[100],
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: getValue("alignmentType") == "verticalview"
                                                ? primaryColors[getValue("quranPageolorsIndex") ?? 0]
                                                : Colors.grey[300]!,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Icon(
                                              Icons.view_column,
                                              color: getValue("alignmentType") == "verticalview"
                                                  ? Colors.white
                                                  : Colors.grey[600],
                                              size: 24,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              "عمودي",
                                              style: TextStyle(
                                                fontFamily: "cairo",
                                                fontSize: 12,
                                                color: getValue("alignmentType") == "verticalview"
                                                    ? Colors.white
                                                    : Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: InkWell(
                                  onTap: () {
                                    final current =
                                        (getValue("quranBoldLevel") ?? 0)
                                            as int;
                                    updateValue(
                                        "quranBoldLevel", current == 1 ? 0 : 1);
                                    setState(() {});
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: ((getValue("quranBoldLevel") ??
                                                  0) ==
                                              1)
                                          ? primaryColors[
                                              getValue("quranPageolorsIndex")]
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: primaryColors[
                                              getValue("quranPageolorsIndex")]),
                                    ),
                                    child: const Text("عريض",
                                        style: TextStyle(fontFamily: "cairo")),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          backgroundColor: Colors.transparent,
          body: Builder(builder: (context) {
            if (getValue("alignmentType") == "pageview") {
              return QuranPageView(
                pageController: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    selectedSpan = "";
                  });
                  this.index = index;
                  updateValue("lastRead", index);
                },
                onBack: () {
                  if (scaffoldKey.currentState?.isEndDrawerOpen == true) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context, rootNavigator: true).maybePop();
                  }
                },
                onSettings: () {
                  scaffoldKey.currentState?.openEndDrawer();
                },
                onShowAyahOptions: (p, s, v) => showAyahOptionsSheet(p, s, v),
                bookmarks: bookmarks,
                jsonData: widget.jsonData,
                quarterJsonData: widget.quarterJsonData,
                shouldHighlightText: widget.shouldHighlightText,
                highlightVerse: widget.highlightVerse,
                index: index,
              );
            } else if (getValue("alignmentType") == "verticalview") {
              return QuranVerticalView(
                itemScrollController: itemScrollController,
                itemPositionsListener: itemPositionsListener,
                onPageChanged: (i) {
                  index = i;
                  updateValue("lastRead", i);
                },
                bookmarks: bookmarks,
                jsonData: widget.jsonData,
                quarterJsonData: widget.quarterJsonData,
                shouldHighlightText: widget.shouldHighlightText,
                highlightVerse: widget.highlightVerse,
                onShowAyahOptions: (p, s, v) => showAyahOptionsSheet(p, s, v),
              );
            } else {
              // العرض الافتراضي - عرض صفحة
              return QuranPageView(
                pageController: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    selectedSpan = "";
                  });
                  this.index = index;
                  updateValue("lastRead", index);
                },
                onBack: () {
                  if (scaffoldKey.currentState?.isEndDrawerOpen == true) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context, rootNavigator: true).maybePop();
                  }
                },
                onSettings: () {
                  scaffoldKey.currentState?.openEndDrawer();
                },
                onShowAyahOptions: (p, s, v) => showAyahOptionsSheet(p, s, v),
                bookmarks: bookmarks,
                jsonData: widget.jsonData,
                quarterJsonData: widget.quarterJsonData,
                shouldHighlightText: widget.shouldHighlightText,
                highlightVerse: widget.highlightVerse,
                index: index,
              );
            }
          }),
        ),
      ),
    );
  }

  showAyahOptionsSheet(index, surahNumber, verseNumber) {
    AyahOptionsSheet.show(
      context,
      surahNumber: surahNumber,
      verseNumber: verseNumber,
      index: index,
      bookmarks: bookmarks,
      jsonData: widget.jsonData,
      onAddBookmark: (s, v) async {
        List<String> colorOptions = [
          "0xFF2196F3",
          "0xFFF44336",
          "0xFFE91E63",
          "0xFF9C27B0",
          "0xFF3F51B5"
        ];
        String selectedColor = colorOptions[0];
        bookmarks.add({
          "suraNumber": s,
          "verseNumber": v,
          "color": selectedColor.replaceAll("0x", "")
        });
        updateValue("bookmarks", json.encode(bookmarks));
        setState(() {});
      },
      onRemoveBookmark: (s, v) {
        bookmarks.removeWhere((element) =>
            element["suraNumber"] == s && element["verseNumber"] == v);
        updateValue("bookmarks", json.encode(bookmarks));
        setState(() {});
      },
      isVerseStarred: isVerseStarred,
      onToggleStar: (s, v) {
        if (isVerseStarred(s, v)) {
          removeStarredVerse(s, v);
        } else {
          addStarredVerse(s, v);
        }
        setState(() {});
      },
    );
  }

  bool showSuraHeader = true;
  bool addAppSlogan = true;

  Set<String> starredVerses = {};

  Future<void> _loadStarredVerses() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? savedData = prefs.getString("starredVerses");
    if (savedData != null && savedData.isNotEmpty) {
      starredVerses = Set<String>.from(json.decode(savedData));
      if (mounted) {
        setState(() {});
      }
    }
  }

  addStarredVerse(int surahNumber, int verseNumber) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // Retrieve the data as a string, not as a map
    final String? savedData = prefs.getString("starredVerses");

    if (savedData != null) {
      // Decode the JSON string to a List<String>
      starredVerses = Set<String>.from(json.decode(savedData));
    }

    final verseKey = "$surahNumber-$verseNumber"; // Create a unique key
    starredVerses.add(verseKey);

    final jsonData = json.encode(
        starredVerses.toList()); // Convert Set to List for serialization
    prefs.setString("starredVerses", jsonData);
    Fluttertoast.showToast(msg: "Added to Starred verses");
  }

  removeStarredVerse(int surahNumber, int verseNumber) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // Retrieve the data as a string, not as a map
    final String? savedData = prefs.getString("starredVerses");

    if (savedData != null) {
      // Decode the JSON string to a List<String>
      starredVerses = Set<String>.from(json.decode(savedData));
    }

    final verseKey = "$surahNumber-$verseNumber"; // Create the same unique key
    starredVerses.remove(verseKey);

    final jsonData = json.encode(
        starredVerses.toList()); // Convert Set to List for serialization
    prefs.setString("starredVerses", jsonData);
    Fluttertoast.showToast(msg: "Removed from Starred verses");
  }

  bool isVerseStarred(int surahNumber, int verseNumber) {
    final verseKey = "$surahNumber-$verseNumber";
    return starredVerses.contains(verseKey);
  }

  bool isDownloading = false;
}
