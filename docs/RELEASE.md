# الإصدار

## كيف يخرج إصدار

```
python3 tools/release/prepare.py 0.5.0     # يرفع pubspec ويقطع قسم [Unreleased] في CHANGELOG
git commit -am "release: 0.5.0"
git tag v0.5.0 && git push origin main v0.5.0
```

دفع الوسم `v*` يشغل `.github/workflows/release.yml`:

1. يتأكد أن الوسم يطابق `pubspec.yaml` وأن في CHANGELOG قسما لهذا الإصدار (`tools/release/check_version.py`)، وإلا يفشل قبل البناء.
2. أندرويد: APK و AAB، موقعان بمفتاح الرفع إن وُجدت الأسرار، وإلا بمفتاح التطوير (للتجربة فقط). ويُرفع الـ AAB إلى المسار الداخلي في Google Play إن وُجد مفتاح الخدمة.
3. iOS وmacOS: تطبيقان بلا توقيع (zip، وdmg لماك)، يوقَّعان من Xcode بشهادة الفريق.
4. ويندوز: zip للتطبيق (يُفك ويُشغَّل `tibyan.exe`). لينكس: tar.gz للحزمة، ويحتاج جهاز القارئ مكتبة libmpv للتلاوة (`apt install libmpv2` أو حزمة mpv في توزيعته).
5. يُنشر إصدار GitHub بملاحظات من CHANGELOG ومعه كل هذه الملفات.
6. مثبّت ويندوز (بعد نشر إصدار GitHub، من جهازك):

   ```
   scripts/build-win-remote.sh                      # فحص فقط، لا يغيّر شيئا
   scripts/build-win-remote.sh --build --publish --notes "..."
   ```

   يأخذ الخادم `tibyan-windows-x64.zip` من إصدار GitHub ويبني منه `Tibyan-Windows-Setup-v<version>.exe` بـ NSIS داخل Docker (`windows/installer/`) في `/opt/tibyan-winbuild`، ثم ينشره مع `latest.json` في `https://tibyan.ahmedhelal.dev/win/`. التطبيق على ويندوز يقرأ `latest.json` ويحدّث نفسه، وزر ويندوز في altibyan.app يشير إلى المثبّت متى وُجد (والـ zip يبقى على `/download/windows-zip`). التراجع: انسخ `win/backups/latest-<UTC>.json` فوق `win/latest.json`.

## ما يلزمك أنت (لا يستطيع المستودع فعله)

أسرار GitHub (Settings ‹ Secrets and variables ‹ Actions):

| السر | المحتوى |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 upload.jks` لمفتاح الرفع |
| `ANDROID_KEYSTORE_PASSWORD`، `ANDROID_KEY_ALIAS`، `ANDROID_KEY_PASSWORD` | بيانات المفتاح |
| `PLAY_SERVICE_ACCOUNT_JSON` | مفتاح حساب خدمة Play (نص JSON)، له صلاحية الإصدار على التطبيق |

بدونها يعمل خط الإصدار كله ما عدا التوقيع الحقيقي والرفع إلى Play. احفظ مفتاح الرفع نسخة احتياطية خارج GitHub: ضياعه يمنع تحديث التطبيق على Play.

iOS وmacOS:
- حساب Apple Developer، وApp ID بالمعرفات `app.tibyan.tibyan` و`.TibyanWidget` و`.TibyanActions`.
- App Group: iOS `group.app.tibyan.tibyan`، macOS `<TeamID>.group.app.tibyan.tibyan` (docs/HOME_WIDGET.md).
- ويندوز: المثبّت والـ zip غير موقّعين، فيظهر تحذير SmartScreen أول مرة. التوقيع يحتاج شهادة توقيع كود. نسخة المتجر (MSIX) يوقّعها المتجر نفسه: انظر «متجر مايكروسوفت» أدناه.
- أرشِف ووقّع من Xcode ثم ارفع بـ Transporter إلى TestFlight (التوقيع الآلي من CI يحتاج شهادة وملف provisioning في الأسرار، ولم يُضف حتى تُنشأ).

## متجر مايكروسوفت (MSIX)

معرّف المتجر `9N944SZ21PTS`. هوية الحزمة في `msix_config` داخل `pubspec.yaml` (Identity Name `AhmedHelal.-`)، ورقم إصدارها `a.b.c.0` من `version`. نسخة المتجر تُبنى بـ `--dart-define=TIBYAN_STORE=msstore`، وفيها المحدّث الداخلي لويندوز مطفأ مع زر «البحث عن تحديثات» (سياسة المتجر؛ المتجر يوصل التحديثات). المثبّت Setup.exe على الموقع لا يتغير.

1. **أول إرسال يدوي في Partner Center:** شغّل `Microsoft Store` (`msstore.yml`) من Actions و`publish` مطفأ، ونزّل `tibyan.msix` من artifacts، وارفعه في Partner Center مع بيانات الصفحة (الوصف، الصور، رابط الخصوصية https://altibyan.app/privacy، التصنيف العمري، السعر والتوفر)، ثم أرسله للمراجعة.
2. **بعد قبول أول إرسال:** شغّل الـ workflow و`publish` مفعّل. ينشئ إرسالاً جديداً بالحزمة عبر `msstore publish` بأسرار `MSSTORE_TENANT_ID` و`MSSTORE_CLIENT_ID` و`MSSTORE_CLIENT_SECRET` و`MSSTORE_SELLER_ID`.
3. **كل تشغيل بـ `publish` مفعّل يحتاج موافقة أحمد في كل مرة.**

## رموز الأعطال (GlitchTip)

ملحق Sentry لـ Gradle (`io.sentry.android.gradle` في `android/app/build.gradle.kts`) يكتب في كل بناء أندرويد مُصغَّر (R8) معرّف UUID لملف الـ mapping داخل `assets/sentry-debug-meta.properties`، فيعرف GlitchTip أي mapping يفك تشويش العطل. يرفع الـ mapping وقت البناء فقط إذا كان `SENTRY_AUTH_TOKEN` موجودا (`set -a; source ~/.config/tibyan/glitchtip.env; set +a` قبل البناء). بدونه يبني دون اتصال ولا يفشل (كما في CI). باقي خصائص الملحق مطفأة. بعد البناء شغّل `tools/upload_symbols.sh <N>`: يرفع رموز Dart والمكتبات الأصلية وdSYMs، ويعيد رفع الـ mapping بنفس الـ UUID المضمَّن (`sentry-cli upload-proguard --uuid`)، ويخرج بخطأ إن فشل الرفع.

## فحص قبل الوسم

`ci.yml` (format وanalyze وtest) و`native.yml` (بناء أندرويد وiOS وmacOS مع الامتدادات) خضراء على الفرع الذي يُدمج.
