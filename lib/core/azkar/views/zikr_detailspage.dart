import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import 'package:nabd/GlobalHelpers/constants.dart';
import 'package:nabd/GlobalHelpers/hive_helper.dart';
import 'package:nabd/core/azkar/model/dua_model.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nabd/core/azkar/data/azkar.dart';
import 'package:nabd/core/sibha/widgets/add_tasbeeh_dialog.dart';

class ZikrPage extends StatefulWidget {
  DuaModel zikr;
  ZikrPage({super.key, required this.zikr});

  @override
  State<ZikrPage> createState() => _ZikrPageState();
}

class _ZikrPageState extends State<ZikrPage> {
  late PageController pageController;
  int count = 0;
  int? currentMax;
  final TextEditingController _maxController = TextEditingController();
  late AudioPlayer _audioPlayer;
  List<DuaItem> customAzkar = [];
  bool _isPlaying = false;
  String? _currentlyPlayingUrl;
  bool _showFavoritesOnly = false;
  Set<dynamic> _favoriteIds = {};
  Map<int, Map<String, dynamic>> _overridesCache = {};
  bool _tapSoundEnabled = true; // حالة صوت النقرة

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _tapSoundEnabled = getValue("tap_sound_enabled") ?? true; // تحميل حالة صوت النقرة
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.completed) {
        setState(() {
          _isPlaying = false;
          _currentlyPlayingUrl = null;
        });
      }
    });
    _loadCustomAzkar();
    if (getValue("${widget.zikr.category}zikrIndex") == null) {
      updateValue("${widget.zikr.category}zikrIndex", 0);
    }
    final idx = getValue("${widget.zikr.category}zikrIndex");
    count = getValue("${widget.zikr.category}-$idx-count") ?? 0;

    // Use default count from azkar data if no user-defined max
    currentMax = getValue("${widget.zikr.category}-$idx-max");
    if (currentMax == null && widget.zikr.array.isNotEmpty) {
      final defaultCount = widget.zikr.array[idx].count;
      currentMax = defaultCount;
      updateValue("${widget.zikr.category}-$idx-max", defaultCount);
    }
  }

  void _loadCustomAzkar() {
    final saved = getValue("customAzkar_${widget.zikr.category}");
    if (saved != null) {
      final List<dynamic> jsonList = json.decode(saved);
      customAzkar = jsonList.map((item) => DuaItem.fromJson(item)).toList();
    }
    // تحميل المفضلة
    final favSaved = getValue("favorites_${widget.zikr.category}");
    if (favSaved != null) {
      try {
        final List<dynamic> favList = json.decode(favSaved);
        _favoriteIds = favList.toSet();
      } catch (_) {}
    }
    _showFavoritesOnly =
        getValue("favorites_filter_${widget.zikr.category}") == true;
    if (_showFavoritesOnly && _favoriteIds.isEmpty) {
      _showFavoritesOnly = false;
      updateValue("favorites_filter_${widget.zikr.category}", false);
    }

    // تحميل تعديلات النصوص/الأعداد إن وجدت
    _overridesCache.clear();
    for (final original in widget.zikr.array) {
      final key = "override_${widget.zikr.category}_${original.id}";
      final raw = getValue(key);
      if (raw is String && raw.isNotEmpty) {
        try {
          final Map<String, dynamic> data = json.decode(raw);
          _overridesCache[original.id] = data;
        } catch (_) {}
      }
    }
    final currentIndex = getValue("${widget.zikr.category}zikrIndex") ?? 0;
    if (_allAzkar.isNotEmpty && currentIndex >= _allAzkar.length) {
      updateValue("${widget.zikr.category}zikrIndex", 0);
    }
  }

  void _saveCustomAzkar() {
    final jsonList = customAzkar
        .map((item) => {
              'id': item.id,
              'text': item.text,
              'count': item.count,
              'audio': item.audio,
              'filename': item.filename,
            })
        .toList();
    updateValue("customAzkar_${widget.zikr.category}", json.encode(jsonList));
  }

  void _addCustomZikr(String text,
      {int? defaultCount, bool enableSound = true}) {
    final newZikr = DuaItem(
      id: DateTime.now().millisecondsSinceEpoch,
      text: text,
      count: defaultCount ?? 33,
      audio: '',
      filename: '',
    );

    // ✅ إصلاح مشكلة عدم تحديث الواجهة عند الإضافة
    setState(() {
      customAzkar.add(newZikr);
      _saveCustomAzkar();

      // إذا كان هذا أول ذكر يتم إضافته، نقوم بتهيئة العدادات
      if (_allAzkar.length == 1) {
        updateValue("${widget.zikr.category}zikrIndex", 0);
        _loadCountersForIndex(0);
      }
    });
    Fluttertoast.showToast(msg: "تم حفظ الذكر بنجاح");
  }

  void _editCurrentZikr(String newText, int? newCount) {
    final idx = getValue("${widget.zikr.category}zikrIndex") ?? 0;
    setState(() {
      if (idx < widget.zikr.array.length) {
        final original = widget.zikr.array[idx];
        final key = "override_${widget.zikr.category}_${original.id}";
        final data = json.encode({
          "text": newText,
          "count": newCount ?? original.count,
        });
        updateValue(key, data);
        _overridesCache[original.id] = {
          "text": newText,
          "count": newCount ?? original.count
        };
      } else {
        final customIndex = idx - widget.zikr.array.length;
        if (customIndex < customAzkar.length) {
          customAzkar[customIndex] = DuaItem(
            id: customAzkar[customIndex].id,
            text: newText,
            count: newCount ?? customAzkar[customIndex].count,
            audio: customAzkar[customIndex].audio,
            filename: customAzkar[customIndex].filename,
          );
        }
      }
      _saveCustomAzkar();
      _loadCountersForIndex(idx);
    });
  }

  void _deleteCurrentZikr() {
    final idx = _safeIndex;

    if (idx < widget.zikr.array.length) {
      // Deleting original azkar - add to custom list as deleted (hidden)
      final customZikr = DuaItem(
        id: -widget
            .zikr.array[idx].id, // Negative ID indicates deleted original
        text: "", // Empty text indicates deleted
        count: widget.zikr.array[idx].count,
        audio: '',
        filename: '',
      );
      customAzkar.add(customZikr);
      _saveCustomAzkar();
    } else {
      // Deleting custom azkar
      final customIndex = idx - widget.zikr.array.length;
      if (customIndex < customAzkar.length) {
        customAzkar.removeAt(customIndex);
        _saveCustomAzkar();
      }
    }

    // Reset to first zikr
    updateValue("${widget.zikr.category}zikrIndex", 0);
    _loadCountersForIndex(0);
    setState(() {});
  }

  List<DuaItem> get _allAzkar {
    final originalAzkar = widget.zikr.array.where((original) {
      return !customAzkar
          .any((custom) => custom.id == -original.id && custom.text.isEmpty);
    }).map((original) {
      final override = _overridesCache[original.id];
      if (override != null) {
        return DuaItem(
          id: original.id,
          text: (override["text"] as String?)?.isNotEmpty == true
              ? override["text"] as String
              : original.text,
          count: (override["count"] as int?) ?? original.count,
          audio: original.audio,
          filename: original.filename,
        );
      }
      return original;
    }).toList();

    final activeCustomAzkar = customAzkar
        .where((custom) => custom.id > 0 && custom.text.isNotEmpty)
        .toList();

    return [...originalAzkar, ...activeCustomAzkar];
  }

  bool _isFavorite(int baseIndex) {
    if (baseIndex < 0 || baseIndex >= _allAzkar.length) return false;
    final id = _allAzkar[baseIndex].id;
    return _favoriteIds.contains(id);
  }

  void _toggleFavoriteForCurrent() {
    final idx = getValue("${widget.zikr.category}zikrIndex") ?? 0;
    if (idx < 0 || idx >= _allAzkar.length) return;
    final id = _allAzkar[idx].id;
    if (_favoriteIds.contains(id)) {
      _favoriteIds.remove(id);
    } else {
      _favoriteIds.add(id);
    }
    updateValue("favorites_${widget.zikr.category}",
        json.encode(_favoriteIds.toList()));
    setState(() {});
  }

  void _toggleFavoritesFilter() {
    setState(() {
      _showFavoritesOnly = !_showFavoritesOnly;
      updateValue(
          "favorites_filter_${widget.zikr.category}", _showFavoritesOnly);
      if (_showFavoritesOnly && _favoriteIds.isEmpty) {
        _showFavoritesOnly = false;
        updateValue(
            "favorites_filter_${widget.zikr.category}", _showFavoritesOnly);
        Fluttertoast.showToast(msg: "لا توجد أذكار مفضلة حالياً");
      }
      updateValue("${widget.zikr.category}zikrIndex", 0);
      _loadCountersForIndex(0);
    });
  }

  int? _nextFavoriteIndex(int current) {
    for (int i = current + 1; i < _allAzkar.length; i++) {
      if (_favoriteIds.contains(_allAzkar[i].id)) return i;
    }
    return null;
  }

  int? _prevFavoriteIndex(int current) {
    for (int i = current - 1; i >= 0; i--) {
      if (_favoriteIds.contains(_allAzkar[i].id)) return i;
    }
    return null;
  }

  int get _safeIndex {
    final idx = getValue("${widget.zikr.category}zikrIndex") ?? 0;
    if (_allAzkar.isEmpty) return 0;
    if (idx < 0 || idx >= _allAzkar.length) return 0;
    return idx;
  }

  void _loadCountersForIndex(int idx) {
    // التأكد من أن الفهرس صالح
    if (idx < 0 || idx >= _allAzkar.length) return;

    count = getValue("${widget.zikr.category}-$idx-count") ?? 0;
    currentMax = getValue("${widget.zikr.category}-$idx-max");

    // إذا لم يحدد المستخدم حداً أقصى، نعود للقيمة الافتراضية
    if (currentMax == null) {
      currentMax = _allAzkar[idx].count;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeList = _allAzkar;
    if (activeList.isEmpty) {
      return _buildEmptyState();
    }

    int storedIndex = getValue("${widget.zikr.category}zikrIndex") ?? 0;
    if (storedIndex >= activeList.length || storedIndex < 0) {
      storedIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          updateValue("${widget.zikr.category}zikrIndex", 0);
          _loadCountersForIndex(0);
          setState(() {});
        }
      });
    }

    if (_showFavoritesOnly && !_isFavorite(storedIndex)) {
      final firstFav = _nextFavoriteIndex(-1);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (firstFav != null) {
            updateValue("${widget.zikr.category}zikrIndex", firstFav);
            _loadCountersForIndex(firstFav);
            setState(() {});
          } else {
            _showFavoritesOnly = false;
            updateValue("favorites_filter_${widget.zikr.category}", false);
            updateValue("${widget.zikr.category}zikrIndex", 0);
            _loadCountersForIndex(0);
            setState(() {});
          }
        }
      });
    }

    return _buildMainContent(storedIndex);
  }

  Widget _buildEmptyState() {
    return Scaffold(
      backgroundColor: darkPrimaryColor,
      appBar: AppBar(
        title: Text(widget.zikr.category,
            style: const TextStyle(fontFamily: "cairo")),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
            )),
        actions: [
          IconButton(
            onPressed: () => showDialog(
              context: context,
              builder: (c) => AddTasbeehDialog(function: _addCustomZikr),
            ),
            icon: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_add, size: 80.sp, color: Colors.white24),
            SizedBox(height: 20.h),
            Text(
              "هذا القسم فارغ حالياً\nاضغط على (+) لإضافة أذكار",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white70, fontFamily: "cairo", fontSize: 16.sp),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(int safeIndex) {
    // نستخدم safeIndex في كل مكان لضمان عدم حدوث RangeError
    final currentZikr = _allAzkar[safeIndex];

    return Container(
      height: MediaQuery.of(context).size.height,
      decoration: const BoxDecoration(
          color: darkPrimaryColor,
          image: DecorationImage(
              fit: BoxFit.fill,
              image: AssetImage(
                "assets/images/zikrbkg.png",
              ),
              alignment: Alignment.center,
              opacity: .15)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(safeIndex),
        body: SafeArea(
          bottom: true,
          child: Stack(
            children: [
              SizedBox(
                  height: MediaQuery.of(context).size.height,
                  child: Column(
                    children: [
                      SizedBox(
                        height: 50.h,
                      ),
                      Text(
                        widget.zikr.category,
                        style: TextStyle(
                            fontFamily: "cairo",
                            color: Colors.white,
                            fontSize: 16.sp),
                      ),
                      SizedBox(
                        height: 10.h,
                      ),
                      // Audio play/pause button
                      if (currentZikr.audio.isNotEmpty)
                        Container(
                          margin: EdgeInsets.zero,
                          child: GestureDetector(
                            onTap: () => _playZikrAudio(currentZikr.audio),
                            child: Container(
                              padding: EdgeInsets.all(10.w),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.5),
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                _isPlaying &&
                                        _currentlyPlayingUrl ==
                                            currentZikr.audio
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                color: Colors.white,
                                size: 28.sp,
                              ),
                            ),
                          ),
                        ),
                      SizedBox(
                          height:
                              (MediaQuery.of(context).size.height * .45) - 30.h,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            transitionBuilder:
                                (Widget child, Animation<double> animation) {
                              return FadeTransition(
                                  opacity: animation, child: child);
                            },
                            child: SingleChildScrollView(
                              key: ValueKey(currentZikr.id),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  SizedBox(height: 5.h),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxHeight:
                                          MediaQuery.of(context).size.height *
                                              0.45,
                                    ),
                                    child: SingleChildScrollView(
                                      physics: const BouncingScrollPhysics(),
                                      child: SizedBox(
                                        width:
                                            MediaQuery.of(context).size.width,
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 50.0.w),
                                          child: GestureDetector(
                                            onLongPress: () {
                                              Clipboard.setData(ClipboardData(
                                                      text: currentZikr.text))
                                                  .then((value) =>
                                                      Fluttertoast.showToast(
                                                          msg:
                                                              "Copied to Clipboard"));
                                            },
                                            child: Text(
                                              currentZikr.text,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  locale: const Locale("ar"),
                                                  fontSize: 19.sp),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )),
                      SizedBox(
                        height: 10.h,
                      ),
                    ],
                  )),

              // Counter Button
              Positioned(
                  bottom: 30.h,
                  width: MediaQuery.of(context).size.width,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildCounterButton(safeIndex),
                      ],
                    ),
                  )),

              // Max Count Settings
              Positioned(
                bottom: 8.h,
                left: 0,
                right: 0,
                child: Center(
                  child: _buildMaxCountSettings(safeIndex),
                ),
              ),

              // Navigation Arrows
              Positioned(
                  width: MediaQuery.of(context).size.width,
                  top: MediaQuery.of(context).size.height * .45,
                  child: _buildNavigationArrows(safeIndex))
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(int safeIndex) {
    return AppBar(
      centerTitle: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.white,
          )),
      actions: [
        // أيقونة التحكم في صوت النقرة
        IconButton(
            onPressed: _toggleTapSound,
            icon: Icon(
              _tapSoundEnabled ? Icons.volume_up : Icons.volume_off,
              color: _tapSoundEnabled ? Colors.white : Colors.grey,
            )),
        IconButton(
            onPressed: _toggleFavoriteForCurrent,
            icon: Icon(
              _isFavorite(safeIndex) ? Icons.star : Icons.star_border,
              color: Colors.amber,
            )),
        IconButton(
            onPressed: _toggleFavoritesFilter,
            icon: Icon(
              _showFavoritesOnly ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: Colors.white,
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
                  context: context,
                  builder: (c) => AddTasbeehDialog(
                        function: _addCustomZikr,
                      ));
            },
            icon: const Icon(Icons.add, color: Colors.white)),
        PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == "edit") {
              await _editCurrentZikrDialog();
            } else if (v == "delete") {
              await _deleteCurrentZikrDialog();
            }
          },
          itemBuilder: (c) => [
            const PopupMenuItem<String>(
              value: "edit",
              child: Text("تعديل", style: TextStyle(fontFamily: "cairo")),
            ),
            const PopupMenuItem<String>(
              value: "delete",
              child: Text("حذف", style: TextStyle(fontFamily: "cairo")),
            ),
          ],
          icon: const Icon(Icons.more_vert, color: Colors.white),
        ),
        IconButton(
            onPressed: () {
              updateValue("${widget.zikr.category}-$safeIndex-count", 0);
              count = 0;
              setState(() {});
            },
            icon: const Icon(
              Icons.replay_outlined,
              color: Colors.white,
            ))
      ],
    );
  }

  Widget _buildCounterButton(int safeIndex) {
    return InkWell(
        overlayColor: WidgetStatePropertyAll(Colors.white.withOpacity(.25)),
        splashColor: Colors.white.withOpacity(.25),
        focusColor: Colors.white.withOpacity(.25),
        hoverColor: Colors.white.withOpacity(.25),
        highlightColor: Colors.white.withOpacity(.15),
        borderRadius: BorderRadius.circular(200),
        onTap: () async {
          final idx = safeIndex;
          final savedMax = getValue("${widget.zikr.category}-$idx-max");
          HapticFeedback.selectionClick();

          // Play sound if enabled
          if (_tapSoundEnabled) {
            _playTapSound();
          }

          if (savedMax != null) {
            final maxInt = savedMax as int;
            if (count >= maxInt) {
              count = maxInt;
              updateValue("${widget.zikr.category}-$idx-count", maxInt);
              HapticFeedback.heavyImpact();
              if (_tapSoundEnabled) _playTapSound();
              if (_allAzkar.length <= 1) {
                HapticFeedback.vibrate();
                setState(() {});
                return;
              }
              if (idx + 1 < _allAzkar.length) {
                final newIdx = idx + 1;
                updateValue("${widget.zikr.category}zikrIndex", newIdx);
                updateValue("${widget.zikr.category}-$newIdx-count", 0);
                _loadCountersForIndex(newIdx);
                if (_tapSoundEnabled) {
                  Future.delayed(const Duration(milliseconds: 100), () => _playTapSound());
                }
              } else {
                // آخر ذكر في القائمة - إعادة للبداية مع تنبيه
                HapticFeedback.heavyImpact();
                if (_tapSoundEnabled) _playTapSound();
                updateValue("${widget.zikr.category}zikrIndex", 0);
                _loadCountersForIndex(0);
              }
              setState(() {});
              return;
            }
            // زيادة العداد إذا لم يصل إلى الحد
            count++;
          } else {
            count++;
          }
          updateValue("${widget.zikr.category}-$idx-count", count);
          _updateAzkarStats(widget.zikr.category, idx, 1);

          // إذا وصل للحد بعد الزيادة، انتقل تلقائيا
          final effectiveMax = savedMax as int? ?? currentMax ?? _allAzkar[idx].count;
          if (count >= effectiveMax) {
            HapticFeedback.mediumImpact();
            if (_tapSoundEnabled) {
              Future.delayed(const Duration(milliseconds: 100), () => _playTapSound());
            }
            if (_allAzkar.length > 1) {
              Future.delayed(const Duration(milliseconds: 300), () {
                if (!mounted) return;
                if (idx + 1 < _allAzkar.length) {
                  updateValue("${widget.zikr.category}zikrIndex", idx + 1);
                  updateValue("${widget.zikr.category}-${idx + 1}-count", 0);
                  _loadCountersForIndex(idx + 1);
                  setState(() {});
                } else {
                  updateValue("${widget.zikr.category}zikrIndex", 0);
                  _loadCountersForIndex(0);
                  setState(() {});
                }
              });
            } else {
              HapticFeedback.heavyImpact();
            }
          }

          setState(() {});
        },
        child: Center(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(200),
              color: Colors.grey.withOpacity(.1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Text("$count${currentMax != null ? " / $currentMax" : ""}",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 40.sp,
                      fontWeight: FontWeight.bold,
                      fontFamily: "roboto")),
            ),
          ),
        ));
  }

  Widget _buildMaxCountSettings(int safeIndex) {
    return InkWell(
      onTap: () async {
        final idx = safeIndex;
        _maxController.text =
            (getValue("${widget.zikr.category}-$idx-max") ?? "").toString();
        await showDialog(
            context: context,
            builder: (c) {
              return AlertDialog(
                title: const Text("تحديد العدد الأقصى",
                    style: TextStyle(fontFamily: "cairo")),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _maxController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: "أدخل العدد الأقصى (اتركه فارغاً لغير محدود)",
                      ),
                    ),
                    SizedBox(height: 10.h),
                    if (_allAzkar.isNotEmpty)
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              final defaultCount = _allAzkar[safeIndex].count;
                              _maxController.text = defaultCount.toString();
                            },
                            child: Text(
                                "استخدام العدد الافتراضي (${_allAzkar[safeIndex].count})"),
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
                        final parsed = int.tryParse(_maxController.text.trim());
                        final idx = safeIndex;
                        if (parsed != null && parsed >= 0) {
                          updateValue(
                              "${widget.zikr.category}-$idx-max", parsed);
                          currentMax = parsed;
                        } else {
                          updateValue("${widget.zikr.category}-$idx-max", null);
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
          Icon(Icons.settings, color: Colors.white.withOpacity(.9)),
          SizedBox(width: 8.w),
          Text(
            currentMax != null ? "الحد الأقصى: $currentMax" : "غير محدود",
            style: const TextStyle(color: Colors.white, fontFamily: "cairo"),
          )
        ],
      ),
    );
  }

  Widget _buildNavigationArrows(int safeIndex) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () async {
            // ✅ 1. إيقاف الصوت عند التنقل لمنع التداخل
            if (_isPlaying) {
              await _audioPlayer.stop();
              setState(() {
                _isPlaying = false;
                _currentlyPlayingUrl = null;
              });
            }

            final current = safeIndex;
            int? targetIdx;
            if (_showFavoritesOnly) {
              targetIdx = _prevFavoriteIndex(current);
            } else if (current > 0) {
              targetIdx = current - 1;
            }

            if (targetIdx != null) {
              // ✅ 2. تحديث الحالة فوراً لتغيير النص والعداد
              setState(() {
                updateValue("${widget.zikr.category}zikrIndex", targetIdx);
                _loadCountersForIndex(targetIdx!);
              });
            }
          },
          child: _buildArrowIcon(Icons.arrow_back_ios, safeIndex == 0),
        ),
        GestureDetector(
          onTap: () async {
            if (_isPlaying) {
              await _audioPlayer.stop();
              setState(() {
                _isPlaying = false;
                _currentlyPlayingUrl = null;
              });
            }

            final current = safeIndex;
            int? targetIdx;
            if (_showFavoritesOnly) {
              targetIdx = _nextFavoriteIndex(current);
            } else if (current + 1 < _allAzkar.length) {
              targetIdx = current + 1;
            }

            if (targetIdx != null) {
              // ✅ 3. تحديث الحالة فوراً لتغيير النص والعداد
              setState(() {
                updateValue("${widget.zikr.category}zikrIndex", targetIdx);
                _loadCountersForIndex(targetIdx!);
              });
            }
          },
          child: _buildArrowIcon(
              Icons.arrow_forward_ios, safeIndex + 1 == _allAzkar.length),
        ),
      ],
    );
  }

  // دالة مساعدة لتصميم الأيقونات لتقليل تكرار الكود
  Widget _buildArrowIcon(IconData icon, bool isDisabled) {
    return Container(
      height: 40.h,
      width: 40.h,
      decoration: const BoxDecoration(
          color: Colors.transparent, shape: BoxShape.circle),
      child: Center(
        child: Icon(icon,
            color: isDisabled ? Colors.grey : Colors.white, size: 28.sp),
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _playTapSound() async {
    try {
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

  Future<void> _playZikrAudio(String? audioUrl) async {
    if (audioUrl == null || audioUrl.isEmpty) return;

    try {
      if (_isPlaying && _currentlyPlayingUrl == audioUrl) {
        // Pause if playing the same audio
        await _audioPlayer.pause();
        setState(() {
          _isPlaying = false;
          _currentlyPlayingUrl = null;
        });
      } else {
        // Play new audio
        await _audioPlayer.play(UrlSource(audioUrl));
        setState(() {
          _isPlaying = true;
          _currentlyPlayingUrl = audioUrl;
        });
      }
    } catch (e) {
      print('Error playing zikr audio: $e');
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن تشغيل الصوت'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  String? _getCurrentZikrAudio() {
    final idx = _safeIndex;
    if (idx < _allAzkar.length) {
      return _allAzkar[idx].audio;
    }
    return null;
  }

  void _updateAzkarStats(String category, int index, int delta) {
    final dateKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    // إجمالي يومي للأذكار
    int dailyAzkar =
        int.tryParse(getValue("$dateKey-azkar-count")?.toString() ?? "0") ?? 0;
    updateValue("$dateKey-azkar-count", dailyAzkar + delta);
    // إجمالي عام للأذكار
    int totalAzkar =
        int.tryParse(getValue("azkar-totalCount")?.toString() ?? "0") ?? 0;
    updateValue("azkar-totalCount", totalAzkar + delta);
    // مفاتيح تفصيلية لكل قسم/عنصر
    final dailyKey = "$dateKey-$category-$index-count";
    final overallKey = "$category-$index-totalCount";
    int currentDailyCount =
        int.tryParse(getValue(dailyKey)?.toString() ?? "0") ?? 0;
    int currentOverallCount =
        int.tryParse(getValue(overallKey)?.toString() ?? "0") ?? 0;
    updateValue(dailyKey, currentDailyCount + delta);
    updateValue(overallKey, currentOverallCount + delta);
  }

  void _dailyReset() {
    for (int i = 0; i < _allAzkar.length; i++) {
      updateValue("${widget.zikr.category}-$i-count", 0);
    }
    updateValue("${widget.zikr.category}zikrIndex", 0);
    _loadCountersForIndex(0);
    setState(() {});
  }

  Future<void> _editCurrentZikrDialog() async {
    final idx = getValue("${widget.zikr.category}zikrIndex");
    if (idx < 0 || idx >= _allAzkar.length) return;
    final zikr = _allAzkar[idx];
    final controller = TextEditingController(text: zikr.text);
    final countController = TextEditingController(text: zikr.count.toString());

    await showDialog(
        context: context,
        builder: (c) {
          return AlertDialog(
            title: const Text("تعديل الذكر",
                style: TextStyle(fontFamily: "cairo")),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: "نص الذكر",
                  ),
                  maxLines: 3,
                ),
                SizedBox(height: 10.h),
                TextField(
                  controller: countController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "العدد الافتراضي",
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text("إلغاء")),
              TextButton(
                  onPressed: () {
                    final newText = controller.text.trim();
                    final newCount = int.tryParse(countController.text);
                    if (newText.isNotEmpty) {
                      _editCurrentZikr(newText, newCount);
                    }
                    Navigator.pop(c);
                  },
                  child: const Text("حفظ"))
            ],
          );
        });
  }

  Future<void> _deleteCurrentZikrDialog() async {
    final idx = _safeIndex;
    if (idx < 0 || idx >= _allAzkar.length) return;

    final isOriginal = idx < widget.zikr.array.length;

    await showDialog(
        context: context,
        builder: (c) {
          return AlertDialog(
            title:
                const Text("حذف الذكر", style: TextStyle(fontFamily: "cairo")),
            content: Text(
                isOriginal
                    ? "هل تريد حذف هذا الذكر الأصلي؟ (سيتم إخفاؤه فقط)"
                    : "هل تريد حذف هذا الذكر؟",
                style: const TextStyle(fontFamily: "cairo")),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text("إلغاء")),
              TextButton(
                  onPressed: () {
                    _deleteCurrentZikr();
                    Navigator.pop(c);
                  },
                  child: const Text("حذف"))
            ],
          );
        });
  }
}
