#!/usr/bin/env python3
"""App Store header / search-results art (5244x2950, 3840x1646), AR + EN, no alpha.
Important content stays inside the central ~70% safe area.
Output: docs/brand/store/graphics/header/{ar,en}/<WxH>.png
"""
import os
from PIL import Image
from common import STORE, CREAM, GOLD, background_svg, render, star_pts, logo_inner

OUT = os.path.join(STORE, 'graphics', 'header')
SIZES = [(5244, 2950), (3840, 1646)]
COPY = {
    'ar': ('تبيان - القرآن الكريم', 'مصحف بلا إعلانات: استماع وتفسير وتسميع', 'Changa,Plex', 'Plex'),
    'en': ('Tibyan - The Holy Quran', 'An ad-free Mushaf: listen, tafsir and recitation check',
           'PlexLatin,Changa', 'PlexLatin,Plex'),
}


def body(W, H, lang):
    title, sub, tf, sf = COPY[lang]
    m = min(W, H)
    vb, logo = logo_inner()
    vw, vh = [float(v) for v in vb.split()[2:]]
    # safe area: central 70%
    sx, sy, sw, sh = W * 0.15, H * 0.15, W * 0.70, H * 0.70
    lh = sh * 0.36
    lw = lh * vw / vh
    deco = ''.join(
        f'<polygon points="{star_pts(x, H/2, m*0.30)}" fill="none" stroke="{GOLD}" stroke-opacity="0.28" stroke-width="{m*0.003:.1f}"/>'
        f'<polygon points="{star_pts(x, H/2, m*0.22)}" fill="{GOLD}" fill-opacity="0.06" stroke="{GOLD}" stroke-opacity="0.18" stroke-width="{m*0.002:.1f}"/>'
        for x in (W * 0.06, W * 0.94))
    svg = (f'<svg width="{W}" height="{H}" viewBox="0 0 {W} {H}">{background_svg(W, H, glow_cy=0.5, big_star=False)}'
           f'{deco}</svg>')
    tsize, ssize = min(sh * 0.15, sw * 0.075), min(sh * 0.075, sw * 0.034)
    if lang == 'en':
        tsize *= 0.9
    star = sh * 0.035
    return svg + (
        f'<div style="position:absolute;left:{sx:.0f}px;top:{sy:.0f}px;width:{sw:.0f}px;height:{sh:.0f}px;'
        f'display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center">'
        f'<svg style="position:static" width="{lw:.0f}" height="{lh:.0f}" viewBox="{vb}">{logo}</svg>'
        f'<div style="font-family:{tf};font-weight:700;font-size:{tsize:.0f}px;line-height:1.3;color:{CREAM};margin-top:{sh*0.05:.0f}px">{title}</div>'
        f'<div style="display:flex;align-items:center;gap:{star:.0f}px;margin-top:{sh*0.02:.0f}px">'
        f'<svg style="position:static" width="{star*2:.0f}" height="{star*2:.0f}"><polygon points="{star_pts(star, star, star)}" fill="{GOLD}"/></svg>'
        f'<div style="font-family:{sf};font-weight:600;font-size:{ssize:.0f}px;white-space:nowrap;color:{GOLD}">{sub}</div>'
        f'<svg style="position:static" width="{star*2:.0f}" height="{star*2:.0f}"><polygon points="{star_pts(star, star, star)}" fill="{GOLD}"/></svg>'
        f'</div></div>')


if __name__ == '__main__':
    for lang in COPY:
        for W, H in SIZES:
            out = os.path.join(OUT, lang, f'{W}x{H}.png')
            render(body(W, H, lang), W, H, out, lang=lang)
            Image.open(out).convert('RGB').save(out)
            print(out)
