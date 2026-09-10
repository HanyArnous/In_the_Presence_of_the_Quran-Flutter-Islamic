import 'package:easy_container/easy_container.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nabd/GlobalHelpers/constants.dart';
import 'package:nabd/GlobalHelpers/hive_helper.dart';
import 'package:nabd/core/QuranPages/helpers/quran_page_utils.dart';
import 'package:quran/quran.dart';

class QuranPageHeader extends StatelessWidget {
  final int index;
  final dynamic jsonData;
  final dynamic quarterJsonData;
  final VoidCallback onBack;
  final VoidCallback onSettings;

  const QuranPageHeader({
    Key? key,
    required this.index,
    required this.jsonData,
    required this.quarterJsonData,
    required this.onBack,
    required this.onSettings,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final int colorIndex = ((getValue("quranPageolorsIndex") ?? 0) is int)
        ? (getValue("quranPageolorsIndex") ?? 0)
        : 0;
    final screenSize = MediaQuery.of(context).size;
    final pageData = getPageData(index);
    final surahNumber = pageData[0]["surah"];
    final surahName = jsonData[surahNumber - 1]["name"];

    return SizedBox(
      width: screenSize.width,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: (screenSize.width * .33).w,
            child: Row(
              children: [
                IconButton(
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        onBack();
                      }
                    },
                    icon: Icon(
                      Icons.arrow_back_ios,
                      size: 24.sp,
                      color: secondaryColors[colorIndex],
                    )),
                Expanded(
                  child: Text(surahName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: secondaryColors[colorIndex],
                          fontFamily: "Taha",
                          fontSize: 14.sp)),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Stack(
                children: [
                  _buildPageInfoChunk(index, pageData, colorIndex),
                ],
              ),
            ),
          ),
          SizedBox(
            width: (screenSize.width * .27).w,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                    onPressed: onSettings,
                    icon: Icon(
                      Icons.settings,
                      size: 24.sp,
                      color: secondaryColors[getValue("quranPageolorsIndex")],
                    ))
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPageInfoChunk(int index, dynamic pageData, int colorIndex) {
    final result = QuranPageUtils.checkIfPageIncludesQuarterAndQuarterIndex(
        quarterJsonData, pageData, indexes);

    if (result.includesQuarter) {
      return EasyContainer(
        borderRadius: 12.r,
        color: secondaryColors[colorIndex].withValues(alpha: .5),
        borderColor: primaryColors[colorIndex],
        showBorder: true,
        height: 30.h,
        width: double.infinity,
        padding: 8.w,
        margin: 0,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              result.includesQuarter == true
                  ? "${"page".tr()} ${(index).toString()} | ${(result.quarterIndex + 1) == 1 ? "" : "${(result.quarterIndex).toString()}/${4.toString()}"} ${"hizb".tr()} ${(result.hizbIndex + 1).toString()} | ${"juz".tr()} ${getJuzNumber(pageData[0]["surah"], pageData[0]["start"])} "
                  : "${"page".tr()} $index | ${"juz".tr()} ${getJuzNumber(pageData[0]["surah"], pageData[0]["start"])}",
              style: TextStyle(
                fontFamily: 'aldahabi',
                fontSize: 13.sp,
                color: backgroundColors[colorIndex],
              ),
            ),
          ),
        ),
      );
    } else {
      return EasyContainer(
        borderRadius: 12.r,
        color: secondaryColors[colorIndex].withValues(alpha: .5),
        borderColor: backgroundColors[colorIndex],
        showBorder: true,
        height: 30.h,
        width: double.infinity,
        padding: 8.w,
        margin: 0,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              "${"page".tr()} $index | ${"juz".tr()} ${getJuzNumber(pageData[0]["surah"], pageData[0]["start"])}",
              style: TextStyle(
                fontFamily: 'aldahabi',
                fontSize: 13.sp,
                color: backgroundColors[colorIndex],
              ),
            ),
          ),
        ),
      );
    }
  }
}
