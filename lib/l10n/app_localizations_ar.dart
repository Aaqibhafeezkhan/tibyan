// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'تبيان';

  @override
  String get appTagline => 'تفسير وتلاوة وحفظ القرآن';

  @override
  String get homeComingTitle => 'قيد البناء';

  @override
  String get homeComingBody =>
      'هذه أول نسخة من تبيان: فيها الأشكال والإعدادات فقط. المصحف والتفسير والاستماع تأتي في المراحل القادمة إن شاء الله.';

  @override
  String get sectionMushaf => 'المصحف';

  @override
  String get sectionTafsir => 'التفسير';

  @override
  String get sectionListen => 'الاستماع';

  @override
  String get sectionHifz => 'الحفظ';

  @override
  String get sectionKhatma => 'الختمة';

  @override
  String get sectionSearch => 'البحث';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get openSettings => 'فتح الإعدادات';

  @override
  String get appearanceTitle => 'شكل المصحف';

  @override
  String get modeLabel => 'وضع الإضاءة';

  @override
  String get modeSystem => 'تلقائي';

  @override
  String get modeSystemHint => 'يتبع إعداد الجهاز';

  @override
  String get modeLight => 'فاتح';

  @override
  String get modeWhite => 'أبيض زاهي';

  @override
  String get modeNight => 'ليلي';

  @override
  String get modeBlack => 'أسود';

  @override
  String get uiFontLabel => 'خط الواجهة';

  @override
  String get uiFontPlex => 'آي بي إم بلكس عربي';

  @override
  String get uiFontKfgqpcAn => 'خط المجمع (AN)';

  @override
  String get uiFontChanga => 'Changa';

  @override
  String get languageLabel => 'اللغة';

  @override
  String get languageSystem => 'لغة الجهاز';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get privacyTitle => 'الخصوصية';

  @override
  String get crashReportsLabel => 'إرسال تقارير الأعطال';

  @override
  String get crashReportsHint =>
      'يرسل تفاصيل تقنية عن الأعطال فقط، بلا أي بيانات شخصية. متوقف حتى توافق.';

  @override
  String get aboutTitle => 'عن التطبيق';

  @override
  String get aboutBody =>
      'تبيان تطبيق لقراءة القرآن الكريم وتدبّره، وشيفرته مفتوحة. كل نص فيه من مصدر موثق مذكور بجانبه.';

  @override
  String versionLabel(String version) {
    return 'الإصدار $version';
  }

  @override
  String get selected => 'محدد';

  @override
  String get onbLanguageTitle => 'اختر اللغة\nChoose your language';

  @override
  String get onbStyleTitle => 'اختر الشكل الذي يريح عينك';

  @override
  String get onbStyleHint => 'يمكنك تغييره في أي وقت من الإعدادات';

  @override
  String get continueLabel => 'متابعة';

  @override
  String get skipLabel => 'تخطي';

  @override
  String get onbEditionTitle => 'اختر طبعة المصحف';

  @override
  String get editionNew => 'مصحف المدينة: الطبعة الحديثة';

  @override
  String get editionNewDesc =>
      'طبعة ١٤٤١هـ من مجمع الملك فهد، مع تظليل الآية أثناء التلاوة.';

  @override
  String get editionOld => 'مصحف المدينة: الطبعة القديمة';

  @override
  String get editionOldDesc =>
      'طبعة ١٤٠٥هـ المشهورة في التطبيقات القديمة، مع تظليل الكلمة.';

  @override
  String get editionShamarly => 'مصحف الشمرلي (الطبعة المصرية)';

  @override
  String get editionShamarlyDesc =>
      'طبعة الشمرلي المصرية المعروفة، ٥٢٢ صفحة، مع تظليل الآية وتظليل الكلمة في كثير من الآيات.';

  @override
  String get defaultTag => 'الافتراضية';

  @override
  String pagesDownloadNote(String size) {
    return 'صفحات هذا المصحف تُحمّل مرة واحدة (نحو $size ميجا)، ثم تعمل دون اتصال. وحتى يكتمل التحميل تقرأ في مصحف المدينة (الطبعة الحديثة) المدمج في التطبيق.';
  }

  @override
  String get downloadTitle => 'تحميل صفحات المصحف';

  @override
  String get downloadStart => 'ابدأ التحميل';

  @override
  String get downloadPause => 'إيقاف مؤقت';

  @override
  String get downloadResume => 'متابعة التحميل';

  @override
  String get downloadRetry => 'إعادة المحاولة';

  @override
  String get downloadVerifying => 'جارٍ التحقق من سلامة الملفات…';

  @override
  String get downloadInstalling => 'جارٍ تجهيز الصفحات…';

  @override
  String get downloadDone => 'اكتمل التحميل';

  @override
  String downloadFailed(String error) {
    return 'تعذّر التحميل: $error';
  }

  @override
  String downloadProgress(String received, String total) {
    return '$received من $total ميجا';
  }

  @override
  String get downloadWifiHint =>
      'يكمل التحميل من حيث توقف إذا انقطع الاتصال. يُفضّل الاتصال بشبكة Wi-Fi.';

  @override
  String get pagesCredit =>
      'صفحات مصحف المدينة من مجمع الملك فهد لطباعة المصحف الشريف.';

  @override
  String get pagesCreditOld =>
      'صفحات الطبعة القديمة (1405هـ) من مجمع الملك فهد لطباعة المصحف الشريف، ومصدرها موقع quran.com، وتُحمّل من خادم تبيان.';

  @override
  String get pagesCreditShamarly =>
      'مصحف الشمرلي بخط محمد سعد إبراهيم الشهير بحداد، والصفحات من أرشيف الإنترنت (archive.org)، وتُحمّل من خادم تبيان.';

  @override
  String get editionLabel => 'طبعة المصحف';

  @override
  String get viewPage => 'الصفحة';

  @override
  String get viewModeLabel => 'طريقة العرض';

  @override
  String get indexTitle => 'الفهرس';

  @override
  String get fawasilTitle => 'الفواصل';

  @override
  String get aboutMushafTitle => 'عن هذا المصحف';

  @override
  String juzPage(String juz, String page) {
    return 'الجزء $juz · الصفحة $page';
  }

  @override
  String surahWord(String name) {
    return 'سورة $name';
  }

  @override
  String verseSelected(String number) {
    return 'الآية $number محددة';
  }

  @override
  String get tapVerseHint => 'اضغط أي آية لتحديدها';

  @override
  String pageOf(String page) {
    return 'الصفحة $page';
  }

  @override
  String get indexSearchHint => 'اسم السورة، أو رقم صفحة، أو ٢:٢٥٥';

  @override
  String get tabSurahs => 'السور';

  @override
  String get tabJuz => 'الأجزاء';

  @override
  String get tabPages => 'الصفحات';

  @override
  String get meccan => 'مكية';

  @override
  String get medinan => 'مدنية';

  @override
  String ayahCount(int n, String count) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$count آية',
      many: '$count آية',
      few: '$count آيات',
      two: 'آيتان',
      one: 'آية واحدة',
      zero: 'لا آيات',
    );
    return '$_temp0';
  }

  @override
  String juzLabel(String number) {
    return 'الجزء $number';
  }

  @override
  String juzStartsAt(String surah, String ayah) {
    return 'يبدأ من $surah $ayah';
  }

  @override
  String pageShort(String page) {
    return 'ص $page';
  }

  @override
  String get lastPosition => 'آخر موضع قراءة، يُحفظ تلقائيا';

  @override
  String get yourFawasil => 'فواصلك';

  @override
  String get fasilNew => 'فاصل جديد';

  @override
  String get fasilName => 'اسم الفاصل';

  @override
  String get fasilSaveHere => 'احفظ الموضع الحالي في فاصل';

  @override
  String fasilLastAt(String surah, String ayah, String page) {
    return 'آخر موضع: $surah $ayah · الصفحة $page';
  }

  @override
  String get fasilHint => 'لكل فاصل لون واسم، ويتحرك إلى آخر موضع قرأت عنده.';

  @override
  String get save => 'حفظ';

  @override
  String get cancel => 'إلغاء';

  @override
  String get delete => 'حذف';

  @override
  String get saved => 'تم الحفظ';

  @override
  String get noFawasil => 'لا توجد فواصل بعد';

  @override
  String get readingTitle => 'القراءة';

  @override
  String get keepScreenOn => 'إبقاء الشاشة مضاءة أثناء القراءة';

  @override
  String get aboutMushafIntro =>
      'كل نص في تبيان منقول من مصدر موثق، ولا يُعدَّل بأيدينا. وهذه مصادر المصحف في التطبيق:';

  @override
  String licenseLabel(String license) {
    return 'الرخصة: $license';
  }

  @override
  String versionShort(String version) {
    return 'الإصدار: $version';
  }

  @override
  String get reviewNotesTitle => 'مسائل معروضة على المراجعة';

  @override
  String reviewNotesBody(int n, String count) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$count موضع',
      many: '$count موضعًا',
      few: '$count مواضع',
      two: 'موضعان',
      one: 'موضع واحد',
      zero: 'لا مواضع',
    );
    return '$_temp0 يختلف فيها مصدرا النص (حدود جزأين، وأربعة مواضع في الرسم) معروضة على مراجع متخصص، ويتبع التطبيق نص تنزيل حتى يصدر القرار.';
  }

  @override
  String get mushafOpen => 'افتح المصحف';

  @override
  String get loadingLabel => 'جارٍ التحميل…';

  @override
  String hizbLabel(String number) {
    return 'الحزب $number';
  }

  @override
  String catchwordLabel(String word) {
    return 'الكلمة الأولى في الصفحة التالية: $word';
  }

  @override
  String get catchwordImageLabel => 'الكلمة الأولى في الصفحة التالية';

  @override
  String get tabHizb => 'الأحزاب';

  @override
  String get goToPage => 'انتقال إلى صفحة';

  @override
  String goToPageHint(String max) {
    return 'رقم الصفحة من ١ إلى $max';
  }

  @override
  String get goLabel => 'انتقال';

  @override
  String hizbStartsAt(String surah, String ayah) {
    return 'يبدأ من $surah $ayah';
  }

  @override
  String get selectionStart => 'بداية التحديد';

  @override
  String get selectionEnd => 'نهاية التحديد';

  @override
  String get servicesTitle => 'خدمات الآيات';

  @override
  String get markReading => 'قراءة';

  @override
  String get markReview => 'مراجعة';

  @override
  String get markHifz => 'حفظ';

  @override
  String get markTadabbur => 'تدبر';

  @override
  String autoFasil(String surah, String ayah) {
    return 'فاصل تلقائي عند $surah $ayah';
  }

  @override
  String markMoved(String mark, String surah, String ayah) {
    return '$mark: $surah $ayah';
  }

  @override
  String verseRange(String surah, String from, String to) {
    return '$surah $from–$to';
  }

  @override
  String versesCount(int n, String count) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$count آية',
      many: '$count آية',
      few: '$count آيات',
      two: 'آيتان',
      one: 'آية واحدة',
      zero: 'لا آيات',
    );
    return '$_temp0';
  }

  @override
  String get twoVerses => 'آيتان';

  @override
  String get markerStyleLabel => 'شكل فواصل الآيات';

  @override
  String get markerTraditional => 'الفاصل التقليدي';

  @override
  String get markerRosette => 'وردة';

  @override
  String get markerTheme => 'حسب الثيم';

  @override
  String get markerThemeHint =>
      '«حسب الثيم» يرسم فاصل الثيم نفسه، وفي «تبيان» وردتها.';

  @override
  String get themeLabel => 'الثيم';

  @override
  String get markerTintLabel => 'لون الفواصل';

  @override
  String get markerTintNone => 'بلا لون';

  @override
  String get reciteMode => 'وضع التسميع';

  @override
  String get autoScroll => 'التمرير التلقائي';

  @override
  String get resume => 'متابعة';

  @override
  String get downloadsSectionMushaf => 'المصاحف';

  @override
  String get downloadsSectionRecitations => 'القراءات الصوتية';

  @override
  String get downloadsSectionResources => 'الموارد';

  @override
  String downloadsOnDevice(String size) {
    return 'على الجهاز · $size ميجا';
  }

  @override
  String downloadsAvailable(String size) {
    return 'متاح للتحميل · $size ميجا';
  }

  @override
  String downloadsReciterOnDevice(String done, String total, String size) {
    return 'على الجهاز: $done / $total · $size ميجا';
  }

  @override
  String get downloadsAvailableShort => 'متاح للتحميل';

  @override
  String get downloadsGoesOn => 'يكمل التحميل في الخلفية';

  @override
  String get pause => 'إيقاف مؤقت';

  @override
  String get downloadsOpen => 'مركز التحميلات';

  @override
  String get downloadsOpenHint =>
      'المصاحف والقراءات الصوتية والموارد: ما على الجهاز وما يحمَّل وما هو متاح';

  @override
  String get audioDownloadResume => 'استئناف';

  @override
  String get slower => 'أبطأ';

  @override
  String get faster => 'أسرع';

  @override
  String get stopAutoScroll => 'إيقاف التمرير';

  @override
  String speedLabel(String speed) {
    return 'السرعة $speed';
  }

  @override
  String surahBannerTitle(String number, String name, String type) {
    return '($number) سورة $name · $type';
  }

  @override
  String surahBannerInfo(String count, String order, String after) {
    return 'آياتها $count · ترتيبها في النزول $order · نزلت بعد $after';
  }

  @override
  String surahBannerInfoFirst(String count, String order) {
    return 'آياتها $count · ترتيبها في النزول $order';
  }

  @override
  String quarterHizb(String number) {
    return 'ربع الحزب $number';
  }

  @override
  String halfHizb(String number) {
    return 'نصف الحزب $number';
  }

  @override
  String threeQuartersHizb(String number) {
    return 'ثلاثة أرباع الحزب $number';
  }

  @override
  String get coverTitle => 'القرآن الكريم';

  @override
  String get coverSubtitle => 'بالرسم العثماني';

  @override
  String get riwayaHafs => 'رواية حفص عن عاصم';

  @override
  String openingInfo(String type, String count, String number) {
    return '$type · آياتها $count · ترتيبها $number';
  }

  @override
  String revealedOrder(String order) {
    return 'ترتيبها في النزول $order';
  }

  @override
  String revealedAfter(String after) {
    return 'نزلت بعد $after';
  }

  @override
  String get multiSelect => 'تحديد عدة آيات';

  @override
  String get multiSelectHint =>
      'اسحب المقبضين، أو اقلب الصفحة واضغط آية لتمديد التحديد إليها';

  @override
  String get doneLabel => 'تم';

  @override
  String get markRemoved => 'أُزيل الفاصل';

  @override
  String get tabMarks => 'فواصل القراءة';

  @override
  String get noMarks => 'لا توجد فواصل بعد. اضغط على فاصل أي آية لتعليمها.';

  @override
  String get shareBrandColours => 'ألوان تبيان الأصلية';

  @override
  String get shareBrandColoursHint => 'بدلًا من ألوان الواجهة والمصحف الحالية';

  @override
  String get highlightDivineNames => 'تمييز لفظ الجلالة';

  @override
  String get highlightDivineNamesHint =>
      'تلوين «الله» و«رب» و«ربنا» في صفحات المصحف';

  @override
  String get tafsirTitle => 'التفسير والترجمة';

  @override
  String get tafsirSettings => 'إعدادات التفسير';

  @override
  String get tafsirFontLabel => 'خط التفسير';

  @override
  String get tafsirFontNaskh => 'نسخ عثمان طه';

  @override
  String get tafsirFontInterface => 'خط الواجهة';

  @override
  String get tafsirTextSize => 'حجم النص';

  @override
  String get tafsirShown => 'النصوص المعروضة';

  @override
  String get englishTafsirVisibilityLabel => 'التفسير الإنجليزي';

  @override
  String get tafsirNoneShown => 'كل النصوص مخفية. اختر نصا من إعدادات التفسير.';

  @override
  String get tafsirFootnotes => 'الحواشي';

  @override
  String get previousVerse => 'الآية السابقة';

  @override
  String get nextVerse => 'الآية التالية';

  @override
  String sourceVersion(String version) {
    return 'الإصدار $version';
  }

  @override
  String sourceRetrieved(String date) {
    return 'نسخة $date';
  }

  @override
  String get tafsirKashida => 'الشد بالكشيدة (تجربة)';

  @override
  String get tafsirKashidaHint =>
      'ضبط سطور التفسير بمدّ الحروف بدل توسيع المسافات. لا يمس الكلمات القرآنية بين الأقواس، والنسخ يأخذ النص الأصلي';

  @override
  String get copyText => 'نسخ النص';

  @override
  String get copied => 'تم النسخ';

  @override
  String get listen => 'استماع';

  @override
  String get reciterLabel => 'القارئ';

  @override
  String get murattal => 'مرتل';

  @override
  String get repeatLabel => 'عدد مرات التكرار';

  @override
  String get repeatForever => 'بلا توقف';

  @override
  String repeatTimes(String n) {
    return '×$n';
  }

  @override
  String get silenceLabel => 'سكوت بين كل تكرار والتالي (للترديد خلف القارئ)';

  @override
  String get silenceNone => 'بلا';

  @override
  String seconds(String n) {
    return '$n ث';
  }

  @override
  String get repeatVerse => 'كرر هذه الآية';

  @override
  String get playToEnd => 'أكمل السورة';

  @override
  String get sleepLabel => 'مؤقت النوم';

  @override
  String get sleepOff => 'إيقاف';

  @override
  String minutes(String n) {
    return '$n د';
  }

  @override
  String get sleepSurahEnd => 'نهاية السورة';

  @override
  String get followRecitation => 'تقليب الصفحات مع التلاوة';

  @override
  String get sajdahTimer => 'مؤقت سجدات التلاوة';

  @override
  String get sajdahTimerHint =>
      'عند آية السجدة يتوقف الشيخ وتظهر بطاقة بأدعية السجود وعدّ تنازلي، ثم تُستكمل التلاوة';

  @override
  String get sajdahTimerLength => 'مدة المؤقت';

  @override
  String get sajdahCardLabel => 'سجدة تلاوة';

  @override
  String get sajdahTapToContinue => 'اضغط للاستكمال';

  @override
  String get sajdahContinue => 'استكمال';

  @override
  String sajdahSecondsLeft(int seconds, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$n ثانية متبقية',
      many: '$n ثانية متبقية',
      few: '$n ثوانٍ متبقية',
      two: 'ثانيتان متبقيتان',
      one: 'ثانية واحدة متبقية',
      zero: 'لم تبقَ ثوانٍ',
    );
    return '$_temp0';
  }

  @override
  String get tapJumpLabel => 'عند لمس آية أثناء الاستماع';

  @override
  String get tapJumpHint => 'لمسة على آية في الصفحة تنقل الشيخ إليها';

  @override
  String get tapJumpVerseStart => 'من أول الآية';

  @override
  String get tapJumpFromWord => 'من الكلمة الملموسة';

  @override
  String get tapJumpNoTiming => 'هذه التلاوة لا تدعم الانتقال إلى آية';

  @override
  String get listenFromVerse => 'استمع من هذه الآية';

  @override
  String get audioDownloads => 'تحميل التلاوات';

  @override
  String get downloadAll => 'تحميل الكل';

  @override
  String get audioDownloaded => 'محملة على الجهاز';

  @override
  String get noTiming =>
      'هذه التلاوة بلا توقيت للآيات في هذه السورة: تُسمع كاملة بلا تظليل ولا تكرار آية';

  @override
  String get playerError =>
      'تعذر تشغيل التلاوة. تأكد من الاتصال بالإنترنت أو حمّل السورة.';

  @override
  String get playerSettings => 'إعدادات الاستماع';

  @override
  String get stopListening => 'إيقاف الاستماع';

  @override
  String repeatProgress(String done, String total) {
    return 'التكرار $done من $total';
  }

  @override
  String get audioCredit => 'التلاوات وتوقيت الآيات: mp3quran.net';

  @override
  String get tafsirAudioListen => 'استمع للتفسير';

  @override
  String get tafsirAudioListenSurah => 'استمع لتفسير السورة';

  @override
  String get translationAudioAfterVerse => 'الترجمة المسموعة بعد كل آية';

  @override
  String get translationAudioHint =>
      'تُسمع ترجمة كل آية بعد تلاوتها، حين تتوالى الآيات بلا تكرار';

  @override
  String clipTranslationOf(String ayah) {
    return 'ترجمة الآية $ayah';
  }

  @override
  String englishTafsirOffer(String title) {
    return 'تنزيل التفسير الإنجليزي: $title';
  }

  @override
  String get touchReading => 'القراءة اللمسية';

  @override
  String get touchReadingOn => 'القراءة اللمسية: المس الآية التي تقرؤها';

  @override
  String get editionOnDevice => 'على الجهاز';

  @override
  String editionNotDownloaded(String size) {
    return 'غير محمّل · $size ميجا';
  }

  @override
  String downloadAllEditions(String size) {
    return 'مركز التحميلات ($size ميجا متاحة)';
  }

  @override
  String get downloadInBackgroundNote =>
      'يمكنك الخروج من التطبيق: التحميل يكمل في الخلفية، ويصلك إشعار عند انتهائه.';

  @override
  String get notifDownloading => 'تحميل صفحات المصحف';

  @override
  String get notifComplete => 'اكتمل تحميل المصحف';

  @override
  String get notifFailed => 'تعذّر تحميل المصحف';

  @override
  String get notifPaused => 'التحميل متوقف مؤقتا';

  @override
  String get readInMadinaWhileDownloading =>
      'اقرأ في مصحف المدينة (الطبعة الحديثة) حتى يكتمل التحميل';

  @override
  String downloadingBanner(String name, String percent) {
    return 'يُحمَّل $name: $percent٪. تقرأ الآن في مصحف المدينة (الطبعة الحديثة)';
  }

  @override
  String get versePauseLabel => 'السكتة بين الآيات';

  @override
  String get versePauseAsRecorded => 'كما سُجّلت';

  @override
  String get versePauseSecond => 'ثانية';

  @override
  String get versePauseHalf => 'نصف ثانية';

  @override
  String get versePauseHint =>
      'يقصّر السكتات الطويلة بين الآيات دون المساس بالتلاوة نفسها';

  @override
  String get listenFromPage => 'استمع من أول الصفحة';

  @override
  String get repeatHint =>
      'إن لم تحدد مقطعًا تتكرر كل آية بهذا العدد ثم تليها التالية';

  @override
  String get homeTitle => 'الرئيسية';

  @override
  String get searchHint => 'ابحث في القرآن، أو اكتب «البقرة ٢٥٥»';

  @override
  String get searchIntro =>
      'اكتب كلمة أو أكثر من القرآن، بتشكيل أو دونه، أو اكتب موضعا مثل «٢:٢٥٥» أو «البقرة ٢٥٥».';

  @override
  String get searchGoTo => 'اذهب إلى الموضع';

  @override
  String get searchNothing => 'لا نتائج';

  @override
  String searchCount(int total, String count, int verseTotal, String verses) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$count موضع',
      many: '$count موضعًا',
      few: '$count مواضع',
      two: 'موضعان',
      one: 'موضع واحد',
      zero: 'لا مواضع',
    );
    String _temp1 = intl.Intl.pluralLogic(
      verseTotal,
      locale: localeName,
      other: 'في $verses آية',
      many: 'في $verses آية',
      few: 'في $verses آيات',
      two: 'في آيتين',
      one: 'في آية واحدة',
      zero: 'في لا آيات',
    );
    return '$_temp0 $_temp1';
  }

  @override
  String searchMore(int n, String count) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'و$count آية أخرى',
      many: 'و$count آية أخرى',
      few: 'و$count آيات أخرى',
      two: 'وآيتان أخريان',
      one: 'وآية أخرى',
      zero: '',
    );
    return '$_temp0، ضيّق البحث لرؤيتها';
  }

  @override
  String get searchHistory => 'عمليات البحث السابقة';

  @override
  String get searchClearHistory => 'مسح';

  @override
  String get continueReading => 'متابعة القراءة';

  @override
  String continueReadingAt(String surah, String ayah, String page) {
    return '$surah | الآية $ayah · صفحة $page';
  }

  @override
  String get openLabel => 'افتح';

  @override
  String get wordStudy => 'دراسة الكلمة';

  @override
  String get wordMeanings => 'معاني الكلمات';

  @override
  String get wordPickHint => 'اضغط على الكلمة التي تريد دراستها';

  @override
  String get wordStudyChoose => 'اختر كلمة من كلمات الآية';

  @override
  String get wordMeaningTitle => 'المعنى';

  @override
  String get wordNoMeaning => 'لا شرح لهذه الكلمة في «الميسر في غريب القرآن».';

  @override
  String get wordRootTitle => 'الجذر';

  @override
  String get wordLemma => 'المدخل المعجمي';

  @override
  String get wordNoRoot => 'لا جذر لهذه الكلمة في المدونة القرآنية.';

  @override
  String get wordNoCorpusData => 'لا بيانات لهذه الكلمة في المدونة القرآنية.';

  @override
  String get rootOccurrencesTitle => 'مواضع الجذر';

  @override
  String rootOccurrencesCount(String words, String verses) {
    return 'الكلمات: $words، الآيات: $verses';
  }

  @override
  String get verseNoMeanings =>
      'لا شرح لكلمات هذه الآية في «الميسر في غريب القرآن».';

  @override
  String wordStudyVerse(String surah, String ayah) {
    return '$surah، الآية $ayah';
  }

  @override
  String get downloadAllTitle => 'مركز التحميلات';

  @override
  String downloadAllCount(String done, String total) {
    return 'اكتمل $done من $total';
  }

  @override
  String get themeArtCredit =>
      'الزخارف: مشروع quran-assets من Quran.ws، تطوير Abdullah Ibeid (github.com/quran-ws/quran-assets). المنقول منها من المصاحف برخصة المشاع الإبداعي غير التجارية CC BY-NC-SA 4.0، وتصميمه لمجمع الملك فهد وناشرين آخرين.';

  @override
  String get khatmaTitle => 'الختمة';

  @override
  String get khatmaPrimaryLabel => 'الختمة الأساسية';

  @override
  String get khatmaOtherPlans => 'ختمات أخرى';

  @override
  String get khatmaSetPrimary => 'تعيين كأساسية';

  @override
  String get khatmaPause => 'إيقاف مؤقت';

  @override
  String get khatmaResume => 'استئناف';

  @override
  String get khatmaPaused => 'متوقفة مؤقتا';

  @override
  String get khatmaStepPlan => 'الخطة';

  @override
  String get khatmaStepSchedule => 'الجدول';

  @override
  String get khatmaStepReview => 'المراجعة';

  @override
  String khatmaLoadFailed(String error) {
    return 'تعذر تحميل بيانات إعداد الختمة: $error';
  }

  @override
  String khatmaCreateFailed(String error) {
    return 'تعذر إنشاء الختمة: $error';
  }

  @override
  String get khatmaKindLabel => 'نوع الخطة';

  @override
  String get khatmaSettings => 'إعدادات الختمة';

  @override
  String get khatmaTabPlan => 'الخطة';

  @override
  String get khatmaTabStats => 'الإحصاءات';

  @override
  String get khatmaStatsPageEquivalents => 'مكافئ الصفحات';

  @override
  String get khatmaStatsSessions => 'جلسات القراءة';

  @override
  String get khatmaStatsMinutes => 'دقائق القراءة';

  @override
  String get khatmaStatsNoActivity =>
      'لا توجد قراءة مسجلة لهذه الختمة في هذه الفترة.';

  @override
  String get khatmaStatsWeek => 'الأسبوع';

  @override
  String get khatmaStatsMonth => 'الشهر';

  @override
  String get khatmaStatsYear => 'السنة';

  @override
  String get khatmaStatsPreviousPeriod => 'الفترة السابقة';

  @override
  String get khatmaStatsNextPeriod => 'الفترة التالية';

  @override
  String khatmaReminderForPlan(String plan) {
    return 'الختمة: $plan';
  }

  @override
  String khatmaReminderMissedTitle(String plan) {
    return 'ما زال هناك وقت لورد $plan';
  }

  @override
  String khatmaReminderMissedBody(String from, String to) {
    return 'ورد اليوم: من صفحة $from إلى صفحة $to';
  }

  @override
  String khatmaReminderRecoveryTitle(String plan) {
    return 'خطة تعويض لطيفة لختمة $plan';
  }

  @override
  String khatmaReminderRecoveryBody(String from, String to) {
    return 'ورد اليوم من صفحة $from إلى صفحة $to. افتح الخطة للاطلاع على خيارات التعويض.';
  }

  @override
  String khatmaReminderTargetTitle(String plan) {
    return 'بقي يوم على موعد ختمة $plan';
  }

  @override
  String get khatmaReminderTargetBody => 'راجع تقدمك وخطتك قبل الموعد.';

  @override
  String khatmaReminderCompletedTitle(String plan) {
    return 'أتممت ختمة $plan';
  }

  @override
  String get khatmaReminderCompletedBody => 'أتممت الختمة. تقبّل الله منك.';

  @override
  String get khatmaReminderPlanLimit =>
      'يمكن تفعيل التذكيرات لعشرين ختمة مفتوحة كحد أقصى.';

  @override
  String get khatmaSaveSettings => 'حفظ الإعدادات';

  @override
  String khatmaSaveFailed(String error) {
    return 'تعذر حفظ إعدادات الختمة: $error';
  }

  @override
  String get khatmaAutoRestart => 'بدء الخطة من جديد عند إكمالها';

  @override
  String get khatmaReplan => 'تعديل الخطة';

  @override
  String get khatmaCatchUpToday => 'إنجاز الورد الفائت اليوم';

  @override
  String get khatmaCatchUpGradually => 'تعويض الورد تدريجيا';

  @override
  String get khatmaCompletionBody => 'أتممت هذه الختمة. تقبّل الله منك.';

  @override
  String get khatmaReusePlan => 'استخدام هذه الخطة مرة أخرى';

  @override
  String get khatmaKindFull => 'القرآن كاملا';

  @override
  String get khatmaKindPartial => 'نطاق محدد';

  @override
  String get khatmaKindDaily => 'ورد يومي';

  @override
  String get khatmaKindCustom => 'نطاق مخصص';

  @override
  String get khatmaPresetLabel => 'قالب جاهز';

  @override
  String get khatmaPresetCustom => 'خطة مخصصة';

  @override
  String get khatmaPresetMonth => 'ختمة في شهر';

  @override
  String khatmaPresetRamadan30(int n, String days) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$days يوم',
      many: '$days يومًا',
      few: '$days أيام',
      two: 'يومان',
      one: 'يوم واحد',
      zero: 'لا أيام',
    );
    return 'رمضان: $_temp0';
  }

  @override
  String get khatmaPresetRamadanTwice => 'ختمتان في رمضان';

  @override
  String get khatmaPresetBeforeLastTen => 'قبل العشر الأواخر';

  @override
  String get khatmaPresetWeekly => 'ختمة في أسبوع';

  @override
  String get khatmaPresetDailyJuz => 'جزء يوميا';

  @override
  String get khatmaFromSurah => 'من سورة';

  @override
  String get khatmaToSurah => 'إلى سورة';

  @override
  String get khatmaFromAyah => 'من آية';

  @override
  String get khatmaToAyah => 'إلى آية';

  @override
  String get khatmaRangeError => 'اختر آية بداية تسبق آية النهاية.';

  @override
  String get khatmaScheduleMode => 'طريقة توزيع الورد';

  @override
  String get khatmaScheduleAdaptive => 'متغير حسب التقدم';

  @override
  String get khatmaScheduleFixed => 'جدول ثابت';

  @override
  String get khatmaRestDays => 'أيام راحة (اختياري)';

  @override
  String get khatmaAtLeastOneReadingDay =>
      'اترك يوما واحدا على الأقل للقراءة كل أسبوع.';

  @override
  String get khatmaCountingMode => 'طريقة احتساب القراءة';

  @override
  String get khatmaCountAuto => 'احتساب تلقائي';

  @override
  String get khatmaCountAsk => 'السؤال في كل مرة';

  @override
  String get khatmaCountManual => 'عند تحديدها كمقروءة فقط';

  @override
  String get khatmaMakePrimary => 'جعلها الختمة الأساسية';

  @override
  String get khatmaUnitRub => 'ربع حزب';

  @override
  String khatmaReviewRange(String from, String to) {
    return 'النطاق: $from–$to';
  }

  @override
  String get khatmaNew => 'ختمة جديدة';

  @override
  String get khatmaEmptyTitle => 'لا ختمة الآن';

  @override
  String get khatmaEmptyBody =>
      'ضع خطة لختم المصحف: حدد موعد الختم أو مقدار الورد اليومي. والصفحات التي تقرؤها في المصحف تُحسب تلقائيا.';

  @override
  String get khatmaDefaultName => 'ختمتي';

  @override
  String get khatmaNameLabel => 'الاسم';

  @override
  String get khatmaByDate => 'حسب موعد الختم';

  @override
  String get khatmaByAmount => 'حسب الورد اليومي';

  @override
  String get khatmaEndDateLabel => 'موعد الختم';

  @override
  String get khatmaAmountLabel => 'المقدار في اليوم';

  @override
  String get khatmaUnitPage => 'صفحة';

  @override
  String get khatmaUnitJuz => 'جزء';

  @override
  String get khatmaUnitHizb => 'حزب';

  @override
  String khatmaAboutPerDay(int n, String count) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$count صفحة',
      many: '$count صفحة',
      few: '$count صفحات',
      two: 'صفحتين',
      one: 'صفحة واحدة',
      zero: 'لا صفحات',
    );
    return 'نحو $_temp0 في اليوم';
  }

  @override
  String khatmaDuration(int n, String count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$count يوم',
      many: '$count يومًا',
      few: '$count أيام',
      two: 'يومان',
      one: 'يوم واحد',
      zero: 'لا أيام',
    );
    return 'المدة: $_temp0، والختم يوم $date';
  }

  @override
  String khatmaEditionNote(String edition) {
    return 'بصفحات $edition';
  }

  @override
  String get khatmaReminder => 'تذكير يومي';

  @override
  String get khatmaReminderOff => 'بلا تذكير';

  @override
  String get khatmaStart => 'ابدأ الختمة';

  @override
  String get khatmaReplaceTitle => 'ختمة مفتوحة';

  @override
  String get khatmaReplaceBody =>
      'تُحذف الختمة الحالية وسجلها عند بدء ختمة جديدة.';

  @override
  String get khatmaToday => 'ورد اليوم';

  @override
  String khatmaPagesRange(String from, String to) {
    return 'من صفحة $from إلى صفحة $to';
  }

  @override
  String khatmaPagesCount(String count) {
    return 'عدد الصفحات: $count';
  }

  @override
  String get khatmaReadNow => 'اقرأ الآن';

  @override
  String get khatmaMarkRead => 'قرأته في مصحف آخر';

  @override
  String get khatmaTodayDone => 'ورد اليوم مقروء';

  @override
  String get khatmaContinue => 'تابع القراءة';

  @override
  String khatmaProgress(String done, int n, String total) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$total صفحة',
      many: '$total صفحة',
      few: '$total صفحات',
      two: 'صفحتين',
      one: 'صفحة واحدة',
      zero: 'لا صفحات',
    );
    return '$done من $_temp0';
  }

  @override
  String khatmaDaysLeft(String count) {
    return 'الأيام الباقية: $count';
  }

  @override
  String khatmaEnds(String date) {
    return 'الختم يوم $date';
  }

  @override
  String khatmaBehindTitle(String count) {
    return 'صفحات من الأيام الماضية: $count';
  }

  @override
  String get khatmaBehindBody =>
      'ينضم ما فات إلى ورد اليوم. اختر إنجازه اليوم، أو تعويضه تدريجيا، أو توزيع الباقي، أو مد موعد الختم.';

  @override
  String get khatmaSpread => 'وزّعها على الأيام الباقية';

  @override
  String get khatmaExtend => 'أخّر موعد الختم';

  @override
  String get khatmaComplete => 'اكتملت الختمة';

  @override
  String khatmaCompletedOn(String date) {
    return 'اكتملت يوم $date';
  }

  @override
  String get khatmaPast => 'ختمات سابقة';

  @override
  String get khatmaDelete => 'حذف الختمة';

  @override
  String get khatmaDeleteBody => 'يُحذف سجل هذه الختمة.';

  @override
  String get khatmaTileStart => 'ابدأ';

  @override
  String khatmaTilePages(String count) {
    return 'ورد اليوم: $count';
  }

  @override
  String get khatmaReminderTitle => 'ورد الختمة';

  @override
  String khatmaReminderBody(String from, String to) {
    return 'ورد اليوم: من صفحة $from إلى صفحة $to';
  }

  @override
  String get khatmaReminderChannel => 'تذكير الختمة';

  @override
  String get homeTodayTitle => 'اليوم';

  @override
  String get widgetNoKhatma => 'ابدأ ختمة في تبيان';

  @override
  String get reportsTitle => 'تقارير القراءة';

  @override
  String get reportsWeek => 'آخر ٧ أيام';

  @override
  String get reportsMonth => 'آخر ٣٠ يوما';

  @override
  String get reportsDays => 'أيام القراءة';

  @override
  String get reportsPages => 'الصفحات';

  @override
  String get reportsReadingMinutes => 'دقائق القراءة';

  @override
  String get reportsListeningMinutes => 'دقائق الاستماع';

  @override
  String get reportsEmpty => 'تظهر هنا قراءتك واستماعك تلقائيا.';

  @override
  String get reportsDayRead => 'يوم فيه قراءة أو استماع';

  @override
  String get streakReadToday => 'قرأت اليوم.';

  @override
  String get streakWelcome => 'مرحبا بعودتك. تابع من حيث وقفت.';

  @override
  String readDaysOfLast(String read, int n, String days) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'آخر $days يوم',
      many: 'آخر $days يومًا',
      few: 'آخر $days أيام',
      two: 'آخر يومين',
      one: 'آخر يوم',
      zero: 'لا أيام',
    );
    return 'قرأت $read من $_temp0';
  }

  @override
  String get streakNotesToggle => 'رسائل الاستمرار';

  @override
  String get streakNotesHint =>
      'ملاحظات هادئة عن قراءتك، لا تعدّ الأيام المتتالية ولا تعرض الأيام الفائتة.';

  @override
  String get journalTitle => 'دفتر التدبر';

  @override
  String get journalSearch => 'ابحث في ملاحظاتك';

  @override
  String get journalEmpty =>
      'لا ملاحظات بعد. اضغط مطولا على آية في المصحف واختر «ملاحظة تدبر».';

  @override
  String get journalNoMatch => 'لا ملاحظات فيها هذه الكلمات.';

  @override
  String get journalAdd => 'ملاحظة تدبر';

  @override
  String get journalHint => 'اكتب ملاحظتك على الآية';

  @override
  String get journalEdit => 'تعديل';

  @override
  String get journalOpenVerse => 'افتح الآية';

  @override
  String journalVerseRef(String surah, String ayah) {
    return 'سورة $surah | آية $ayah';
  }

  @override
  String get journalSaved => 'حُفظت الملاحظة';

  @override
  String get journalEarlier => 'ملاحظاتك على هذه الآية';

  @override
  String get elderlyMode => 'وضع كبار السن';

  @override
  String get elderlyModeHint =>
      'خط أكبر، وأزرار أكبر بأسمائها، وألوان أوضح، وصفحة رئيسية فيها المهم فقط، وصفحة المصحف بأكبر حجم، وانتقالات أهدأ';

  @override
  String get searchModeWords => 'بالكلمات';

  @override
  String get searchModeMeaning => 'بالمعنى';

  @override
  String get searchMeaningHint => 'اكتب فكرة أو سؤالا بكلماتك';

  @override
  String get searchMeaningIntro =>
      'اكتب فكرة بكلماتك، بالعربية أو بالإنجليزية، مثل «الصبر على البلاء» أو «بر الوالدين»، فتظهر الآيات التي يتناولها معناها في التفسير الميسر والترجمتين. تظهر كل آية بنصها، ومعها النص الذي طابق كما هو من مصدره.';

  @override
  String searchMatchedIn(String source) {
    return 'طابق في: $source';
  }

  @override
  String searchMeaningCount(int n, String count) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$count آية',
      many: '$count آية',
      few: '$count آيات',
      two: 'آيتان',
      one: 'آية واحدة',
      zero: 'لا آيات',
    );
    return '$_temp0';
  }

  @override
  String get semanticPackName => 'حزمة البحث بالمعنى';

  @override
  String semanticPackOffer(String size) {
    return 'البحث الآن بالكلمات داخل نصوص المعاني. نزّل حزمة البحث بالمعنى (نحو $size ميجا) ليجد البحث الآيات بمعناها وإن اختلفت الكلمات، دون اتصال.';
  }

  @override
  String get semanticPackDownload => 'تنزيل الحزمة';

  @override
  String semanticPackDownloading(String percent) {
    return 'يُنزَّل: $percent٪';
  }

  @override
  String get semanticPackVerifying => 'يُتحقَّق من الحزمة ويُثبَّت…';

  @override
  String get semanticPackFailed => 'تعذّر التنزيل. حاول مرة أخرى.';

  @override
  String get semanticPackLoading => 'يُجهَّز البحث بالمعنى…';

  @override
  String get semanticPackError =>
      'تعذّر فتح حزمة البحث بالمعنى، فالبحث الآن بالكلمات.';

  @override
  String get semanticResultsNote =>
      'نتائج تقريبية مرتبة بقرب المعنى. راجع الآية في موضعها وفي تفسيرها.';

  @override
  String verseLabel(String surah, String ayah) {
    return 'سورة $surah، الآية $ayah';
  }

  @override
  String pageLabelFull(String page, String surah) {
    return 'الصفحة $page، $surah';
  }

  @override
  String get markThisVerse => 'ضع علامة القراءة عند هذه الآية أو أزلها';

  @override
  String loadingPage(String page) {
    return 'تُحمَّل الصفحة $page';
  }

  @override
  String get clearSearch => 'مسح البحث';

  @override
  String get previousPageNumber => 'الصفحة السابقة';

  @override
  String get nextPageNumber => 'الصفحة التالية';

  @override
  String get showMenus => 'إظهار القوائم';

  @override
  String get hideMenus => 'إخفاء القوائم';

  @override
  String downloadSurah(String surah) {
    return 'تنزيل سورة $surah';
  }

  @override
  String retryDownloadSurah(String surah) {
    return 'أعد تنزيل سورة $surah';
  }

  @override
  String deleteSurahDownload(String surah) {
    return 'سورة $surah منزّلة. احذفها';
  }

  @override
  String downloadingSurah(String surah) {
    return 'تُنزَّل سورة $surah';
  }

  @override
  String verseCounter(String current, String total) {
    return 'الآية $current من $total';
  }

  @override
  String downloadPercentSpoken(String percent) {
    return 'اكتمل $percent٪ من التحميل';
  }

  @override
  String get hifzTitle => 'الحفظ';

  @override
  String get hifzTileNote => 'المراجعة والتسميع';

  @override
  String get hifzToday => 'مراجعة اليوم';

  @override
  String get hifzNothingDue => 'لا مراجعة مستحقة اليوم.';

  @override
  String get hifzNothingDueHint =>
      'سمّع صفحة أو ربعا أو سورة ثم قيّم تسميعك، فتدخل المراجعة المتباعدة.';

  @override
  String get hifzStartTest => 'ابدأ تسميعا';

  @override
  String get hifzMap => 'خريطة الحفظ';

  @override
  String get hifzMapHint =>
      'كل صفحة ملوّنة بقوة حفظها، ومعها علامة تقرأ دون ألوان.';

  @override
  String get hifzAllUnits => 'كل وحدات المراجعة';

  @override
  String get hifzDueToday => 'مستحقة اليوم';

  @override
  String hifzDueOn(String date) {
    return 'موعدها $date';
  }

  @override
  String hifzQuarter(String number) {
    return 'الربع $number';
  }

  @override
  String get hifzUnitPage => 'صفحة';

  @override
  String get hifzUnitQuarter => 'ربع';

  @override
  String get hifzUnitSurah => 'سورة';

  @override
  String get hifzChooseUnit => 'ماذا تسمّع؟';

  @override
  String hifzNumberRange(String max) {
    return 'الرقم، من ١ إلى $max';
  }

  @override
  String get hifzBegin => 'ابدأ';

  @override
  String get hifzRemove => 'احذف من المراجعة';

  @override
  String get revealNextWord => 'الكلمة التالية';

  @override
  String get revealNextVerse => 'الآية التالية';

  @override
  String get revealAll => 'الكل';

  @override
  String get endRecite => 'إنهاء التسميع';

  @override
  String get verseRemembered => 'حفظت';

  @override
  String get verseMissed => 'أخطأت';

  @override
  String testCounts(String remembered, String missed) {
    return 'حفظت $remembered · أخطأت $missed';
  }

  @override
  String get revealByLine =>
      'لا مواضع لكلمات هذه الآية في هذه الطبعة، فتُكشف سطرا سطرا.';

  @override
  String get gradeUnit => 'قيّم';

  @override
  String get gradeTitle => 'كيف كان تسميعك؟';

  @override
  String get gradeSuggested => 'الاختيار المقترح من نتائج الآيات';

  @override
  String get gradeAgain => 'أعِدها';

  @override
  String get gradeHard => 'صعبة';

  @override
  String get gradeGood => 'جيدة';

  @override
  String get gradeEasy => 'سهلة';

  @override
  String gradeSaved(String date) {
    return 'المراجعة القادمة: $date';
  }

  @override
  String get similarVerses => 'المتشابهات';

  @override
  String similarCount(String count) {
    return 'متشابهات ($count)';
  }

  @override
  String get similarThisVerse => 'الآية';

  @override
  String get similarFollowing => 'والآية بعدها';

  @override
  String get strengthNone => 'لم يُحفظ';

  @override
  String get strengthWeak => 'ضعيف';

  @override
  String get strengthFair => 'متوسط';

  @override
  String get strengthGood => 'جيد';

  @override
  String get strengthStrong => 'متقن';

  @override
  String get mapPages => 'الصفحات';

  @override
  String get mapSurahs => 'السور';

  @override
  String get mapZoomIn => 'تكبير';

  @override
  String get mapZoomOut => 'تصغير';

  @override
  String mapCell(String name, String strength) {
    return '$name: $strength';
  }

  @override
  String get tajweedColors => 'تلوين أحكام التجويد';

  @override
  String get tajweedColorsHint =>
      'تلوين الحروف التي يقع عليها الحكم فقط، بالألوان التي تختارها';

  @override
  String get tajweedLegend => 'مفتاح ألوان التجويد';

  @override
  String get tajweedRuleColors => 'لون كل حكم';

  @override
  String get tajweedNoColor => 'بلا لون';

  @override
  String get tajweedReset => 'إعادة الألوان الافتراضية';

  @override
  String tajweedPickColor(String rule) {
    return 'لون «$rule»';
  }

  @override
  String get tajweedSourceNote =>
      'مواضع الأحكام من بيانات quran-tajweed (Collin Fair، رخصة CC BY 4.0)، وهي مولّدة آليا ولم يراجعها متخصص بعد. وموضع الحرف داخل الكلمة تقديري، وفي الشمرلي حدود بعض الكلمات تقديرية أيضا.';

  @override
  String get tajweedLegendHint =>
      'اضغط مطولا على زر التلوين في الصفحة لعرض هذا المفتاح.';

  @override
  String get tajweedHueCrimson => 'أحمر داكن';

  @override
  String get tajweedHueRed => 'أحمر';

  @override
  String get tajweedHueOrange => 'برتقالي';

  @override
  String get tajweedHueGold => 'ذهبي';

  @override
  String get tajweedHueGreen => 'أخضر';

  @override
  String get tajweedHueLightGreen => 'أخضر فاتح';

  @override
  String get tajweedHueTeal => 'فيروزي';

  @override
  String get tajweedHueBlue => 'أزرق';

  @override
  String get tajweedHuePurple => 'بنفسجي';

  @override
  String get tajweedHuePink => 'وردي';

  @override
  String get tajweedHueGrey => 'رمادي';

  @override
  String get tajweedHueViolet => 'ليلكي';

  @override
  String get tajweedHueAmber => 'كهرماني';

  @override
  String get tajweedNoDataRiwaya =>
      'لا تلوين للتجويد في مصاحف الروايات (ورش وقالون والدوري وشعبة): لا توجد بعد بيانات أحكام موثوقة لهذه الروايات، ولا نضع أحكاما بلا مصدر. التلوين يعمل في مصاحف حفص.';

  @override
  String get tajweedHamzatWasl => 'همزة الوصل';

  @override
  String get tajweedLamShamsiyyah => 'اللام الشمسية';

  @override
  String get tajweedSilent => 'الحروف التي لا تُنطق';

  @override
  String get tajweedMadd2 => 'المد الطبيعي (حركتان)';

  @override
  String get tajweedMadd246 => 'المد العارض واللين (٢ أو ٤ أو ٦ حركات)';

  @override
  String get tajweedMaddMuttasil => 'المد المتصل (٤ أو ٥ حركات)';

  @override
  String get tajweedMaddMunfasil => 'المد المنفصل (٤ أو ٥ حركات)';

  @override
  String get tajweedMadd6 => 'المد اللازم (٦ حركات)';

  @override
  String get tajweedGhunnah => 'الغنة';

  @override
  String get tajweedIkhfa => 'الإخفاء';

  @override
  String get tajweedIkhfaShafawi => 'الإخفاء الشفوي';

  @override
  String get tajweedIqlab => 'الإقلاب';

  @override
  String get tajweedIdghaamGhunnah => 'الإدغام بغنة';

  @override
  String get tajweedIdghaamNoGhunnah => 'الإدغام بلا غنة';

  @override
  String get tajweedIdghaamShafawi => 'الإدغام الشفوي';

  @override
  String get tajweedIdghaamMutajanisayn => 'إدغام المتجانسين';

  @override
  String get tajweedIdghaamMutaqaribayn => 'إدغام المتقاربين';

  @override
  String get tajweedQalqalah => 'القلقلة';

  @override
  String get editionWarsh => 'مصحف المدينة برواية ورش عن نافع';

  @override
  String get editionQalun => 'مصحف المدينة برواية قالون عن نافع';

  @override
  String get editionDouri => 'مصحف المدينة برواية الدوري عن أبي عمرو';

  @override
  String get editionShubah => 'مصحف المدينة برواية شعبة عن عاصم';

  @override
  String get riwayaWarsh => 'رواية ورش عن نافع';

  @override
  String get riwayaQalun => 'رواية قالون عن نافع';

  @override
  String get riwayaDouri => 'رواية الدوري عن أبي عمرو';

  @override
  String get riwayaShubah => 'رواية شعبة عن عاصم';

  @override
  String get riwayatTitle => 'مصاحف الروايات';

  @override
  String get riwayaEditionDesc =>
      'صفحات مصحف المدينة لهذه الرواية من مجمع الملك فهد، بعدّ آياتها وترقيمها. التفسير والترجمة والفواصل تُربط بالآيات المقابلة في عدّ حفص.';

  @override
  String get riwayaGaps =>
      'في مصاحف الروايات: لا تظليل للكلمة أثناء التلاوة (تلاواتها موقّتة بالآيات وحدها)، ولا يظهر الحزب وأرباعه في الإطار (الصفحة نفسها تحمل علاماتها المطبوعة).';

  @override
  String get riwayaNoWordBoxes =>
      'صفحات هذه الرواية المنزّلة لا تحمل مربعات الكلمات، فلا تلوين فيها للفظ الجلالة ولا اختيار للكلمة. تحملها حزمة الصفحات الأحدث.';

  @override
  String get riwayaWordNoStudy =>
      'لا دراسة لهذه الكلمة هنا: دراسة الكلمة مبنية على كلمات رواية حفص، وتُفتح لكلمة الرواية حين تكون هي كلمة حفص نفسها في الآية نفسها، بحروفها.';

  @override
  String riwayaTafsirNote(
    String ayah,
    String surah,
    String riwaya,
    String hafs,
  ) {
    return 'الآية $ayah من سورة $surah في $riwaya يقابلها في عدّ حفص: $hafs. التفسير والترجمة ونص الآية أدناه بعدّ حفص وروايته.';
  }

  @override
  String get riwayaNoHafs => 'لا تقابلها آية في عدّ حفص';

  @override
  String hafsVerseOne(String number) {
    return 'الآية $number';
  }

  @override
  String hafsVerseRange(String from, String to) {
    return 'الآيات $from إلى $to';
  }

  @override
  String riwayaVerseText(String riwaya) {
    return 'نص الآية في $riwaya';
  }

  @override
  String riwayaRecitersNote(String riwaya) {
    return 'تلاوات $riwaya';
  }

  @override
  String get reciterPhotosTitle => 'صور القرّاء';

  @override
  String get reciterPhotosNote =>
      'من ويكيميديا كومنز، مصغّرة ومقصوصة في تبيان.';

  @override
  String reciterPhotoCredit(String author, String license) {
    return '$author، $license';
  }

  @override
  String get unknownAuthor => 'مصوّر غير معروف';

  @override
  String get otherRiwayaReciters => 'قرّاء الروايات الأخرى';

  @override
  String get otherRiwayaHint =>
      'تُختار تلاواتهم من مصحف روايتهم، لأن ترقيم آياتها يختلف.';

  @override
  String reciterOfRiwaya(String riwaya) {
    return 'رواية $riwaya';
  }

  @override
  String get copyVerses => 'نسخ';

  @override
  String get shareVerseText => 'مشاركة نصًا';

  @override
  String get shareVerseImage => 'مشاركة كصورة';

  @override
  String get sharePreparing => 'جارٍ تجهيز الصورة…';

  @override
  String get shareImageFailed => 'تعذر تجهيز الصورة';

  @override
  String get shareSurahImage => 'مشاركة السورة كصورة';

  @override
  String get shareImageTitle => 'مشاركة كصورة';

  @override
  String shareImageOf(String n, String total) {
    return '$n من $total';
  }

  @override
  String get sharePreviousImage => 'الصورة السابقة';

  @override
  String get shareNextImage => 'الصورة التالية';

  @override
  String get shareButton => 'مشاركة';

  @override
  String get saveToPhotos => 'حفظ في الصور';

  @override
  String get savedToPhotos => 'حُفظت الصور';

  @override
  String savedToFolder(String folder) {
    return 'حُفظت الصور في $folder';
  }

  @override
  String get saveToPhotosFailed => 'تعذر الحفظ في الصور';

  @override
  String get shareImageRiwayaUnavailable =>
      'نص هذه الرواية وخطها غير متاحين على هذا الجهاز بعد، فلا تُشارك آياتها صورةً. نزّل صفحات الرواية أولا.';

  @override
  String get backupTitle => 'النسخ الاحتياطي';

  @override
  String get backupExport => 'حفظ نسخة احتياطية';

  @override
  String get backupExportHint =>
      'ملف واحد فيه فواصلك وعلاماتك وموضع القراءة والختمة والتقارير وملاحظات التدبر وتقدم الحفظ، وإعداداتك. احتفظ به أو أرسله لنفسك.';

  @override
  String get backupImport => 'استعادة من نسخة';

  @override
  String get backupImportHint =>
      'يدمج النسخة مع ما على جهازك: لا يحذف شيئا، ويأخذ الأحدث عند التعارض، ويعيد الإعدادات كما كانت في النسخة.';

  @override
  String backupDone(String added, String updated) {
    return 'تمت الاستعادة: $added جديد، $updated محدَّث';
  }

  @override
  String get backupInvalid => 'هذا الملف ليس نسخة احتياطية من تبيان';

  @override
  String get backupFailed => 'تعذرت العملية';

  @override
  String get playbackSpeedLabel => 'سرعة التلاوة';

  @override
  String playbackSpeedValue(String value) {
    return '×$value';
  }

  @override
  String get storageTitle => 'التخزين والتنزيلات';

  @override
  String get storageOpen => 'التخزين والتنزيلات';

  @override
  String get storageOpenHint =>
      'ما نُزِّل على الجهاز وأحجامه، وحذف ما لا تحتاجه';

  @override
  String get storageIntro =>
      'كل ما نزّله التطبيق على جهازك. يمكنك حذف أي منها وتنزيله لاحقا. بياناتك (الفواصل، الختمة، الملاحظات) لا تظهر هنا ولا تُمس.';

  @override
  String storageTotal(String size) {
    return 'المجموع: $size';
  }

  @override
  String get storageBundled => 'مضمّن مع التطبيق';

  @override
  String storageSize(String mb) {
    return '$mb ميجا';
  }

  @override
  String storageAudioOf(String name) {
    return 'تلاوات $name';
  }

  @override
  String get storageSemantic => 'حزمة البحث بالمعنى';

  @override
  String get storageTiming => 'تحديثات توقيت التلاوة';

  @override
  String get storagePartial => 'تنزيلات غير مكتملة';

  @override
  String get storagePartialHint => 'بقايا تنزيلات توقفت؛ حذفها آمن';

  @override
  String get storageClean => 'تنظيف';

  @override
  String storageDeleteAsk(String name, String size) {
    return 'حذف $name ($size)؟';
  }

  @override
  String storageFreed(String size) {
    return 'تم تحرير $size';
  }

  @override
  String get storageEmpty => 'لا شيء منزَّل غير ما يأتي مع التطبيق';

  @override
  String get storageUnknown => 'ملفات أخرى';

  @override
  String get asbabTitle => 'أسباب النزول';

  @override
  String asbabCount(String count) {
    return 'أسباب النزول ($count)';
  }

  @override
  String bookCitationTahqiq(String name) {
    return 'تحقيق $name';
  }

  @override
  String bookCitationVolume(String volume) {
    return 'ج $volume';
  }

  @override
  String bookCitationPage(String page) {
    return 'ص $page';
  }

  @override
  String bookCitationPages(String from, String to) {
    return 'ص $from–$to';
  }

  @override
  String storageBook(String title) {
    return 'كتاب «$title»';
  }

  @override
  String get storageBooksAvailable => 'كتب يمكن تنزيلها';

  @override
  String get bookPackDownload => 'تنزيل';

  @override
  String get munasabatTitle => 'المناسبات';

  @override
  String munasabatCount(String count) {
    return 'المناسبات ($count)';
  }

  @override
  String get wujuhTitle => 'الوجوه والنظائر';

  @override
  String get bookKindTafsir => 'تفسير';

  @override
  String bookEntryVerses(String from, String to) {
    return 'الآيات $from–$to';
  }

  @override
  String get continuousView => 'عرض متتالي';

  @override
  String get underVerseTitle => 'ما يظهر تحت الآية';

  @override
  String get underArabicOnly => 'عربي فقط';

  @override
  String get underTranslation => 'عربي مع ترجمة';

  @override
  String get underTranslationHint => 'اختر ترجمة أو اثنتين';

  @override
  String get underMuyassar => 'عربي مع التفسير الميسر';

  @override
  String get splitTranslationLabel => 'بجانب الصفحة على الشاشات العريضة';

  @override
  String get splitTranslationHint =>
      'الصفحة كما هي، وبجانبها ما اخترته لآياتها';

  @override
  String get nextSurah => 'السورة التالية';

  @override
  String get previousSurah => 'السورة السابقة';

  @override
  String get hafsTextNote => 'النص هنا برواية حفص';

  @override
  String get twoPageSpread => 'صفحتان متقابلتان';

  @override
  String get twoPageSpreadHint =>
      'على الشاشات العريضة في الوضع الأفقي، كالمصحف المفتوح';

  @override
  String get oneVerse => 'آية آية';

  @override
  String get oneVerseHint => 'آية واحدة في كل شاشة بخط كبير، والجهاز بالعرض';

  @override
  String get oneVerseAutoOff => 'الانتقال التلقائي متوقف. اضغط لتشغيله';

  @override
  String oneVerseAutoOn(int n, String seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'كل $seconds ثانية',
      many: 'كل $seconds ثانية',
      few: 'كل $seconds ثوانٍ',
      two: 'كل ثانيتين',
      one: 'كل ثانية',
      zero: 'فورًا',
    );
    return 'ينتقل للآية التالية $_temp0. اضغط للتغيير';
  }

  @override
  String get oneVerseAutoShort => 'تلقائي';

  @override
  String secondsShort(String n) {
    return '$n ث';
  }

  @override
  String get searchScopeAll => 'كل المصحف';

  @override
  String get searchScopeJuz => 'في جزء';

  @override
  String get searchScopeSurah => 'في سورة';

  @override
  String get whatsNewTitle => 'ما الجديد';

  @override
  String get whatsNewDone => 'حسنا';

  @override
  String get newOneVerse => 'آية آية';

  @override
  String get newOneVerseBody =>
      'زر تحت الصفحة يقلب الموبايل بالعرض ويعرض آية واحدة بخط كبير، مع انتقال تلقائي اختياري.';

  @override
  String get newUnderVerse => 'الترجمة تحت الآية';

  @override
  String get newUnderVerseBody =>
      'العرض المتتالي من أدوات الصفحة: ترجمة أو اثنتان أو التفسير الميسر تحت كل آية.';

  @override
  String get newShare => 'النسخ والمشاركة';

  @override
  String get newShareBody =>
      'انسخ الآية أو شاركها نصا أو صورة بتصميم تبيان، ولو امتدت على صفحات. واضغط مطولا على اسم السورة أعلى الصفحة لمشاركة السورة كلها صورا.';

  @override
  String get newSpread => 'صفحتان متقابلتان';

  @override
  String get newSpreadBody =>
      'على التابلت والشاشات العريضة بالعرض يظهر المصحف مفتوحا.';

  @override
  String get newWidgets => 'أدوات الشاشة';

  @override
  String get newWidgetsBody =>
      'ورد الختمة واختصارات القراءة والاستماع على الشاشة الرئيسية، وزر استماع في الإعدادات السريعة.';

  @override
  String get newBackup => 'النسخة الاحتياطية';

  @override
  String get newBackupBody =>
      'احفظ فواصلك وختمتك وملاحظاتك وإعداداتك في ملف واحد، واستعدها على أي جهاز.';

  @override
  String get carContinue => 'تابع من موضع القراءة';

  @override
  String get carReciters => 'القراء';

  @override
  String get pagesMapCurrent => 'الصفحة الحالية';

  @override
  String get pagesMapRead => 'مقروءة في الختمة';

  @override
  String get pagesMapMarked => 'فيها فاصل';

  @override
  String pagesRange(String first, String last) {
    return 'ص $first–$last';
  }

  @override
  String pagesMapJuzRead(String read, String total) {
    return 'قُرئ $read من $total';
  }

  @override
  String get focusModeTitle => 'وضع التركيز';

  @override
  String get focusModeHint =>
      'الصفحة وحدها بلا إطار ولا شيء تحتها، وشريط رفيع في الأعلى';

  @override
  String get focusToolsLabel => 'إظهار الأدوات';

  @override
  String get focusToolsButton => 'الزرار البسيط';

  @override
  String get focusToolsButtonHint => 'ثلاثة أزرار صغيرة في الشريط العلوي';

  @override
  String get focusToolsMenu => 'القائمة';

  @override
  String get focusToolsMenuHint =>
      'ضغطة مطولة على الصفحة تفتح نافذة فيها كل الأدوات';

  @override
  String get pageTurnLabel => 'تأثير قلب الصفحة';

  @override
  String get pageTurnNormal => 'طبيعي';

  @override
  String get pageTurnNormalHint => 'تنزلق الصفحة جانبًا';

  @override
  String get pageTurnCurl => 'قلب ثلاثي الأبعاد';

  @override
  String get pageTurnCurlHint => 'تنقلب الصفحة كورق المصحف';

  @override
  String get pageTurnBend => 'انحناء الورقة';

  @override
  String get pageTurnBendHint => 'تلتف الصفحة مع إصبعك كالورق ويظهر ظهرها';

  @override
  String get pageTurnFold => 'انحناء خفيف';

  @override
  String get pageTurnFoldHint => 'ينثني طرف الصفحة مع إصبعك، أخف على الجهاز';

  @override
  String get pageTurnFade => 'تلاشي';

  @override
  String get pageTurnFadeHint => 'تظهر الصفحة التالية فوق السابقة بهدوء';

  @override
  String get pageFillLabel => 'ملء الشاشة';

  @override
  String get pageFillLines => 'توزيع السطور';

  @override
  String get pageFillLinesHint => 'كل سطر بعرض الشاشة، والسطور موزعة على طولها';

  @override
  String get pageFillStretch => 'توزيع + مط خفيف';

  @override
  String get pageFillStretchHint => 'ومط أفقي حتى ١٢٪ حيث تملأ الصفحة الطول';

  @override
  String get pageFillFull => 'مط كامل';

  @override
  String get pageFillFullHint =>
      'تملأ الصفحة الشاشة طولا وعرضا، ويتغير بذلك شكل الحروف';

  @override
  String get playerStyleLabel => 'شكل المشغل';

  @override
  String get playerStyleAuto => 'تلقائي';

  @override
  String get playerStyleAutoHint =>
      'العادي في القراءة، وشكل وضع التركيز مع وضع التركيز';

  @override
  String get playerStyleNormal => 'العادي';

  @override
  String get playerStylePill => 'وضع التركيز';

  @override
  String get playerStylePillHint => 'صغير وشفاف، فيه تشغيل وإعدادات وإغلاق';

  @override
  String get playerStyleButton => 'الزر الواحد';

  @override
  String get playerStyleButtonHint =>
      'زر صغير: ضغطة للتشغيل والإيقاف، وضغطة مطولة للقائمة';

  @override
  String get focusExit => 'إنهاء التركيز';

  @override
  String get focusTools => 'الأدوات';

  @override
  String get focusShowTools => 'إظهار الأدوات';

  @override
  String get focusHideTools => 'إخفاء الأدوات';

  @override
  String get focusMenus => 'القوائم';

  @override
  String get focusPageTools => 'أدوات الصفحة';

  @override
  String get playerFull => 'المشغل كاملًا';

  @override
  String get tajweedMarksSubtitle => 'أحكام التجويد: ألوانها ومواضعها';

  @override
  String get tajweedMarksHint =>
      'كل حكم بلونه في صفحات المصحف، ومواضعه في المصحف كله. اضغط الحكم لتعرض مواضعه، واضغط الموضع لتفتح صفحته.';

  @override
  String tajweedRuleCount(String verses, String letters) {
    return 'الآيات: $verses · الحروف الملونة: $letters';
  }

  @override
  String tajweedPlaceAt(String surah, String ayah, String page) {
    return '$surah $ayah · الصفحة $page';
  }

  @override
  String get tajweedIndexColorNote =>
      'الألوان كما تُرسم في الصفحات الآن: اختيارك، أو اللون الافتراضي. وتُغيَّر من «شكل المصحف».';

  @override
  String get tajweedIndexLoadError => 'تعذرت قراءة مواضع هذا الحكم.';

  @override
  String get tajweedMarksInkNote =>
      'حين يقع الحكم على علامة وحدها (مثل الميم الصغيرة) تبقى العلامة هنا بلون النص: الخط لا يلوّن العلامة دون جزء من حرفها. وتظهر ملونة في صفحة المصحف.';

  @override
  String get assistantTitle => 'المساعد';

  @override
  String get assistantIntro => 'المساعدة في استخدام التطبيق والمصحف';

  @override
  String get tajweedMarksTitle => 'علامات التجويد';

  @override
  String get moreLabel => 'المزيد';

  @override
  String wirdIndicator(String read, String total) {
    return 'ورد اليوم: $read من $total';
  }

  @override
  String get khatmaContinueMine => 'متابعة ختمتي';

  @override
  String askCreditLine(String plan) {
    return 'قراءتك الأخيرة تدخل في «$plan». أتُحتسب لها؟';
  }

  @override
  String get askCreditCount => 'احتسب';

  @override
  String get askCreditNo => 'لا';

  @override
  String get khatmaPendingTitle => 'قراءات تنتظر الاحتساب';

  @override
  String khatmaPendingOn(String date) {
    return 'قراءة $date';
  }

  @override
  String get tasmeeTitle => 'التسميع';

  @override
  String get tasmeeDescription =>
      'اقرأ من حفظك؛ يسمعك تبيان على جهازك ويُظهر الكلمات ويعلّم مواضع الخطأ. لا يُرسل الصوت ولا يُقيَّم التجويد.';

  @override
  String get tasmeeSelectRange => 'اختر نطاق التسميع';

  @override
  String get tasmeeSurah => 'السورة';

  @override
  String get tasmeeJuz => 'الجزء';

  @override
  String get tasmeeHizb => 'الحزب';

  @override
  String get tasmeeFirstHalf => 'الأول';

  @override
  String get tasmeeSecondHalf => 'الثاني';

  @override
  String get tasmeeFromSecondQuarter => 'ابدأ من الربع الثاني';

  @override
  String get tasmeeMode => 'طريقة التسميع';

  @override
  String get tasmeeContinuous => 'متصل';

  @override
  String get tasmeeVerseByVerse => 'آية بآية';

  @override
  String get tasmeeInvalidRange => 'تحقق من أرقام النطاق.';

  @override
  String get tasmeeDownloadModel => 'تنزيل نموذج التسميع';

  @override
  String get tasmeeListening => 'أستمع إليك';

  @override
  String get tasmeeNotListening => 'اضغط للبدء واقرأ من حفظك';

  @override
  String get tasmeeModelLoad => 'جارٍ تجهيز النموذج';

  @override
  String get tasmeeWordWrong => 'خطأ';

  @override
  String get tasmeeWordSkipped => 'متجاوزة';

  @override
  String get tasmeeSessionComplete => 'انتهى التسميع';

  @override
  String tasmeeSessionDoubtful(int n, String count) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$count كلمة مشكوك فيها، لم تُحسب في الدقة',
      many: '$count كلمة مشكوك فيها، لم تُحسب في الدقة',
      few: '$count كلمات مشكوك فيها، لم تُحسب في الدقة',
      two: 'كلمتان مشكوك فيهما، لم تُحسبا في الدقة',
      one: 'كلمة واحدة مشكوك فيها، لم تُحسب في الدقة',
      zero: 'لا كلمات مشكوك فيها',
    );
    return '$_temp0';
  }

  @override
  String get tasmeeAccuracy => 'الدقة';

  @override
  String get tasmeeAccuracyShort => 'الدقة';

  @override
  String tasmeeAcrossSurahs(
    String fromSurah,
    String fromAyah,
    String toSurah,
    String toAyah,
    String mode,
  ) {
    return '$fromSurah $fromAyah – $toSurah $toAyah · $mode';
  }

  @override
  String get tasmeeAyah => 'آية';

  @override
  String get tasmeeCancelDownload => 'إلغاء التنزيل';

  @override
  String get tasmeeClearHistory => 'مسح سجل التسميع';

  @override
  String get tasmeeClearHistoryBody =>
      'يُمسح ما يحفظه التطبيق عن جلساتك السابقة (آخر تسميع). لا يوجد صوت محفوظ أصلا.';

  @override
  String get tasmeeClearHistoryHint => 'آخر تسميع ونتيجته';

  @override
  String get tasmeeTrainTitle => 'ساعدنا في تحسين النموذج وتدريبه بتسجيلاتك';

  @override
  String get tasmeeTrainBody =>
      'على منصة «تدريب التسميع» تقرأ آيات من حفظك وتتبرّع بتسجيلك، ليتعلّم نموذج التسميع ويصبح أدق. المشاركة اختيارية بالكامل.';

  @override
  String get tasmeeTrainHowTitle => 'كيف تشارك؟';

  @override
  String get tasmeeTrainStep1 =>
      'أنشئ حسابًا ببريدك الإلكتروني ووافق على شروط المشاركة.';

  @override
  String get tasmeeTrainStep2 =>
      'اختر سورة ونطاق آيات، واقرأها من حفظك في الميكروفون. التسجيل الواحد حتى دقيقتين.';

  @override
  String get tasmeeTrainStep3 =>
      'سجّل في مكان هادئ وقريبًا من الميكروفون، بوضوح وبسرعة مريحة. القراءة الصحيحة والخطأ المتعمّد كلاهما مطلوب للتدريب.';

  @override
  String get tasmeeTrainStep4 =>
      'يراجع متطوعون تسجيلك قبل دخوله بيانات التدريب.';

  @override
  String get tasmeeTrainPrivacy =>
      'الخصوصية: نطلب بريدك الإلكتروني وسنة ميلادك فقط، ومن هم دون ١٨ يحتاجون موافقة ولي الأمر. التسجيلات المقبولة تُشارك برخصة CC BY 4.0، والملفات الخام لا تُعرض للعامة، وتقدر تمسح تسجيلاتك في أي وقت.';

  @override
  String get tasmeeTrainOpen => 'افتح منصة التدريب';

  @override
  String get tasmeeTrainOpenFailed =>
      'تعذّر فتح المتصفح. افتح train.altibyan.app يدويًا.';

  @override
  String get tasmeeClose => 'إغلاق';

  @override
  String get tasmeeConfirm => 'تأكيد';

  @override
  String get tasmeeContinueLast => 'أكمل';

  @override
  String get tasmeeContinuousHint =>
      'اقرأ متصلا؛ تظهر كل كلمة في موضعها لحظة قراءتها';

  @override
  String get tasmeeDefaultsNote => 'القيم الافتراضية من الإعدادات › التسميع';

  @override
  String get tasmeeDeleteModel => 'حذف النموذج';

  @override
  String get tasmeeDeleteModelBody =>
      'يُحذف نموذج التسميع من الجهاز. تحتاج إلى تنزيله ثانية قبل التسميع القادم.';

  @override
  String get tasmeeDone => 'تم';

  @override
  String get tasmeeDownloadShort => 'نزّل النموذج';

  @override
  String tasmeeDownloadSize(String size) {
    return 'نزّل ($size م.ب)';
  }

  @override
  String tasmeeDurationWords(
    String minutes,
    String seconds,
    int n,
    String words,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$words كلمة',
      many: '$words كلمة',
      few: '$words كلمات',
      two: 'كلمتان',
      one: 'كلمة واحدة',
      zero: 'لا كلمات',
    );
    return 'المدة $minutes د $seconds ث · $_temp0';
  }

  @override
  String get tasmeeElapsed => 'المدة';

  @override
  String get tasmeeEnd => 'إنهاء';

  @override
  String get tasmeeFeedback => 'أثناء التسميع';

  @override
  String get tasmeeFinishing => 'أنهي التسميع…';

  @override
  String get tasmeeFromPage => 'من صفحة';

  @override
  String get tasmeeFromSurah => 'من سورة';

  @override
  String get tasmeeHelp => 'المساعدة';

  @override
  String get tasmeeHint => 'تلميح';

  @override
  String get tasmeeHistory => 'السجل';

  @override
  String get tasmeeKindHalfHizb => 'نصف حزب';

  @override
  String get tasmeeKindHizb => 'حزب';

  @override
  String get tasmeeKindJuz => 'جزء';

  @override
  String get tasmeeKindPages => 'صفحات';

  @override
  String get tasmeeKindQuarter => 'ربع حزب';

  @override
  String get tasmeeKindSurah => 'سورة';

  @override
  String get tasmeeKindThreeQuarters => '٣ أرباع حزب';

  @override
  String get tasmeeKindVerses => 'آيات';

  @override
  String tasmeeLastSession(String range, String accuracy) {
    return 'آخر تسميع: $range · $accuracy';
  }

  @override
  String get tasmeeLenient => 'متسامح';

  @override
  String get tasmeeLenientHint => 'يقبل فرقا أكبر في نطق الكلمة';

  @override
  String get tasmeeLess => 'أقل';

  @override
  String tasmeeListeningVerse(String ayah) {
    return 'الآية $ayah: أستمع إليك';
  }

  @override
  String get tasmeeMarkAndGoOn => 'تابع وعلّمه';

  @override
  String get tasmeeMedium => 'متوسط';

  @override
  String get tasmeeMediumHint => 'يتجاوز عن حرف واحد في الكلمة الطويلة';

  @override
  String get tasmeeMicOff => 'الميكروفون غير مسموح';

  @override
  String get tasmeeMicPrivacy =>
      'التسميع يسمع قراءتك على جهازك فقط. لا يُرسل الصوت ولا يُحفظ.';

  @override
  String tasmeeMistakes(String count) {
    return '$count أخطاء';
  }

  @override
  String get tasmeeModelChecking => 'جارٍ معرفة الحجم…';

  @override
  String get tasmeeModelDetails => 'المصدر والرخصة في «عن المصحف» › المصادر';

  @override
  String get tasmeeModelFailed => 'تعذر الاتصال. تحقق من الإنترنت وحاول ثانية.';

  @override
  String tasmeeModelInstalled(String version) {
    return 'النموذج منزّل (الإصدار $version)';
  }

  @override
  String get tasmeeModelMissing => 'نموذج التسميع غير منزّل';

  @override
  String get tasmeeModelOffline => 'يعمل بعدها بلا إنترنت';

  @override
  String tasmeeModelProgress(String done, String total) {
    return '$done من $total م.ب';
  }

  @override
  String get tasmeeModelRemove => 'تحذفه متى شئت من الإعدادات › التسميع';

  @override
  String tasmeeModelSize(String size) {
    return '$size م.ب · مرة واحدة';
  }

  @override
  String get tasmeeModelSizeUnknown => 'مرة واحدة';

  @override
  String tasmeeModelSpace(String size) {
    return 'المساحة المستخدمة: $size م.ب';
  }

  @override
  String get tasmeeModelTitle => 'نموذج التسميع';

  @override
  String get tasmeeModelUpdate => 'تحديث النموذج';

  @override
  String tasmeeModelUpdateAvailable(String size) {
    return 'تحديث لنموذج التسميع متاح ($size م.ب)';
  }

  @override
  String get tasmeeModelUpdateKeeps =>
      'يبقى النموذج الحالي يعمل حتى يكتمل تنزيل الجديد، ثم يُحذف';

  @override
  String get tasmeeModelUpdateTitle => 'تحديث نموذج التسميع';

  @override
  String get tasmeeModelVoiceStays => 'صوتك يبقى على جهازك، لا يُرسل ولا يُحفظ';

  @override
  String get tasmeeModelWifiNote =>
      'يُفضَّل التنزيل عبر Wi‑Fi؛ قد تُحسب بيانات الهاتف';

  @override
  String get tasmeeMore => 'أكثر';

  @override
  String get tasmeeNew => 'تسميع جديد';

  @override
  String get tasmeeNoAudioKept => 'يُحفظ آخر تسميع لتكمل منه. لا يُحفظ أي صوت.';

  @override
  String get tasmeeNoMistakes => 'بلا أخطاء';

  @override
  String get tasmeeNotNow => 'ليس الآن';

  @override
  String get tasmeeNothingToReview => 'أحسنت، لا آيات تحتاج مراجعة.';

  @override
  String get tasmeeNoticeDeviceBody => 'صوتك لا يُرسل إلى أي خادم ولا يُحفظ.';

  @override
  String get tasmeeNoticeDeviceTitle => 'يعمل على جهازك';

  @override
  String get tasmeeNoticeMishearBody =>
      'الكلمة التي يشك فيها تُعلَّم بنقاط خفيفة ولا تُحسب عليك.';

  @override
  String get tasmeeNoticeMishearTitle => 'قد يخطئ في السماع';

  @override
  String get tasmeeNoticeOk => 'فهمت';

  @override
  String get tasmeeNoticeStart => 'فهمت، ابدأ';

  @override
  String get tasmeeNoticeTajweedBody =>
      'ولا المخارج ولا المدود ولا الوقف والابتداء.';

  @override
  String get tasmeeNoticeTajweedTitle => 'لا يقيّم التجويد ولا أحكام الأداء';

  @override
  String get tasmeeNoticeTitle => 'التسميع يختبر حفظك، لا تجويدك';

  @override
  String get tasmeeNoticeWordsBody => 'هل قرأت ما في المصحف كلمة كلمة؟';

  @override
  String get tasmeeNoticeWordsTitle => 'يتحقق من الكلمات وترتيبها';

  @override
  String get tasmeeOnError => 'عند الخطأ';

  @override
  String get tasmeeOneMistake => 'خطأ واحد';

  @override
  String tasmeeOneTo(String max) {
    return 'من ١ إلى $max';
  }

  @override
  String get tasmeeOpenDeviceSettings => 'افتح إعدادات الجهاز';

  @override
  String get tasmeeOtherEdition =>
      'التسميع يتبع صفحات مصحف المدينة الجديد (١٤٤١)؛ في طبعتك تظهر الكلمات هنا متتابعة.';

  @override
  String get tasmeePause => 'إيقاف مؤقت';

  @override
  String get tasmeePaused => 'متوقف مؤقتا';

  @override
  String get tasmeeProgress => 'ما سُمّع من النطاق';

  @override
  String get tasmeeQuarterOfHizb => 'الربع';

  @override
  String get tasmeeRange => 'النطاق';

  @override
  String tasmeeRangeSummary(
    String from,
    String to,
    int verseTotal,
    String verses,
    int wordTotal,
    String words,
    String pages,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      verseTotal,
      locale: localeName,
      other: '$verses آية',
      many: '$verses آية',
      few: '$verses آيات',
      two: 'آيتان',
      one: 'آية واحدة',
      zero: 'لا آيات',
    );
    String _temp1 = intl.Intl.pluralLogic(
      wordTotal,
      locale: localeName,
      other: '$words كلمة',
      many: '$words كلمة',
      few: '$words كلمات',
      two: 'كلمتان',
      one: 'كلمة واحدة',
      zero: 'لا كلمات',
    );
    return 'من $from إلى $to · $_temp0 · $_temp1 · ص $pages';
  }

  @override
  String get tasmeeReReadWord => 'أعد قراءة الكلمة المعلّمة بالأحمر';

  @override
  String get tasmeeReciteAgain => 'سمّع هذه الآيات ثانية';

  @override
  String get tasmeeReciteVerse => 'سمّع الآية';

  @override
  String get tasmeeRedownload => 'إعادة تنزيل النموذج';

  @override
  String get tasmeeRedownloadBody => 'يُحذف النموذج الحالي ثم يُنزّل من جديد.';

  @override
  String get tasmeeRepeat => 'أعد';

  @override
  String get tasmeeResume => 'متابعة';

  @override
  String get tasmeeRetry => 'حاول ثانية';

  @override
  String tasmeeReviewRow(String ayah, String accuracy) {
    return 'الآية $ayah، الدقة $accuracy';
  }

  @override
  String tasmeeRingSemantics(String title, String note, String value) {
    return '$title، $note: $value';
  }

  @override
  String tasmeeSeconds(String count) {
    return '$count ث';
  }

  @override
  String tasmeeSessionTitle(String surah) {
    return 'تسميع · $surah';
  }

  @override
  String get tasmeeSettingsNote => 'الطريقة، السلوك عند الخطأ، النموذج';

  @override
  String get tasmeeSkipWord => 'تجاوزها';

  @override
  String get tasmeeStart => 'ابدأ';

  @override
  String get tasmeeStartReciting => 'ابدأ التسميع';

  @override
  String get tasmeeStopToCorrect => 'توقّف للتصحيح';

  @override
  String get tasmeeStopToCorrectHint => 'لا يتقدم حتى تقرأ الكلمة الصحيحة';

  @override
  String get tasmeeStrict => 'صارم';

  @override
  String get tasmeeStrictHint => 'الكلمة كما هي حرفا حرفا';

  @override
  String get tasmeeStrictness => 'حساسية المطابقة';

  @override
  String get tasmeeSummary => 'الملخص';

  @override
  String get tasmeeTestByTouch => 'اختبر حفظك باللمس بدلا من ذلك';

  @override
  String get tasmeeThisVerse => 'دقة الآية';

  @override
  String get tasmeeToPage => 'إلى صفحة';

  @override
  String get tasmeeToReview => 'آيات تحتاج مراجعة';

  @override
  String get tasmeeToSurah => 'إلى سورة';

  @override
  String get tasmeeToastDuration => 'مدة ظهور نتيجة الآية';

  @override
  String get tasmeeVerseByVerseHint => 'اضغط، اقرأ آية، ثم تظهر كاملة بنتيجتها';

  @override
  String get tasmeeVerseDone => 'انتهت الآية';

  @override
  String tasmeeVerseNumber(String ayah) {
    return 'الآية $ayah';
  }

  @override
  String tasmeeVerseOf(String n, String count) {
    return 'الآية $n من $count: اضغط وسمّعها';
  }

  @override
  String tasmeeVerseResult(String ayah, String accuracy, String detail) {
    return 'الآية $ayah · $accuracy · $detail';
  }

  @override
  String get tasmeeVersesHeading => 'الآيات';

  @override
  String tasmeeVersesLine(String from, String to, String mode) {
    return 'الآيات $from–$to · $mode';
  }

  @override
  String get tasmeeVibration => 'الاهتزاز عند الخطأ';

  @override
  String get tasmeeVibrationHint =>
      'اهتزاز خفيف حين تُعلَّم كلمة خطأ أو متجاوزة';

  @override
  String get tasmeeWholeSession => 'للتسميع كله';

  @override
  String get tasmeeWordCorrectedShort => 'صُحّحت';

  @override
  String get tasmeeWordHinted => 'بتلميح';

  @override
  String get tasmeeAllowMicHint =>
      'افتح إعدادات الجهاز، ثم اسمح لتبيان باستخدام الميكروفون.';

  @override
  String get newKhatmah => 'الختمة الجديدة';

  @override
  String get newKhatmahBody =>
      'أكثر من ختمة معا، ومعالج إنشاء بقوالب جاهزة، وورد يومي يتكيّف، وإحصاءات وتذكيرات أدق، ومؤشر ورد اليوم في المصحف.';

  @override
  String get newTasmee => 'التسميع بالصوت (تجريبي)';

  @override
  String get newTasmeeBody =>
      'اقرأ من حفظك، فتظهر كل كلمة في موضعها وتُعلَّم الأخطاء. يعمل على جهازك دون إنترنت بعد تنزيل النموذج، ويختبر الحفظ لا التجويد.';

  @override
  String get newSajdah => 'مؤقت سجدات التلاوة';

  @override
  String get newSajdahBody =>
      'عند آية السجدة يتوقف الشيخ وتظهر بطاقة بأذكار السجود وعدّ تنازلي، ثم تُستكمل التلاوة. يُفعَّل من الإعدادات.';

  @override
  String get newAssistant => 'المساعد: المساعدة في استخدام التطبيق';

  @override
  String get newAssistantBody =>
      'شاشة جديدة فيها أحكام التجويد بألوانها، ولكل حكم مواضعه في المصحف.';

  @override
  String get newFocus => 'وضع التركيز';

  @override
  String get newFocusBody =>
      'الصفحة وحدها بلا إطار وتملأ الشاشة، والأدوات عند الحاجة، ومشغّل صغير تسحبه أينما شئت.';

  @override
  String get tasmeeAutoUpdateModel => 'تحديث النموذج تلقائيًا على الواي فاي';

  @override
  String get tasmeeAutoUpdateModelHint =>
      'يُنزَّل الإصدار الأحدث في الخلفية ويبقى الحالي يعمل حتى يكتمل';

  @override
  String tasmeeModelUpdated(String version) {
    return 'تم تحديث نموذج التسميع إلى الإصدار $version';
  }

  @override
  String sourceInstalledVersion(String version) {
    return 'الإصدار المثبّت: $version';
  }

  @override
  String sourceAlsoCredited(String names) {
    return 'ويُنسب أيضًا إلى: $names';
  }

  @override
  String get navHome => 'الرئيسية';

  @override
  String get homeSections => 'الأقسام';

  @override
  String get homeContinueHint => 'تابع من حيث توقفت';

  @override
  String get interfaceStyleTitle => 'شكل الواجهة';

  @override
  String get interfaceStyleHint =>
      'شكل الرئيسية والفهرس والإعدادات والنوافذ، ولا يغيّر شكل صفحة المصحف';

  @override
  String get interfaceStyleMakhtuta => 'مخطوطة';

  @override
  String get interfaceStyleHandasi => 'هندسي';

  @override
  String get interfaceStyleLayli => 'ليلي ذهبي';

  @override
  String get settingsGroupAppearance => 'المظهر';

  @override
  String get settingsGroupListening => 'الاستماع والتسميع';

  @override
  String get settingsGroupData => 'البيانات والخصوصية';

  @override
  String get newLook => 'شكل جديد للواجهة';

  @override
  String get newLookBody =>
      'ثلاثة أشكال تختار منها في الإعدادات: هندسي ومخطوطة وليلي ذهبي، بأسماء السور بخط مجمع الملك فهد، وعلامات المكية والمدنية.';

  @override
  String get newModelUpdate => 'تحديث نموذج التسميع تلقائيًا';

  @override
  String get newModelUpdateBody =>
      'حين يتحسّن نموذج التسميع ينزل وحده على الواي فاي، ويظل القديم يعمل حتى يكتمل الجديد.';

  @override
  String get progressSaved => 'حُفظت النتيجة';

  @override
  String progressNewlyMastered(String count) {
    return 'أُتقنت آيات جديدة: $count';
  }

  @override
  String progressStillMastered(String count) {
    return 'متقن: $count';
  }

  @override
  String progressToReview(String count) {
    return 'تحتاج مراجعة: $count';
  }

  @override
  String get hifzTabToday => 'اليوم';

  @override
  String get hifzTabProgress => 'التقدّم';

  @override
  String get hifzTabHistory => 'السجل';

  @override
  String get hifzTabHardWords => 'الكلمات الصعبة';

  @override
  String get hifzTabGoals => 'الأهداف';

  @override
  String get hifzJourney => 'مسيرة الحفظ';

  @override
  String hifzJourneyLine(int n, String memorized, String mastered) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$memorized آية',
      many: '$memorized آية',
      few: '$memorized آيات',
      two: 'آيتان',
      one: 'آية واحدة',
      zero: 'لا آيات',
    );
    return 'محفوظ $_temp0، منها $mastered متقنة';
  }

  @override
  String get hifzJourneyEmpty => 'سمّع ما تحفظ فيُحفظ هنا تقدّمك.';

  @override
  String get progressOverall => 'في المجمل';

  @override
  String get progressJuzCount => 'أجزاء';

  @override
  String get progressPagesCount => 'صفحات';

  @override
  String get progressVersesCount => 'آيات';

  @override
  String get progressMemorized => 'محفوظ';

  @override
  String get progressMastered => 'متقن';

  @override
  String get progressNeedsReview => 'يحتاج مراجعة';

  @override
  String get progressAccuracy30 => 'متوسط الدقة في آخر ٣٠ يوما';

  @override
  String get progressBySurah => 'حسب السورة';

  @override
  String get progressByJuz => 'حسب الجزء';

  @override
  String progressLastRecited(String date) {
    return 'آخر تسميع $date';
  }

  @override
  String get progressNotRecited => 'لم يُسمَّع بعد';

  @override
  String progressShares(String memorized, String mastered) {
    return 'محفوظ $memorized · متقن $mastered';
  }

  @override
  String progressAccuracy(String value) {
    return 'الدقة $value';
  }

  @override
  String progressSuggestRecite(String count) {
    return 'آيات محفوظة لم تُسمَّع بعد: $count. سمّعها لتصير متقنة.';
  }

  @override
  String get progressMasteryRule =>
      'الآية تصير «متقنة» إذا سمّعتها بدقة ٩٠٪ أو أكثر.';

  @override
  String get progressEmpty =>
      'لم تعلّم حفظ شيء بعد. علّم ما تحفظ في الخريطة، أو سمّع.';

  @override
  String get progressOpenMap => 'افتح الخريطة';

  @override
  String get historyEmpty =>
      'لا تسميع محفوظ بعد. كل جلسة تسميع تُحفظ هنا وحدها، نتيجتها فقط دون صوت.';

  @override
  String get recitationVoice => 'بالصوت';

  @override
  String get recitationTouch => 'باللمس';

  @override
  String get recitationTest => 'اختبار الحفظ';

  @override
  String historyVerses(int n, String count) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$count آية',
      many: '$count آية',
      few: '$count آيات',
      two: 'آيتان',
      one: 'آية واحدة',
      zero: 'لا آيات',
    );
    return '$_temp0';
  }

  @override
  String get sessionSummary => 'ملخّص الجلسة';

  @override
  String get sessionDelete => 'احذف من السجل';

  @override
  String sessionSensitivity(String level) {
    return 'حساسية المطابقة: $level';
  }

  @override
  String get sessionSlips => 'مواضع الخطأ';

  @override
  String get hardWordsEmpty =>
      'لا كلمات صعبة بعد. الكلمة التي تخطئ فيها أو تتخطاها أكثر من مرة تظهر هنا.';

  @override
  String hardWordsCount(int n, String count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$count مرة',
      many: '$count مرة',
      few: '$count مرات',
      two: 'مرتان',
      one: 'مرة واحدة',
      zero: 'لا مرات',
    );
    return '$_temp0 · آخرها $date';
  }

  @override
  String get hardWordsHint => 'آيات هذه الكلمات تأتي أولا في المراجعة.';

  @override
  String get goalsEmpty => 'لا أهداف بعد. اختر هدفا جاهزا أو اصنع هدفك.';

  @override
  String get goalNew => 'هدف جديد';

  @override
  String get goalTemplateAmma => 'جزء عمّ في شهرين';

  @override
  String get goalTemplatePageDaily => 'صفحة يوميا';

  @override
  String get goalTemplateHizbWeekly => 'مراجعة حزب كل أسبوع';

  @override
  String get goalTemplateFixSurah => 'تثبيت سورة';

  @override
  String get goalOpen => 'هدف مفتوح';

  @override
  String get goalOpenHint => 'تختار النطاق والمدة والوحدة';

  @override
  String get goalFromSurah => 'من سورة';

  @override
  String get goalToSurah => 'إلى سورة';

  @override
  String get goalSurah => 'السورة';

  @override
  String get goalHizb => 'الحزب';

  @override
  String goalDays(int n, String days) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$days يوم',
      many: '$days يومًا',
      few: '$days أيام',
      two: 'يومان',
      one: 'يوم واحد',
      zero: 'لا أيام',
    );
    return 'المدة: $_temp0';
  }

  @override
  String get goalUnit => 'الوحدة';

  @override
  String get goalCreate => 'أنشئ الهدف';

  @override
  String get goalTodayWird => 'ورد اليوم';

  @override
  String get goalMemorize => 'احفظ';

  @override
  String get goalReview => 'راجع';

  @override
  String goalReviewDue(String count) {
    return 'وحدات مستحقة للمراجعة: $count';
  }

  @override
  String goalReviewHard(String count) {
    return 'آيات فيها كلمات صعبة: $count';
  }

  @override
  String get goalNothingToday => 'لا ورد اليوم.';

  @override
  String goalMasteredShare(String value) {
    return 'متقن $value';
  }

  @override
  String goalLeft(int n, String pages) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'تبقّى $pages صفحة',
      many: 'تبقّى $pages صفحة',
      few: 'تبقّت $pages صفحات',
      two: 'تبقّت صفحتان',
      one: 'تبقّت صفحة واحدة',
      zero: 'لم تبقَ صفحات',
    );
    return '$_temp0';
  }

  @override
  String goalUntil(String date) {
    return 'حتى $date';
  }

  @override
  String goalBehind(int n, String pages) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$pages صفحة',
      many: '$pages صفحة',
      few: '$pages صفحات',
      two: 'صفحتان',
      one: 'صفحة واحدة',
      zero: 'لا شيء',
    );
    return 'تبقّى من الأيام الماضية $_temp0';
  }

  @override
  String get goalCatchUp => 'عوّض على أيام';

  @override
  String get goalExtend => 'مد الموعد';

  @override
  String get goalPause => 'أوقف مؤقتا';

  @override
  String get goalResume => 'استأنف';

  @override
  String get goalDelete => 'احذف الهدف';

  @override
  String get goalReminder => 'تذكير يومي';

  @override
  String goalReminderAt(String time) {
    return 'تذكير $time';
  }

  @override
  String get goalReminderOff => 'أوقف التذكير';

  @override
  String get goalPaused => 'متوقف';

  @override
  String get goalComplete => 'اكتمل الهدف، بارك الله فيك.';

  @override
  String get goalCountedByMastery =>
      'يُحسب التقدّم بالتسميع المتقن، لا بالتعليم باليد.';

  @override
  String get goalReminderTitle => 'ورد الحفظ';

  @override
  String goalReminderBody(String from, String to) {
    return 'احفظ: الصفحات $from–$to';
  }

  @override
  String get goalRecite => 'سمّع';

  @override
  String get hifzMapShowMastery => 'الإتقان';

  @override
  String get hifzMapShowStrength => 'القوة';

  @override
  String get whatsNewHifzProgress => 'مسيرة الحفظ';

  @override
  String get newJourney => 'مسيرة الحفظ';

  @override
  String get newJourneyBody =>
      'كل تسميع يُحفظ ويقيس إتقانك: نسب لكل سورة وجزء، وخريطة إتقان، والكلمات التي تخطئ فيها، وأهداف حفظ بورد يومي.';

  @override
  String onbStepOf(String step, String total) {
    return 'الخطوة $step من $total';
  }

  @override
  String get onbSkipAll => 'تخطَّ الكل';

  @override
  String get onbSkip => 'تخطَّ';

  @override
  String get onbInterfaceTitle => 'اختر شكل الواجهة وإضاءتها';

  @override
  String get onbPageTitle => 'اختر شكل صفحة المصحف';

  @override
  String get onbReciterTitle => 'اسمع المصحف بصوت من تحب';

  @override
  String onbReciterSuggest(String name) {
    return 'نزّل المصحف كاملًا بصوت الشيخ $name';
  }

  @override
  String onbReciterSize(String size) {
    return 'نحو $size ميجا · يكمل في الخلفية وأنت تتابع';
  }

  @override
  String get onbReciterOther => 'اختر شيخًا آخر';

  @override
  String get onbReciterOnline => 'تقدر تسمع أي شيخ أونلاين من غير تحميل';

  @override
  String onbDownloadingBg(String done, String total) {
    return 'يُنزَّل في الخلفية: $done من $total';
  }

  @override
  String get onbTasmeeTitle => 'التسميع بصوتك';

  @override
  String get onbTasmeeBody =>
      'يستمع تبيان لتلاوتك وينبّهك عند الخطأ، على جهازك ومن غير إنترنت. يحتاج نموذج تعرّف على الصوت يُنزَّل مرة واحدة.';

  @override
  String get onbTasmeeDownload => 'نزّل النموذج';

  @override
  String onbTasmeeDownloading(String percent) {
    return 'يُنزَّل النموذج في الخلفية: $percent٪';
  }

  @override
  String get onbTasmeeReady => 'نموذج التسميع جاهز';

  @override
  String get onbTasmeeFailed =>
      'تعذّر التنزيل. تقدر تنزّله لاحقًا من الإعدادات › الحفظ والتسميع.';

  @override
  String get onbStart => 'ابدأ القراءة';

  @override
  String get settingsSectionAppearance => 'المظهر';

  @override
  String get settingsSectionAppearanceHint => 'الواجهة، الإضاءة، اللغة، الخط';

  @override
  String get settingsSectionMushaf => 'المصحف';

  @override
  String get settingsSectionMushafHint =>
      'الطبعة، شكل الصفحة، التجويد، التركيز';

  @override
  String get settingsSectionListening => 'الاستماع';

  @override
  String get settingsSectionListeningHint => 'القرّاء، المشغّل، مؤقت السجدة';

  @override
  String get settingsSectionHifz => 'الحفظ والتسميع';

  @override
  String get settingsSectionHifzHint => 'الحفظ، التسميع، نموذج الصوت';

  @override
  String get settingsSectionKhatma => 'الختمة والتذكيرات';

  @override
  String get settingsSectionKhatmaHint => 'الخطط، التذكيرات، الورد';

  @override
  String get settingsSectionStorage => 'التخزين والنسخ الاحتياطي';

  @override
  String get settingsSectionStorageHint => 'المساحة، النسخ، الاستعادة';

  @override
  String get settingsSectionAssistant => 'المساعد';

  @override
  String get settingsSectionAssistantHint =>
      'المساعدة في استخدام التطبيق والمصحف';

  @override
  String get settingsSectionAbout => 'عن تبيان';

  @override
  String get settingsSectionAboutHint => 'الجديد، المصادر، الإصدار';

  @override
  String get settingsSearchHint => 'ابحث في الإعدادات';

  @override
  String get settingsSearchEmpty => 'لا إعداد بهذا الاسم. جرّب كلمة أخرى.';

  @override
  String get settingsKhatmaPlans => 'خطط الختمة وتذكيراتها';

  @override
  String get settingsWirdIndicator => 'مؤشر الورد فوق المصحف';

  @override
  String get settingsCountListening => 'احتساب الاستماع من الورد';

  @override
  String get settingsHifzGoals => 'أهداف الحفظ وتذكيراتها';

  @override
  String get digitsFontTitle => 'خط الأرقام في الواجهة (Tibyan Digits)';

  @override
  String get digitsFontNote =>
      'أرقام الواجهة كلها بخط واحد واضح: مقتطع من IBM Plex Sans Arabic (حقوقه لشركة IBM، 2017) يضم الأرقام وحدها، وسُمّي باسم جديد لأن «Plex» اسم محجوز. الرخصة: رخصة الخطوط المفتوحة SIL OFL 1.1، وهي تبيح الاقتطاع والتعديل بشرط تغيير الاسم وبقاء الرخصة نفسها.';

  @override
  String get newSettings => 'إعدادات أسهل';

  @override
  String get newSettingsBody =>
      'الإعدادات صارت ثمانية أقسام مع بحث يوصلك لأي إعداد، وصيغ الأعداد صحيحة («٧ آيات»)، وأرقام أوضح في الواجهة.';

  @override
  String get reportProblemTitle => 'الإبلاغ عن مشكلة';

  @override
  String get reportProblemHint => 'أرسل لنا عطلا أو مشكلة أو اقتراحا';

  @override
  String get reportType => 'نوع البلاغ';

  @override
  String get reportTypeBug => 'عطل';

  @override
  String get reportTypeProblem => 'مشكلة';

  @override
  String get reportTypeSuggestion => 'تحسين مقترح';

  @override
  String get reportTypeOther => 'أخرى';

  @override
  String get reportDescription => 'الوصف';

  @override
  String get reportDescriptionHint => 'اكتب ما حدث، وأين، وما توقعت أن يحدث';

  @override
  String get reportDescriptionShort => 'اكتب خمسة أحرف على الأقل';

  @override
  String get reportPhone => 'رقم الهاتف (اختياري)';

  @override
  String get reportPhoneInvalid => 'رقم الهاتف غير صحيح';

  @override
  String get reportEmail => 'البريد الإلكتروني (اختياري)';

  @override
  String get reportEmailInvalid => 'البريد الإلكتروني غير صحيح';

  @override
  String get reportContactNote =>
      'نستخدم الهاتف والبريد للرد عليك فقط إن كتبتهما.';

  @override
  String get reportDeviceTitle => 'يُرفق مع البلاغ';

  @override
  String reportDeviceVersion(String version) {
    return 'إصدار التطبيق: $version';
  }

  @override
  String reportDeviceSystem(String platform, String os) {
    return 'النظام: $platform $os';
  }

  @override
  String get reportSend => 'إرسال البلاغ';

  @override
  String get reportSent => 'وصل بلاغك، شكرا لك.';

  @override
  String get reportQueued =>
      'لا اتصال الآن. حُفظ البلاغ وسيُرسل وحده حين يعود الاتصال.';

  @override
  String get reportFailed => 'تعذّر إرسال البلاغ. راجع ما كتبت وحاول مرة أخرى.';

  @override
  String get reportRateLimited => 'أرسلت بلاغات كثيرة للتو. حاول بعد قليل.';

  @override
  String reportPendingCount(int n) {
    return 'بلاغات تنتظر الإرسال: $n';
  }

  @override
  String get helpGroupUsage => 'استخدام التطبيق';

  @override
  String get helpGroupMarks => 'التجويد والضبط';

  @override
  String get helpGroupFaq => 'أسئلة شائعة وحلول';

  @override
  String get onbTasmeeChecking => 'نتحقق من حجم النموذج…';

  @override
  String get onbTasmeeManifestFailed =>
      'تعذّر جلب معلومات النموذج. تأكد من اتصالك بالإنترنت ثم أعد المحاولة.';

  @override
  String get onbTasmeeUnsupported =>
      'التسميع بالصوت غير متاح على هذا الجهاز بعد. تقدر تكمل وتستخدم باقي التطبيق.';

  @override
  String get assistantTileNote => 'دليل الاستخدام';
}
