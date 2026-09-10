import 'package:flutter/material.dart';
import 'package:nabd/GlobalHelpers/constants.dart';
import 'package:nabd/GlobalHelpers/hive_helper.dart';

class SupportPage extends StatefulWidget {
  const SupportPage({super.key});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          getValue("darkMode") ? quranPagesColorDark : quranPagesColorLight,
      appBar: AppBar(
        elevation: 0,
        actions: const [],
        centerTitle: true,
        // leading: Padding(

        backgroundColor:
            getValue("darkMode") ? darkModeSecondaryColor : blueColor,
        automaticallyImplyLeading: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "صدقة جارية",
          style: TextStyle(
            fontFamily: "cairo",
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "هذا التطبيق مجاني بالكامل وهو صدقة جارية. إذا نال إعجابكم واستفدتم منه، فنسألكم خالص الدعاء بظهر الغيب لوالديَّ ولي ولأسرتي ولجميع المسلمين والمسلمات، في كل استخدام أو كلما تيسر لكم ذلك. جزاكم الله خيراً وبارك فيكم.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: "cairo",
              fontSize: 20,
              height: 1.7,
              color: getValue("darkMode") ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
