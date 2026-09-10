# Keystore - تعليمات هامة

- الملف الحقيقي: `android/app/quranpresence-release.jks` **لا يُرفع إلى Git** (محجوب في .gitignore)
- البصمات الحالية (SHA256): `2D:DB:CE:07:C8:54:BF:E9:12:AF:3F:D0:23:99:82:AC:07:E5:09:B1:20:6A:30:45:8D:E0:40:33:2A:6C:0E:44`
- Alias: `quranpresence` Validity: 10000 يوم (حتى 2054)
- ملف `android/key.properties` محلي فقط، انسخ من `key.properties.example` وضع كلمات السر.
- احتفظ بنسخة احتياطية آمنة خارج Git + فعّل Play App Signing في Play Console.
- المفاتيح القديمة المسربة (In_the_Presence...jks, keys/keystore.jks) تم حذفها من الريبو الجديد.
