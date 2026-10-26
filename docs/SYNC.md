# المزامنة وتطبيق الساعة: خطوات التجهيز في المتصفح

هذا الملف دليل تنفيذ لوكيل يعمل في المتصفح (Claude Cowork في Chrome) تحت إشراف أحمد. يغطي ما لا يُعمل من الكود: إعداد Apple Developer وApp Store Connect وGoogle Cloud وGoogle Play. أما ما يُعمل على الماك (ملفات المشروع وXcode والبناء والرفع) فمكانه قسم «بعد المتصفح» في آخر الملف، ويقوم به Claude Code.

## قواعد للوكيل

1. **توقف واطلب أحمد** في كل مرة: تسجيل دخول، أو كلمة مرور، أو رمز تحقق (2FA)، أو أي دفع، أو قبول اتفاقية أو شروط جديدة، أو أي زر حذف، أو أي شيء غير متوقع في الصفحة.
2. لا تكتب كلمات مرور ولا أسرارًا في أي مكان، ولا تنسخ أي «Client secret». معرّفات العملاء (Client ID) ليست أسرارًا، وهي المطلوبة.
3. لا تحذف ولا تعدّل أي معرّف أو تطبيق موجود. أضف فقط ما في هذا الملف. إن وُجد ما تريد إنشاءه من قبل فاستخدمه ولا تُنشئ نسخة ثانية.
4. بعد كل قسم، اكتب لأحمد سطرًا بما تم وانتقل للتالي. وفي النهاية املأ جدول «ما يُسلَّم» في آخر الملف.

## ثوابت المشروع

| البند | القيمة |
|---|---|
| Team ID في Apple | `T958VWM76Z` |
| معرّف التطبيق (iOS وmacOS وAndroid) | `app.tibyan.tibyan` |
| تطبيق الساعة | `app.tibyan.tibyan.watchkitapp` |
| إضافة واجهة الساعة (complication) | `app.tibyan.tibyan.watchkitapp.widgets` |
| App Group | `group.app.tibyan.tibyan` |
| حاوية iCloud | `iCloud.app.tibyan.tibyan` |
| النطاق | `altibyan.app` |
| سياسة الخصوصية | https://altibyan.app/privacy |
| بريد الدعم | info@altibyan.app |
| اسم التطبيق | تبيان (Tibyan) |

بصمات SHA-1 لتوقيع أندرويد (بصمات عامة، ليست أسرارًا):

| المفتاح | SHA-1 |
|---|---|
| debug (للتجربة من الماك) | `28:CC:02:B4:91:4A:0E:95:1F:DB:FE:4A:E2:47:02:BA:EA:91:29:55` |
| upload (مفتاح الرفع) | `F1:FF:F2:F9:10:A3:F8:56:5D:63:FC:A7:82:02:1B:26:38:C0:72:5F` |
| Play app signing | تُنسخ من Play Console في الخطوة ج-1 |

---

## أ. Apple Developer (developer.apple.com/account)

### أ-1. حاوية iCloud
1. Certificates, Identifiers & Profiles > Identifiers > زر **+** > **iCloud Containers** > Continue.
2. Description: `Tibyan iCloud`، Identifier: `iCloud.app.tibyan.tibyan` > Continue > Register.

### أ-2. تفعيل iCloud على التطبيق
1. Identifiers > اختر `app.tibyan.tibyan`.
2. في Capabilities فعّل **iCloud** واختر **Include CloudKit support** (أو iCloud Documents إن ظهر الخياران؛ المطلوب الوصول لحاوية iCloud).
3. اضغط **Configure** بجوار iCloud واختر الحاوية `iCloud.app.tibyan.tibyan` > Continue > Save.
4. لا تغيّر أي capability أخرى (App Groups وAssociated Domains وPush إن وُجدت تبقى كما هي).
5. إن ظهر تنبيه أن الملفات الشخصية (profiles) ستُبطل: هذا متوقع، وافق.

### أ-3. روابط الختمة الجماعية (Associated Domains)
1. في نفس صفحة `app.tibyan.tibyan`: إن لم تكن **Associated Domains** مفعّلة ففعّلها > Save.

### أ-4. معرّفا تطبيق الساعة
1. Identifiers > **+** > **App IDs** > **App** > Continue.
2. Description: `Tibyan Watch`، Bundle ID (Explicit): `app.tibyan.tibyan.watchkitapp`.
3. Capabilities: فعّل **App Groups** فقط > Continue > Register. ثم افتحه > App Groups > Configure > اختر `group.app.tibyan.tibyan` > Save.
4. كرر للإضافة: Description `Tibyan Watch Widgets`، Bundle ID `app.tibyan.tibyan.watchkitapp.widgets`، مع **App Groups** فقط ونفس المجموعة.

### أ-5. تسجيل الماك كجهاز (لبناء Debug بقدرة iCloud)
هذه الخطوة يحتاج فيها الوكيل إلى رقم الماك:
1. اطلب من أحمد أن يشغّل في التيرمنال: `system_profiler SPHardwareDataType | grep "Provisioning UDID"` ويعطيك الرقم.
2. Devices > **+** > Platform: **macOS**، Name: `Ahmed Mac`، Device ID: الرقم > Continue > Register.

---

## ب. App Store Connect (appstoreconnect.apple.com)

تطبيق الساعة **ليس منصة مستقلة** هنا، ولا يُضاف من قائمة المنصات (التي تعرض tvOS وvisionOS فقط). هو جزء من تطبيق iOS نفسه ويُرفع داخل نفس الـ build. ما يُعمل في المتصفح:

1. Apps > تبيان > تأكد أن صفحة نسخة iOS موجودة. لا تُنشئ تطبيقًا جديدًا للساعة.
2. لا شيء آخر قبل الرفع. بعد أول build فيه الساعة (من قسم «بعد المتصفح») يظهر في صفحة نسخة iOS قسم **Apple Watch** لصور الشاشة، وفي TestFlight يظهر نفس الـ build ومعه الساعة.
3. (بعد الرفع) TestFlight: تأكد أن الـ build الجديد حالته Ready to Test، ثم أبلغ أحمد ليثبّته على الآيفون، ومن تطبيق **Watch** على الآيفون يضغط Install بجوار تبيان.

---

## ج. Google Play Console (play.google.com/console)

### ج-1. بصمة توقيع Play
1. التطبيق تبيان > **Test and release** > **App integrity** (أو Setup > App signing) > **App signing key certificate**.
2. انسخ **SHA-1** (وليس SHA-256) واكتبه في جدول «ما يُسلَّم».

### ج-2. إضافة Wear OS
1. Test and release > **Advanced settings** > **Form factors** > **+ Add form factor** > **Wear OS**.
2. اقرأ لأحمد شروط مراجعة Wear OS، **وتوقف ليقبلها هو**.
3. اختر مسار Wear OS للاختبار الداخلي (Internal testing) إن عُرض اختيار.
4. صور شاشة الساعة: توقف واطلبها من أحمد (يجهّزها Claude Code لاحقًا من المحاكي). لا ترفع صورًا من عندك.
5. لا ترفع أي ملف bundle: الرفع يتم من الماك (قسم «بعد المتصفح»).

---

## د. Google Cloud (console.cloud.google.com)

### د-1. المشروع والـ API
1. توقف إن طُلب إنشاء حساب فوترة أو أي دفع؛ هذا الإعداد مجاني ولا يحتاج فوترة.
2. أنشئ مشروعًا: Project name `Tibyan`. (إن وُجد مشروع لتبيان فاستخدمه.)
3. APIs & Services > Library > ابحث **Google Drive API** > Enable.

### د-2. شاشة الموافقة (Google Auth Platform / OAuth consent screen)
1. User type: **External**.
2. App name: `تبيان`، User support email: `info@altibyan.app` (أو بريد أحمد إن لم يُقبل)، Developer contact: نفسه.
3. App domain: Home page `https://altibyan.app`، Privacy policy `https://altibyan.app/privacy`، Authorized domains: `altibyan.app`.
4. Scopes / Data access: أضف **`https://www.googleapis.com/auth/drive.appdata`** فقط. لا تضف أي نطاق آخر.
5. Audience / Publishing status: **Publish app** (إلى Production). نطاق appdata غير حساس، فلا يحتاج مراجعة Google. إن طُلب تحقق (verification) فتوقف وأخبر أحمد.

### د-3. عملاء OAuth (Clients)
أنشئ هذه العملاء من Clients (أو Credentials) > **Create client**:

| النوع | الاسم | Package name | SHA-1 |
|---|---|---|---|
| Android | `Tibyan Android debug` | `app.tibyan.tibyan` | بصمة debug من الجدول أعلاه |
| Android | `Tibyan Android upload` | `app.tibyan.tibyan` | بصمة upload من الجدول أعلاه |
| Android | `Tibyan Android Play` | `app.tibyan.tibyan` | بصمة Play من ج-1 |
| Web application | `Tibyan Web` | (لا شيء) | (لا شيء) |

- لعميل Web: لا تضف Authorized origins ولا redirect URIs.
- انسخ **Client ID** لعميل Web فقط (ينتهي بـ `.apps.googleusercontent.com`) إلى جدول «ما يُسلَّم». **لا تنسخ Client secret**، ولا تحمّل ملف JSON.

---

## ما يُسلَّم (يملؤه الوكيل في النهاية ويرسله لأحمد)

| البند | الحالة / القيمة |
|---|---|
| أ-1 حاوية iCloud | |
| أ-2 iCloud على `app.tibyan.tibyan` | |
| أ-3 Associated Domains | |
| أ-4 App IDs الساعة (2) + App Group | |
| أ-5 تسجيل الماك | |
| ب التحقق من صفحة iOS | |
| ج-1 SHA-1 لتوقيع Play | |
| ج-2 Wear OS مضاف | |
| د-1 مشروع Google + Drive API | |
| د-2 شاشة الموافقة منشورة | |
| د-3 عملاء أندرويد (3) | |
| د-3 Web Client ID | |
| ملاحظات أو أشياء توقفت عندها | |

---

## بعد المتصفح (يقوم به Claude Code على الماك)

1. **iCloud:** نقل مفاتيح `ios/Runner/iCloud.entitlements.disabled` إلى `ios/Runner/Runner.entitlements` و`macos/Runner/DebugProfile.entitlements` و`macos/Runner/Release.entitlements`، وإضافة `applinks:altibyan.app` إن لم تكن، ثم البناء بـ `-allowProvisioningUpdates`.
2. **Google:** حفظ Web Client ID خارج المستودع (في `~/.config/tibyan/`) وتمريره في البناء: `--dart-define=TIBYAN_GOOGLE_SERVER_CLIENT_ID=<web client id>`.
3. **الساعة:** `ruby tools/apple/add_watch_target.rb --embed`، ثم Signing تلقائي للهدفين `TibyanWatch` و`TibyanWatchWidgets` بنفس الفريق، وإضافة أيقونة الساعة 1024، ومطابقة الإصدار ورقم البناء مع التطبيق. التفاصيل في `docs/WATCH.md`.
4. **Wear OS:** `cd android && ./gradlew :wear:bundleRelease` ثم رفعه لمسار Wear OS الداخلي، وصور شاشة من محاكي Wear OS.
5. **الرفع:** أرشيف iOS وmacOS ورفعهما (طريقة الرفع في الذاكرة وملف handoff)، وحزمة أندرويد إلى Play الداخلي. فقط حين يطلب أحمد.
6. **التحقق:** على الآيفون من TestFlight مع الساعة: المسبحة على الساعة تضيف للهاتف، وورد اليوم يظهر، والمزامنة تعمل بين الآيفون والماك عبر iCloud، وبين جهازي أندرويد عبر Google Drive.

---

## مرجع تقني (للمطورين)

الكود: `lib/core/sync/cloud/` (المحرك والمخازن) و`lib/features/sync/` (المتحكم والشاشة: الإعدادات > البيانات > «المزامنة»). كل جهاز يكتب ملفه فقط `tibyan-sync-<deviceId>.json` ويقرأ ملفات كل الأجهزة؛ الدمج آخر كتابة تغلب لكل سجل مع شواهد حذف، ودفتر `sync_journal` في user.db. بدون الإعداد أعلاه تعرض الشاشة «غير متاحة في هذه النسخة».

يُزامَن: الفواصل، والختمات وتقدمها، وجلسات القراءة والاستماع، والمسبحة، والحفظ وتقييمات وضع الحفظ، وملاحظات التدبر (`reflection`)، وآخر موضع قراءة (`reading_positions`، بالسورة والآية فيصلح لأي طبعة)، و13 إعدادًا للشكل والوضع والتقليب والبرواز والقارئ. سجل المسبحة اليومي `tasbih_day` صف لكل جهاز (عمود `device`) والعدد اليومي = مجموع الأجهزة، ومنه عدّات الساعة لأنها تُسجَّل على الهاتف. أي ختم زمني أبعد من يوم في المستقبل يُعامل بوقت وصوله.

الختمة الجماعية لا تستخدم هذه المزامنة: هي بلينك ومن غير حسابات، وخادمها في `training-platform/app/group_khatma.py` (القرار في `docs/plan/post-launch-roadmap.md`).

خطة الحسابات القديمة عبر Supabase أُلغيت بقرار أحمد (2026-10-24: مزامنة عبر iCloud وGoogle Drive، بلا حسابات). نصها في تاريخ git لهذا الملف لمن أراد الرجوع إليه.
