import 'package:flutter/material.dart';
import 'package:fluttericon/font_awesome_icons.dart';
import 'package:nabd/GlobalHelpers/constants.dart';
import 'package:nabd/GlobalHelpers/hive_helper.dart';
import 'package:url_launcher/url_launcher.dart';

/// رابط سياسة الخصوصية العام (GitHub Pages — يُفعّل من Settings > Pages > Deploy from branch: main /docs).
const String kPrivacyPolicyUrl =
    'https://hanyarnous.github.io/In_the_Presence_of_the_Quran-Flutter-Islamic/privacy.html';
const String kSupportEmail = 'hany.hossam.arnous@gmail.com';
const String kDeveloperName = 'هانى حسام';
const String kWhatsAppNumber = '201004126245';

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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "هذا التطبيق مجاني بالكامل وهو صدقة جارية. إذا نال إعجابكم واستفدتم منه، فنسألكم خالص الدعاء بظهر الغيب لوالديَّ ولي ولأسرتي ولجميع المسلمين والمسلمات، في كل استخدام أو كلما تيسر لكم ذلك. جزاكم الله خيراً وبارك فيكم.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: "cairo",
                  fontSize: 20,
                  height: 1.7,
                  color: getValue("darkMode") ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              // رابط سياسة الخصوصية — مطلوب لمراجعة Google Play (Data Safety + حقل Privacy policy)
              OutlinedButton.icon(
                onPressed: () async {
                  final uri = Uri.parse(kPrivacyPolicyUrl);
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                icon: const Icon(Icons.privacy_tip_outlined),
                label: const Text(
                  "سياسة الخصوصية",
                  style: TextStyle(fontFamily: "cairo"),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  final uri = Uri.parse("mailto:$kSupportEmail");
                  await launchUrl(uri);
                },
                icon: const Icon(Icons.mail_outline),
                label: const Text(
                  kSupportEmail,
                  style: TextStyle(fontFamily: "cairo"),
                  textDirection: TextDirection.ltr,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              // مطور التطبيق + واتساب أسفل البريد
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_outline, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    "مطور التطبيق: $kDeveloperName",
                    style: TextStyle(
                      fontFamily: "cairo",
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: getValue("darkMode")
                          ? Colors.white70
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final uri =
                      Uri.parse("https://wa.me/$kWhatsAppNumber");
                  await launchUrl(uri,
                      mode: LaunchMode.externalApplication);
                },
                icon: const Icon(FontAwesome.whatsapp, color: Colors.green),
                label: const Text(
                  "تواصل واتساب",
                  style: TextStyle(fontFamily: "cairo"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
