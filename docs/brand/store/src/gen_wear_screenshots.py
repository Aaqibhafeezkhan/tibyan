#!/usr/bin/env python3
"""Generate Wear OS store screenshots in the «ليل هندسي» look (454x454 / 512x512)."""
import math, os, subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_WEAR = os.path.abspath(os.path.join(HERE, '../../play/wear'))
OUT_STORE = os.path.abspath(os.path.join(HERE, '../screenshots/wear_os'))
FONTS = os.path.abspath(os.path.join(HERE, '../../../../assets/fonts/ofl'))
CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'

SIZE = 512
TEAL, DEEP, NIGHT = "#0e5f58", "#06302c", "#020c0b"
CREAM, GOLD = "#f4ecd8", "#d9b266"

def star_pts(cx, cy, r, inner=0.765):
    pts = []
    for i in range(16):
        rr = r if i % 2 == 0 else r * inner
        a = -math.pi / 2 + i * math.pi / 8
        pts.append(f"{cx + math.cos(a) * rr:.1f},{cy + math.sin(a) * rr:.1f}")
    return ' '.join(pts)

def girih_svg(s, cell=128):
    paths = []
    y = 0.0
    while y < s + cell:
        x = 0.0
        while x < s + cell:
            paths.append(f'<polygon points="{star_pts(x, y, cell * 0.5, 0.72)}"/>')
            x += cell
        y += cell
    return ''.join(paths)

def ring_path(cx, cy, r, progress):
    # Arc from -90 deg clockwise
    angle = 360 * progress
    rad = math.radians(angle - 90)
    end_x = cx + r * math.cos(rad)
    end_y = cy + r * math.sin(rad)
    large = 1 if angle > 180 else 0
    return f"M{cx},{cy-r} A{r},{r} 0 {large},1 {end_x:.1f},{end_y:.1f}"

SCREENS = [
    {
        'file': '01_wear_misbaha.png',
        'legacy_alias': 'wear-misbaha.png',
        'title': 'المسبحة',
        'content': f"""
        <!-- Gold Edge Progress Ring (100%) -->
        <circle cx="256" cy="256" r="238" fill="none" stroke="{GOLD}" stroke-width="12" stroke-linecap="round"/>
        <text x="256" y="115" text-anchor="middle" fill="{GOLD}" font-family="Plex" font-size="22" font-weight="600">سُبْحَانَ اللَّهِ</text>
        <text x="256" y="275" text-anchor="middle" fill="{CREAM}" font-family="Changa,Plex" font-size="118" font-weight="700">٣٣</text>
        <text x="256" y="340" text-anchor="middle" fill="{GOLD}" font-family="Plex" font-size="24" font-weight="500">من ٣٣</text>
        <!-- Stage pill -->
        <rect x="206" y="385" width="100" height="34" rx="17" fill="rgba(217,178,102,0.18)" stroke="{GOLD}" stroke-width="1.2"/>
        <text x="256" y="409" text-anchor="middle" fill="{CREAM}" font-family="Plex" font-size="19" font-weight="600">١ / ٤</text>
        """
    },
    {
        'file': '02_wear_wird.png',
        'legacy_alias': None,
        'title': 'الورد القرآني',
        'content': f"""
        <!-- Gold Edge Progress Ring (45%) -->
        <path d="{ring_path(256, 256, 238, 0.45)}" fill="none" stroke="{GOLD}" stroke-width="12" stroke-linecap="round"/>
        <circle cx="256" cy="256" r="238" fill="none" stroke="{GOLD}" stroke-opacity="0.2" stroke-width="12"/>
        <!-- 8-point mini star -->
        <polygon points="{star_pts(256, 120, 26, 0.765)}" fill="{CREAM}" fill-opacity="0.1" stroke="{GOLD}" stroke-width="1.5"/>
        <text x="256" y="185" text-anchor="middle" fill="{GOLD}" font-family="Plex" font-size="24" font-weight="600">سورة البقرة</text>
        <text x="256" y="270" text-anchor="middle" fill="{CREAM}" font-family="Changa,Plex" font-size="64" font-weight="700">٤٥٪</text>
        <text x="256" y="335" text-anchor="middle" fill="{CREAM}" font-family="Plex" font-size="26" font-weight="500">صفحة ٢٤ من ٥٠</text>
        <text x="256" y="395" text-anchor="middle" fill="{GOLD}" font-family="Plex" font-size="20" font-weight="600">متبقي ٢٦ صفحة</text>
        """
    },
    {
        'file': '03_wear_tile.png',
        'legacy_alias': 'wear-tile.png',
        'title': 'بطاقة الختمة (Tile)',
        'content': f"""
        <circle cx="256" cy="256" r="238" fill="none" stroke="{GOLD}" stroke-opacity="0.3" stroke-width="8"/>
        <text x="256" y="130" text-anchor="middle" fill="{CREAM}" font-family="Plex" font-size="22" font-weight="500">ختمة رمضان المباركة</text>
        <text x="256" y="225" text-anchor="middle" fill="{GOLD}" font-family="Changa,Plex" font-size="76" font-weight="700">الجزء ١٢</text>
        <text x="256" y="295" text-anchor="middle" fill="{CREAM}" font-family="Plex" font-size="24" font-weight="600">الحزب ٢٣ · ص ٢٤٢</text>
        <!-- Continue reading pill -->
        <g transform="translate(146, 350)">
          <rect width="220" height="52" rx="26" fill="{GOLD}"/>
          <text x="110" y="34" text-anchor="middle" fill="{NIGHT}" font-family="Plex" font-size="23" font-weight="700">تابع القراءة</text>
        </g>
        """
    },
    {
        'file': '04_wear_complication.png',
        'legacy_alias': None,
        'title': 'المضاعفات والإضافات',
        'content': f"""
        <circle cx="256" cy="256" r="238" fill="none" stroke="{GOLD}" stroke-opacity="0.25" stroke-width="8"/>
        <!-- Big decorative Girih Star -->
        <polygon points="{star_pts(256, 256, 170, 0.765)}" fill="{CREAM}" fill-opacity="0.06" stroke="{GOLD}" stroke-width="2.5"/>
        <polygon points="{star_pts(256, 256, 145, 0.765)}" fill="none" stroke="{GOLD}" stroke-opacity="0.4" stroke-width="1.2"/>
        <text x="256" y="235" text-anchor="middle" fill="{CREAM}" font-family="Changa" font-size="36" font-weight="700">تِبيَان</text>
        <text x="256" y="280" text-anchor="middle" fill="{GOLD}" font-family="Plex" font-size="22" font-weight="600">مصحف وذكر</text>
        <text x="256" y="355" text-anchor="middle" fill="{CREAM}" font-family="Plex" font-size="19" font-weight="500">مضاعفات واجهة الساعة</text>
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
html,body{{width:{SIZE}px;height:{SIZE}px;overflow:hidden;background:#000}}
body{{position:relative;font-family:Plex,sans-serif;-webkit-font-smoothing:antialiased}}
</style></head><body>
<svg width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}">
  <defs>
    <radialGradient id="bgGrad" cx="50%" cy="32%" r="68%">
      <stop offset="0%" stop-color="{TEAL}"/>
      <stop offset="58%" stop-color="{DEEP}"/>
      <stop offset="100%" stop-color="{NIGHT}"/>
    </radialGradient>
    <clipPath id="circleClip">
      <circle cx="256" cy="256" r="256"/>
    </clipPath>
  </defs>
  <!-- Circular Watch Face -->
  <g clip-path="url(#circleClip)">
    <rect width="{SIZE}" height="{SIZE}" fill="url(#bgGrad)"/>
    <g fill="none" stroke="{CREAM}" stroke-opacity="0.13" stroke-width="1.8">
      {girih_svg(SIZE, 128)}
    </g>
    {screen['content']}
  </g>
</svg>
</body></html>"""

def main():
    os.makedirs(OUT_WEAR, exist_ok=True)
    os.makedirs(OUT_STORE, exist_ok=True)
    tmp = os.path.join(HERE, '_wear_tmp.html')

    for sc in SCREENS:
        html = make_html(sc)
        with open(tmp, 'w') as f:
            f.write(html)
        
        # Render to store screenshots dir
        out_path = os.path.join(OUT_STORE, sc['file'])
        cmd = [
            CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars',
            '--allow-file-access-from-files', '--force-device-scale-factor=1',
            f'--window-size={SIZE},{SIZE}', '--virtual-time-budget=2000',
            f'--screenshot={out_path}', f'file://{tmp}'
        ]
        subprocess.run(cmd, check=True)
        print(f"Generated {out_path}")

        # Also copy/save to docs/brand/play/wear/
        wear_path = os.path.join(OUT_WEAR, sc['file'])
        subprocess.run(['cp', out_path, wear_path], check=True)
        if sc.get('legacy_alias'):
            alias_path = os.path.join(OUT_WEAR, sc['legacy_alias'])
            subprocess.run(['cp', out_path, alias_path], check=True)
            print(f"Updated legacy alias {alias_path}")

    if os.path.exists(tmp):
        os.remove(tmp)

if __name__ == '__main__':
    main()
