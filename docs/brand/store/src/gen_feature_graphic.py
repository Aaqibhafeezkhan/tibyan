#!/usr/bin/env python3
"""Generate Google Play Feature Graphic (1024x500) matching Facebook cover C style."""
import math, os, subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(os.path.join(HERE, '../graphics'))
FONTS = os.path.abspath(os.path.join(HERE, '../../../../assets/fonts/ofl'))
CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'

TEAL_1, TEAL_2 = '#11706A', '#0A4F4A'
CREAM = '#F6F1E8'
GOLD = '#D9B266'
MINT = '#CFE3DF'

W, H = 1024, 500

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

def build_html():
    s = 96
    tile = khatam_tile(s, CREAM, 0.06, 1.2)
    star1 = star_pts(290, 250, 230, 0.7654)
    star2 = star_pts(290, 250, 215, 0.7654)

    return f"""<!doctype html><html dir="rtl" lang="ar"><head><meta charset="utf-8"><style>
@font-face{{font-family:Plex;src:url('file://{FONTS}/ibmplexsansarabic/IBMPlexSansArabic-Regular.ttf');font-weight:400}}
@font-face{{font-family:Plex;src:url('file://{FONTS}/ibmplexsansarabic/IBMPlexSansArabic-Medium.ttf');font-weight:500}}
@font-face{{font-family:Plex;src:url('file://{FONTS}/ibmplexsansarabic/IBMPlexSansArabic-SemiBold.ttf');font-weight:600}}
@font-face{{font-family:Plex;src:url('file://{FONTS}/ibmplexsansarabic/IBMPlexSansArabic-Bold.ttf');font-weight:700}}
@font-face{{font-family:Changa;src:url('file://{FONTS}/changa/Changa[wght].ttf')}}
*{{margin:0;padding:0;box-sizing:border-box}}
html,body{{width:{W}px;height:{H}px;overflow:hidden}}
body{{position:relative;font-family:Changa,Plex,sans-serif;-webkit-font-smoothing:antialiased}}
.abs{{position:absolute}}
.logo{{position:absolute;background:url(logo_F6F1E8.svg) center/contain no-repeat}}
</style></head><body>
<svg class="abs" width="{W}" height="{H}">
  <defs>
    {tile}
    <linearGradient id="bg" x1="1" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="{TEAL_1}"/>
      <stop offset="100%" stop-color="{TEAL_2}"/>
    </linearGradient>
    <radialGradient id="hl" cx="30%" cy="40%" r="50%">
      <stop offset="0%" stop-color="#55BDB2" stop-opacity="0.25"/>
      <stop offset="100%" stop-color="#55BDB2" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="{W}" height="{H}" fill="url(#bg)"/>
  <rect width="{W}" height="{H}" fill="url(#kh)"/>
  <rect width="{W}" height="{H}" fill="url(#hl)"/>
  <polygon points="{star1}" fill="{CREAM}" fill-opacity="0.04" stroke="{GOLD}" stroke-opacity="0.45" stroke-width="1.3"/>
  <polygon points="{star2}" fill="none" stroke="{GOLD}" stroke-opacity="0.22" stroke-width="1"/>
</svg>

<!-- Phone mockup showing Mushaf -->
<div class="abs" style="left:190px;top:45px;width:196px;height:410px;border-radius:32px;background:#0A2422;padding:7px;box-shadow:0 25px 50px -15px rgba(5,25,23,0.7),0 0 0 1.5px rgba(217,178,102,0.4);">
  <div style="width:100%;height:100%;border-radius:25px;overflow:hidden;background:url(mushaf.jpg) center top/cover no-repeat;background-position:center 0px;"></div>
</div>

<!-- Left peek phone showing Home -->
<div class="abs" style="left:75px;top:75px;width:170px;height:355px;border-radius:28px;background:#0A2422;padding:6px;box-shadow:0 20px 40px -15px rgba(5,25,23,0.6),0 0 0 1px rgba(217,178,102,0.25);opacity:0.85;">
  <div style="width:100%;height:100%;border-radius:22px;overflow:hidden;background:url(home.jpg) center top/cover no-repeat;background-position:center -12px;"></div>
</div>

<!-- Right Content -->
<div class="logo" style="right:80px;top:55px;width:220px;height:120px;"></div>

<div class="abs" style="right:80px;top:185px;text-align:right;color:{CREAM};">
  <div style="font-size:38px;font-weight:700;line-height:1.2;text-shadow:0 3px 12px rgba(4,30,28,0.4);">تبيان — القرآن الكريم</div>
  <div style="font-size:21px;font-weight:500;color:{MINT};margin-top:8px;font-family:Plex,sans-serif;">مصحف بلا إعلانات: استماع وتفسير وتسميع</div>
</div>

<!-- Feature pills -->
<div class="abs" style="right:80px;top:285px;display:flex;gap:18px;">
  <div style="display:inline-flex;align-items:center;gap:8px;padding:6px 16px;border-radius:999px;background:rgba(10,63,59,0.6);border:1px solid rgba(217,178,102,0.5);">
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="{GOLD}" stroke-width="1.8"><path d="M3 5.5c3-1.2 6-1 9 1 3-2 6-2.2 9-1V19c-3-1.2-6-1-9 1-3-2-6-2.2-9-1z M12 6.5V20"/></svg>
    <span style="font-size:18px;font-weight:600;color:{CREAM}">اقرأ</span>
  </div>
  <div style="display:inline-flex;align-items:center;gap:8px;padding:6px 16px;border-radius:999px;background:rgba(10,63,59,0.6);border:1px solid rgba(217,178,102,0.5);">
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="{GOLD}" stroke-width="1.8"><path d="M4 15v-3a8 8 0 0 1 16 0v3"/><rect x="3.5" y="14" width="4" height="6" rx="1.5"/><rect x="16.5" y="14" width="4" height="6" rx="1.5"/></svg>
    <span style="font-size:18px;font-weight:600;color:{CREAM}">استمع</span>
  </div>
  <div style="display:inline-flex;align-items:center;gap:8px;padding:6px 16px;border-radius:999px;background:rgba(10,63,59,0.6);border:1px solid rgba(217,178,102,0.5);">
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="{GOLD}" stroke-width="1.8"><circle cx="12" cy="12" r="8.5"/><path d="M8 12.2l2.7 2.7L16.2 9.4"/></svg>
    <span style="font-size:18px;font-weight:600;color:{CREAM}">احفظ</span>
  </div>
  <div style="display:inline-flex;align-items:center;gap:8px;padding:6px 16px;border-radius:999px;background:rgba(10,63,59,0.6);border:1px solid rgba(217,178,102,0.5);">
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="{GOLD}" stroke-width="1.8"><circle cx="12" cy="5" r="2.5"/><circle cx="18" cy="11" r="2.5"/><circle cx="15" cy="18" r="2.5"/><circle cx="9" cy="18" r="2.5"/><circle cx="6" cy="11" r="2.5"/></svg>
    <span style="font-size:18px;font-weight:600;color:{CREAM}">سمّع</span>
  </div>
</div>

<div class="abs" style="right:80px;top:370px;display:flex;align-items:center;gap:12px;font-family:Plex,sans-serif;color:{GOLD};font-size:16px;font-weight:500;">
  <span>✦ مجاني وغير ربحي</span>
  <span>✦ بلا إعلانات إطلاقًا</span>
  <span>✦ يعمل دون إنترنت</span>
</div>

</body></html>"""

def main():
    os.makedirs(OUT, exist_ok=True)
    html = build_html()
    hpath = os.path.join(HERE, 'feature_graphic.html')
    with open(hpath, 'w') as f:
        f.write(html)
    png = os.path.join(OUT, 'play_feature_graphic_1024x500.png')
    cmd = [
        CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars',
        '--allow-file-access-from-files', '--force-device-scale-factor=1',
        f'--window-size={W},{H}', '--virtual-time-budget=2000',
        f'--screenshot={png}', f'file://{hpath}'
    ]
    subprocess.run(cmd, check=True)
    print(f"Generated {png}")

if __name__ == '__main__':
    main()
