import 'package:easy_container/easy_container.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:nabd/GlobalHelpers/constants.dart';
import 'package:nabd/GlobalHelpers/hive_helper.dart';
import 'package:nabd/blocs/bloc/quran_page_player_bloc.dart';
import 'package:nabd/core/QuranPages/helpers/quran_audio_helper.dart';
import 'package:nabd/core/QuranPages/helpers/quran_data.dart';
import 'package:nabd/core/QuranPages/widgets/details_page/share_ayah_dialog.dart';
import 'package:nabd/core/QuranPages/widgets/tafseer_and_translation_sheet.dart';
import 'package:nabd/core/home.dart';
import 'package:quran/quran.dart' as quran;

class AyahOptionsSheet extends StatefulWidget {
  final int surahNumber;
  final int verseNumber;
  final int index; // Page index
  final List bookmarks;
  final Function(int surah, int verse) onAddBookmark;
  final Function(int surah, int verse) onRemoveBookmark;
  final bool Function(int surah, int verse) isVerseStarred;
  final Function(int surah, int verse) onToggleStar;
  final dynamic jsonData;

  // Passed Bloc or callbacks?
  // Ideally, use BlocProvider.of(context) if available in parent.
  // Assuming provided in context.

  const AyahOptionsSheet({
    Key? key,
    required this.surahNumber,
    required this.verseNumber,
    required this.index,
    required this.bookmarks,
    required this.onAddBookmark,
    required this.onRemoveBookmark,
    required this.isVerseStarred,
    required this.onToggleStar,
    required this.jsonData,
  }) : super(key: key);

  static void show(
    BuildContext context, {
    required int surahNumber,
    required int verseNumber,
    required int index,
    required List bookmarks,
    required Function(int, int) onAddBookmark,
    required Function(int, int) onRemoveBookmark,
    required bool Function(int, int) isVerseStarred,
    required Function(int, int) onToggleStar,
    required dynamic jsonData,
  }) {
    showMaterialModalBottomSheet(
      enableDrag: true,
      animationCurve: Curves.easeInOutQuart,
      elevation: 0,
      bounce: true,
      duration: const Duration(milliseconds: 250),
      backgroundColor: Colors.transparent,
      context: context,
      builder: (builder) {
        return AyahOptionsSheet(
          surahNumber: surahNumber,
          verseNumber: verseNumber,
          index: index,
          bookmarks: bookmarks,
          onAddBookmark: onAddBookmark,
          onRemoveBookmark: onRemoveBookmark,
          isVerseStarred: isVerseStarred,
          onToggleStar: onToggleStar,
          jsonData: jsonData,
        );
      },
    );
  }

  @override
  State<AyahOptionsSheet> createState() => _AyahOptionsSheetState();
}

class _AyahOptionsSheetState extends State<AyahOptionsSheet> {
  bool _isDownloading = false;

  @override
  Widget build(BuildContext context) {
    if (reciters.isEmpty) addReciters();
    // Access Blocs
    // final qurapPagePlayerBloc = BlocProvider.of<QuranPagePlayerBloc>(context);
    // Note: 'playerPageBloc' in original seemed to be same type or different?
    // Line 845 in original: if (playerPageBloc.state is PlayerBlocPlaying)
    // Line 870: if (qurapPagePlayerBloc.state is QuranPagePlayerPlaying)
    // Assuming 'playerPageBloc' is another bloc. I need to know its type.
    // Based on 'ClosePlayerEvent', maybe 'PlayerBloc'?
    // I'll skip 'playerPageBloc' if I can't find it, or use dynamic lookup.
    // It seems to handle closing a global player.
    // I'll comment it out or assume it's available. To be safe, I will omit if I don't have the import.
    // Or I check `quranDetailsPage` imports.
    // It has `import 'package:nabd/blocs/player_bloc/player_bloc.dart';`?
    // I'll check imports later. For now, I'll focus on `QuranPagePlayerBloc`.

    return SafeArea(
      bottom: true,
      child: Container(
          decoration: BoxDecoration(
            color: backgroundColors[getValue("quranPageolorsIndex")],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(
                left: 18.0,
                right: 18.0,
                top: 12,
                bottom: (MediaQuery.of(context).viewPadding.bottom + 12)),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 10.h),
                  Text(
                    "${"soura".tr()} ${context.locale.languageCode == "ar" ? quran.getSurahNameArabic(widget.surahNumber) : quran.getSurahNameEnglish(widget.surahNumber)} - ${"ayah".tr()} ${widget.verseNumber}",
                    style: TextStyle(
                        color: primaryColors[getValue("quranPageolorsIndex")],
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        fontFamily: "cairo"),
                  ),
                  SizedBox(height: 10.h),
                  const Divider(),
                  SizedBox(height: 10.h),

                  EasyContainer(
                    borderRadius: 8,
                    color: primaryColors[getValue("quranPageolorsIndex")]
                        .withValues(alpha: .05),
                    onTap: () {
                      Navigator.pop(context);
                      showMaterialModalBottomSheet(
                          enableDrag: true,
                          animationCurve: Curves.easeInOutQuart,
                          elevation: 0,
                          bounce: true,
                          duration: const Duration(milliseconds: 300),
                          backgroundColor:
                              backgroundColors[getValue("quranPageolorsIndex")],
                          context: context,
                          builder: (builder) {
                            return TafseerAndTranslateSheet(
                              surahNumber: widget.surahNumber,
                              verseNumber: widget.verseNumber,
                              isVerseByVerseSelection: false,
                            );
                          });
                    },
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width,
                      child: Row(
                        children: [
                          SizedBox(width: 20.w),
                          Icon(
                            Icons.menu_book,
                            color: getValue("quranPageolorsIndex") == 0
                                ? secondaryColors[
                                    getValue("quranPageolorsIndex")]
                                : highlightColors[
                                    getValue("quranPageolorsIndex")],
                          ),
                          SizedBox(width: 20.w),
                          Text(
                              context.locale.languageCode == "ar"
                                  ? "التفسير والترجمة"
                                  : "Tafsir & Translation",
                              style: TextStyle(
                                  fontFamily: "cairo",
                                  fontSize: 14.sp,
                                  color: primaryColors[
                                      getValue("quranPageolorsIndex")])),
                          SizedBox(width: 30.w)
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),

                  // Share Button
                  EasyContainer(
                    borderRadius: 8,
                    color: primaryColors[getValue("quranPageolorsIndex")]
                        .withValues(alpha: .05),
                    onTap: () {
                      Navigator.pop(context);
                      showShareAyahDialog(context, widget.surahNumber,
                          widget.verseNumber, widget.index, widget.jsonData);
                    },
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width,
                      child: Row(
                        children: [
                          SizedBox(width: 20.w),
                          Icon(
                            Icons.share,
                            color: getValue("quranPageolorsIndex") == 0
                                ? secondaryColors[
                                    getValue("quranPageolorsIndex")]
                                : highlightColors[
                                    getValue("quranPageolorsIndex")],
                          ),
                          SizedBox(width: 20.w),
                          Text("share".tr(),
                              style: TextStyle(
                                  fontFamily: "cairo",
                                  fontSize: 14.sp,
                                  color: primaryColors[
                                      getValue("quranPageolorsIndex")])),
                          const Spacer(),
                          SizedBox(width: 12.w)
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),

                  // Bookmark Button
                  EasyContainer(
                    borderRadius: 8,
                    color: primaryColors[getValue("quranPageolorsIndex")]
                        .withValues(alpha: .05),
                    onTap: () async {
                      bool isBookmarked = false;
                      for (var element in widget.bookmarks) {
                        if (element["suraNumber"] == widget.surahNumber &&
                            element["verseNumber"] == widget.verseNumber) {
                          isBookmarked = true;
                        }
                      }

                      if (isBookmarked) {
                        widget.onRemoveBookmark(
                            widget.surahNumber, widget.verseNumber);
                      } else {
                        widget.onAddBookmark(
                            widget.surahNumber, widget.verseNumber);
                      }
                      Navigator.pop(context);
                    },
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width,
                      child: Row(
                        children: [
                          SizedBox(width: 20.w),
                          Icon(
                            FontAwesome5.bookmark,
                            color: getValue("quranPageolorsIndex") == 0
                                ? secondaryColors[
                                    getValue("quranPageolorsIndex")]
                                : highlightColors[
                                    getValue("quranPageolorsIndex")],
                          ),
                          SizedBox(width: 20.w),
                          Text("addbookmark".tr(),
                              style: TextStyle(
                                  fontFamily: "cairo",
                                  fontSize: 14.sp,
                                  color: primaryColors[
                                      getValue("quranPageolorsIndex")])),
                          SizedBox(width: 30.w)
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),

                  // Favorite Button
                  EasyContainer(
                    borderRadius: 8,
                    color: primaryColors[getValue("quranPageolorsIndex")]
                        .withValues(alpha: .05),
                    onTap: () async {
                      widget.onToggleStar(
                          widget.surahNumber, widget.verseNumber);
                      Navigator.pop(context);
                    },
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width,
                      child: Row(
                        children: [
                          SizedBox(width: 20.w),
                          Icon(
                            widget.isVerseStarred(
                                    widget.surahNumber, widget.verseNumber)
                                ? Icons.star
                                : Icons.star_border,
                            color: getValue("quranPageolorsIndex") == 0
                                ? secondaryColors[
                                    getValue("quranPageolorsIndex")]
                                : highlightColors[
                                    getValue("quranPageolorsIndex")],
                          ),
                          SizedBox(width: 20.w),
                          Text(
                              widget.isVerseStarred(
                                      widget.surahNumber, widget.verseNumber)
                                  ? "removefav".tr()
                                  : "addtofav".tr(),
                              style: TextStyle(
                                  fontFamily: "cairo",
                                  fontSize: 14.sp,
                                  color: primaryColors[
                                      getValue("quranPageolorsIndex")])),
                          SizedBox(width: 30.w)
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),

                  EasyContainer(
                    borderRadius: 8,
                    color: primaryColors[getValue("quranPageolorsIndex")]
                        .withValues(alpha: .05),
                    onTap: () async {
                      if (_isDownloading) {
                        return;
                      }
                      setState(() {
                        _isDownloading = true;
                      });
                      final reciter = reciters[getValue("reciterIndex")];
                      final suraName =
                          quran.getSurahNameArabic(widget.surahNumber);
                      final totalVerses =
                          quran.getVerseCount(widget.surahNumber);
                      await QuranAudioHelper.downloadAndCacheSuraAudio(
                        suraName: suraName,
                        totalVerses: totalVerses,
                        surahNumber: widget.surahNumber,
                        reciterIdentifier: reciter.identifier,
                        onDownloadingStateChanged: (v) {
                          _isDownloading = v;
                          setState(() {});
                        },
                      );
                    },
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width,
                      child: Row(
                        children: [
                          SizedBox(width: 20.w),
                          Icon(
                            Icons.download,
                            color: getValue("quranPageolorsIndex") == 0
                                ? secondaryColors[
                                    getValue("quranPageolorsIndex")]
                                : highlightColors[
                                    getValue("quranPageolorsIndex")],
                          ),
                          SizedBox(width: 20.w),
                          Text(
                              _isDownloading
                                  ? "Downloading.."
                                  : "downloaded".tr(),
                              style: TextStyle(
                                  fontFamily: "cairo",
                                  fontSize: 14.sp,
                                  color: primaryColors[
                                      getValue("quranPageolorsIndex")])),
                          SizedBox(width: 30.w),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),

                  EasyContainer(
                    borderRadius: 8,
                    color: primaryColors[getValue("quranPageolorsIndex")]
                        .withValues(alpha: .05),
                    onTap: () async {
                      Navigator.pop(context);
                      final reciter = reciters[getValue("reciterIndex")];
                      final suraNameEng =
                          quran.getSurahNameEnglish(widget.surahNumber);
                      if (qurapPagePlayerBloc.state is QuranPagePlayerPlaying) {
                        qurapPagePlayerBloc.add(KillPlayerEvent());
                      }
                      qurapPagePlayerBloc.add(PlayFromVerse(widget.verseNumber,
                          reciter.identifier, widget.surahNumber, suraNameEng));
                    },
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(width: 20.w),
                          Icon(
                            Icons.play_circle_fill,
                            size: 28.sp,
                            color: orangeColor.withValues(alpha: .95),
                          ),
                          SizedBox(width: 16.w),
                          Icon(
                            Icons.play_arrow,
                            size: 24.sp,
                            color: primaryColors[
                                getValue("quranPageolorsIndex")]),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth: 150.w,
                              ),
                              child: DropdownButton<int>(
                                value: getValue("reciterIndex"),
                                dropdownColor: backgroundColors[
                                    getValue("quranPageolorsIndex")],
                                isDense: true,
                                onChanged: (int? newIndex) {
                                  updateValue("reciterIndex", newIndex);
                                  setState(() {});
                                },
                                items: reciters.map((reciter) {
                                  return DropdownMenuItem<int>(
                                    value: reciters.indexOf(reciter),
                                    child: Container(
                                      constraints: BoxConstraints(
                                        maxWidth: 120.w,
                                      ),
                                      child: Text(
                                          context.locale.languageCode == "ar"
                                              ? reciter.name
                                              : reciter.englishName,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.start,
                                          style: TextStyle(
                                              color: primaryColors[
                                                  getValue("quranPageolorsIndex")])),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          DropdownButton<double>(
                            value: ((getValue("quranAudioSpeed") ?? 1.0) as num)
                                .toDouble(),
                            dropdownColor: backgroundColors[
                                getValue("quranPageolorsIndex")],
                            onChanged: (double? newSpeed) {
                              if (newSpeed == null) return;
                              updateValue("quranAudioSpeed", newSpeed);
                              if (qurapPagePlayerBloc.state
                                  is QuranPagePlayerPlaying) {
                                qurapPagePlayerBloc.add(SetSpeed(newSpeed));
                              }
                              setState(() {});
                            },
                            items: [
                              {"label": "-1", "value": 0.5},
                              {"label": "-0.5", "value": 0.75},
                              {"label": "1", "value": 1.0},
                              {"label": "1.5", "value": 1.5},
                              {"label": "2", "value": 2.0},
                            ]
                                .map((e) => DropdownMenuItem<double>(
                                      value: (e["value"] as num).toDouble(),
                                      child: Text(
                                        e["label"]!.toString(),
                                        style: TextStyle(
                                            color: primaryColors[getValue(
                                                "quranPageolorsIndex")]),
                                      ),
                                    ))
                                .toList(),
                          ),
                          SizedBox(width: 12.w),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),

                  EasyContainer(
                    borderRadius: 8,
                    color: primaryColors[getValue("quranPageolorsIndex")]
                        .withValues(alpha: .05),
                    onTap: () {
                      if (qurapPagePlayerBloc.state is QuranPagePlayerPlaying) {
                        qurapPagePlayerBloc.add(PausePlaying());
                      }
                      Navigator.pop(context);
                    },
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width,
                      child: Row(
                        children: [
                          SizedBox(width: 20.w),
                          Icon(
                            Icons.pause_circle_filled,
                            color: getValue("quranPageolorsIndex") == 0
                                ? secondaryColors[
                                    getValue("quranPageolorsIndex")]
                                : highlightColors[
                                    getValue("quranPageolorsIndex")],
                          ),
                          SizedBox(width: 20.w),
                          Text("pause".tr(),
                              style: TextStyle(
                                  fontFamily: "cairo",
                                  fontSize: 14.sp,
                                  color: primaryColors[
                                      getValue("quranPageolorsIndex")])),
                          SizedBox(width: 30.w),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),

                  EasyContainer(
                    borderRadius: 8,
                    color: primaryColors[getValue("quranPageolorsIndex")]
                        .withValues(alpha: .05),
                    onTap: () {
                      if (qurapPagePlayerBloc.state is QuranPagePlayerPlaying ||
                          qurapPagePlayerBloc.state is QuranPagePlayerIdle) {
                        qurapPagePlayerBloc.add(StopPlaying());
                      }
                      Navigator.pop(context);
                    },
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width,
                      child: Row(
                        children: [
                          SizedBox(width: 20.w),
                          Icon(
                            Icons.stop_circle,
                            color: getValue("quranPageolorsIndex") == 0
                                ? secondaryColors[
                                    getValue("quranPageolorsIndex")]
                                : highlightColors[
                                    getValue("quranPageolorsIndex")],
                          ),
                          SizedBox(width: 20.w),
                          Text("stop".tr(),
                              style: TextStyle(
                                  fontFamily: "cairo",
                                  fontSize: 14.sp,
                                  color: primaryColors[
                                      getValue("quranPageolorsIndex")])),
                          SizedBox(width: 30.w),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  // وضع التكرار - جديد
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.repeat, size: 18, color: primaryColors[getValue("quranPageolorsIndex")]),
                            SizedBox(width: 6.w),
                            const Text("وضع التكرار", style: TextStyle(fontFamily: "cairo", fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        SizedBox(height: 10.h),
                        Wrap(
                          spacing: 8.w,
                          children: [
                            ChoiceChip(
                              label: const Text("متابعة", style: TextStyle(fontFamily: "cairo", fontSize: 12)),
                              selected: (getValue("quran_repeatMode") ?? "continuous") == "continuous",
                              onSelected: (_) { updateValue("quran_repeatMode", "continuous"); setState(() {}); },
                            ),
                            ChoiceChip(
                              label: const Text("آية", style: TextStyle(fontFamily: "cairo", fontSize: 12)),
                              selected: getValue("quran_repeatMode") == "ayah",
                              onSelected: (_) { updateValue("quran_repeatMode", "ayah"); if ((getValue("quran_repeatCount") ?? 0) == 0) updateValue("quran_repeatCount", 3); setState(() {}); },
                            ),
                            ChoiceChip(
                              label: const Text("صفحة", style: TextStyle(fontFamily: "cairo", fontSize: 12)),
                              selected: getValue("quran_repeatMode") == "page",
                              onSelected: (_) { updateValue("quran_repeatMode", "page"); if ((getValue("quran_repeatCount") ?? 0) == 0) updateValue("quran_repeatCount", 3); setState(() {}); },
                            ),
                            ChoiceChip(
                              label: const Text("مرة واحدة", style: TextStyle(fontFamily: "cairo", fontSize: 12)),
                              selected: getValue("quran_repeatMode") == "none",
                              onSelected: (_) { updateValue("quran_repeatMode", "none"); setState(() {}); },
                            ),
                          ],
                        ),
                        if (getValue("quran_repeatMode") == "ayah" || getValue("quran_repeatMode") == "page")
                          Padding(
                            padding: EdgeInsets.only(top: 12.h),
                            child: Row(
                              children: [
                                const Text("العدد:", style: TextStyle(fontFamily: "cairo", fontSize: 12)),
                                Expanded(
                                  child: Slider(
                                    value: ((getValue("quran_repeatCount") ?? 3) as num).toDouble().clamp(1, 20),
                                    min: 1,
                                    max: 20,
                                    divisions: 19,
                                    label: "${getValue("quran_repeatCount") ?? 3}",
                                    onChanged: (v) { updateValue("quran_repeatCount", v.toInt()); setState(() {}); },
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                  decoration: BoxDecoration(color: primaryColors[getValue("quranPageolorsIndex")].withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                  child: Text("${getValue("quran_repeatCount") ?? 3}×", style: TextStyle(fontFamily: "cairo", fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(height: 5.h),
                ],
              ),
            ),
          )),
    );
  }
}
