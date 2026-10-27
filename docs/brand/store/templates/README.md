# قوالب لقطات المتجرين — Tibyan App Store and Google Play templates

## بالعربية

كل مقاس في مجلد `<الجهاز>/<العرض×الارتفاع>/` ويحتوي على:

- `template.png`: الخلفية والإطار، والشاشة شفافة (الشفافية داخل الشاشة فقط).
- `template.psd`: ملف فوتوشوب بطبقات (الخلفية، مكان اللقطة، الإطار، العنوان العربي، العنوان الإنجليزي مخفي).
- `layers/`: `background.png` و`frame.png` و`headline.png` (عربي) و`headline_en.png` (إنجليزي) و`screen_mask.png` (شكل الشاشة باللون الأبيض).
- `screen.json`: موضع الشاشة بالبكسل (x وy والعرض والارتفاع) ونصف قطر الزوايا، ومقاس اللقطة المقترح.

### الاستخدام في فوتوشوب
1. افتح `template.psd` (أو افتح `layers/background.png` ثم أضف بقية الطبقات بالترتيب نفسه).
2. اسحب لقطة الشاشة الحقيقية وضعها تحت طبقة `frame` مباشرة.
3. غيّر مقاسها إلى مقاس الشاشة المذكور في `screen.json` وضعها في الموضع المذكور.
4. اقصص اللقطة على شكل الشاشة: ضع طبقة `screen_mask` تحتها ثم اختر Layer ‏> Create Clipping Mask (Alt+Ctrl+G).
5. أظهر العنوان العربي أو الإنجليزي أو عدّل نصه، أو احذفه.
6. Layer ‏> Flatten Image، ثم File ‏> Export ‏> Export As ‏> PNG مع إلغاء خيار الشفافية. يرفض متجر آبل الصور التي فيها قناة ألفا.

### قوالب Google Play
مجلدات `android_phone` و`android_tablet_7` و`android_tablet_10` تُستعمل بالطريقة نفسها. حدود Google Play: كل ضلع بين ٣٢٠ و٣٨٤٠ بكسل، والضلع الأطول لا يزيد على ضعف الأقصر. المقاس 1080×2400 نسبته 2.22 فيتجاوز هذا الحد، فاستعمل 1080×1920 للرفع على Google Play.

## English

Each size lives in `<device>/<WxH>/` with `template.png` (background + frame, screen transparent; alpha only inside the screen), a layered `template.psd`, the PNG `layers/` and `screen.json` (screen rect, corner radius, recommended screenshot size).

### Photoshop
1. Open `template.psd` (or stack the `layers/` PNGs: background, screen_mask, frame, headline).
2. Drop your real screenshot directly under the `frame` layer.
3. Scale it to the screen size in `screen.json` and move it to its x/y.
4. Clip it to the screen: put it right above `screen_mask` and choose Layer > Create Clipping Mask.
5. Show the Arabic or English headline layer, edit it, or hide both.
6. Layer > Flatten Image, then Export As PNG with Transparency off. App Store Connect rejects images with an alpha channel.

The screenshot to paste is a real device capture of the same pixel size as the template (for example a 1206×2622 iPhone capture for the 1206×2622 template), scaled down into the screen hole. The Mac notch and the iPhone Dynamic Island are part of the frame layer and sit over the screenshot.

Google Play templates (`android_phone`, `android_tablet_7`, `android_tablet_10`) work the same way. Play requires each side between 320 and 3840 px and the long side at most twice the short side: 1080×2400 (ratio 2.22) breaks that rule, so upload the 1080×1920 version to Play.

Frames are generic vector drawings (no Apple bezel images, no Apple logo). Regenerate with `docs/brand/store/src/templates/gen_templates.py` (needs Pillow, psd-tools and Google Chrome).

## Sizes / المقاسات

| Template | Canvas | Screen rect | Corner radius |
|---|---|---|---|
| `android_phone/1080x1920` | 1080×1920 (Play limits: OK) | x=151, y=455, 778×1384 | 66 |
| `android_phone/1080x2400` | 1080×2400 (**exceeds Play 2:1 limit**) | x=148, y=564, 783×1741 | 67 |
| `android_phone/1920x1080` | 1920×1080 (Play limits: OK) | x=267, y=245, 1386×779 | 66 |
| `android_tablet_10/1600x2560` | 1600×2560 (Play limits: OK) | x=239, y=632, 1122×1795 | 39 |
| `android_tablet_10/2560x1600` | 2560×1600 (Play limits: OK) | x=390, y=384, 1780×1113 | 39 |
| `android_tablet_7/1200x1920` | 1200×1920 (Play limits: OK) | x=182, y=478, 836×1338 | 29 |
| `android_tablet_7/1920x1200` | 1920×1200 (Play limits: OK) | x=298, y=291, 1323×827 | 29 |
| `ipad_13/2048x2732` | 2048×2732 | x=312, y=683, 1423×1899 | 54 |
| `ipad_13/2064x2752` | 2064×2752 | x=315, y=688, 1434×1913 | 55 |
| `ipad_13/2732x2048` | 2732×2048 | x=413, y=488, 1907×1429 | 54 |
| `ipad_13/2752x2064` | 2752×2064 | x=416, y=492, 1921×1441 | 55 |
| `iphone_6.3/1179x2556` | 1179×2556 | x=167, y=611, 846×1833 | 116 |
| `iphone_6.3/1206x2622` | 1206×2622 | x=170, y=626, 865×1881 | 119 |
| `iphone_6.3/2556x1179` | 2556×1179 | x=376, y=277, 1804×832 | 114 |
| `iphone_6.3/2622x1206` | 2622×1206 | x=386, y=283, 1850×851 | 117 |
| `iphone_duo/1398x2034` | 1398×2034 | x=203, y=493, 992×1444 | 74 |
| `iphone_duo/2007x2853` | 2007×2853 | x=292, y=693, 1423×2023 | 107 |
| `iphone_duo/2034x1398` | 2034×1398 | x=291, y=323, 1452×998 | 75 |
| `iphone_duo/2853x2007` | 2853×2007 | x=409, y=463, 2036×1432 | 107 |
| `mac/1280x800` | 1280×800 | x=217, y=184, 846×529 | 9 |
| `mac/1440x900` | 1440×900 | x=244, y=207, 952×595 | 10 |
| `mac/2560x1600` | 2560×1600 | x=434, y=369, 1693×1058 | 19 |
| `mac/2880x1800` | 2880×1800 | x=488, y=415, 1905×1190 | 21 |

Header / search-results art: `docs/brand/store/graphics/header/{ar,en}/` (5244×2950, 3840×1646; key content inside the central 70%).
Apple Watch screenshots: `docs/brand/store/screenshots/apple_watch/{ar,en}/<WxH>/`.
Wear OS screenshots: `docs/brand/store/screenshots/wear_os/{ar,en}/{454x454,384x384}/`.
