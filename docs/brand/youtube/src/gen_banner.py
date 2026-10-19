#!/usr/bin/env python3
"""YouTube banner 2560x1440 in the Facebook cover C style. Reuses facebook/src/gen.py helpers."""
import os, sys, subprocess
HERE = os.path.dirname(os.path.abspath(__file__))
FB = os.path.abspath(os.path.join(HERE, '../../facebook/src'))
sys.path.insert(0, FB)
import gen  # noqa: E402
from gen import star_pts, khatam_tile, phone, icon, stores  # noqa: E402

W, H = 2560, 1440
SX, SY, SW, SH = (W - 1546) // 2, (H - 423) // 2, 1546, 423  # safe area 507,508
CY = SY + SH / 2
F = '../../facebook/src/'


def banner():
    sc = 1.6  # pattern/star scale relative to the 624px cover
    s = [f'<svg class="abs" width="{W}" height="{H}"><defs>{khatam_tile(int(104*sc), "#F6F1E8", .06, 1.6)}'
         f'<linearGradient id="t" x1="1" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#11706A"/><stop offset="1" stop-color="#0A4F4A"/></linearGradient>'
         f'<radialGradient id="hl" cx="{(SX+222)/W*100:.1f}%" cy="50%" r="32%"><stop offset="0" stop-color="#55BDB2" stop-opacity=".22"/><stop offset="1" stop-color="#55BDB2" stop-opacity="0"/></radialGradient></defs>'
         f'<rect width="{W}" height="{H}" fill="url(#t)"/>'
         f'<rect width="{W}" height="{H}" fill="url(#kh)"/>'
         f'<rect width="{W}" height="{H}" fill="url(#hl)"/>']
    scx = SX + 222
    s.append(f'<polygon points="{star_pts(scx, CY, 470, .78)}" fill="#F6F1E8" fill-opacity=".045" stroke="#D9B266" stroke-opacity=".5" stroke-width="1.8"/>'
             f'<polygon points="{star_pts(scx, CY, 444, .78)}" fill="none" stroke="#D9B266" stroke-opacity=".22" stroke-width="1.3"/></svg>')
    # devices: centred on the star, fully inside the 423px band height
    pw1, pw2 = 188, 202
    h1, h2 = pw1 * 2.06, pw2 * 2.06
    s.append(phone(scx - pw1 - 6, CY - h1 / 2 + 8, pw1, F + 'mushaf.jpg', frame='#0A2422'))
    s.append(phone(scx + 10, CY - h2 / 2, pw2, F + 'home.jpg', frame='#0A2422', crop_top=17))
    # logo (right, RTL) + type block
    lw = 236
    lh = lw * 1019 / 1392
    right = W - (SX + SW) + 34  # css right offset of logo
    s.append(f'<div class="logo" style="right:{right}px;top:{CY-lh/2-14:.0f}px;width:{lw}px;height:{lh:.0f}px;'
             f'background-image:url({F}logo_F6F1E8.svg)"></div>')
    tr = right + lw + 56
    s.append(f'<div class="abs" style="right:{tr}px;top:{SY+46}px;text-align:right;color:#F6F1E8;font-family:Changa,Plex">'
             '<div style="font-weight:600;font-size:56px;line-height:1.2">مصحفك… بهدوء</div>'
             '<div style="margin-top:4px;font-weight:400;font-size:27px;color:#CFE3DF">مجاني بالكامل · بلا إعلانات</div></div>')
    feats = [('read', 'اقرأ'), ('listen', 'استمع'), ('memo', 'احفظ')]
    row = ''.join(f'<div style="display:flex;align-items:center;gap:12px">{icon(k, "#D9B266", 32)}'
                  f'<span style="font-family:Changa;font-weight:500;font-size:29px;color:#F6F1E8">{t}</span></div>' for k, t in feats)
    s.append(f'<div class="abs" style="right:{tr}px;top:{SY+212}px;display:flex;gap:40px">{row}</div>')
    s.append(f'<div class="abs" style="right:{tr}px;top:{SY+284}px">{stores("#CFE3DF", 21, 28, 19, 400, "Changa")}</div>')
    handles = ['altibyan.app', 'facebook.com/tibyanapp', 'instagram.com/tibyanapp', 'tiktok.com/@altibyanapp']
    hs = '<span style="color:#D9B266;opacity:.7;margin:0 12px">·</span>'.join(handles)
    s.append(f'<div class="abs" dir="ltr" style="right:{tr}px;top:{SY+338}px;font-family:Changa;font-size:17px;'
             f'letter-spacing:.3px;color:#A9CBC6;white-space:nowrap">{hs}</div>')
    return ''.join(s)


def guides():
    """Debug overlay of the safe area."""
    return (f'<div class="abs" style="left:{SX}px;top:{SY}px;width:{SW}px;height:{SH}px;outline:2px dashed red"></div>')


if __name__ == '__main__':
    dbg = 'debug' in sys.argv
    html = gen.HEAD.replace('%W%', str(W)).replace('%H%', str(H)) + banner() + (guides() if dbg else '') + '</body></html>'
    p = os.path.join(HERE, 'banner.html')
    open(p, 'w').write(html)
    out = os.path.join(os.path.dirname(HERE), 'youtube_banner_2560x1440' + ('_debug' if dbg else '') + '.png')
    subprocess.run(['nice', '-n', '15', gen.CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars',
                    '--allow-file-access-from-files', '--force-device-scale-factor=1',
                    f'--window-size={W},{H}', '--virtual-time-budget=3000', f'--screenshot={out}', 'file://' + p],
                   capture_output=True)
    print(out, os.path.getsize(out))
