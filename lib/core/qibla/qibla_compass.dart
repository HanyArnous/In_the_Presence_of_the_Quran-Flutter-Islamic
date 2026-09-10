import 'dart:math' show pi;

import 'package:flutter/material.dart';
import 'package:flutter_qiblah/flutter_qiblah.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

class QiblahCompassWidget extends StatefulWidget {
  const QiblahCompassWidget({super.key});

  @override
  State<QiblahCompassWidget> createState() => _QiblahCompassWidgetState();
}

class _QiblahCompassWidgetState extends State<QiblahCompassWidget> {
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ensurePermissions();
  }

  Future<void> _ensurePermissions() async {
    final status = await FlutterQiblah.checkLocationStatus();
    if (status.enabled == true &&
        (status.status.name == "always" ||
            status.status.name == "whileInUse")) {
      setState(() {
        _ready = true;
        _error = null;
      });
      return;
    }
    await FlutterQiblah.requestPermissions();
    final s2 = await FlutterQiblah.checkLocationStatus();
    setState(() {
      _ready = s2.enabled == true &&
          (s2.status.name == "always" || s2.status.name == "whileInUse");
      _error = _ready
          ? null
          : "الرجاء تفعيل الموقع ومنح الإذن للتطبيق للوصول إلى الموقع.";
    });
  }

  @override
  void dispose() {
    FlutterQiblah().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = 220.w;

    return SizedBox(
      width: size,
      height: size,
      child: !_ready
          ? Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white,
                    ),
                    SizedBox(height: 12.h),
                    if (_error != null)
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: "cairo",
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            )
          : StreamBuilder<QiblahDirection>(
              stream: FlutterQiblah.qiblahStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white,
                    ),
                  );
                }

                if (snapshot.hasError || !snapshot.hasData) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: const Text(
                        "تعذر الحصول على اتجاه القبلة.\nيرجى تفعيل خدمة تحديد الموقع ومنح التطبيق الإذن بالوصول إلى الموقع.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: "cairo",
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                }

                final qiblahDirection = snapshot.data!;
                final direction = qiblahDirection.direction;
                final qiblah = qiblahDirection.qiblah;

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedRotation(
                      turns: (direction / 360) * -1,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      child: Image.asset(
                        "assets/images/compassn.png",
                        fit: BoxFit.contain,
                        width: size,
                        height: size,
                      ),
                    ),
                    AnimatedRotation(
                      turns: (qiblah / 360) * -1,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      child: SvgPicture.asset(
                        "assets/images/needle.svg",
                        fit: BoxFit.contain,
                        width: size * 0.8,
                        height: size * 0.8,
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      child: Text(
                        "${qiblahDirection.offset.toStringAsFixed(1)}°",
                        style: const TextStyle(
                          fontFamily: "cairo",
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
