import sys
from PIL import Image, ImageChops, ImageDraw, ImageFont, ImageFilter, ImageOps

S = sys.argv[1]
R = '/Users/ahmed/Projects/Tibyan-Quran-App'
L = R + '/docs/brand/store/templates/mac/2880x1800/layers/'
SHOTS = '/Users/ahmed/Desktop/Tibyan-MSStore/screenshots/'
OUT = '/Users/ahmed/Desktop/Tibyan-MSStore/art/'
FONT = R + '/assets/fonts/ofl/changa/Changa[wght].ttf'

BG = Image.open(L + 'background.png').convert('RGB')  # 2880x1800
LOGO = Image.open(S + '/logo_gold.png').convert('RGBA')  # 8649 wide, gold
frame_a = Image.open(L + 'frame.png').convert('RGBA').getchannel('A')
screen_a = Image.open(L + 'screen_mask.png').convert('RGBA').getchannel('A')
LAP_BOX = (335, 367, 2545, 1746)
lap_mask = ImageChops.lighter(frame_a, screen_a).crop(LAP_BOX)


def laptop(n):
    shot = Image.open(SHOTS + f'mac-ar-{n:02d}.png').convert('RGBA').crop(LAP_BOX)
    shot.putalpha(lap_mask)
    return shot  # 2210x1379


def background(w, h):
    """Mirror-extend the 2880x1800 background (no upscaling), centred on its star."""
    bw, bh = BG.size
    canvas = Image.new('RGB', (max(w, bw) + 2 * bw, max(h, bh) + 2 * bh))
    # 3x3 mirrored tiling
    tiles = {}
    for ix in (-1, 0, 1):
        for iy in (-1, 0, 1):
            t = BG
            if ix:
                t = ImageOps.mirror(t)
            if iy:
                t = ImageOps.flip(t)
            tiles[(ix, iy)] = t
    cw, ch = 3 * bw, 3 * bh
    canvas = Image.new('RGB', (cw, ch))
    for (ix, iy), t in tiles.items():
        canvas.paste(t, ((ix + 1) * bw, (iy + 1) * bh))
    cx, cy = cw // 2, ch // 2
    if w > cw or h > ch:
        raise ValueError
    out = canvas.crop((cx - w // 2, cy - h // 2, cx - w // 2 + w, cy - h // 2 + h))
    return out


def fit(img, w=None, h=None):
    if w and not h:
        h = round(img.height * w / img.width)
    if h and not w:
        w = round(img.width * h / img.height)
    assert w <= img.width, 'upscale'
    return img.resize((w, h), Image.LANCZOS)


def shadow(canvas, img, pos, r=None):
    r = r or max(8, img.width // 60)
    a = img.getchannel('A').filter(ImageFilter.GaussianBlur(r))
    sh = Image.new('RGBA', img.size, (0, 0, 0, 0))
    sh.putalpha(a.point(lambda v: v * 0.55))
    canvas.alpha_composite(sh, (pos[0], pos[1] + r))
    canvas.alpha_composite(img, pos)


def text(canvas, s, cx, y, size, fill=(246, 241, 232, 255), weight=500):
    f = ImageFont.truetype(FONT, size, layout_engine=ImageFont.Layout.RAQM)
    try:
        f.set_variation_by_axes([weight])
    except Exception:
        pass
    d = ImageDraw.Draw(canvas)
    d.text((cx, y), s, font=f, fill=fill, anchor='ma', direction='rtl' if any('؀' <= c <= 'ۿ' for c in s) else 'ltr')


TITLE_AR = 'تبيان - القرآن الكريم'
TITLE_EN = 'Tibyan - The Holy Quran'


def logo_card(w, h, logo_frac, with_titles=True):
    c = background(w, h).convert('RGBA')
    lg = fit(LOGO, w=round(w * logo_frac))
    unit = min(w, h)
    block_h = lg.height + (int(unit * 0.16) if with_titles else 0)
    y0 = (h - block_h) // 2
    c.alpha_composite(lg, ((w - lg.width) // 2, y0))
    if with_titles:
        y = y0 + lg.height + int(unit * 0.035)
        text(c, TITLE_AR, w // 2, y, int(unit * 0.065), weight=600)
        text(c, TITLE_EN, w // 2, y + int(unit * 0.085), int(unit * 0.04), fill=(217, 178, 102, 255), weight=400)
    return c.convert('RGB')


def save(img, name):
    img.save(OUT + name, optimize=True)
    print(name, img.size)


# 1. poster 9:16 (2:3 per brief's sizes 720x1080 / 1440x2160)
for w, h in ((720, 1080), (1440, 2160)):
    save(logo_card(w, h, 0.62), f'poster-9x16-{w}x{h}.png')
# 2. box art 1:1
for s in (1080, 2160):
    save(logo_card(s, s, 0.52), f'boxart-1x1-{s}x{s}.png')
# 6. featured square
save(logo_card(1080, 1080, 0.52), 'featured-square-1080x1080.png')
# 4. branded key art
save(logo_card(584, 800, 0.66), 'branded-key-art-584x800.png')


# 3. super hero, no title/logo; laptop centre-right, bottom-left calm
def superhero(w, h):
    c = background(w, h).convert('RGBA')
    lap = laptop(1)
    lw = round(w * 0.56)
    lp = fit(lap, w=lw)
    x = round(w * 0.95) - lp.width
    y = round(h * 0.10)
    shadow(c, lp, (x, y))
    return c.convert('RGB')


for w, h in ((1920, 1080), (3840, 2160)):
    save(superhero(w, h), f'superhero-16x9-{w}x{h}.png')


# 5. titled hero: logo + titles left, laptop right
def titled(w, h):
    c = background(w, h).convert('RGBA')
    lp = fit(laptop(1), w=round(w * 0.52))
    shadow(c, lp, (round(w * 0.95) - lp.width, (h - lp.height) // 2))
    col = round(w * 0.24)
    lg = fit(LOGO, w=round(w * 0.27))
    y0 = round(h * 0.22)
    c.alpha_composite(lg, (col - lg.width // 2, y0))
    y = y0 + lg.height + round(h * 0.05)
    text(c, TITLE_AR, col, y, round(h * 0.065), weight=600)
    text(c, TITLE_EN, col, y + round(h * 0.09), round(h * 0.042), fill=(217, 178, 102, 255), weight=400)
    return c.convert('RGB')


save(titled(1920, 1080), 'titled-hero-1920x1080.png')
