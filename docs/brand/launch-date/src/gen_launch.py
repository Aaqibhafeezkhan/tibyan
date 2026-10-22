#!/usr/bin/env python3
"""Launch-date post (cover C look): feed 4:5, story 9:16, square. Reuses ../../facebook/src/gen.py."""
import os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.dirname(HERE)
sys.path.insert(0, os.path.abspath(os.path.join(HERE, '../../facebook/src')))
from gen import HEAD, CHROME, FONTS, khatam_tile, star_pts, logo  # noqa: E402

CREAM, GOLD, MINT, SOFT = '#F6F1E8', '#D9B266', '#55BDB2', '#CFE3DF'
DIGITS = (f"@font-face{{font-family:TDig;src:url('file://{FONTS}/tibyandigits/TibyanDigits-Bold.ttf');font-weight:700}}"
          f"@font-face{{font-family:TDig;src:url('file://{FONTS}/tibyandigits/TibyanDigits-Medium.ttf');font-weight:500}}")


def big_star(cx, cy, r):
    """Approved countdown motif: two overlapped gold squares, inner echo."""
    return (f'<polygon points="{star_pts(cx, cy, r)}" fill="#0A2422" fill-opacity=".30" stroke="{GOLD}" stroke-width="3"/>'
            f'<polygon points="{star_pts(cx, cy, r * 0.82)}" fill="none" stroke="{GOLD}" stroke-opacity=".55" stroke-width="1.5"/>')


def post(W, H):
    story, sq = H > 1500, H == W
    k = 0.86 if sq else 1.0
    star_r = 230 if story else (150 if sq else 190)
    star_cy = {True: 720}.get(story, 330 if sq else 470)
    s = [f'<svg class="abs" width="{W}" height="{H}"><defs>{khatam_tile(104, CREAM, 0.06)}'
         f'<linearGradient id="t" x1="1" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#11706A"/>'
         f'<stop offset="1" stop-color="#0A4F4A"/></linearGradient>'
         f'<radialGradient id="hl" cx="50%" cy="{star_cy / H * 100:.0f}%" r="55%"><stop offset="0" stop-color="{GOLD}" stop-opacity=".22"/>'
         f'<stop offset="1" stop-color="{GOLD}" stop-opacity="0"/></radialGradient></defs>'
         f'<rect width="{W}" height="{H}" fill="url(#t)"/><rect width="{W}" height="{H}" fill="url(#kh)"/>'
         f'<rect width="{W}" height="{H}" fill="url(#hl)"/>'
         + big_star(W / 2, star_cy, star_r)
         + ''.join(f'<polygon points="{star_pts(x, y, r)}" fill="{GOLD}" fill-opacity="{o}"/>'
                   for x, y, r, o in [(150, star_cy - star_r * .7, 16, .7), (W - 160, star_cy + star_r * .5, 11, .55),
                                      (W - 230, star_cy - star_r * 1.0, 8, .45), (210, star_cy + star_r * .9, 7, .4)])
         + '</svg>']
    # star centre: day number + month
    s.append(f'<div class="abs" style="left:0;right:0;top:{star_cy - star_r * .55}px;text-align:center;color:{CREAM}">'
             f'<div style="font-family:TDig,Plex;font-weight:700;font-size:{star_r * .74:.0f}px;line-height:1">٢٧</div>'
             f'<div style="font-family:Changa;font-weight:600;font-size:{star_r * .24:.0f}px;color:{GOLD};margin-top:{star_r*.06:.0f}px">رجب ١٤٤٨</div></div>')
    lw = 190 if story else 150 * k
    s.append(logo('F6F1E8', (W - lw) / 2, 90 if story else 56, lw))
    ty = star_cy + star_r + (80 if story else 46)
    s.append(f'<div class="abs" style="left:70px;right:70px;top:{ty}px;text-align:center;font-family:Changa;color:{CREAM}">'
             f'<div style="font-weight:600;font-size:{30 * k:.0f}px;color:{GOLD}">الإطلاق الرسمي لتطبيق تبيان</div>'
             f'<div style="font-weight:700;font-size:{(104 if story else 92) * k:.0f}px;line-height:1.2;margin-top:6px">موعدنا ليلة ٢٧ رجب</div>'
             f'<div style="margin:{20 * k:.0f}px auto 0;display:inline-block;padding:{12 * k:.0f}px 34px;border:1.5px solid rgba(217,178,102,.6);'
             f'border-radius:999px;font-family:Plex;font-weight:600;font-size:{36 * k:.0f}px;background:rgba(10,36,34,.25)">'
             f'الاثنين <span style="font-family:TDig,Plex">٤</span> يناير <span style="font-family:TDig,Plex">٢٠٢٧</span>'
             f' <span style="color:{GOLD}">·</span> بعد المغرب</div>'
             f'<div style="margin-top:{18 * k:.0f}px;font-family:Plex;font-size:{27 * k:.0f}px;color:{SOFT}">'
             f'ليلة الإسراء والمعراج · الساعة <span style="font-family:TDig,Plex">٦</span> مساءً بتوقيت القاهرة</div></div>')
    fy = H - (230 if story else 150 * k)
    s.append(f'<div class="abs" style="left:80px;right:80px;top:{fy}px;height:1px;background:rgba(217,178,102,.35)"></div>')
    s.append(f'<div class="abs" style="left:80px;right:80px;top:{fy + 28 * k:.0f}px;text-align:center">'
             f'<div style="font-family:Plex;font-size:{24 * k:.0f}px;color:{SOFT}">مجاني · بلا إعلانات · مفتوح المصدر · أندرويد وآيفون وماك</div>'
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
