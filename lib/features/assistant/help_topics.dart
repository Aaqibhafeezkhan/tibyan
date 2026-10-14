import 'package:flutter/material.dart';

import 'tajweed_marks_screen.dart' show tajweedMarksLocation;

/// The kinds of help in «المساعد».
enum HelpGroup { usage, marks, faq }

/// A paragraph or step of a help topic, in both languages.
typedef HelpText = ({String ar, String en});

/// One topic of the help centre. A topic with a [location] opens its own
/// screen (the tajweed and dabt marks); the others show their [steps].
///
/// These texts explain how to use the app only; nothing in them is
/// religious content.
class HelpTopic {
  const HelpTopic({
    required this.id,
    required this.group,
    required this.icon,
    required this.title,
    this.steps = const [],
    this.location,
    this.keywords = '',
  });

  final String id;
  final HelpGroup group;
  final IconData icon;
  final HelpText title;
  final List<HelpText> steps;
  final String? location;
  final String keywords;

  String titleIn(String lang) => lang == 'ar' ? title.ar : title.en;

  /// Where the topic opens.
  String get route => location ?? '$helpTopicLocation?id=$id';
}

const helpTopicLocation = '/assistant/topic';

HelpTopic? helpTopicById(String id) {
  for (final t in helpTopics) {
    if (t.id == id) return t;
  }
  return null;
}

const helpTopics = <HelpTopic>[
  HelpTopic(
    id: 'reading',
    group: HelpGroup.usage,
    icon: Icons.chrome_reader_mode_outlined,
    title: (ar: 'القراءة والتنقل', en: 'Reading and navigation'),
    keywords: 'قراءة تنقل صفحة فهرس سورة جزء reading navigation page index',
    steps: [
      (
        ar: 'اسحب الصفحة يمينا أو يسارا لتنتقل بين الصفحات.',
        en: 'Swipe the page left or right to move between pages.',
      ),
      (
        ar: 'اضغط على الصفحة لتظهر الأدوات أو تخفيها.',
        en: 'Tap the page to show or hide the tools.',
      ),
      (
        ar: 'افتح «الفهرس» لتنتقل إلى سورة أو جزء، أو اكتب رقم صفحة أو «٢:٢٥٥».',
        en: 'Open «Index» to go to a surah or juz, or type a page number or «2:255».',
      ),
      (
        ar: 'اضغط مطولا على آية لتحددها وتظهر خياراتها، مثل الاستماع والتفسير والمشاركة.',
        en: 'Long-press a verse to select it and show its options, such as listening, tafsir and sharing.',
      ),
      (
        ar: 'تغيّر الطبعة وشكل الصفحة من الإعدادات › المصحف.',
        en: 'Change the edition and page look in Settings › Mushaf.',
      ),
    ],
  ),
  HelpTopic(
    id: 'bookmarks',
    group: HelpGroup.usage,
    icon: Icons.bookmark_border,
    title: (ar: 'الفواصل والعلامات', en: 'Bookmarks'),
    keywords: 'فاصل فواصل علامة حفظ موضع bookmark marker save place',
    steps: [
      (
        ar: 'افتح «الفواصل» من أدوات القارئ.',
        en: 'Open «Bookmarks» from the reader tools.',
      ),
      (
        ar: 'اضغط «احفظ الموضع الحالي في فاصل»، أو أنشئ «فاصل جديد» باسم ولون.',
        en: 'Tap «Save the current place to a bookmark», or create a «New bookmark» with a name and colour.',
      ),
      (
        ar: 'اضغط الفاصل لتعود إلى آخر موضع قرأت عنده.',
        en: 'Tap a bookmark to return to the last place you read with it.',
      ),
    ],
  ),
  HelpTopic(
    id: 'search',
    group: HelpGroup.usage,
    icon: Icons.search,
    title: (ar: 'البحث', en: 'Search'),
    keywords: 'بحث كلمة آية معنى search word verse meaning',
    steps: [
      (
        ar: 'اضغط البحث في الرئيسية، واكتب كلمة أو جزءا من آية.',
        en: 'Tap search on the home screen and type a word or part of a verse.',
      ),
      (
        ar: 'اكتب اسم السورة ورقم الآية، مثل «البقرة ٢٥٥»، لتنتقل إليها مباشرة.',
        en: 'Type a surah name and verse number, like «Al-Baqarah 255», to jump straight to it.',
      ),
      (
        ar: 'نزّل «حزمة البحث بالمعنى» ليجد البحث الآيات بمعناها دون اتصال.',
        en: 'Download the «Search-by-meaning pack» to find verses by meaning, offline.',
      ),
    ],
  ),
  HelpTopic(
    id: 'khatma',
    group: HelpGroup.usage,
    icon: Icons.event_repeat_outlined,
    title: (ar: 'الختمة', en: 'Khatma'),
    keywords: 'ختمة خطة ورد تذكير khatma plan portion reminder',
    steps: [
      (
        ar: 'افتح «الختمة» من الرئيسية، واضغط «ختمة جديدة».',
        en: 'Open «Khatma» from the home screen and tap «New khatma».',
      ),
      (
        ar: 'اختر المدة أو مقدار الورد اليومي، ووقت التذكير إن أردت.',
        en: 'Choose the duration or daily portion, and a reminder time if you like.',
      ),
      (
        ar: 'يتقدم الورد وحده كلما قرأت، وتجد التقارير والملاحظات في صفحة الختمة.',
        en: 'Your portion advances as you read; reports and notes are on the khatma page.',
      ),
    ],
  ),
  HelpTopic(
    id: 'hifz',
    group: HelpGroup.usage,
    icon: Icons.psychology_alt_outlined,
    title: (ar: 'الحفظ والتسميع', en: 'Memorization and recitation practice'),
    keywords: 'حفظ تسميع مراجعة أهداف hifz tasmee memorize review goals',
    steps: [
      (
        ar: 'افتح «الحفظ» لتحدد ما تحفظه وتتابع مراجعته وأهدافك.',
        en: 'Open «Memorization» to set what you memorize and follow its review and goals.',
      ),
      (
        ar: 'اضغط «ابدأ تسميعا» واقرأ بصوتك؛ يتابعك التطبيق ويبيّن ما فاتك.',
        en: 'Tap «Start a test» and recite aloud; the app follows you and shows what you missed.',
      ),
      (
        ar: 'التسميع يحتاج «نموذج التسميع» مرة واحدة: نزّله من الإعدادات › الحفظ والتسميع. الصوت يبقى على جهازك.',
        en: 'Recitation practice needs the «Tasmee model» once: download it in Settings › Memorization. Audio stays on your device.',
      ),
    ],
  ),
  HelpTopic(
    id: 'listening',
    group: HelpGroup.usage,
    icon: Icons.headphones_outlined,
    title: (ar: 'الاستماع والتنزيلات', en: 'Listening and downloads'),
    keywords: 'استماع قارئ تلاوة تنزيل تحميل listen reciter audio download',
    steps: [
      (
        ar: 'اختر القارئ من الإعدادات › الاستماع › إعدادات الاستماع.',
        en: 'Choose the reciter in Settings › Listening › Listening settings.',
      ),
      (
        ar: 'لتستمع دون اتصال افتح «تحميل التلاوات» ونزّل سورا أو المصحف كاملا.',
        en: 'To listen offline, open «Download recitations» and download surahs or the whole mushaf.',
      ),
      (
        ar: 'تستمر التنزيلات إذا خرجت من الشاشة أو التطبيق، وتجدها كلها في شاشة «التنزيلات» حيث توقفها أو تستأنفها أو تلغيها.',
        en: 'Downloads continue if you leave the screen or the app; find them all in «Downloads», where you can pause, resume or cancel them.',
      ),
    ],
  ),
  HelpTopic(
    id: 'backup',
    group: HelpGroup.usage,
    icon: Icons.ios_share,
    title: (ar: 'النسخ الاحتياطي', en: 'Backup'),
    keywords: 'نسخ احتياطي استعادة تصدير backup restore export',
    steps: [
      (
        ar: 'من الإعدادات › التخزين والنسخ الاحتياطي اضغط «حفظ نسخة احتياطية».',
        en: 'In Settings › Storage & backup, tap «Save a backup».',
      ),
      (
        ar: 'احفظ الملف أو أرسله لنفسك؛ فيه فواصلك والختمة والحفظ وإعداداتك.',
        en: 'Keep the file or send it to yourself; it holds your bookmarks, khatma, memorization and settings.',
      ),
    ],
  ),
  HelpTopic(
    id: 'settings',
    group: HelpGroup.usage,
    icon: Icons.tune,
    title: (ar: 'الإعدادات والبحث فيها', en: 'Settings and settings search'),
    keywords: 'إعدادات بحث settings search',
    steps: [
      (
        ar: 'الإعدادات ثمانية أقسام، كل قسم في بطاقة.',
        en: 'Settings come in eight sections, one card each.',
      ),
      (
        ar: 'اكتب في «ابحث في الإعدادات» اسم ما تريد بالعربية أو الإنجليزية، واضغط النتيجة لتصل إليه.',
        en: 'Type what you want in «Search settings», in Arabic or English, and tap the result to reach it.',
      ),
    ],
  ),
  HelpTopic(
    id: 'marks',
    group: HelpGroup.marks,
    icon: Icons.palette_outlined,
    title: (ar: 'علامات التجويد والضبط', en: 'Tajweed and dabt marks'),
    location: tajweedMarksLocation,
    keywords:
        'علامات التجويد الضبط أحكام ألوان tajweed dabt marks rules colours',
  ),
  HelpTopic(
    id: 'faq-audio',
    group: HelpGroup.faq,
    icon: Icons.volume_off_outlined,
    title: (ar: 'الصوت لا يعمل', en: 'Audio is not playing'),
    keywords: 'صوت لا يعمل تشغيل audio not playing sound',
    steps: [
      (
        ar: 'تأكد من رفع صوت الجهاز وأنه ليس على الوضع الصامت.',
        en: 'Make sure the device volume is up and it is not on silent.',
      ),
      (
        ar: 'إن لم تكن التلاوة منزّلة فالاستماع يحتاج اتصالا بالإنترنت.',
        en: 'If the recitation is not downloaded, listening needs an internet connection.',
      ),
      (
        ar: 'جرّب قارئا آخر، أو احذف تلاوة القارئ من «التخزين والتنزيلات» ونزّلها من جديد.',
        en: 'Try another reciter, or delete the reciter\'s audio in «Storage and downloads» and download it again.',
      ),
    ],
  ),
  HelpTopic(
    id: 'faq-mic',
    group: HelpGroup.faq,
    icon: Icons.mic_off_outlined,
    title: (
      ar: 'التسميع لا يسمعني (إذن الميكروفون)',
      en: 'Recitation practice can\'t hear me (microphone)',
    ),
    keywords: 'ميكروفون إذن لا يسمع microphone permission mic',
    steps: [
      (
        ar: 'اسمح لتبيان باستخدام الميكروفون من إعدادات الجهاز › التطبيقات › تبيان › الأذونات.',
        en: 'Allow Tibyan to use the microphone in device Settings › Apps › Tibyan › Permissions.',
      ),
      (
        ar: 'تأكد أن «نموذج التسميع» منزّل في الإعدادات › الحفظ والتسميع.',
        en: 'Make sure the «Tasmee model» is downloaded in Settings › Memorization.',
      ),
      (
        ar: 'اقرأ بصوت واضح قريبا من الجهاز، وأغلق أي تطبيق آخر يستخدم الميكروفون.',
        en: 'Recite clearly near the device, and close any other app using the microphone.',
      ),
    ],
  ),
  HelpTopic(
    id: 'faq-storage',
    group: HelpGroup.faq,
    icon: Icons.sd_storage_outlined,
    title: (ar: 'المساحة ممتلئة', en: 'Storage is full'),
    keywords: 'مساحة ممتلئة تخزين حذف storage full space delete',
    steps: [
      (
        ar: 'افتح الإعدادات › التخزين والنسخ الاحتياطي › «التخزين والتنزيلات».',
        en: 'Open Settings › Storage & backup › «Storage and downloads».',
      ),
      (
        ar: 'احذف ما لا تحتاجه، مثل تلاوات قارئ أو طبعة لا تستخدمها، واضغط «تنظيف» للتنزيلات غير المكتملة.',
        en: 'Delete what you don\'t need, such as a reciter\'s audio or an unused edition, and tap «Clean up» for unfinished downloads.',
      ),
      (
        ar: 'بياناتك (الفواصل والختمة والملاحظات) لا تُحذف من هناك.',
        en: 'Your data (bookmarks, khatma, notes) is never deleted from there.',
      ),
    ],
  ),
  HelpTopic(
    id: 'faq-restore',
    group: HelpGroup.faq,
    icon: Icons.restore,
    title: (ar: 'استعادة نسخة احتياطية', en: 'Restoring a backup'),
    keywords: 'استعادة نسخة احتياطية restore backup import',
    steps: [
      (
        ar: 'من الإعدادات › التخزين والنسخ الاحتياطي اضغط «استعادة من نسخة» واختر ملف النسخة.',
        en: 'In Settings › Storage & backup, tap «Restore from a backup» and pick the backup file.',
      ),
      (
        ar: 'تُدمج النسخة مع ما على جهازك ولا يُحذف شيء؛ وعند التعارض يؤخذ الأحدث.',
        en: 'The backup is merged with what is on your device and nothing is deleted; on a conflict the newer one is kept.',
      ),
      (
        ar: 'إن ظهر «هذا الملف ليس نسخة احتياطية من تبيان» فاختر الملف الذي حفظه التطبيق نفسه.',
        en: 'If you see «This file is not a Tibyan backup», pick the file the app itself saved.',
      ),
    ],
  ),
  HelpTopic(
    id: 'faq-model',
    group: HelpGroup.faq,
    icon: Icons.memory,
    title: (ar: 'تنزيل نموذج التسميع', en: 'Downloading the tasmee model'),
    keywords: 'نموذج تسميع تنزيل توقف model download stuck',
    steps: [
      (
        ar: 'ابدأ التنزيل من الإعدادات › الحفظ والتسميع › نموذج التسميع.',
        en: 'Start the download in Settings › Memorization › Tasmee model.',
      ),
      (
        ar: 'يستمر التنزيل إذا خرجت من الشاشة أو التطبيق، وتتابعه في شاشة «التنزيلات» والإشعار.',
        en: 'It continues if you leave the screen or the app; follow it in «Downloads» and the notification.',
      ),
      (
        ar: 'إن توقف أو فشل فاضغط «استئناف» أو «إعادة المحاولة» في «التنزيلات»، وتأكد من الاتصال ومن وجود مساحة كافية.',
        en: 'If it stops or fails, tap «Resume» or «Retry» in «Downloads», and check your connection and free space.',
      ),
      (
        ar: 'بعد التنزيل يتحقق التطبيق من سلامة الملف قبل استخدامه.',
        en: 'After downloading, the app verifies the file before using it.',
      ),
    ],
  ),
];
