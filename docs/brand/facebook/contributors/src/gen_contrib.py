#!/usr/bin/env python3
"""Contributors call post (cover C style). Reuses helpers from ../../src/gen.py."""
import os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.dirname(HERE)
sys.path.insert(0, os.path.abspath(os.path.join(HERE, '../../src')))
from gen import HEAD, CHROME, khatam_tile, star_pts, logo  # noqa: E402

CREAM, GOLD, MINT, SOFT, INK = '#F6F1E8', '#D9B266', '#55BDB2', '#CFE3DF', '#0A2422'

ICONS = {
    'code': '<path d="M8 7l-5 5 5 5 M16 7l5 5-5 5 M13.5 4.5l-3 15"/>',
    'design': '<path d="M4 20l4.2-1 11-11-3.2-3.2-11 11z M14 6.8l3.2 3.2"/>',
    'test': '<circle cx="11" cy="11" r="6.5"/><path d="M16 16l4.5 4.5 M8.4 11.2l2 2 3.4-3.6"/>',
    'translate': '<path d="M3 5.5h9 M7.5 3.5v2 M5 5.5c.8 3.6 3.6 6.4 7 7.6 M10 5.5c-.8 3.6-3.6 6.4-7 7.6 M13 20.5l4-9 4 9 M14.4 17.3h5.2"/>',
    'verify': '<path d="M5 3.5h9.5l4.5 4.5v12.5H5z M14.5 3.5V8H19 M8.5 14l2.4 2.4L15.6 11.6"/>',
    'voice': '<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5.5 11a6.5 6.5 0 0 0 13 0 M12 17.5V21 M8.5 21h7"/>',
}
CHIPS = [('code', 'برمجة'), ('design', 'تصميم'), ('test', 'اختبار'),
         ('translate', 'ترجمة'), ('verify', 'مراجعة المصادر'), ('voice', 'سجّل صوتك')]


def ic(name, size, color=GOLD, sw=1.6):
    return (f'<svg width="{size}" height="{size}" viewBox="0 0 24 24" fill="none" stroke="{color}" '
            f'stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round">{ICONS[name]}</svg>')


def chips(fs, isz, gap, padv, padh):
    out = []
    for k, t in CHIPS:
        out.append(f'<div style="display:flex;align-items:center;justify-content:center;gap:12px;'
                   f'padding:{padv}px {padh}px;border:1.4px solid rgba(217,178,102,.55);border-radius:999px;'
                   f'background:rgba(246,241,232,.05)">{ic(k, isz)}'
                   f'<span style="font-family:Changa;font-weight:500;font-size:{fs}px;color:{CREAM}">{t}</span></div>')
    return (f'<div style="display:grid;grid-template-columns:repeat(3,1fr);gap:{gap}px">' + ''.join(out) + '</div>')


def repo_card(w, compact=False):
    """Hand-drawn repo window: tab bar, path, topic tags, tree + code. Latin/digits in Plex."""
    P = 'font-family:Plex'
    tags = ''.join(f'<span style="padding:3px 12px;border-radius:999px;background:rgba(85,189,178,.16);'
                   f'color:{MINT};font-size:17px">{t}</span>'
                   for t in ['Flutter', 'Dart', 'FastAPI', 'sherpa-onnx', 'GPL-3.0'])
    tree = [('dir', 'lib/'), ('dir', 'training-platform/'), ('file', 'CONTRIBUTING.md'), ('file', 'LICENSE')]
    tree_html = ''.join(
        f'<div style="display:flex;align-items:center;gap:10px;color:{CREAM if k == "dir" else SOFT};'
        f'{"font-weight:600;" if t == "CONTRIBUTING.md" else ""}">'
        f'<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="{GOLD if t == "CONTRIBUTING.md" else MINT}" '
        f'stroke-width="1.7" stroke-linejoin="round">'
        + ('<path d="M3 6.5h6l2 2h10v10H3z"/>' if k == 'dir' else '<path d="M6 3h8l4 4v14H6z M14 3v4h4"/>')
        + f'</svg>{t}</div>' for k, t in tree)
    code = [
        (f'<span style="color:{GOLD}">git</span> clone github.com/helalrules7/tibyan', ''),
        (f'<span style="color:{GOLD}">git</span> checkout -b fix/your-idea', ''),
        (f'<span style="color:{MINT}">flutter</span> test', f'<span style="color:{MINT}">✓</span>'),
        (f'<span style="color:{SOFT};opacity:.6">// open a pull request</span>', ''),
    ]
    code_html = ''.join(
        f'<div style="display:flex;gap:16px"><span style="color:{SOFT};opacity:.35;width:18px;text-align:right">{i+1}</span>'
        f'<span style="color:{CREAM}">{c} {extra}</span></div>' for i, (c, extra) in enumerate(code))
    body = (f'<div style="display:flex;gap:26px;padding:20px 26px 24px">'
            f'<div style="display:flex;flex-direction:column;gap:9px;font-size:18px;min-width:210px;'
            f'padding-right:22px;border-right:1px solid rgba(207,227,223,.12)">{tree_html}</div>'
            f'<div style="display:flex;flex-direction:column;gap:9px;font-size:18px">{code_html}</div></div>')
    if compact:
        body = (f'<div style="padding:16px 26px 20px;display:flex;flex-direction:column;gap:8px;font-size:18px">'
                f'{code_html}</div>')
    return (f'<div dir="ltr" style="{P};width:{w}px;border-radius:22px;background:{INK};'
            f'border:1px solid rgba(85,189,178,.28);box-shadow:0 40px 70px -30px rgba(0,0,0,.55);overflow:hidden">'
            f'<div style="display:flex;align-items:center;gap:9px;padding:14px 22px;background:rgba(246,241,232,.04);'
            f'border-bottom:1px solid rgba(207,227,223,.10)">'
            + ''.join(f'<span style="width:12px;height:12px;border-radius:50%;background:{c};opacity:.8"></span>'
                      for c in ('#D9B266', '#55BDB2', '#CFE3DF'))
            + f'<span style="margin-left:14px;color:{SOFT};font-size:17px;opacity:.75">GitHub</span></div>'
            f'<div style="padding:20px 26px 0">'
            f'<div style="font-size:27px;color:{CREAM}"><span style="opacity:.7">helalrules7 /</span> '
            f'<b style="font-weight:700">tibyan</b>'
            f'<span style="margin-left:14px;font-size:15px;padding:2px 10px;border:1px solid rgba(207,227,223,.3);'
            f'border-radius:999px;color:{SOFT};vertical-align:4px">Public</span></div>'
            f'<div style="margin-top:12px;display:flex;flex-wrap:wrap;gap:8px">{tags}</div></div>'
            + body + '</div>')


def post(W, H):
    sq = H == W
    s = [f'<svg class="abs" width="{W}" height="{H}"><defs>{khatam_tile(104, CREAM, 0.06)}'
         f'<linearGradient id="t" x1="1" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#11706A"/>'
         f'<stop offset="1" stop-color="#0A4F4A"/></linearGradient>'
         f'<radialGradient id="hl" cx="78%" cy="14%" r="55%"><stop offset="0" stop-color="{MINT}" stop-opacity=".22"/>'
         f'<stop offset="1" stop-color="{MINT}" stop-opacity="0"/></radialGradient></defs>'
         f'<rect width="{W}" height="{H}" fill="url(#t)"/><rect width="{W}" height="{H}" fill="url(#kh)"/>'
         f'<rect width="{W}" height="{H}" fill="url(#hl)"/>'
         f'<polygon points="{star_pts(W - 70, 150, 330, 0.83)}" fill="{CREAM}" fill-opacity=".04" stroke="{GOLD}" '
         f'stroke-opacity=".45" stroke-width="1.3"/>'
         f'<polygon points="{star_pts(W - 70, 150, 312, 0.83)}" fill="none" stroke="{GOLD}" stroke-opacity=".2"/>'
         f'</svg>']
    M = 80
    # header: logo + eyebrow
    s.append(logo('F6F1E8', W - M - 150, 64, 150))
    s.append(f'<div class="abs" style="left:{M}px;top:84px;display:flex;align-items:center;gap:10px;'
             f'font-family:Plex;font-weight:500;font-size:21px;color:{GOLD};letter-spacing:.3px">'
             f'<span>مفتوح المصدر</span><span style="opacity:.6">·</span><span dir="ltr">GPL-3.0</span></div>')
    top = 220 if not sq else 180
    s.append(f'<div class="abs" style="right:{M}px;left:{M}px;top:{top}px;text-align:right;color:{CREAM};font-family:Changa">'
             f'<div style="font-weight:700;font-size:{88 if not sq else 78}px;line-height:1.15">ساهم في بناء تبيان</div>'
             f'<div style="margin-top:14px;font-weight:400;font-size:{31 if not sq else 26}px;line-height:1.5;color:{SOFT}">'
             f'تطبيق قرآن مجاني بلا إعلانات، وكوده مفتوح للجميع.<br>مكانك محجوز: بكودك أو تصميمك أو صوتك.</div></div>')
    cy = 520 if not sq else 410
    s.append(f'<div class="abs" style="left:{M}px;right:{M}px;top:{cy}px">{chips(26 if not sq else 24, 28, 16, 15 if not sq else 11, 18)}</div>')
    ry = 740 if not sq else 584
    s.append(f'<div class="abs" style="left:{M}px;top:{ry}px">{repo_card(W - 2 * M, compact=sq)}</div>')
    # footer CTA
    fy = H - 170 if not sq else H - 146
    s.append(f'<div class="abs" style="left:{M}px;right:{M}px;top:{fy}px;height:1px;background:rgba(217,178,102,.35)"></div>')
    s.append(f'<div class="abs" style="left:{M}px;right:{M}px;top:{fy + 30}px;display:flex;justify-content:space-between;align-items:center">'
             f'<div style="font-family:Changa;font-weight:500;font-size:29px;color:{CREAM}">ابدأ بقراءة '
             f'<span dir="ltr" style="font-family:Plex;font-weight:600;color:{GOLD}">CONTRIBUTING.md</span></div>'
             f'<div dir="ltr" style="font-family:Plex;font-weight:600;font-size:29px;color:{CREAM}">github.com/helalrules7/<span style="color:{GOLD}">tibyan</span></div></div>')
    s.append(f'<div class="abs" style="left:{M}px;right:{M}px;top:{fy + 88}px;text-align:right;font-family:Plex;'
             f'font-size:20px;color:{SOFT};opacity:.8">altibyan.app</div>')
    return ''.join(s)


def render(name, w, h):
    html = HEAD.replace('%W%', str(w)).replace('%H%', str(h)) + post(w, h) + '</body></html>'
    html = html.replace('url(logo_', 'url(logo_')  # logo svg sits next to this html
    p = os.path.join(HERE, name + '.html')
    open(p, 'w').write(html)
    out = os.path.join(OUT, name + '.png')
    subprocess.run([CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars', '--allow-file-access-from-files',
                    '--force-device-scale-factor=1', f'--window-size={w},{h}', '--virtual-time-budget=3000',
                    f'--screenshot={out}', 'file://' + p], check=False, capture_output=True)
    print(out, os.path.exists(out))


if __name__ == '__main__':
    render('post_1080x1350', 1080, 1350)
    render('post_1080x1080', 1080, 1080)
