#!/usr/bin/env python3
"""Generate branded store screenshots for App Store and Google Play."""
import math, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.abspath(os.path.join(HERE, '../screenshots'))
FONTS = os.path.abspath(os.path.join(HERE, '../../../../assets/fonts/ofl'))
SCREENS_DIR = os.path.join(HERE, 'screens')
CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'

TEAL_1, TEAL_2 = '#11706A', '#0A4F4A'
CREAM = '#F6F1E8'
GOLD = '#D9B266'
MINT = '#CFE3DF'

SCREENS_DATA = [
    {
        'id': '01_mushaf_listen',
        'badge': 'تلاوة متزامنة',
        'title': 'تتبّع التلاوة كلمةً كلمة',
        'subtitle': 'إضاءة تفاعلية متزامنة مع كبار القرّاء بروايات متعددة',
        'img': '01_listen.png',
        'img_spread': '03_qiraat.png',
    },
    {
        'id': '02_tasmee',
        'badge': 'تسميع ذكي',
        'title': 'يستمع لتلاوتك ويُنبّهك',
        'subtitle': 'مصحح تلاوة آلي ينبّه لمواضع الخطأ والنسيان بلا إنترنت',
        'img': '02_tasmee.png',
        'img_spread': '02_tasmee.png',
    },
    {
        'id': '03_qiraat',
        'badge': 'المصاحف والروايات',
        'title': 'مصحف المدينة والشمرلي',
        'subtitle': 'روايات ورش وقالون والدوري بخطوط وطباعات متقنة',
        'img': '03_qiraat_phone.jpg',
        'img_spread': '03_qiraat.png',
    },
    {
        'id': '04_tafsir',
        'badge': 'التفسير والتدبر',
        'title': 'التفسير الميسّر ومعاني الكلمات',
        'subtitle': 'فهم الآيات بلمسة مع بيان أسباب النزول والإعراب',
        'img': '04_tafsir.png',
        'img_spread': '04_tafsir.png',
    },
    {
        'id': '05_hifz',
        'badge': 'رحلة الحفظ',
        'title': 'خريطة مصورة لمقدار حفظك',
        'subtitle': 'نظام حفظ مرن مع إخفاء الكلمات ومتابعة التثبيت والمراجعة',
        'img': '05_hifz.png',
        'img_spread': '05_hifz.png',
    },
    {
        'id': '06_khatma',
        'badge': 'الختمات المباركة',
        'title': 'ختمات فردية وجماعية',
        'subtitle': 'خطط مرنة للختم وتوزيع الأجزاء مع الأهل والأصدقاء',
        'img': '06_khatma.png',
        'img_spread': '06_khatma.png',
    },
    {
        'id': '07_styles',
        'badge': 'تصميم إسلامي راقٍ',
        'title': 'أنماط هندسية ووضع ليلي',
        'subtitle': 'ثلاثة أنماط للواجهة مع وضع ليلي مريح ووضع لكبار السن',
        'img': '07_styles.png',
        'img_spread': '07_styles.png',
    },
    {
        'id': '08_misbaha',
        'badge': 'مسبحة إلكترونية',
        'title': 'مسبحة ثلاثية الأبعاد ذكية',
        'subtitle': 'أذكار مأثورة واهتزازات تفاعلية وتزامن كامل مع الساعة',
        'img': '08_tasbih.png',
        'img_spread': '08_tasbih.png',
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

def render_html_phone(w, h, data):
    img_path = f"screens/{data['img']}"
    # Header scales nicely based on canvas height
    scale = h / 2796.0
    title_sz = int(68 * scale)
    sub_sz = int(34 * scale)
    badge_sz = int(32 * scale)
    top_pad = int(140 * scale)
    
    # Phone mockup sizing
    phone_w = int(w * 0.82)
    phone_h = int(phone_w * 2.15)
    phone_left = (w - phone_w) // 2
    phone_top = int(480 * scale)
    phone_radius = int(64 * scale)
    phone_border = int(14 * scale)

    star_svg = star_pts(w / 2, h * 0.55, w * 0.65, 0.7654)

    return f"""<!doctype html><html dir="rtl" lang="ar"><head><meta charset="utf-8"><style>
@font-face{{font-family:Plex;src:url('file://{FONTS}/ibmplexsansarabic/IBMPlexSansArabic-Medium.ttf');font-weight:500}}
@font-face{{font-family:Plex;src:url('file://{FONTS}/ibmplexsansarabic/IBMPlexSansArabic-SemiBold.ttf');font-weight:600}}
@font-face{{font-family:Plex;src:url('file://{FONTS}/ibmplexsansarabic/IBMPlexSansArabic-Bold.ttf');font-weight:700}}
@font-face{{font-family:Changa;src:url('file://{FONTS}/changa/Changa[wght].ttf')}}
*{{margin:0;padding:0;box-sizing:border-box}}
html,body{{width:{w}px;height:{h}px;overflow:hidden}}
body{{position:relative;font-family:Changa,Plex,sans-serif;-webkit-font-smoothing:antialiased}}
.abs{{position:absolute}}
</style></head><body>
<svg class="abs" width="{w}" height="{h}">
  <defs>
    {khatam_tile(120, CREAM, 0.06, 1.2)}
    <linearGradient id="bg" x1="1" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="{TEAL_1}"/>
      <stop offset="100%" stop-color="{TEAL_2}"/>
    </linearGradient>
    <radialGradient id="hl" cx="50%" cy="30%" r="55%">
      <stop offset="0%" stop-color="#55BDB2" stop-opacity="0.28"/>
      <stop offset="100%" stop-color="#55BDB2" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="{w}" height="{h}" fill="url(#bg)"/>
  <rect width="{w}" height="{h}" fill="url(#kh)"/>
  <rect width="{w}" height="{h}" fill="url(#hl)"/>
  <polygon points="{star_svg}" fill="{CREAM}" fill-opacity="0.03" stroke="{GOLD}" stroke-opacity="0.35" stroke-width="1.5"/>
</svg>

<!-- Header Content -->
<div class="abs" style="left:40px;right:40px;top:{top_pad}px;text-align:center;">
  <div style="display:inline-block;padding:{int(8*scale)}px {int(28*scale)}px;border-radius:999px;border:1.5px solid rgba(217,178,102,0.65);background:rgba(10,63,59,0.7);color:{GOLD};font-size:{badge_sz}px;font-weight:600;font-family:Plex,sans-serif;">
    {data['badge']}
  </div>
  <div style="font-size:{title_sz}px;font-weight:700;color:{CREAM};margin-top:{int(18*scale)}px;line-height:1.2;text-shadow:0 4px 16px rgba(4,30,28,0.5);">
    {data['title']}
  </div>
  <div style="font-size:{sub_sz}px;font-weight:500;color:{MINT};margin-top:{int(10*scale)}px;font-family:Plex,sans-serif;">
    {data['subtitle']}
  </div>
</div>

<!-- Phone Device Mockup -->
<div class="abs" style="left:{phone_left}px;top:{phone_top}px;width:{phone_w}px;height:{phone_h}px;border-radius:{phone_radius}px;background:#0A2422;padding:{phone_border}px;box-shadow:0 {int(45*scale)}px {int(90*scale)}px -{int(25*scale)}px rgba(5,25,23,0.85), 0 0 0 {int(2.5*scale)}px rgba(217,178,102,0.45);">
  <div style="width:100%;height:100%;border-radius:{phone_radius - phone_border}px;overflow:hidden;background:#051413 url({img_path}) center top/cover no-repeat;"></div>
</div>

</body></html>"""

def render_html_tablet(w, h, data):
    img_path = f"screens/{data['img_spread'] if data['id'] == '03_qiraat' else data['img']}"
    scale = h / 2732.0
    title_sz = int(72 * scale)
    sub_sz = int(36 * scale)
    badge_sz = int(34 * scale)
    top_pad = int(140 * scale)

    tab_w = int(w * 0.86)
    tab_h = int(h * 0.76)
    tab_left = (w - tab_w) // 2
    tab_top = int(480 * scale)
    tab_radius = int(48 * scale)
    tab_border = int(16 * scale)

    star_svg = star_pts(w / 2, h * 0.58, w * 0.72, 0.7654)

    return f"""<!doctype html><html dir="rtl" lang="ar"><head><meta charset="utf-8"><style>
@font-face{{font-family:Plex;src:url('file://{FONTS}/ibmplexsansarabic/IBMPlexSansArabic-Medium.ttf');font-weight:500}}
@font-face{{font-family:Plex;src:url('file://{FONTS}/ibmplexsansarabic/IBMPlexSansArabic-SemiBold.ttf');font-weight:600}}
@font-face{{font-family:Plex;src:url('file://{FONTS}/ibmplexsansarabic/IBMPlexSansArabic-Bold.ttf');font-weight:700}}
@font-face{{font-family:Changa;src:url('file://{FONTS}/changa/Changa[wght].ttf')}}
*{{margin:0;padding:0;box-sizing:border-box}}
html,body{{width:{w}px;height:{h}px;overflow:hidden}}
body{{position:relative;font-family:Changa,Plex,sans-serif;-webkit-font-smoothing:antialiased}}
.abs{{position:absolute}}
</style></head><body>
<svg class="abs" width="{w}" height="{h}">
  <defs>
    {khatam_tile(140, CREAM, 0.06, 1.2)}
    <linearGradient id="bg" x1="1" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="{TEAL_1}"/>
      <stop offset="100%" stop-color="{TEAL_2}"/>
    </linearGradient>
    <radialGradient id="hl" cx="50%" cy="30%" r="55%">
      <stop offset="0%" stop-color="#55BDB2" stop-opacity="0.28"/>
      <stop offset="100%" stop-color="#55BDB2" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="{w}" height="{h}" fill="url(#bg)"/>
  <rect width="{w}" height="{h}" fill="url(#kh)"/>
  <rect width="{w}" height="{h}" fill="url(#hl)"/>
  <polygon points="{star_svg}" fill="{CREAM}" fill-opacity="0.03" stroke="{GOLD}" stroke-opacity="0.35" stroke-width="1.6"/>
</svg>

<div class="abs" style="left:50px;right:50px;top:{top_pad}px;text-align:center;">
  <div style="display:inline-block;padding:{int(10*scale)}px {int(32*scale)}px;border-radius:999px;border:1.6px solid rgba(217,178,102,0.65);background:rgba(10,63,59,0.7);color:{GOLD};font-size:{badge_sz}px;font-weight:600;font-family:Plex,sans-serif;">
    {data['badge']}
  </div>
  <div style="font-size:{title_sz}px;font-weight:700;color:{CREAM};margin-top:{int(20*scale)}px;line-height:1.2;text-shadow:0 4px 16px rgba(4,30,28,0.5);">
    {data['title']}
  </div>
  <div style="font-size:{sub_sz}px;font-weight:500;color:{MINT};margin-top:{int(12*scale)}px;font-family:Plex,sans-serif;">
    {data['subtitle']}
  </div>
</div>

<!-- Tablet Mockup -->
<div class="abs" style="left:{tab_left}px;top:{tab_top}px;width:{tab_w}px;height:{tab_h}px;border-radius:{tab_radius}px;background:#0A2422;padding:{tab_border}px;box-shadow:0 {int(50*scale)}px {int(100*scale)}px -{int(25*scale)}px rgba(5,25,23,0.85), 0 0 0 {int(2.5*scale)}px rgba(217,178,102,0.45);">
  <div style="width:100%;height:100%;border-radius:{tab_radius - tab_border}px;overflow:hidden;background:#051413 url({img_path}) center/contain no-repeat;"></div>
</div>

</body></html>"""

def render_html_mac(w, h, data):
    img_path = f"screens/{data['img_spread'] if data['id'] == '03_qiraat' else data['img']}"
    scale = w / 2880.0
    title_sz = int(64 * scale)
    sub_sz = int(32 * scale)
    badge_sz = int(30 * scale)
    top_pad = int(80 * scale)

    lap_w = int(w * 0.78)
    lap_h = int(lap_w * 0.62)
    lap_left = (w - lap_w) // 2
    lap_top = int(340 * scale)
    lap_radius = int(24 * scale)
    lap_border = int(18 * scale)

    star_svg = star_pts(w / 2, h * 0.62, h * 0.65, 0.7654)

    return f"""<!doctype html><html dir="rtl" lang="ar"><head><meta charset="utf-8"><style>
@font-face{{font-family:Plex;src:url('file://{FONTS}/ibmplexsansarabic/IBMPlexSansArabic-Medium.ttf');font-weight:500}}
@font-face{{font-family:Plex;src:url('file://{FONTS}/ibmplexsansarabic/IBMPlexSansArabic-SemiBold.ttf');font-weight:600}}
@font-face{{font-family:Plex;src:url('file://{FONTS}/ibmplexsansarabic/IBMPlexSansArabic-Bold.ttf');font-weight:700}}
@font-face{{font-family:Changa;src:url('file://{FONTS}/changa/Changa[wght].ttf')}}
*{{margin:0;padding:0;box-sizing:border-box}}
html,body{{width:{w}px;height:{h}px;overflow:hidden}}
body{{position:relative;font-family:Changa,Plex,sans-serif;-webkit-font-smoothing:antialiased}}
.abs{{position:absolute}}
</style></head><body>
<svg class="abs" width="{w}" height="{h}">
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
  <rect width="{w}" height="{h}" fill="url(#bg)"/>
  <rect width="{w}" height="{h}" fill="url(#kh)"/>
  <rect width="{w}" height="{h}" fill="url(#hl)"/>
  <polygon points="{star_svg}" fill="{CREAM}" fill-opacity="0.03" stroke="{GOLD}" stroke-opacity="0.35" stroke-width="1.6"/>
</svg>

<div class="abs" style="left:60px;right:60px;top:{top_pad}px;text-align:center;">
  <div style="display:inline-block;padding:{int(8*scale)}px {int(28*scale)}px;border-radius:999px;border:1.6px solid rgba(217,178,102,0.65);background:rgba(10,63,59,0.7);color:{GOLD};font-size:{badge_sz}px;font-weight:600;font-family:Plex,sans-serif;">
    {data['badge']}
  </div>
  <div style="font-size:{title_sz}px;font-weight:700;color:{CREAM};margin-top:{int(16*scale)}px;line-height:1.2;text-shadow:0 4px 16px rgba(4,30,28,0.5);">
    {data['title']}
  </div>
  <div style="font-size:{sub_sz}px;font-weight:500;color:{MINT};margin-top:{int(10*scale)}px;font-family:Plex,sans-serif;">
    {data['subtitle']}
  </div>
</div>

<!-- Laptop Mockup -->
<div class="abs" style="left:{lap_left}px;top:{lap_top}px;width:{lap_w}px;">
  <div style="width:100%;height:{lap_h}px;border-radius:{lap_radius}px {lap_radius}px 4px 4px;background:#181A1A;padding:{lap_border}px;box-shadow:0 0 0 2px rgba(217,178,102,0.35);">
    <div style="width:100%;height:100%;border-radius:6px;overflow:hidden;background:#051413 url({img_path}) center/contain no-repeat;"></div>
  </div>
  <div style="height:{int(22*scale)}px;margin:0 -{int(45*scale)}px;background:linear-gradient(#C9C6BF,#8F8C86);border-radius:0 0 {int(20*scale)}px {int(20*scale)}px;box-shadow:0 {int(30*scale)}px {int(60*scale)}px -{int(15*scale)}px rgba(5,25,23,0.8);">
    <div style="width:{int(160*scale)}px;height:{int(8*scale)}px;margin:0 auto;background:#77746F;border-radius:0 0 8px 8px;"></div>
  </div>
</div>

</body></html>"""

TARGETS = [
    ('iphone_6.9', 1290, 2796, render_html_phone),
    ('android_phone', 1080, 2400, render_html_phone),
    ('ipad_13', 2048, 2732, render_html_tablet),
    ('android_tablet_7', 1200, 1920, render_html_tablet),
    ('android_tablet_10', 1600, 2560, render_html_tablet),
    ('mac', 2880, 1800, render_html_mac),
]

def main():
    tmp_html = os.path.join(HERE, '_render_tmp.html')
    
    for device_name, w, h, render_fn in TARGETS:
        device_out = os.path.join(OUT_DIR, device_name)
        os.makedirs(device_out, exist_ok=True)
        print(f"\n--- Generating {device_name} ({w}x{h}) ---")
        
        for data in SCREENS_DATA:
            html = render_fn(w, h, data)
            with open(tmp_html, 'w') as f:
                f.write(html)
            
            out_png = os.path.join(device_out, f"{data['id']}.png")
            cmd = [
                CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars',
                '--allow-file-access-from-files', '--force-device-scale-factor=1',
                f'--window-size={w},{h}', '--virtual-time-budget=2000',
                f'--screenshot={out_png}', f'file://{tmp_html}'
            ]
            subprocess.run(cmd, check=True)
            print(f"  ✓ {data['id']}.png")
            
    if os.path.exists(tmp_html):
        os.remove(tmp_html)
    print("\nAll device screenshots generated successfully!")

if __name__ == '__main__':
    main()
