#!/usr/bin/env python3
"""Generate 7-inch Android Tablet screenshots in TRUE LANDSCAPE (1920x1200) with edge-to-edge tablet layouts."""
import math, os, subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.abspath(os.path.join(HERE, '../screenshots/android_tablet_7'))
FONTS = os.path.abspath(os.path.join(HERE, '../../../../assets/fonts/ofl'))
CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'

W, H = 1920, 1200

TEAL_1, TEAL_2 = '#11706A', '#0A4F4A'
CREAM = '#F6F1E8'
GOLD = '#D9B266'
MINT = '#CFE3DF'
DEEP_BG = '#071F1D'

def star_pts(cx, cy, r, inner=0.7654):
    pts = []
    for i in range(16):
        a = math.pi / 8 * i - math.pi / 2
        rr = r if i % 2 == 0 else r * inner
        pts.append(f"{cx + rr * math.cos(a):.2f},{cy + rr * math.sin(a):.2f}")
    return ' '.join(pts)

def khatam_tile(size, stroke, op, sw=1.2):
    s = size
    r = s * 0.36
    star = star_pts(s / 2, s / 2, r)
    corners = ''.join(f'<polygon points="{star_pts(x, y, r)}"/>' for x, y in [(0, 0), (s, 0), (0, s), (s, s)])
    return (f'<pattern id="kh" width="{s}" height="{s}" patternUnits="userSpaceOnUse">'
            f'<g fill="none" stroke="{stroke}" stroke-opacity="{op}" stroke-width="{sw}">'
            f'<polygon points="{star}"/>{corners}'
            f'<circle cx="{s/2}" cy="{s/2}" r="{r*0.42:.2f}"/></g></pattern>')

def build_screen_content(screen_id):
    if screen_id == '01_mushaf_listen':
        return f"""
        <div style="width:100%;height:100%;background:#0A2624 url(screens/spread_604.png) center/cover no-repeat;position:relative;">
          <div style="position:absolute;bottom:25px;left:50px;right:50px;height:75px;border-radius:999px;background:rgba(7,31,29,0.92);backdrop-filter:blur(20px);border:1.5px solid {GOLD};display:flex;align-items:center;justify-content:space-between;padding:0 25px;box-shadow:0 15px 30px rgba(0,0,0,0.5);">
            <div style="display:flex;align-items:center;gap:15px;">
              <div style="width:46px;height:46px;border-radius:50%;background:{GOLD};display:flex;align-items:center;justify-content:center;">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="{DEEP_BG}"><polygon points="7 4 19 12 7 20 7 4"/></svg>
              </div>
              <div>
                <div style="font-family:Plex;font-weight:700;font-size:19px;color:{CREAM};">الشيخ مشاري راشد العفاسي</div>
                <div style="font-family:Plex;font-size:15px;color:{GOLD};">سورة الناس · الآية ٣ · إضاءة متزامنة كلمةً كلمة</div>
              </div>
            </div>
            <div style="display:flex;align-items:center;gap:20px;color:{MINT};font-family:Plex;font-size:16px;font-weight:600;">
              <span>تكرار: ١</span>
              <span style="color:{GOLD};">● تلاوة حية</span>
            </div>
          </div>
        </div>
        """
    elif screen_id == '02_tasmee':
        return f"""
        <div style="width:100%;height:100%;display:flex;background:{DEEP_BG};">
          <div style="width:48%;height:100%;padding:30px;display:flex;flex-direction:column;justify-content:space-between;border-left:1.5px solid rgba(217,178,102,0.3);background:linear-gradient(135deg, #0A2624, #061917);">
            <div>
              <div style="display:inline-flex;align-items:center;gap:8px;padding:4px 16px;border-radius:999px;background:rgba(217,178,102,0.15);border:1px solid {GOLD};color:{GOLD};font-family:Plex;font-size:16px;font-weight:600;">
                <span>● التسميع المباشر يعمل بلا إنترنت</span>
              </div>
              <div style="font-family:Changa;font-size:32px;font-weight:700;color:{CREAM};margin-top:14px;">مصحح التلاوة الذكي</div>
              <div style="font-family:Plex;font-size:18px;color:{MINT};margin-top:6px;">يستمع لقراءتك وينبّهك لكل موضع خطأ</div>
            </div>
            
            <div style="background:rgba(10,38,36,0.85);border:1.5px solid rgba(217,178,102,0.4);border-radius:20px;padding:20px;text-align:center;">
              <div style="width:64px;height:64px;margin:0 auto;border-radius:50%;background:{GOLD};display:flex;align-items:center;justify-content:center;box-shadow:0 0 25px rgba(217,178,102,0.5);">
                <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="{DEEP_BG}" stroke-width="2"><path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z"/><path d="M19 10v2a7 7 0 0 1-14 0v-2"/><line x1="12" y1="19" x2="12" y2="23"/><line x1="8" y1="23" x2="16" y2="23"/></svg>
              </div>
              <div style="font-family:Plex;font-size:20px;font-weight:700;color:{CREAM};margin-top:14px;">يستمع الآن لتلاوتك…</div>
              <div style="display:flex;align-items:center;justify-content:center;gap:6px;height:35px;margin-top:12px;">
                <div style="width:5px;height:18px;background:{GOLD};border-radius:2px;"></div>
                <div style="width:5px;height:32px;background:{GOLD};border-radius:2px;"></div>
                <div style="width:5px;height:24px;background:{GOLD};border-radius:2px;"></div>
                <div style="width:5px;height:35px;background:{GOLD};border-radius:2px;"></div>
                <div style="width:5px;height:22px;background:{GOLD};border-radius:2px;"></div>
                <div style="width:5px;height:15px;background:{GOLD};border-radius:2px;"></div>
              </div>
              <div style="font-family:Plex;font-size:16px;color:#55BDB2;margin-top:10px;font-weight:600;">✓ التلاوة صحيحة · لا توجد أخطاء</div>
            </div>

            <div style="font-family:Plex;font-size:15px;color:{MINT};text-align:center;">معالجة صوتية فورية داخل جهازك لحماية خصوصيتك</div>
          </div>
          <div style="width:52%;height:100%;background:url(screens/03_qiraat.png) center/cover no-repeat;"></div>
        </div>
        """
    elif screen_id == '03_qiraat':
        return f"""
        <div style="width:100%;height:100%;background:#0A2624 url(screens/03_qiraat.png) center/cover no-repeat;position:relative;">
          <div style="position:absolute;top:20px;left:50%;transform:translateX(-50%);padding:8px 24px;border-radius:999px;background:rgba(7,31,29,0.9);border:1.5px solid {GOLD};font-family:Plex;font-size:18px;font-weight:700;color:{CREAM};">
            مصحف المدينة المنورة · رواية حفص عن عاصم (طبعة ١٤٤١هـ)
          </div>
        </div>
        """
    elif screen_id == '04_tafsir':
        return f"""
        <div style="width:100%;height:100%;display:flex;background:{DEEP_BG};">
          <div style="width:50%;height:100%;padding:35px;display:flex;flex-direction:column;justify-content:space-between;border-left:1.5px solid rgba(217,178,102,0.3);background:linear-gradient(135deg, #0A2624, #08201E);">
            <div>
              <div style="display:inline-flex;align-items:center;gap:8px;padding:4px 16px;border-radius:999px;background:rgba(217,178,102,0.15);border:1px solid {GOLD};color:{GOLD};font-family:Plex;font-size:16px;font-weight:600;">
                التفسير الميسّر · سورة الفاتحة
              </div>
              <div style="font-family:Changa;font-size:28px;font-weight:700;color:{GOLD};margin-top:16px;line-height:1.4;">
                ﴿ إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ ﴾
              </div>
              <div style="font-family:Plex;font-size:19px;color:{CREAM};margin-top:14px;line-height:1.6;">
                إنا نخصك وحدك بالعبادة، ونستعين بك وحدك في جميع أمورنا؛ فالأمر كله بيدك وحده.
              </div>
            </div>

            <div style="background:rgba(10,38,36,0.8);border-radius:16px;border:1px solid rgba(217,178,102,0.3);padding:18px;">
              <div style="font-family:Plex;font-weight:700;font-size:18px;color:{GOLD};">معاني الكلمات:</div>
              <div style="font-family:Plex;font-size:16px;color:{MINT};margin-top:8px;line-height:1.5;">
                • <strong style="color:{CREAM};">إِيَّاكَ نَعْبُدُ:</strong> نطيعك وحدك ونتذلل لك.<br>
                • <strong style="color:{CREAM};">نَسْتَعِينُ:</strong> نطلب العون والمدد منك.
              </div>
            </div>
            
            <div style="font-family:Plex;font-size:15px;color:{GOLD};font-weight:600;">بلمسة واحدة تظهر المعاني والإعراب فورًا</div>
          </div>
          <div style="width:50%;height:100%;background:url(screens/03_qiraat.png) center/cover no-repeat;"></div>
        </div>
        """
    elif screen_id == '05_hifz':
        return f"""
        <div style="width:100%;height:100%;padding:35px 50px;background:radial-gradient(circle at 50% 30%, #0F3834, {DEEP_BG});display:flex;flex-direction:column;justify-content:space-between;">
          <div style="display:flex;justify-content:space-between;align-items:center;">
            <div>
              <div style="font-family:Changa;font-size:34px;font-weight:700;color:{CREAM};">رحلة حفظ القرآن الكريم</div>
              <div style="font-family:Plex;font-size:18px;color:{MINT};margin-top:4px;">متابعة دقيقة لكل حزب وصفحة مع إخفاء الكلمات للتثبيت</div>
            </div>
            <div style="text-align:left;">
              <div style="font-family:Changa;font-size:38px;font-weight:700;color:{GOLD};">١٢ / ٣٠ جزءًا</div>
              <div style="font-family:Plex;font-size:16px;color:{MINT};">٤٠٪ من القرآن الكريم</div>
            </div>
          </div>

          <div style="display:grid;grid-template-columns:repeat(10, 1fr);gap:10px;margin-top:15px;">
            {''.join(f'<div style="background:{"#11706A" if i <= 12 else "rgba(10,38,36,0.6)"};border:1.2px solid {"#D9B266" if i <= 12 else "rgba(217,178,102,0.2)"};border-radius:10px;padding:10px 4px;text-align:center;"><div style="font-family:Changa;font-weight:700;font-size:17px;color:{CREAM};">ج {i}</div><div style="font-family:Plex;font-size:12px;color:{"#F6F1E8" if i <= 12 else "#CFE3DF"};margin-top:2px;">{"متقن ✓" if i <= 12 else "قيد الحفظ"}</div></div>' for i in range(1, 31))}
          </div>

          <div style="background:rgba(10,38,36,0.85);border-radius:16px;border:1.2px solid rgba(217,178,102,0.35);padding:15px 25px;display:flex;justify-content:space-between;align-items:center;">
            <div style="font-family:Plex;font-size:18px;color:{CREAM};font-weight:600;">ورد المراجعة اليومي: <span style="color:{GOLD};">سورة البقرة (ص ٢ - ٢٤)</span></div>
            <div style="padding:8px 22px;border-radius:999px;background:{GOLD};color:{DEEP_BG};font-family:Plex;font-size:17px;font-weight:700;">ابدأ جلسة التثبيت الآن</div>
          </div>
        </div>
        """
    elif screen_id == '06_khatma':
        return f"""
        <div style="width:100%;height:100%;padding:40px 55px;background:radial-gradient(circle at 50% 30%, #0F3834, {DEEP_BG});display:flex;flex-direction:column;justify-content:space-between;">
          <div>
            <div style="font-family:Changa;font-size:36px;font-weight:700;color:{CREAM};">الختمات الفردية والجماعية</div>
            <div style="font-family:Plex;font-size:18px;color:{MINT};margin-top:4px;">نظّم قراءتك وشارك ثواب الختمة مع الأهل والأصدقاء</div>
          </div>

          <div style="display:flex;gap:25px;margin-top:15px;">
            <div style="flex:1;background:rgba(10,38,36,0.85);border:1.5px solid {GOLD};border-radius:20px;padding:25px;">
              <div style="display:inline-block;padding:4px 14px;border-radius:999px;background:rgba(217,178,102,0.2);color:{GOLD};font-family:Plex;font-weight:700;font-size:15px;">ختمة فردية</div>
              <div style="font-family:Changa;font-size:26px;font-weight:700;color:{CREAM};margin-top:10px;">ختمة رمضان المباركة</div>
              <div style="font-family:Plex;font-size:18px;color:{GOLD};margin-top:6px;">صفحة ٢٤٢ من ٦٠٤ (٤٠٪)</div>
              <div style="width:100%;height:10px;background:rgba(255,255,255,0.1);border-radius:5px;margin-top:14px;overflow:hidden;">
                <div style="width:40%;height:100%;background:{GOLD};border-radius:5px;"></div>
              </div>
              <div style="font-family:Plex;font-size:15px;color:{MINT};margin-top:10px;">متبقي ٢٠ يومًا · ٤ صفحات يوميًا</div>
            </div>

            <div style="flex:1;background:rgba(10,38,36,0.85);border:1.5px solid rgba(217,178,102,0.4);border-radius:20px;padding:25px;">
              <div style="display:inline-block;padding:4px 14px;border-radius:999px;background:rgba(85,189,178,0.2);color:#55BDB2;font-family:Plex;font-weight:700;font-size:15px;">ختمة جماعية</div>
              <div style="font-family:Changa;font-size:26px;font-weight:700;color:{CREAM};margin-top:10px;">ختمة العائلة الكريمة</div>
              <div style="font-family:Plex;font-size:18px;color:#55BDB2;margin-top:6px;">مكتمل ٢٢ جزءًا من ٣٠ (٧٣٪)</div>
              <div style="width:100%;height:10px;background:rgba(255,255,255,0.1);border-radius:5px;margin-top:14px;overflow:hidden;">
                <div style="width:73%;height:100%;background:#55BDB2;border-radius:5px;"></div>
              </div>
              <div style="font-family:Plex;font-size:15px;color:{MINT};margin-top:10px;">٥ أعضاء مشاركون · الختام: الجمعة</div>
            </div>
          </div>

          <div style="font-family:Plex;font-size:16px;color:{GOLD};text-align:center;font-weight:600;">مزامنة سحابية فورية لكل الأجهزة عبر iCloud و Google Drive</div>
        </div>
        """
    elif screen_id == '07_styles':
        return f"""
        <div style="width:100%;height:100%;background:#041412 url(screens/spread_elderly.png) center/cover no-repeat;position:relative;">
          <div style="position:absolute;inset:0;background:radial-gradient(circle, rgba(14,95,88,0.2) 0%, rgba(2,12,11,0.65) 100%);"></div>
          <div style="position:absolute;top:20px;left:50%;transform:translateX(-50%);padding:8px 28px;border-radius:999px;background:rgba(4,20,18,0.92);border:1.5px solid {GOLD};font-family:Plex;font-size:18px;font-weight:700;color:{GOLD};box-shadow:0 8px 20px rgba(0,0,0,0.6);">
            النمط الليلي الذهبي · راحة تامة للعين في القراءة الليلية
          </div>
        </div>
        """
    elif screen_id == '08_misbaha':
        return f"""
        <div style="width:100%;height:100%;display:flex;background:{DEEP_BG};">
          <div style="width:52%;height:100%;padding:40px;display:flex;flex-direction:column;justify-content:space-between;border-left:1.5px solid rgba(217,178,102,0.3);background:linear-gradient(135deg, #0A2624, #061917);">
            <div>
              <div style="font-family:Changa;font-size:32px;font-weight:700;color:{CREAM};">المسبحة الإلكترونية الذكية</div>
              <div style="font-family:Plex;font-size:18px;color:{MINT};margin-top:4px;">أذكار مأثورة واهتزازات تفاعلية متزامنة مع الساعة</div>
            </div>

            <div style="display:flex;flex-direction:column;gap:10px;margin-top:15px;">
              <div style="background:rgba(217,178,102,0.18);border:1.2px solid {GOLD};border-radius:14px;padding:15px 20px;display:flex;justify-content:space-between;align-items:center;">
                <div style="font-family:Plex;font-size:20px;font-weight:700;color:{CREAM};">سُبْحَانَ اللَّهِ</div>
                <div style="font-family:Changa;font-size:24px;font-weight:700;color:{GOLD};">٣٣ / ٣٣ ✓</div>
              </div>
              <div style="background:rgba(10,38,36,0.6);border:1px solid rgba(217,178,102,0.3);border-radius:14px;padding:15px 20px;display:flex;justify-content:space-between;align-items:center;">
                <div style="font-family:Plex;font-size:20px;font-weight:600;color:{CREAM};">الْحَمْدُ لِلَّهِ</div>
                <div style="font-family:Changa;font-size:24px;font-weight:700;color:{MINT};">١٧ / ٣٣</div>
              </div>
              <div style="background:rgba(10,38,36,0.6);border:1px solid rgba(217,178,102,0.3);border-radius:14px;padding:15px 20px;display:flex;justify-content:space-between;align-items:center;">
                <div style="font-family:Plex;font-size:20px;font-weight:600;color:{CREAM};">اللَّهُ أَكْبَرُ</div>
                <div style="font-family:Changa;font-size:24px;font-weight:700;color:{MINT};">٠ / ٣٣</div>
              </div>
            </div>

            <div style="font-family:Plex;font-size:16px;color:{GOLD};font-weight:600;">تتزامن التسبيحات آنيًا مع Apple Watch و Wear OS</div>
          </div>

          <div style="width:48%;height:100%;display:flex;flex-direction:column;align-items:center;justify-content:center;background:radial-gradient(circle, #0F3834 0%, {DEEP_BG} 70%);position:relative;">
            <svg width="320" height="320" viewBox="0 0 320 320">
              <circle cx="160" cy="160" r="140" fill="none" stroke="rgba(217,178,102,0.2)" stroke-width="12"/>
              <circle cx="160" cy="160" r="140" fill="none" stroke="{GOLD}" stroke-width="12" stroke-dasharray="880" stroke-dashoffset="0" stroke-linecap="round"/>
            </svg>
            <div style="position:absolute;text-align:center;">
              <div style="font-family:Changa;font-size:90px;font-weight:700;color:{CREAM};line-height:1;">٣٣</div>
              <div style="font-family:Plex;font-size:22px;color:{GOLD};margin-top:6px;font-weight:600;">سُبْحَانَ اللَّهِ</div>
              <div style="font-family:Plex;font-size:16px;color:{MINT};margin-top:4px;">اكتمل الهدف</div>
            </div>
          </div>
        </div>
        """
    return ''

TABLET_SCREENS = [
    {
        'id': '01_mushaf_listen',
        'badge': 'صفحتان متقابلتان',
        'title': 'مصحفك مفتوحًا كالمصحف الشريف',
        'subtitle': 'عرض صفحتين متقابلتين مع تتبّع التلاوة وتظليل الكلمات آنيًا',
    },
    {
        'id': '02_tasmee',
        'badge': 'تسميع ذكي',
        'title': 'يستمع لتلاوتك ويُنبّهك بدقة',
        'subtitle': 'مصحح تلاوة آلي ينبّه لمواضع الخطأ والنسيان دون اتصال بالإنترنت',
    },
    {
        'id': '03_qiraat',
        'badge': 'المصاحف والروايات',
        'title': 'مصاحف متعددة وقراءات متواترة',
        'subtitle': 'مصحف المدينة المنورة والشمرلي بروايات ورش وقالون والدوري',
    },
    {
        'id': '04_tafsir',
        'badge': 'التفسير والتدبر',
        'title': 'التفسير الميسّر ومعاني المفردات',
        'subtitle': 'فهم الآيات بلمسة واحدة مع أسباب النزول وبيان الإعراب',
    },
    {
        'id': '05_hifz',
        'badge': 'رحلة الحفظ',
        'title': 'خريطة مصورة لمقدار حفظك',
        'subtitle': 'نظام متكامل لمتابعة الحفظ وتثبيته مع وضع إخفاء الكلمات',
    },
    {
        'id': '06_khatma',
        'badge': 'الختمات المباركة',
        'title': 'ختمات فردية وجماعية مع العائلة',
        'subtitle': 'خطط مرنة للختم وتوزيع الأجزاء ومتابعة الإنجاز اليومي',
    },
    {
        'id': '07_styles',
        'badge': 'تصميم إسلامي راقٍ',
        'title': 'أنماط هندسية ووضع ليلي مريح',
        'subtitle': 'ثلاثة أنماط إسلامية بديعة مع وضع ليلي مريح ووضع لكبار السن',
    },
    {
        'id': '08_misbaha',
        'badge': 'مسبحة إلكترونية',
        'title': 'مسبحة ثلاثية الأبعاد ذكية',
        'subtitle': 'أذكار مأثورة واهتزازات تفاعلية وتزامن كامل مع ساعتك الذكية',
    },
]

def render_tablet_7_html(data):
    star_svg = star_pts(W / 2, H * 0.65, H * 0.75, 0.7654)
    tab_w = 1540
    tab_h = 960
    tab_left = (W - tab_w) // 2
    tab_top = 210
    tab_radius = 34
    tab_border = 14

    inner_content = build_screen_content(data['id'])

    return f"""<!doctype html><html dir="rtl" lang="ar"><head><meta charset="utf-8"><style>
@font-face{{font-family:Plex;src:url('file://{FONTS}/ibmplexsansarabic/IBMPlexSansArabic-Medium.ttf');font-weight:500}}
@font-face{{font-family:Plex;src:url('file://{FONTS}/ibmplexsansarabic/IBMPlexSansArabic-SemiBold.ttf');font-weight:600}}
@font-face{{font-family:Plex;src:url('file://{FONTS}/ibmplexsansarabic/IBMPlexSansArabic-Bold.ttf');font-weight:700}}
@font-face{{font-family:Changa;src:url('file://{FONTS}/changa/Changa[wght].ttf')}}
*{{margin:0;padding:0;box-sizing:border-box}}
html,body{{width:{W}px;height:{H}px;overflow:hidden}}
body{{position:relative;font-family:Changa,Plex,sans-serif;-webkit-font-smoothing:antialiased}}
.abs{{position:absolute}}
</style></head><body>
<svg class="abs" width="{W}" height="{H}">
  <defs>
    {khatam_tile(120, CREAM, 0.06, 1.2)}
    <linearGradient id="bg" x1="1" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="{TEAL_1}"/>
      <stop offset="100%" stop-color="{TEAL_2}"/>
    </linearGradient>
    <radialGradient id="hl" cx="50%" cy="30%" r="55%">
      <stop offset="0%" stop-color="#55BDB2" stop-opacity="0.25"/>
      <stop offset="100%" stop-color="#55BDB2" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="{W}" height="{H}" fill="url(#bg)"/>
  <rect width="{W}" height="{H}" fill="url(#kh)"/>
  <rect width="{W}" height="{H}" fill="url(#hl)"/>
  <polygon points="{star_svg}" fill="{CREAM}" fill-opacity="0.03" stroke="{GOLD}" stroke-opacity="0.35" stroke-width="1.6"/>
</svg>

<!-- Header Content -->
<div class="abs" style="left:60px;right:60px;top:40px;text-align:center;">
  <div style="display:inline-block;padding:6px 26px;border-radius:999px;border:1.4px solid rgba(217,178,102,0.65);background:rgba(10,63,59,0.7);color:{GOLD};font-size:22px;font-weight:600;font-family:Plex,sans-serif;">
    {data['badge']}
  </div>
  <div style="font-size:42px;font-weight:700;color:{CREAM};margin-top:10px;line-height:1.2;text-shadow:0 4px 16px rgba(4,30,28,0.5);">
    {data['title']}
  </div>
  <div style="font-size:20px;font-weight:500;color:{MINT};margin-top:6px;font-family:Plex,sans-serif;">
    {data['subtitle']}
  </div>
</div>

<!-- 7-inch Landscape Tablet Device Frame -->
<div class="abs" style="left:{tab_left}px;top:{tab_top}px;width:{tab_w}px;height:{tab_h}px;border-radius:{tab_radius}px;background:#0A2422;padding:{tab_border}px;box-shadow:0 40px 80px -20px rgba(5,25,23,0.85), 0 0 0 2px rgba(217,178,102,0.45);">
  <div style="width:100%;height:100%;border-radius:{tab_radius - tab_border}px;overflow:hidden;background:{DEEP_BG};">
    {inner_content}
  </div>
</div>

</body></html>"""

def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    tmp_html = os.path.join(HERE, '_tab7_tmp.html')

    print(f"\n--- Generating 7-inch Android Tablet Screenshots in TRUE LANDSCAPE ({W}x{H}) ---")
    for data in TABLET_SCREENS:
        html = render_tablet_7_html(data)
        with open(tmp_html, 'w') as f:
            f.write(html)
        
        out_png = os.path.join(OUT_DIR, f"{data['id']}.png")
        cmd = [
            CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars',
            '--allow-file-access-from-files', '--force-device-scale-factor=1',
            f'--window-size={W},{H}', '--virtual-time-budget=2000',
            f'--screenshot={out_png}', f'file://{tmp_html}'
        ]
        subprocess.run(cmd, check=True)
        print(f"  ✓ {data['id']}.png (1920x1200 landscape)")

    if os.path.exists(tmp_html):
        os.remove(tmp_html)
    print("All 7-inch tablet screenshots generated successfully in landscape!")

if __name__ == '__main__':
    main()
