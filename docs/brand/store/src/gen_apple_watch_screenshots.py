#!/usr/bin/env python3
"""Generate Apple Watch store screenshots in the «ليل هندسي» look (410x502 for Apple Watch Ultra)."""
import math, os, subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_APPSTORE = os.path.abspath(os.path.join(HERE, '../../appstore/watch'))
OUT_STORE = os.path.abspath(os.path.join(HERE, '../screenshots/apple_watch'))
FONTS = os.path.abspath(os.path.join(HERE, '../../../../assets/fonts/ofl'))
CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'

WIDTH, HEIGHT = 410, 502
TEAL, DEEP, NIGHT = "#0e5f58", "#06302c", "#020c0b"
CREAM, GOLD = "#f4ecd8", "#d9b266"

def star_pts(cx, cy, r, inner=0.765):
    pts = []
    for i in range(16):
        rr = r if i % 2 == 0 else r * inner
        a = -math.pi / 2 + i * math.pi / 8
        pts.append(f"{cx + math.cos(a) * rr:.1f},{cy + math.sin(a) * rr:.1f}")
    return ' '.join(pts)

def girih_svg(w, h, cell=110):
    paths = []
    y = 0.0
    while y < h + cell:
        x = 0.0
        while x < w + cell:
            paths.append(f'<polygon points="{star_pts(x, y, cell * 0.5, 0.72)}"/>')
            x += cell
        y += cell
    return ''.join(paths)

def ring_path(cx, cy, r, progress):
    angle = 360 * progress
    rad = math.radians(angle - 90)
    end_x = cx + r * math.cos(rad)
    end_y = cy + r * math.sin(rad)
    large = 1 if angle > 180 else 0
    return f"M{cx},{cy-r} A{r},{r} 0 {large},1 {end_x:.1f},{end_y:.1f}"

SCREENS = [
    {
        'file': '01_apple_watch_misbaha.png',
        'title': 'المسبحة الذكية',
        'content': f"""
        <!-- Gold Edge Progress Ring -->
        <circle cx="205" cy="251" r="185" fill="none" stroke="{GOLD}" stroke-width="10" stroke-linecap="round"/>
        <text x="205" y="125" text-anchor="middle" fill="{GOLD}" font-family="Plex" font-size="20" font-weight="600">سُبْحَانَ اللَّهِ</text>
        <text x="205" y="270" text-anchor="middle" fill="{CREAM}" font-family="Changa,Plex" font-size="110" font-weight="700">٣٣</text>
        <text x="205" y="335" text-anchor="middle" fill="{GOLD}" font-family="Plex" font-size="22" font-weight="500">من ٣٣</text>
        <!-- Stage pill -->
        <rect x="155" y="380" width="100" height="34" rx="17" fill="rgba(217,178,102,0.18)" stroke="{GOLD}" stroke-width="1.2"/>
        <text x="205" y="404" text-anchor="middle" fill="{CREAM}" font-family="Plex" font-size="18" font-weight="600">١ / ٤</text>
        """
    },
    {
        'file': '02_apple_watch_wird.png',
        'title': 'الورد القرآني',
        'content': f"""
        <!-- Gold Edge Progress Ring (45%) -->
        <circle cx="205" cy="251" r="185" fill="none" stroke="{GOLD}" stroke-opacity="0.2" stroke-width="10"/>
        <path d="{ring_path(205, 251, 185, 0.45)}" fill="none" stroke="{GOLD}" stroke-width="10" stroke-linecap="round"/>
        <!-- 8-point mini star -->
        <polygon points="{star_pts(205, 125, 24, 0.765)}" fill="{CREAM}" fill-opacity="0.1" stroke="{GOLD}" stroke-width="1.5"/>
        <text x="205" y="185" text-anchor="middle" fill="{GOLD}" font-family="Plex" font-size="22" font-weight="600">سورة البقرة</text>
        <text x="205" y="265" text-anchor="middle" fill="{CREAM}" font-family="Changa,Plex" font-size="62" font-weight="700">٤٥٪</text>
        <text x="205" y="328" text-anchor="middle" fill="{CREAM}" font-family="Plex" font-size="24" font-weight="500">صفحة ٢٤ من ٥٠</text>
        <text x="205" y="385" text-anchor="middle" fill="{GOLD}" font-family="Plex" font-size="19" font-weight="600">متبقي ٢٦ صفحة</text>
        """
    },
    {
        'file': '03_apple_watch_khatma.png',
        'title': 'متابعة الختمة',
        'content': f"""
        <rect x="18" y="55" width="374" height="392" rx="38" fill="none" stroke="{GOLD}" stroke-opacity="0.3" stroke-width="3"/>
        <text x="205" y="130" text-anchor="middle" fill="{CREAM}" font-family="Plex" font-size="21" font-weight="500">ختمة رمضان المباركة</text>
        <text x="205" y="225" text-anchor="middle" fill="{GOLD}" font-family="Changa,Plex" font-size="74" font-weight="700">الجزء ١٢</text>
        <text x="205" y="295" text-anchor="middle" fill="{CREAM}" font-family="Plex" font-size="23" font-weight="600">الحزب ٢٣ · ص ٢٤٢</text>
        <!-- Continue reading pill -->
        <g transform="translate(105, 345)">
          <rect width="200" height="50" rx="25" fill="{GOLD}"/>
          <text x="100" y="33" text-anchor="middle" fill="{NIGHT}" font-family="Plex" font-size="22" font-weight="700">تابع القراءة</text>
        </g>
        """
    },
    {
        'file': '04_apple_watch_complications.png',
        'title': 'الويدجت والتعقيدات',
        'content': f"""
        <rect x="18" y="55" width="374" height="392" rx="38" fill="none" stroke="{GOLD}" stroke-opacity="0.25" stroke-width="2"/>
        <!-- Big decorative Girih Star -->
        <polygon points="{star_pts(205, 245, 145, 0.765)}" fill="{CREAM}" fill-opacity="0.06" stroke="{GOLD}" stroke-width="2.2"/>
        <polygon points="{star_pts(205, 245, 120, 0.765)}" fill="none" stroke="{GOLD}" stroke-opacity="0.4" stroke-width="1.2"/>
        <text x="205" y="225" text-anchor="middle" fill="{CREAM}" font-family="Changa" font-size="34" font-weight="700">تِبيَان</text>
        <text x="205" y="270" text-anchor="middle" fill="{GOLD}" font-family="Plex" font-size="21" font-weight="600">مصحف وذكر</text>
        <text x="205" y="350" text-anchor="middle" fill="{CREAM}" font-family="Plex" font-size="18" font-weight="500">ويدجت وتعقيدات الساعة</text>
        """
    }
]

def make_html(screen):
    return f"""<!doctype html><html dir="rtl" lang="ar"><head><meta charset="utf-8"><style>
@font-face{{font-family:Plex;src:url('file://{FONTS}/ibmplexsansarabic/IBMPlexSansArabic-Medium.ttf');font-weight:500}}
@font-face{{font-family:Plex;src:url('file://{FONTS}/ibmplexsansarabic/IBMPlexSansArabic-SemiBold.ttf');font-weight:600}}
@font-face{{font-family:Plex;src:url('file://{FONTS}/ibmplexsansarabic/IBMPlexSansArabic-Bold.ttf');font-weight:700}}
@font-face{{font-family:Changa;src:url('file://{FONTS}/changa/Changa[wght].ttf')}}
*{{margin:0;padding:0;box-sizing:border-box}}
html,body{{width:{WIDTH}px;height:{HEIGHT}px;overflow:hidden;background:#000}}
body{{position:relative;font-family:Plex,sans-serif;-webkit-font-smoothing:antialiased}}
</style></head><body>
<svg width="{WIDTH}" height="{HEIGHT}" viewBox="0 0 {WIDTH} {HEIGHT}">
  <defs>
    <radialGradient id="bgGrad" cx="50%" cy="32%" r="68%">
      <stop offset="0%" stop-color="{TEAL}"/>
      <stop offset="58%" stop-color="{DEEP}"/>
      <stop offset="100%" stop-color="{NIGHT}"/>
    </radialGradient>
  </defs>
  <!-- Apple Watch Rectangular Display with Rounded Corners -->
  <rect width="{WIDTH}" height="{HEIGHT}" rx="48" fill="url(#bgGrad)"/>
  <g fill="none" stroke="{CREAM}" stroke-opacity="0.13" stroke-width="1.8">
    {girih_svg(WIDTH, HEIGHT, 110)}
  </g>
  {screen['content']}
</svg>
</body></html>"""

def main():
    os.makedirs(OUT_APPSTORE, exist_ok=True)
    os.makedirs(OUT_STORE, exist_ok=True)
    tmp = os.path.join(HERE, '_apple_watch_tmp.html')

    for sc in SCREENS:
        html = make_html(sc)
        with open(tmp, 'w') as f:
            f.write(html)
        
        out_path = os.path.join(OUT_STORE, sc['file'])
        cmd = [
            CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars',
            '--allow-file-access-from-files', '--force-device-scale-factor=1',
            f'--window-size={WIDTH},{HEIGHT}', '--virtual-time-budget=2000',
            f'--screenshot={out_path}', f'file://{tmp}'
        ]
        subprocess.run(cmd, check=True)
        print(f"Generated {out_path}")

        appstore_path = os.path.join(OUT_APPSTORE, sc['file'])
        subprocess.run(['cp', out_path, appstore_path], check=True)

    if os.path.exists(tmp):
        os.remove(tmp)

if __name__ == '__main__':
    main()
