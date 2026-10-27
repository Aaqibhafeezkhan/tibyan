"""Shared helpers for the store template / header generators (Tibyan brand look)."""
import math, os, subprocess, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '../../../../..'))
STORE = os.path.abspath(os.path.join(HERE, '../..'))
FONTS = os.path.join(REPO, 'assets/fonts/ofl')
LOGO_SVG = os.path.join(STORE, 'src/logo_F6F1E8.svg')
CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'

TEAL, DEEP, NIGHT = '#0e5f58', '#06302c', '#031a18'
CREAM, GOLD = '#f4ecd8', '#d9b266'


def star_pts(cx, cy, r, inner=0.765, rot=0.0):
    pts = []
    for i in range(16):
        rr = r if i % 2 == 0 else r * inner
        a = -math.pi / 2 + i * math.pi / 8 + rot
        pts.append(f'{cx + math.cos(a) * rr:.1f},{cy + math.sin(a) * rr:.1f}')
    return ' '.join(pts)


def girih(w, h, cell):
    out, y = [], 0.0
    while y < h + cell:
        x = 0.0
        while x < w + cell:
            out.append(f'<polygon points="{star_pts(x, y, cell * 0.5, 0.72)}"/>')
            x += cell
        y += cell
    return ''.join(out)


def background_svg(w, h, glow_cy=0.55, big_star=True):
    m = min(w, h)
    cell = m * 0.16
    sw = max(1.2, m * 0.0016)
    star = ''
    if big_star:
        r = m * 0.46
        star = (f'<polygon points="{star_pts(w/2, h*glow_cy, r)}" fill="{GOLD}" fill-opacity="0.05" '
                f'stroke="{GOLD}" stroke-opacity="0.22" stroke-width="{sw*1.6:.1f}"/>'
                f'<polygon points="{star_pts(w/2, h*glow_cy, r*0.8)}" fill="none" '
                f'stroke="{GOLD}" stroke-opacity="0.12" stroke-width="{sw:.1f}"/>')
    return f'''
  <defs>
    <radialGradient id="bg" cx="50%" cy="{glow_cy*100:.0f}%" r="75%">
      <stop offset="0%" stop-color="{TEAL}"/><stop offset="60%" stop-color="{DEEP}"/>
      <stop offset="100%" stop-color="{NIGHT}"/>
    </radialGradient>
  </defs>
  <rect width="{w}" height="{h}" fill="url(#bg)"/>
  <g fill="none" stroke="{CREAM}" stroke-opacity="0.07" stroke-width="{sw:.1f}">{girih(w, h, cell)}</g>
  {star}'''


def font_css():
    f = 'file://' + FONTS
    return f'''
@font-face{{font-family:Plex;src:url('{f}/ibmplexsansarabic/IBMPlexSansArabic-Medium.ttf');font-weight:500}}
@font-face{{font-family:Plex;src:url('{f}/ibmplexsansarabic/IBMPlexSansArabic-SemiBold.ttf');font-weight:600}}
@font-face{{font-family:Plex;src:url('{f}/ibmplexsansarabic/IBMPlexSansArabic-Bold.ttf');font-weight:700}}
@font-face{{font-family:Changa;src:url('{f}/changa/Changa%5Bwght%5D.ttf');font-weight:200 800}}
@font-face{{font-family:PlexLatin;src:url('{f}/ibmplexsans/IBMPlexSans%5Bwdth,wght%5D.ttf');font-weight:100 700}}
'''


def render(body, w, h, out, transparent=False, lang='ar'):
    """Render an HTML body (absolute layout) at exactly w x h px with headless Chrome."""
    bg = 'transparent' if transparent else '#000'
    html = f'''<!doctype html><html lang="{lang}" dir="{'rtl' if lang=='ar' else 'ltr'}"><head><meta charset="utf-8"><style>
{font_css()}
*{{margin:0;padding:0;box-sizing:border-box}}
html,body{{width:{w}px;height:{h}px;overflow:hidden;background:{bg}}}
body{{position:relative;-webkit-font-smoothing:antialiased}}
svg{{position:absolute;left:0;top:0}}
</style></head><body>{body}</body></html>'''
    fd, tmp = tempfile.mkstemp(suffix='.html', dir=HERE)
    with os.fdopen(fd, 'w') as fh:
        fh.write(html)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    cmd = [CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars',
           '--allow-file-access-from-files', '--force-device-scale-factor=1',
           f'--window-size={w},{h}', '--virtual-time-budget=3000',
           f'--screenshot={out}', 'file://' + tmp]
    if transparent:
        cmd.insert(1, '--default-background-color=00000000')
    try:
        subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    finally:
        os.remove(tmp)


def logo_inner():
    """Return (viewBox, inner markup) of the cream logo SVG."""
    s = open(LOGO_SVG).read()
    vb = s.split('viewBox="')[1].split('"')[0]
    inner = s[s.index('>') + 1:s.rindex('</svg>')]
    return vb, inner
