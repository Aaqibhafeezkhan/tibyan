#!/usr/bin/env python3
"""Update teaser (cover C look): feed 4:5, story 9:16, square. Reuses ../../facebook/src/gen.py."""
import os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.dirname(HERE)
sys.path.insert(0, os.path.abspath(os.path.join(HERE, '../../facebook/src')))
from gen import HEAD, CHROME, FONTS, khatam_tile, star_pts, logo  # noqa: E402

CREAM, GOLD, MINT, SOFT = '#F6F1E8', '#D9B266', '#55BDB2', '#CFE3DF'
DIGITS = (f"@font-face{{font-family:TDig;src:url('file://{FONTS}/tibyandigits/TibyanDigits-Bold.ttf');font-weight:700}}"
          f"@font-face{{font-family:TDig;src:url('file://{FONTS}/tibyandigits/TibyanDigits-Medium.ttf');font-weight:500}}")


def wrapped_star(cx, cy, r):
    """Mystery motif: glowing gold star, cream centre star, concentric ring and sparkles."""
    import math
    sp = ''.join(f'<polygon points="{star_pts(cx + r*1.24*math.cos(a), cy + r*1.24*math.sin(a), sz)}" fill="{GOLD}" fill-opacity="{o}"/>'
                 for a, sz, o in [(math.radians(d), z, o) for d, z, o in [(-60, 9, .9), (-20, 5, .6), (35, 7, .75), (150, 6, .7), (200, 10, .85), (250, 5, .55)]])
    return (f'<defs><filter id="gl" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="{r*.12:.0f}"/></filter>'
            f'<radialGradient id="ig"><stop offset="0" stop-color="{GOLD}" stop-opacity=".45"/><stop offset="1" stop-color="{GOLD}" stop-opacity="0"/></radialGradient></defs>'
            f'<polygon points="{star_pts(cx, cy, r*1.02)}" fill="{GOLD}" fill-opacity=".3" filter="url(#gl)"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{r*1.24:.0f}" fill="none" stroke="{GOLD}" stroke-opacity=".55" stroke-width="1.5"/>'
            f'<polygon points="{star_pts(cx, cy, r)}" fill="#0A2422" fill-opacity=".45" stroke="{GOLD}" stroke-width="3"/>'
            f'<polygon points="{star_pts(cx, cy, r*.82)}" fill="url(#ig)" stroke="{GOLD}" stroke-opacity=".55" stroke-width="1.5"/>'
            f'<polygon points="{star_pts(cx, cy, r*.3)}" fill="{CREAM}" stroke="{GOLD}" stroke-width="3"/>' + sp)


ICONS = {  # generic line icons, 48x48 viewBox
    'Mac': '<rect x="9" y="11" width="30" height="20" rx="2"/><path d="M4 36h40l-3 3H7z"/>',
    'Android': '<rect x="14" y="6" width="20" height="36" rx="4"/><path d="M21 37h6"/><path d="M19 15a5 5 0 0 1 10 0z"/><path d="M20 10l-2-3M28 10l2-3"/>',
    'Windows': '<rect x="8" y="8" width="32" height="32" rx="2"/><path d="M24 8v32M8 24h32"/>',
    'Linux': '<rect x="6" y="9" width="36" height="30" rx="3"/><path d="M6 16h36"/><path d="M13 23l5 4-5 4M21 32h8"/>',
    'iOS': '<rect x="14" y="6" width="20" height="36" rx="5"/><path d="M21 10h6"/><path d="M21 37h6"/>',
    'Wearable': '<rect x="14" y="14" width="20" height="20" rx="5"/><path d="M18 14l2-8h8l2 8M18 34l2 8h8l2-8"/><path d="M24 19v5l3 2"/>',
}


def platforms(top, k):
    sz = 56 * k
    cells = ''.join(f'<div style="width:{130*k:.0f}px;text-align:center">'
                    f'<svg width="{sz:.0f}" height="{sz:.0f}" viewBox="0 0 48 48" fill="none" stroke="#F4ECD8" stroke-width="2.2" '
                    f'stroke-linecap="round" stroke-linejoin="round">{svg}</svg>'
                    f'<div style="font-family:Plex;font-weight:500;font-size:{21*k:.0f}px;color:#F4ECD8;margin-top:4px">{n}</div></div>'
                    for n, svg in ICONS.items())
    return f'<div class="abs" dir="ltr" style="left:0;right:0;top:{top:.0f}px;display:flex;justify-content:center;gap:{12*k:.0f}px">{cells}</div>'


def post(W, H):
    story, sq = H > 1500, H == W
    k = 0.86 if sq else 1.0
    star_r = 240 if story else (140 if sq else 185)
    star_cy = 760 if story else (350 if sq else 470)
    s = [f'<svg class="abs" width="{W}" height="{H}"><defs>{khatam_tile(104, CREAM, 0.06)}'
         f'<linearGradient id="t" x1="1" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#11706A"/>'
         f'<stop offset="1" stop-color="#0A4F4A"/></linearGradient>'
         f'<radialGradient id="hl" cx="50%" cy="{star_cy / H * 100:.0f}%" r="55%"><stop offset="0" stop-color="{GOLD}" stop-opacity=".22"/>'
         f'<stop offset="1" stop-color="{GOLD}" stop-opacity="0"/></radialGradient></defs>'
         f'<rect width="{W}" height="{H}" fill="url(#t)"/><rect width="{W}" height="{H}" fill="url(#kh)"/>'
         f'<rect width="{W}" height="{H}" fill="url(#hl)"/>'
         + wrapped_star(W / 2, star_cy, star_r)
         + ''.join(f'<polygon points="{star_pts(x, y, r)}" fill="{GOLD}" fill-opacity="{o}"/>'
                   for x, y, r, o in [(150, star_cy - star_r * .7, 16, .7), (W - 160, star_cy + star_r * .5, 11, .55),
                                      (W - 230, star_cy - star_r * 1.0, 8, .45), (210, star_cy + star_r * .9, 7, .4)])
         + '</svg>']
    lw = 190 if story else 150 * k
    s.append(logo('F6F1E8', (W - lw) / 2, 90 if story else 56, lw))
    ty = star_cy + star_r + (90 if story else 50)
    s.append(f'<div class="abs" style="left:70px;right:70px;top:{ty}px;text-align:center;font-family:Changa;color:{CREAM}">'
             f'<div style="font-weight:600;font-size:{32 * k:.0f}px;color:{GOLD}">قريبًا… تحديث جديد لتبيان</div>'
             f'<div style="font-weight:700;font-size:{(100 if story else 88) * k:.0f}px;line-height:1.2;margin-top:6px">أعددنا لكم الجديد</div>'
             f'<div style="margin:{22 * k:.0f}px auto 0;display:inline-block;padding:{12 * k:.0f}px 38px;border:1.5px solid rgba(217,178,102,.6);'
             f'border-radius:999px;font-family:Plex;font-weight:600;font-size:{34 * k:.0f}px;background:rgba(10,36,34,.25)">'
             f'تابعونا في الأيام القادمة</div></div>')
    fy = H - (230 if story else 150 * k)
    s.append(platforms(fy - (190 if story else (125 if sq else 150)), 1.15 if story else (0.9 if sq else 1.0)))
    s.append(f'<div class="abs" style="left:80px;right:80px;top:{fy}px;height:1px;background:rgba(217,178,102,.35)"></div>')
    s.append(f'<div class="abs" style="left:80px;right:80px;top:{fy + 28 * k:.0f}px;text-align:center">'
             f'<div style="font-family:Plex;font-size:{24 * k:.0f}px;color:{SOFT}">نسخة تجريبية جديدة في الطريق</div>'
             f'<div dir="ltr" style="margin-top:8px;font-family:Plex;font-weight:700;font-size:{40 * k:.0f}px;color:{CREAM}">'
             f'altibyan<span style="color:{GOLD}">.app</span></div></div>')
    return ''.join(s)


def render(name, w, h):
    html = HEAD.replace('%W%', str(w)).replace('%H%', str(h)).replace('</style>', DIGITS + '</style>') + post(w, h) + '</body></html>'
    p = os.path.join(HERE, name + '.html')
    open(p, 'w').write(html)
    out = os.path.join(OUT, name + '.png')
    subprocess.run([CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars', '--allow-file-access-from-files',
                    '--force-device-scale-factor=1', f'--window-size={w},{h}', '--virtual-time-budget=3000',
                    f'--screenshot={out}', 'file://' + p], check=False, capture_output=True)
    print(out, os.path.exists(out))


if __name__ == '__main__':
    render('post_1080x1350', 1080, 1350)
    render('story_1080x1920', 1080, 1920)
    render('post_1080x1080', 1080, 1080)
