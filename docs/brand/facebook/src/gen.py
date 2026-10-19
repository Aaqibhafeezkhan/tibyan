#!/usr/bin/env python3
"""Generate Tibyan Facebook profile/cover HTML, render PNGs with headless Chrome."""
import math, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.dirname(HERE)
FONTS = os.path.abspath(os.path.join(HERE, '../../../../assets/fonts/ofl'))
CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'

HEAD = f"""<!doctype html><html dir="rtl" lang="ar"><head><meta charset="utf-8"><style>
@font-face{{font-family:Plex;src:url('file://{FONTS}/ibmplexsansarabic/IBMPlexSansArabic-Regular.ttf');font-weight:400}}
@font-face{{font-family:Plex;src:url('file://{FONTS}/ibmplexsansarabic/IBMPlexSansArabic-Medium.ttf');font-weight:500}}
@font-face{{font-family:Plex;src:url('file://{FONTS}/ibmplexsansarabic/IBMPlexSansArabic-SemiBold.ttf');font-weight:600}}
@font-face{{font-family:Plex;src:url('file://{FONTS}/ibmplexsansarabic/IBMPlexSansArabic-Bold.ttf');font-weight:700}}
@font-face{{font-family:Ruqaa;src:url('file://{FONTS}/arefruqaa/ArefRuqaa-Bold.ttf')}}
@font-face{{font-family:Changa;src:url('file://{FONTS}/changa/Changa[wght].ttf')}}
*{{margin:0;padding:0;box-sizing:border-box}}
html,body{{width:%W%px;height:%H%px;overflow:hidden}}
body{{position:relative;font-family:Plex,sans-serif;-webkit-font-smoothing:antialiased}}
.abs{{position:absolute}}
.logo{{position:absolute;background-repeat:no-repeat;background-size:contain;background-position:center}}
</style></head><body>"""


def star_pts(cx, cy, r, inner=0.7654):
    """8-point star (two overlapped squares outline) — matches app StarPainter."""
    pts = []
    for i in range(16):
        a = math.pi / 8 * i - math.pi / 2
        rr = r if i % 2 == 0 else r * inner
        pts.append(f"{cx + rr * math.cos(a):.2f},{cy + rr * math.sin(a):.2f}")
    return ' '.join(pts)


def khatam_tile(size, stroke, op, sw=1.2):
    """Seamless tile of 8-point stars and crosses (classic khatam lattice)."""
    s = size
    r = s * 0.36
    star = star_pts(s / 2, s / 2, r)
    corners = ''.join(
        f'<polygon points="{star_pts(x, y, r)}"/>' for x, y in [(0, 0), (s, 0), (0, s), (s, s)])
    return (f'<pattern id="kh" width="{s}" height="{s}" patternUnits="userSpaceOnUse">'
            f'<g fill="none" stroke="{stroke}" stroke-opacity="{op}" stroke-width="{sw}">'
            f'<polygon points="{star}"/>{corners}'
            f'<circle cx="{s/2}" cy="{s/2}" r="{r*0.42:.2f}"/></g></pattern>')


def arch_path(x, y, w, h, spring=0.42):
    """Pointed (mihrab) arch: straight sides, two arcs meeting at a point."""
    sy = y + h * spring  # springline
    return (f'M{x},{y+h} L{x},{sy} '
            f'C{x},{y + h*spring*0.35} {x + w*0.32},{y + h*0.06} {x + w/2},{y} '
            f'C{x + w*0.68},{y + h*0.06} {x+w},{y + h*spring*0.35} {x+w},{sy} '
            f'L{x+w},{y+h} Z')


def logo(color, x, y, w):
    h = w * 1019 / 1392
    return (f'<div class="logo" style="left:{x}px;top:{y}px;width:{w}px;height:{h:.1f}px;'
            f'background-image:url(logo_{color}.svg)"></div>')


def phone(x, y, w, img, frame='#1d2322', pos='center top', radius=None, shadow=True, crop_top=0):
    h = w * 2.06
    r = radius or w * 0.15
    bz = w * 0.035
    sh = 'box-shadow:0 30px 60px -20px rgba(10,30,28,.45),0 8px 18px -8px rgba(10,30,28,.35);' if shadow else ''
    return (f'<div class="abs" style="left:{x}px;top:{y}px;width:{w}px;height:{h:.0f}px;border-radius:{r:.0f}px;'
            f'background:{frame};padding:{bz:.1f}px;{sh}">'
            f'<div style="width:100%;height:100%;border-radius:{r-bz:.0f}px;overflow:hidden;'
            f'background:url({img}) {pos}/cover no-repeat;'
            f'background-position:center {-crop_top}px;background-size:100% auto"></div></div>')


ICONS = {  # simple line glyphs drawn here (24-unit grid)
    'read': '<path d="M3 5.5c3-1.2 6-1 9 1 3-2 6-2.2 9-1V19c-3-1.2-6-1-9 1-3-2-6-2.2-9-1z M12 6.5V20"/>',
    'listen': '<path d="M4 15v-3a8 8 0 0 1 16 0v3"/><rect x="3.5" y="14" width="4" height="6" rx="1.5"/><rect x="16.5" y="14" width="4" height="6" rx="1.5"/>',
    'memo': '<circle cx="12" cy="12" r="8.5"/><path d="M8 12.2l2.7 2.7L16.2 9.4"/>',
}


def icon(name, color, size, sw=1.6):
    return (f'<svg width="{size}" height="{size}" viewBox="0 0 24 24" fill="none" stroke="{color}" '
            f'stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round">{ICONS[name]}</svg>')


STORE = {
    'play': '<path d="M5 3.5v17l9-8.5z M5 3.5l11 6.3-2 2.2 M5 20.5l11-6.3-2-2.2 M16 9.8l3.2 1.8c.6.4.6 1 0 1.3L16 14.2"/>',
    'apple': '<path d="M16.4 12.6c0-2.4 2-3.5 2-3.6-1.1-1.6-2.8-1.8-3.4-1.8-1.4-.1-2.8.9-3.5.9s-1.9-.9-3.1-.8C6.800 7.300 5.300 8.200 4.500 9.600c-1.700 2.900-.4 7.200 1.200 9.600.8 1.100 1.700 2.400 3 2.400 1.200-.1 1.600-.8 3.100-.8s1.800.8 3.100.8c1.300 0 2.100-1.200 2.900-2.300.9-1.300 1.300-2.600 1.300-2.700-.1 0-2.600-1-2.700-4z M14.200 5.400c.6-.8 1.100-1.900 1-3-1 .1-2.100.7-2.800 1.500-.6.700-1.200 1.800-1 2.900 1.100.1 2.100-.6 2.800-1.400z"/>',
    'mac': '<rect x="2.5" y="4" width="19" height="13" rx="1.6"/><path d="M8.5 21h7 M12 17v4"/>',
}


def stores(color, size=22, gap=34, fs=21, weight=500, font='Plex'):
    items = [('play', 'Google Play'), ('apple', 'App Store'), ('mac', 'Mac')]
    parts = []
    for k, t in items:
        fill = color if k == 'apple' else 'none'
        stroke = 'none' if k == 'apple' else color
        parts.append(
            f'<span style="display:inline-flex;align-items:center;gap:9px">'
            f'<svg width="{size}" height="{size}" viewBox="0 0 24 24" fill="{fill}" stroke="{stroke}" stroke-width="1.6" '
            f'stroke-linejoin="round" stroke-linecap="round">{STORE[k]}</svg>'
            f'<span style="font-family:{font};font-weight:{weight};font-size:{fs}px;letter-spacing:.2px">{t}</span></span>')
    return (f'<div dir="ltr" style="display:flex;gap:{gap}px;align-items:center;color:{color}">'
            + ''.join(parts) + '</div>')


# ------------------------------------------------------------------ PROFILES
def profile(bg, ring, logo_c, pattern_c, pattern_op, star_fill=None, glow=None):
    S = 720
    body = [f'<svg class="abs" width="{S}" height="{S}" style="left:0;top:0">'
            f'<defs>{khatam_tile(120, pattern_c, pattern_op, 1.4)}'
            f'<radialGradient id="v" cx="50%" cy="46%" r="60%"><stop offset="0" stop-color="{glow or bg}" stop-opacity="1"/>'
            f'<stop offset="1" stop-color="{bg}" stop-opacity="1"/></radialGradient></defs>'
            f'<rect width="{S}" height="{S}" fill="url(#v)"/>'
            f'<rect width="{S}" height="{S}" fill="url(#kh)" transform="translate(0 0)"/>'
            # quiet field: big 8-point star carrying the logo
            f'<polygon points="{star_pts(360, 360, 318, 0.83)}" fill="{star_fill or bg}" stroke="{ring}" stroke-width="3"/>'
            f'<polygon points="{star_pts(360, 360, 300, 0.83)}" fill="none" stroke="{ring}" stroke-opacity=".45" stroke-width="1.2"/>'
            f'</svg>']
    lw = 430
    body.append(logo(logo_c, (S - lw) / 2, (S - lw * 1019 / 1392) / 2 - 6, lw))
    return S, S, ''.join(body)


PROFILES = {
    'profile_teal': profile('#0F6660', '#D9B266', 'F6F1E8', '#F6F1E8', .07, star_fill='#0F6660', glow='#14766F'),
    'profile_light': profile('#F6F1E8', '#0F6660', '0F6660', '#0F6660', .07, star_fill='#FFFCF6'),
    'profile_nightgold': profile('#0E1A1B', '#D9B266', 'D9B266', '#55BDB2', .06, star_fill='#122223', glow='#152627'),
}

# ------------------------------------------------------------------ COVERS
W, H = 1640, 624


def cover_mihrab():
    """Concept A — the mihrab arch frames the device; cream and teal, the app's own home hero."""
    ax, aw, ah = 300, 420, 560
    ay = H - ah  # arch rises from the bottom edge
    s = [
         f'<svg class="abs" width="{W}" height="{H}"><defs>{khatam_tile(88, "#0F6660", .075, 1.1)}'
         f'<linearGradient id="ag" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#127069"/><stop offset="1" stop-color="#0B524D"/></linearGradient>'
         f'<pattern id="kl" width="64" height="64" patternUnits="userSpaceOnUse"><g fill="none" stroke="#F6F1E8" stroke-opacity=".08" stroke-width="1">'
         f'<polygon points="{star_pts(32,32,23)}"/>' + ''.join(f'<polygon points="{star_pts(x,y,23)}"/>' for x, y in [(0,0),(64,0),(0,64),(64,64)]) +
         f'</g></pattern></defs>'
         f'<rect width="{W}" height="{H}" fill="#F6F1E8"/>'
         f'<rect width="{W}" height="{H}" fill="url(#kh)"/>'
         # soft wash so the type side is calm
         f'<rect x="760" y="0" width="{W-760}" height="{H}" fill="#F6F1E8" opacity=".72"/>'
         f'<path d="{arch_path(ax-16, ay-16, aw+32, ah+16)}" fill="none" stroke="#9A7428" stroke-width="1.6" stroke-opacity=".8"/>'
         f'<path d="{arch_path(ax, ay, aw, ah)}" fill="url(#ag)"/>'
         f'<path d="{arch_path(ax, ay, aw, ah)}" fill="url(#kl)"/>'
         f'<path d="{arch_path(ax+12, ay+12, aw-24, ah-12)}" fill="none" stroke="#D9B266" stroke-opacity=".7" stroke-width="1.2"/>'
         # small star finial
         f'<polygon points="{star_pts(ax+aw/2, ay-44, 13)}" fill="#9A7428"/>'
         f'</svg>']
    # device inside the arch
    pw = 214
    s.append(phone(ax + (aw - pw) / 2, 128, pw, 'mushaf.jpg', frame='#132321', crop_top=0))
    # type block (right, RTL)
    s.append(logo('0F6660', 1040, 92, 300))
    s.append('<div class="abs" style="right:300px;top:330px;width:560px;text-align:right">'
             '<div style="font-weight:600;font-size:46px;color:#1E1915;line-height:1.25">مصحفك… بهدوء</div>'
             '<div style="margin-top:10px;font-weight:400;font-size:24px;color:#5E5A52">مجاني بالكامل · بلا إعلانات</div>'
             '</div>')
    s.append(f'<div class="abs" style="right:300px;top:468px">{stores("#0F6660")}</div>')
    return ''.join(s)


def cover_night():
    """Concept B — night-gold manuscript: ruled gold frame, central logo like an illuminated title."""
    gold = '#D9B266'
    fx, fy, fw, fh = 230, 70, 1180, 470  # frame ~ safe zone
    corners = ''.join(
        f'<polygon points="{star_pts(x, y, 15)}" fill="#16110D" stroke="{gold}" stroke-width="1.4"/>'
        f'<circle cx="{x}" cy="{y}" r="4" fill="{gold}"/>'
        for x, y in [(fx, fy), (fx + fw, fy), (fx, fy + fh), (fx + fw, fy + fh)])
    band = ''.join(f'<polygon points="{star_pts(x, 0, 9)}" fill="none" stroke="{gold}" stroke-opacity=".35" stroke-width="1"/>'
                   for x in range(0, W + 40, 40))
    # side medallions (cartouche ends)
    med = ''
    for cx in (fx + 120, fx + fw - 120):
        med += (f'<polygon points="{star_pts(cx, fy+fh/2, 64, .78)}" fill="none" stroke="{gold}" stroke-opacity=".55" stroke-width="1.2"/>'
                f'<polygon points="{star_pts(cx, fy+fh/2, 52, .78)}" fill="none" stroke="{gold}" stroke-opacity=".3" stroke-width="1"/>'
                f'<circle cx="{cx}" cy="{fy+fh/2}" r="26" fill="none" stroke="{gold}" stroke-opacity=".45"/>'
                f'<polygon points="{star_pts(cx, fy+fh/2, 12)}" fill="{gold}" fill-opacity=".8"/>')
    s = [f'<svg class="abs" width="{W}" height="{H}"><defs>{khatam_tile(96, gold, .05, 1)}'
         f'<radialGradient id="g" cx="50%" cy="48%" r="55%"><stop offset="0" stop-color="#2A1F15"/><stop offset="1" stop-color="#110C09"/></radialGradient></defs>'
         f'<rect width="{W}" height="{H}" fill="url(#g)"/>'
         f'<rect width="{W}" height="{H}" fill="url(#kh)"/>'
         f'<rect x="{fx}" y="{fy}" width="{fw}" height="{fh}" fill="#16110D" fill-opacity=".85"/>'
         f'<rect x="{fx}" y="{fy}" width="{fw}" height="{fh}" fill="none" stroke="{gold}" stroke-width="2"/>'
         f'<rect x="{fx+10}" y="{fy+10}" width="{fw-20}" height="{fh-20}" fill="none" stroke="{gold}" stroke-opacity=".5" stroke-width="1"/>'
         f'<rect x="{fx+16}" y="{fy+16}" width="{fw-32}" height="{fh-32}" fill="none" stroke="#C98B5A" stroke-opacity=".35" stroke-width=".8"/>'
         f'{med}{corners}'
         f'<g transform="translate(0 24)">{band}</g><g transform="translate(20 {H-24})">{band}</g>'
         f'</svg>']
    lw = 330
    s.append(logo('E2B95E', (W - lw) / 2, fy + 40, lw))
    s.append(f'<div class="abs" style="left:{fx}px;width:{fw}px;top:{fy+300}px;text-align:center;color:#F1E4CC">'
             '<div style="font-weight:500;font-size:34px;letter-spacing:.5px">اقرأ · استمع · احفظ</div>'
             '<div style="margin-top:8px;font-size:20px;color:#C2AE92">مجاني بالكامل · بلا إعلانات · بلا حسابات</div></div>')
    s.append(f'<div class="abs" style="left:0;width:{W}px;top:{fy+fh-58}px;display:flex;justify-content:center">{stores("#D6A94E", 20, 30, 18)}</div>')
    return ''.join(s)


def cover_teal():
    """Concept C — minimal teal field, tonal lattice, home screen tilted out of the field, features row."""
    s = [f'<svg class="abs" width="{W}" height="{H}"><defs>{khatam_tile(104, "#F6F1E8", .06, 1.2)}'
         f'<linearGradient id="t" x1="1" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#11706A"/><stop offset="1" stop-color="#0A4F4A"/></linearGradient>'
         f'<radialGradient id="hl" cx="30%" cy="40%" r="40%"><stop offset="0" stop-color="#55BDB2" stop-opacity=".22"/><stop offset="1" stop-color="#55BDB2" stop-opacity="0"/></radialGradient></defs>'
         f'<rect width="{W}" height="{H}" fill="url(#t)"/>'
         f'<rect width="{W}" height="{H}" fill="url(#kh)"/>'
         f'<rect width="{W}" height="{H}" fill="url(#hl)"/>'
         # big ghost star behind devices
         f'<polygon points="{star_pts(520, 330, 300, .78)}" fill="#F6F1E8" fill-opacity=".045" stroke="#D9B266" stroke-opacity=".5" stroke-width="1.3"/>'
         f'<polygon points="{star_pts(520, 330, 282, .78)}" fill="none" stroke="#D9B266" stroke-opacity=".22" stroke-width="1"/>'
         f'</svg>']
    pw = 200
    s.append(phone(330, 120, pw, 'mushaf.jpg', frame='#0A2422'))
    s.append(phone(540, 86, pw + 14, 'home.jpg', frame='#0A2422', crop_top=18))
    s.append(logo('F6F1E8', 1090, 96, 250))
    s.append('<div class="abs" style="right:300px;top:296px;text-align:right;color:#F6F1E8;font-family:Changa,Plex">'
             '<div style="font-weight:600;font-size:44px;line-height:1.2">مصحفك… بهدوء</div>'
             '<div style="margin-top:6px;font-weight:400;font-size:22px;color:#CFE3DF">مجاني بالكامل · بلا إعلانات</div></div>')
    feats = [('read', 'اقرأ'), ('listen', 'استمع'), ('memo', 'احفظ')]
    row = ''.join(f'<div style="display:flex;align-items:center;gap:10px">{icon(k, "#D9B266", 28)}'
                  f'<span style="font-family:Changa;font-weight:500;font-size:25px;color:#F6F1E8">{t}</span></div>' for k, t in feats)
    s.append(f'<div class="abs" style="right:300px;top:428px;display:flex;gap:34px">{row}</div>')
    s.append(f'<div class="abs" style="right:300px;top:492px">{stores("#CFE3DF", 19, 26, 17, 400, 'Changa')}</div>')
    return ''.join(s)


COVERS = {
    'cover_A_mihrab': cover_mihrab,
    'cover_B_night_manuscript': cover_night,
    'cover_C_teal_minimal': cover_teal,
}


def render(name, w, h, inner):
    html = HEAD.replace('%W%', str(w)).replace('%H%', str(h)) + inner + '</body></html>'
    p = os.path.join(HERE, name + '.html')
    open(p, 'w').write(html)
    for scale, suf in ((1, ''), (2, '@2x')):
        out = os.path.join(OUT, f'{name}{suf}.png')
        subprocess.run([CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars',
                        '--allow-file-access-from-files', f'--force-device-scale-factor={scale}',
                        f'--window-size={w},{h}', '--virtual-time-budget=3000',
                        f'--screenshot={out}', 'file://' + p],
                       check=False, capture_output=True)
        if not os.path.exists(out): print('FAIL', out)
        print(out)


if __name__ == '__main__':
    only = sys.argv[1:]
    for n, (w, h, inner) in PROFILES.items():
        if not only or n in only:
            render(n, w, h, inner)
    for n, f in COVERS.items():
        if not only or n in only:
            render(n, W, H, f())
