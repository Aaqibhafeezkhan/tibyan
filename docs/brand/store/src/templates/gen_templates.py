#!/usr/bin/env python3
"""App Store screenshot TEMPLATES: Tibyan background + generic vector device frame with a
transparent screen hole. Output: docs/brand/store/templates/<device>/<WxH>/.

Needs Pillow (+ psd-tools for the optional layered PSD) and Google Chrome.
Run: python3 gen_templates.py
"""
import json, os, sys
from PIL import Image, ImageChops
from common import STORE, CREAM, GOLD, background_svg, render, star_pts

OUT = os.path.join(STORE, 'templates')

HEAD_AR = 'اسمع وتابع الكلمة وهي تُتلى'
HEAD_EN = 'Listen and follow each word as it is recited'

# device, canvas sizes. The screen aspect = the screenshot size itself (that is the
# pixel size the owner will paste).
SIZES = {
    'iphone_6.3': [(1179, 2556), (2556, 1179), (1206, 2622), (2622, 1206)],
    'iphone_duo': [(1398, 2034), (2034, 1398), (2007, 2853), (2853, 2007)],
    'ipad_13': [(2048, 2732), (2732, 2048), (2064, 2752), (2752, 2064)],
    'mac': [(2880, 1800), (2560, 1600), (1440, 900), (1280, 800)],
    # Google Play
    'android_phone': [(1080, 1920), (1080, 2400), (1920, 1080)],
    'android_tablet_7': [(1200, 1920), (1920, 1200)],
    'android_tablet_10': [(1600, 2560), (2560, 1600)],
}
TABLETS = ('ipad_13', 'android_tablet_7', 'android_tablet_10')
# per device: (bezel k, screen corner k, outer corner extra) as fractions of min(screen w,h)
SPEC = {
    'iphone_6.3': dict(bezel=0.042, radius=0.137),
    'iphone_duo': dict(bezel=0.036, radius=0.075),
    'ipad_13': dict(bezel=0.048, radius=0.038),
    'android_phone': dict(bezel=0.030, radius=0.085),
    'android_tablet_7': dict(bezel=0.055, radius=0.035),
    'android_tablet_10': dict(bezel=0.050, radius=0.035),
}
BODY, EDGE, INNER = '#151a1b', '#5a6467', '#050707'


def rr_path(x, y, w, h, r):
    return (f'M{x+r:.2f},{y:.2f}H{x+w-r:.2f}A{r:.2f},{r:.2f} 0 0 1 {x+w:.2f},{y+r:.2f}'
            f'V{y+h-r:.2f}A{r:.2f},{r:.2f} 0 0 1 {x+w-r:.2f},{y+h:.2f}H{x+r:.2f}'
            f'A{r:.2f},{r:.2f} 0 0 1 {x:.2f},{y+h-r:.2f}V{y+r:.2f}A{r:.2f},{r:.2f} 0 0 1 {x+r:.2f},{y:.2f}Z')


def layout(W, H):
    """Headline band and device area (x, y, w, h)."""
    if H > W:
        band = (0.06 * W, 0.035 * H, 0.88 * W, 0.17 * H)
        area = (0.08 * W, 0.225 * H, 0.84 * W, 0.745 * H)
    else:
        band = (0.08 * W, 0.03 * H, 0.84 * W, 0.15 * H)
        area = (0.06 * W, 0.205 * H, 0.88 * W, 0.765 * H)
    return band, area


def handheld(device, W, H):
    """Phone / tablet frame. Returns (frame svg, mask svg, screen dict)."""
    k = SPEC[device]
    _, (ax, ay, aw, ah) = layout(W, H)
    nm = min(W, H)
    s = min(aw / (W + 2 * k['bezel'] * nm), ah / (H + 2 * k['bezel'] * nm))
    sw, sh = W * s, H * s
    m = min(sw, sh)
    b = k['bezel'] * m
    ow, oh = sw + 2 * b, sh + 2 * b
    ox, oy = ax + (aw - ow) / 2, ay + (ah - oh) / 2
    sx, sy = ox + b, oy + b
    r = k['radius'] * m
    R = r + b
    portrait = H > W
    edge = max(1.5, m * 0.006)
    parts = []
    # side buttons (drawn first, under the body)
    if device not in TABLETS:
        bt = m * 0.012
        btn = []
        if portrait:
            for (yy, ll) in [(0.18, 0.05), (0.27, 0.09), (0.38, 0.09)]:
                btn.append((ox - bt, oy + oh * yy, bt * 2, oh * ll))
            btn.append((ox + ow - bt, oy + oh * 0.27, bt * 2, oh * 0.14))
        else:
            for (xx, ll) in [(0.18, 0.05), (0.27, 0.09), (0.38, 0.09)]:
                btn.append((ox + ow * (1 - xx - ll), oy - bt, ow * ll, bt * 2))
            btn.append((ox + ow * (1 - 0.27 - 0.14), oy + oh - bt, ow * 0.14, bt * 2))
        for (x, y, w, h) in btn:
            parts.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" rx="{bt:.1f}" fill="#2b3234" stroke="{EDGE}" stroke-width="{edge*0.5:.1f}"/>')
    hole = rr_path(sx, sy, sw, sh, r)
    parts.append(f'<path fill-rule="evenodd" d="{rr_path(ox, oy, ow, oh, R)} {hole}" fill="{BODY}"/>')
    # inner black bezel ring
    ib = b * 0.55
    parts.append(f'<path fill-rule="evenodd" d="{rr_path(sx-ib, sy-ib, sw+2*ib, sh+2*ib, r+ib)} {hole}" fill="{INNER}"/>')
    parts.append(f'<path d="{rr_path(ox, oy, ow, oh, R)}" fill="none" stroke="{EDGE}" stroke-width="{edge:.1f}"/>')
    parts.append(f'<path d="{rr_path(ox+edge*1.6, oy+edge*1.6, ow-edge*3.2, oh-edge*3.2, R-edge*1.6)}" fill="none" stroke="#ffffff" stroke-opacity="0.08" stroke-width="{edge*0.6:.1f}"/>')
    if device == 'iphone_6.3':  # Dynamic Island (on the display)
        iw, ih = 0.31 * m, 0.092 * m
        if portrait:
            parts.append(f'<rect x="{sx+(sw-iw)/2:.1f}" y="{sy+0.028*m:.1f}" width="{iw:.1f}" height="{ih:.1f}" rx="{ih/2:.1f}" fill="#000"/>')
        else:
            parts.append(f'<rect x="{sx+0.028*m:.1f}" y="{sy+(sh-iw)/2:.1f}" width="{ih:.1f}" height="{iw:.1f}" rx="{ih/2:.1f}" fill="#000"/>')
    elif device == 'android_phone':  # punch-hole camera (on the display)
        pr = 0.028 * m
        cx, cy = ((sx + sw / 2, sy + 0.045 * m) if portrait else (sx + 0.045 * m, sy + sh / 2))
        parts.append(f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{pr:.1f}" fill="#000"/>')
    else:  # camera dot in the bezel
        cr = b * 0.16
        if device in TABLETS:
            cx, cy = ((ox + ow - b / 2, oy + oh / 2) if portrait else (ox + ow / 2, oy + b / 2))
        else:
            cx, cy = ox + ow / 2, oy + b / 2
        parts.append(f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{cr:.1f}" fill="#0b1a24" stroke="#24333b" stroke-width="{cr*0.35:.1f}"/>')
    if device == 'iphone_duo':  # fold hinge marks on the outer edge
        hx = ox + ow / 2 if not portrait else None
        if portrait:
            hy = oy + oh / 2
            for x in (ox, ox + ow):
                parts.append(f'<rect x="{x-edge:.1f}" y="{hy-b*0.9:.1f}" width="{edge*2:.1f}" height="{b*1.8:.1f}" fill="{EDGE}"/>')
        else:
            for y in (oy, oy + oh):
                parts.append(f'<rect x="{hx-b*0.9:.1f}" y="{y-edge:.1f}" width="{b*1.8:.1f}" height="{edge*2:.1f}" fill="{EDGE}"/>')
    mask = f'<path d="{hole}" fill="#fff"/>'
    screen = dict(x=round(sx), y=round(sy), w=round(sw), h=round(sh), corner_radius=round(r))
    return ''.join(parts), mask, screen


def macbook(W, H):
    _, (ax, ay, aw, ah) = layout(W, H)
    # proportions relative to screen width sw
    bs, bt, bb = 0.020, 0.024, 0.040    # bezel side / top / chin
    base_w, base_h = 1.16, 0.034
    tot_w = lambda sw: sw * max(1 + 2 * bs, base_w)
    tot_h = lambda sw: sw * (H / W + bt + bb + base_h)
    sw = min(aw / tot_w(1), ah / tot_h(1))
    sh = sw * H / W
    ow, oh = sw * (1 + 2 * bs), sh + sw * (bt + bb)
    ox = ax + (aw - ow) / 2
    oy = ay + (ah - tot_h(sw)) / 2
    sx, sy = ox + sw * bs, oy + sw * bt
    r = 0.011 * sw
    R = 0.032 * sw
    edge = max(1.2, sw * 0.0012)
    parts = []
    lid = (f'M{ox:.1f},{oy+R:.1f}A{R:.1f},{R:.1f} 0 0 1 {ox+R:.1f},{oy:.1f}H{ox+ow-R:.1f}'
           f'A{R:.1f},{R:.1f} 0 0 1 {ox+ow:.1f},{oy+R:.1f}V{oy+oh:.1f}H{ox:.1f}Z')
    hole = rr_path(sx, sy, sw, sh, r)
    parts.append(f'<path fill-rule="evenodd" d="{lid} {hole}" fill="{INNER}"/>')
    parts.append(f'<path d="{lid}" fill="none" stroke="{EDGE}" stroke-width="{edge*1.5:.1f}"/>')
    # notch (part of the frame, over the display)
    nw, nh, nr = 0.125 * sw, 0.021 * sw, 0.008 * sw
    nx = sx + (sw - nw) / 2
    notch = (f'M{nx:.1f},{sy-1:.1f}H{nx+nw:.1f}V{sy+nh-nr:.1f}A{nr:.1f},{nr:.1f} 0 0 1 {nx+nw-nr:.1f},{sy+nh:.1f}'
             f'H{nx+nr:.1f}A{nr:.1f},{nr:.1f} 0 0 1 {nx:.1f},{sy+nh-nr:.1f}Z')
    parts.append(f'<path d="{notch}" fill="{INNER}"/>')
    parts.append(f'<circle cx="{sx+sw/2:.1f}" cy="{sy+nh*0.45:.1f}" r="{nh*0.18:.1f}" fill="#0b1a24"/>')
    # base
    bw, bh = sw * base_w, sw * base_h
    bx, by = sx + sw / 2 - bw / 2, oy + oh
    br = bh * 0.9
    base = (f'M{bx:.1f},{by:.1f}H{bx+bw:.1f}V{by+bh*0.35:.1f}'
            f'C{bx+bw:.1f},{by+bh:.1f} {bx+bw-br:.1f},{by+bh:.1f} {bx+bw-br*1.4:.1f},{by+bh:.1f}'
            f'H{bx+br*1.4:.1f}C{bx+br:.1f},{by+bh:.1f} {bx:.1f},{by+bh:.1f} {bx:.1f},{by+bh*0.35:.1f}Z')
    parts.append('<defs><linearGradient id="alu" x1="0" y1="0" x2="0" y2="1">'
                 '<stop offset="0" stop-color="#d5dadc"/><stop offset="0.35" stop-color="#aab1b4"/>'
                 '<stop offset="1" stop-color="#6c7477"/></linearGradient></defs>')
    parts.append(f'<path d="{base}" fill="url(#alu)"/>')
    gw = bw * 0.13
    parts.append(f'<path d="M{sx+sw/2-gw/2:.1f},{by:.1f}H{sx+sw/2+gw/2:.1f}V{by+bh*0.28:.1f}'
                 f'Q{sx+sw/2+gw/2:.1f},{by+bh*0.4:.1f} {sx+sw/2+gw/2-bh*0.3:.1f},{by+bh*0.4:.1f}'
                 f'H{sx+sw/2-gw/2+bh*0.3:.1f}Q{sx+sw/2-gw/2:.1f},{by+bh*0.4:.1f} {sx+sw/2-gw/2:.1f},{by+bh*0.28:.1f}Z" fill="#8d9598"/>')
    parts.append(f'<rect x="{bx:.1f}" y="{by:.1f}" width="{bw:.1f}" height="{max(1, bh*0.07):.1f}" fill="#eef1f2" opacity="0.7"/>')
    mask = f'<path fill-rule="evenodd" d="{hole} {notch}" fill="#fff"/>'
    screen = dict(x=round(sx), y=round(sy), w=round(sw), h=round(sh), corner_radius=round(r),
                  notch=dict(x=round(nx), y=round(sy), w=round(nw), h=round(nh)))
    return ''.join(parts), mask, screen


def headline_body(W, H, text, lang):
    (bx, by, bw, bh), _ = layout(W, H)
    m = min(W, H)
    fs = W * 0.064 if H > W else H * 0.068
    star = fs * 0.32
    fam = "Changa,Plex,sans-serif" if lang == 'ar' else "PlexLatin,Changa,sans-serif"
    weight = 700 if lang == 'ar' else 600
    if lang == 'en':
        fs *= 0.86
    return (f'<div style="position:absolute;left:{bx:.0f}px;top:{by:.0f}px;width:{bw:.0f}px;height:{bh:.0f}px;'
            f'display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;gap:{fs*0.18:.0f}px">'
            f'<svg style="position:static" width="{star*2:.0f}" height="{star*2:.0f}"><polygon points="{star_pts(star, star, star)}" fill="{GOLD}"/></svg>'
            f'<div style="font-family:{fam};font-weight:{weight};font-size:{fs:.0f}px;line-height:1.25;text-wrap:balance;color:{CREAM}">{text}</div></div>')


def build(device, W, H, psd=True):
    d = os.path.join(OUT, device, f'{W}x{H}')
    L = os.path.join(d, 'layers')
    os.makedirs(L, exist_ok=True)
    frame, mask, screen = macbook(W, H) if device == 'mac' else handheld(device, W, H)
    svg = lambda inner: f'<svg width="{W}" height="{H}" viewBox="0 0 {W} {H}">{inner}</svg>'
    render(svg(background_svg(W, H, glow_cy=0.6)), W, H, os.path.join(L, 'background.png'))
    render(svg(frame), W, H, os.path.join(L, 'frame.png'), transparent=True)
    render(svg(mask), W, H, os.path.join(L, 'screen_mask.png'), transparent=True)
    render(headline_body(W, H, HEAD_AR, 'ar'), W, H, os.path.join(L, 'headline.png'), transparent=True, lang='ar')
    render(headline_body(W, H, HEAD_EN, 'en'), W, H, os.path.join(L, 'headline_en.png'), transparent=True, lang='en')
    bg = Image.open(os.path.join(L, 'background.png')).convert('RGB')
    bg.save(os.path.join(L, 'background.png'))
    fr = Image.open(os.path.join(L, 'frame.png')).convert('RGBA')
    mk = Image.open(os.path.join(L, 'screen_mask.png')).convert('RGBA')
    hole = ImageChops.invert(mk.getchannel('A'))
    tpl = bg.convert('RGBA')
    tpl.putalpha(hole)
    tpl = Image.alpha_composite(tpl, fr)
    tpl.save(os.path.join(d, 'template.png'))
    native = {'iphone_6.3': 'iPhone 6.1"/6.3" screenshot', 'iphone_duo': 'iPhone Duo screenshot',
              'ipad_13': 'iPad 12.9"/13" screenshot', 'mac': 'Mac screenshot',
              'android_phone': 'Android phone screenshot', 'android_tablet_7': '7-inch Android tablet screenshot',
              'android_tablet_10': '10-inch Android tablet screenshot'}[device]
    info = dict(device=device, canvas=dict(w=W, h=H), screen=screen,
                paste_screenshot=dict(w=W, h=H, note=f'Use a {native} of {W}x{H} px; scale it to exactly '
                                      f'{screen["w"]}x{screen["h"]} px and place it at x={screen["x"]}, y={screen["y"]}.'),
                headline_band=dict(zip('xywh', [round(v) for v in layout(W, H)[0]])),
                layers=['background.png', 'frame.png', 'headline.png', 'headline_en.png', 'screen_mask.png'])
    with open(os.path.join(d, 'screen.json'), 'w') as fh:
        json.dump(info, fh, indent=2)
        fh.write('\n')
    if psd:
        write_psd(d, L, W, H)
    print(d)


def write_psd(d, L, W, H):
    try:
        from psd_tools import PSDImage
        from psd_tools.api.layers import PixelLayer
        from psd_tools.constants import Compression
    except ImportError:
        return
    p = PSDImage.new('RGB', (W, H))
    for name, f in [('background', 'background.png'), ('SCREENSHOT goes here (clip to screen_mask)', 'screen_mask.png'),
                    ('frame', 'frame.png'), ('headline AR', 'headline.png'), ('headline EN', 'headline_en.png')]:
        im = Image.open(os.path.join(L, f)).convert('RGBA')
        lay = PixelLayer.frompil(im, p, name, compression=Compression.ZIP)
        if name == 'headline EN':
            lay.visible = False
        p.append(lay)
    p.save(os.path.join(d, 'template.psd'))


if __name__ == '__main__':
    only = sys.argv[1:]
    for dev, sizes in SIZES.items():
        for (W, H) in sizes:
            if only and f'{W}x{H}' not in only:
                continue
            build(dev, W, H)
