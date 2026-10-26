#!/usr/bin/env python3
"""Generate 10-inch Android Tablet screenshots in LANDSCAPE (2560x1600) showing the 2-page spread."""
import math, os, subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.abspath(os.path.join(HERE, '../screenshots/android_tablet_10'))
FONTS = os.path.abspath(os.path.join(HERE, '../../../../assets/fonts/ofl'))
CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'

W, H = 2560, 1600

TEAL_1, TEAL_2 = '#11706A', '#0A4F4A'
CREAM = '#F6F1E8'
GOLD = '#D9B266'
MINT = '#CFE3DF'

TABLET_SCREENS = [
    {
        'id': '01_mushaf_listen',
        'badge': 'صفحتان متقابلتان',
        'title': 'مصحفك مفتوحًا كالمصحف الشريف',
        'subtitle': 'عرض صفحتين متقابلتين مع تتبّع التلاوة وتظليل الكلمات آنيًا',
        'img': '03_qiraat.png', # 2-page spread
    },
    {
        'id': '02_tasmee',
        'badge': 'تسميع ذكي',
        'title': 'يستمع لتلاوتك ويُنبّهك بدقة',
        'subtitle': 'مصحح تلاوة آلي ينبّه لمواضع الخطأ والنسيان دون اتصال بالإنترنت',
        'img': '02_tasmee.png',
    },
    {
        'id': '03_qiraat',
        'badge': 'المصاحف والروايات',
        'title': 'مصاحف متعددة وقراءات متواترة',
        'subtitle': 'مصحف المدينة المنورة والشمرلي بروايات ورش وقالون والدوري',
        'img': '03_qiraat.png', # 2-page spread
    },
    {
        'id': '04_tafsir',
        'badge': 'التفسير والتدبر',
        'title': 'التفسير الميسّر ومعاني المفردات',
        'subtitle': 'فهم الآيات بلمسة واحدة مع أسباب النزول وبيان الإعراب',
        'img': '04_tafsir.png',
    },
    {
        'id': '05_hifz',
        'badge': 'رحلة الحفظ',
        'title': 'خريطة مصورة لمقدار حفظك',
        'subtitle': 'نظام متكامل لمتابعة الحفظ وتثبيته مع وضع إخفاء الكلمات',
        'img': '05_hifz.png',
    },
    {
        'id': '06_khatma',
        'badge': 'الختمات المباركة',
        'title': 'ختمات فردية وجماعية مع العائلة',
        'subtitle': 'خطط مرنة للختم وتوزيع الأجزاء ومتابعة الإنجاز اليومي',
        'img': '06_khatma.png',
    },
    {
        'id': '07_styles',
        'badge': 'تصميم إسلامي راقٍ',
        'title': 'أنماط هندسية ووضع ليلي مريح',
        'subtitle': 'ثلاثة أنماط إسلامية بديعة مع وضع ليلي مريح ووضع لكبار السن',
        'img': '07_styles.png',
    },
    {
        'id': '08_misbaha',
        'badge': 'مسبحة إلكترونية',
        'title': 'مسبحة ثلاثية الأبعاد ذكية',
        'subtitle': 'أذكار مأثورة واهتزازات تفاعلية وتزامن كامل مع ساعتك الذكية',
        'img': '08_tasbih.png',
    },
]

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

def render_tablet_landscape_html(data):
    img_path = f"screens/{data['img']}"
    # In landscape:
    # 2-page spread images (03_qiraat) use cover/contain nicely
    fit_mode = 'cover' if 'qiraat' in data['img'] else 'contain'
    star_svg = star_pts(W / 2, H * 0.65, H * 0.75, 0.7654)

    tab_w = 1960
    tab_h = 1225
    tab_left = (W - tab_w) // 2
    tab_top = 310
    tab_radius = 42
    tab_border = 18

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
    {khatam_tile(140, CREAM, 0.06, 1.2)}
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
  <polygon points="{star_svg}" fill="{CREAM}" fill-opacity="0.03" stroke="{GOLD}" stroke-opacity="0.35" stroke-width="1.8"/>
</svg>

<!-- Header Content -->
<div class="abs" style="left:80px;right:80px;top:70px;text-align:center;">
  <div style="display:inline-block;padding:8px 32px;border-radius:999px;border:1.6px solid rgba(217,178,102,0.65);background:rgba(10,63,59,0.7);color:{GOLD};font-size:28px;font-weight:600;font-family:Plex,sans-serif;">
    {data['badge']}
  </div>
  <div style="font-size:56px;font-weight:700;color:{CREAM};margin-top:16px;line-height:1.2;text-shadow:0 4px 16px rgba(4,30,28,0.5);">
    {data['title']}
  </div>
  <div style="font-size:28px;font-weight:500;color:{MINT};margin-top:10px;font-family:Plex,sans-serif;">
    {data['subtitle']}
  </div>
</div>

<!-- 10-inch Landscape Tablet Device Frame -->
<div class="abs" style="left:{tab_left}px;top:{tab_top}px;width:{tab_w}px;height:{tab_h}px;border-radius:{tab_radius}px;background:#0A2422;padding:{tab_border}px;box-shadow:0 50px 100px -25px rgba(5,25,23,0.85), 0 0 0 2.5px rgba(217,178,102,0.45);">
  <div style="width:100%;height:100%;border-radius:{tab_radius - tab_border}px;overflow:hidden;background:#051413 url({img_path}) center/{fit_mode} no-repeat;"></div>
</div>

</body></html>"""

def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    tmp_html = os.path.join(HERE, '_tab10_tmp.html')

    print(f"\n--- Generating 10-inch Android Tablet Screenshots in LANDSCAPE ({W}x{H}) ---")
    for data in TABLET_SCREENS:
        html = render_tablet_landscape_html(data)
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
        print(f"  ✓ {data['id']}.png (2560x1600 landscape)")

    if os.path.exists(tmp_html):
        os.remove(tmp_html)
    print("Done!")

if __name__ == '__main__':
    main()
