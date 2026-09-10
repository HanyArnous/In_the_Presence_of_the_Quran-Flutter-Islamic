import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nabd/GlobalHelpers/constants.dart';
import 'package:nabd/core/qibla/qibla_compass.dart';

class CompassWithQibla extends StatefulWidget {
  const CompassWithQibla({super.key});

  @override
  State<CompassWithQibla> createState() => _CompassWithQiblaState();
}

class _CompassWithQiblaState extends State<CompassWithQibla> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          color: darkPrimaryColor,
          image: DecorationImage(
              fit: BoxFit.cover,
              image: AssetImage(
                "assets/images/tasbeehbackground.png",
              ),
              alignment: Alignment.center,
              opacity: .05)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          // leading: Padding(
          //   padding: const EdgeInsets.all(8.0),
          //   child: IconButton(
          //       icon: const Icon(
          //         MfgLabs.right_open,
          //         color: Colors.black,
          //       ),
          //       onPressed: () {}),
          // ),
          backgroundColor: Colors.transparent, automaticallyImplyLeading: true,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            'qibla'.tr(),
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Colors.white.withOpacity(.9)),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 30.h,
              ),
              const QiblahCompassWidget(),
            ],
          ),
        ),
      ),
    );
  }
}
