#!/usr/bin/env python3
"""GitHub social preview (1280x640) in the cover C style: teal field, khatam lattice,
two app screens, the logo, Changa type. Renders with headless Chrome.

    python3 docs/brand/github/src/gen.py   ->  docs/brand/github/social_preview.png

Upload by hand: GitHub > Settings > General > Social preview (no API for it).
"""
import math, os, subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.dirname(HERE)
FONTS = os.path.abspath(os.path.join(HERE, '../../../../assets/fonts/ofl'))
CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
W, H = 1280, 640


def star_pts(cx, cy, r, inner=0.7654):
    pts = []
    for i in range(16):
        a = math.pi / 8 * i - math.pi / 2
        rr = r if i % 2 == 0 else r * inner
        pts.append(f"{cx + rr * math.cos(a):.2f},{cy + rr * math.sin(a):.2f}")
    return ' '.join(pts)


def khatam_tile(size, stroke, op, sw=1.2):
    s, r = size, size * 0.36
    corners = ''.join(f'<polygon points="{star_pts(x, y, r)}"/>' for x, y in [(0, 0), (s, 0), (0, s), (s, s)])
    return (f'<pattern id="kh" width="{s}" height="{s}" patternUnits="userSpaceOnUse">'
            f'<g fill="none" stroke="{stroke}" stroke-opacity="{op}" stroke-width="{sw}">'
            f'<polygon points="{star_pts(s / 2, s / 2, r)}"/>{corners}'
            f'<circle cx="{s/2}" cy="{s/2}" r="{r*0.42:.2f}"/></g></pattern>')


def phone(x, y, w, img, crop_top=0):
    h, r, bz = w * 2.06, w * 0.15, w * 0.035
    return (f'<div class="abs" style="left:{x}px;top:{y}px;width:{w}px;height:{h:.0f}px;border-radius:{r:.0f}px;'
            f'background:#0A2422;padding:{bz:.1f}px;box-shadow:0 30px 60px -20px rgba(10,30,28,.5)">'
            f'<div style="width:100%;height:100%;border-radius:{r-bz:.0f}px;overflow:hidden;'
            f'background:url({img}) no-repeat;background-position:center {-crop_top}px;background-size:100% auto"></div></div>')


def page():
    s = [f'<svg class="abs" width="{W}" height="{H}"><defs>{khatam_tile(104, "#F6F1E8", .06)}'
         '<linearGradient id="t" x1="1" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#11706A"/><stop offset="1" stop-color="#0A4F4A"/></linearGradient>'
         '<radialGradient id="hl" cx="28%" cy="45%" r="40%"><stop offset="0" stop-color="#55BDB2" stop-opacity=".22"/><stop offset="1" stop-color="#55BDB2" stop-opacity="0"/></radialGradient></defs>'
         f'<rect width="{W}" height="{H}" fill="url(#t)"/><rect width="{W}" height="{H}" fill="url(#kh)"/><rect width="{W}" height="{H}" fill="url(#hl)"/>'
         f'<polygon points="{star_pts(340, 330, 280, .78)}" fill="#F6F1E8" fill-opacity=".045" stroke="#D9B266" stroke-opacity=".5" stroke-width="1.3"/>'
         f'<polygon points="{star_pts(340, 330, 262, .78)}" fill="none" stroke="#D9B266" stroke-opacity=".22"/>'
         '</svg>']
    s.append(phone(150, 120, 190, 'mushaf.jpg'))
    s.append(phone(350, 86, 204, 'home.jpg', crop_top=18))
    lw = 230
    s.append(f'<div class="logo" style="right:110px;top:92px;width:{lw}px;height:{lw*1019/1392:.0f}px;background-image:url(logo_F6F1E8.svg)"></div>')
    s.append('<div class="abs" style="right:110px;top:270px;text-align:right;color:#F6F1E8;font-family:Changa,Plex">'
             '<div style="font-weight:600;font-size:44px;line-height:1.25;width:560px">تطبيق قرآن مجاني<br>ومفتوح المصدر</div>'
             '<div style="margin-top:8px;font-weight:400;font-size:24px;color:#CFE3DF">بلا إعلانات · بلا تتبع · كل مصدر موثق</div>'
             '<div dir="ltr" style="margin-top:26px;font-weight:500;font-size:24px;color:#D9B266">Free, open-source Quran app</div>'
             '<div dir="ltr" style="margin-top:4px;font-family:Plex;font-size:19px;color:#CFE3DF">Android · iOS · macOS · Windows · Linux &nbsp;—&nbsp; altibyan.app</div>'
             '</div>')
    return ''.join(s)


HEAD = f"""<!doctype html><html dir="rtl" lang="ar"><head><meta charset="utf-8"><style>
@font-face{{font-family:Plex;src:url('file://{FONTS}/ibmplexsansarabic/IBMPlexSansArabic-Regular.ttf')}}
@font-face{{font-family:Changa;src:url('file://{FONTS}/changa/Changa[wght].ttf')}}
*{{margin:0;padding:0;box-sizing:border-box}}
html,body{{width:{W}px;height:{H}px;overflow:hidden}}
body{{position:relative;font-family:Plex,sans-serif;-webkit-font-smoothing:antialiased}}
.abs{{position:absolute}}
.logo{{position:absolute;background-repeat:no-repeat;background-size:contain;background-position:center}}
</style></head><body>"""

if __name__ == '__main__':
    p = os.path.join(HERE, 'social_preview.html')
    open(p, 'w').write(HEAD + page() + '</body></html>')
    out = os.path.join(OUT, 'social_preview.png')
    subprocess.run([CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars', '--allow-file-access-from-files',
                    '--force-device-scale-factor=1', f'--window-size={W},{H}', '--virtual-time-budget=3000',
                    f'--screenshot={out}', 'file://' + p], check=False, capture_output=True)
    print(out if os.path.exists(out) else 'FAIL')
