"""Where to cut each page into its 15 lines, so the app can spread the
lines over the screen height without clipping any mark.

New edition (quran-ws SVG): for each gap between two lines, the row that
crosses the fewest contours. Contours that still cross it are recorded
with their exact outline and the line they belong to, so the app can give
each one to its own line (a straight cut would clip them).

Old edition (quran.com PNG): the row with the least ink in each gap.

The page artwork is never modified; this only records geometry.
Called by build_content_db.py.
"""
import io
import sys
import zipfile
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_word_boxes as B  # noqa: E402
import xml.etree.ElementTree as ET  # noqa: E402

ROOT = Path(__file__).resolve().parent
IMAGES = ROOT / '.cache' / 'images_1024.zip'
FIRST, PITCH, LINES = 26.2, 35.75, 15          # new edition line grid
OLD_TOP, OLD_PITCH = 8, 1594 / 15              # old edition line grid (px)


def _segments(d):
    """Subpaths of a path: [[start], segment...], each segment its points
    after the current one ([end] for a line, [control, end] for a quadratic,
    [control, control, end] for a cubic). S and T are written out with their
    implied first control point."""
    toks = B.TOKENS.findall(d)
    i, cmd = 0, None
    x = y = sx = sy = 0.0
    out, cur = [], []

    def num():
        nonlocal i
        i += 1
        return float(toks[i - 1])

    while i < len(toks):
        if toks[i].isalpha():
            cmd = toks[i]
            i += 1
            if cmd in 'Zz':
                x, y = sx, sy
                continue
        rel, c = cmd.islower(), cmd.upper()
        if c == 'M':
            dx, dy = num(), num()
            x, y = (x + dx, y + dy) if rel else (dx, dy)
            if cur:
                out.append(cur)
            cur, sx, sy = [[(x, y)]], x, y
            cmd = 'l' if rel else 'L'
            continue
        if c == 'L':
            dx, dy = num(), num()
            nx, ny = (x + dx, y + dy) if rel else (dx, dy)
            pts = [(nx, ny)]
        elif c == 'H':
            dx = num()
            pts = [(x + dx if rel else dx, y)]
        elif c == 'V':
            dy = num()
            pts = [(x, y + dy if rel else dy)]
        elif c in 'CQST':
            pts = []
            for _ in range(3 if c == 'C' else 1 if c == 'T' else 2):
                dx, dy = num(), num()
                pts.append((x + dx, y + dy) if rel else (dx, dy))
            if c in 'ST':
                # The first control point is the previous curve's last one
                # reflected about the current point (or the current point).
                prev = cur[-1] if cur else []
                kind = {'S': 4, 'T': 3}[c]
                if len(prev) == kind - 1 and len(cur) > 1:
                    px, py = prev[-2]
                    pts.insert(0, (2 * x - px, 2 * y - py))
                else:
                    pts.insert(0, (x, y))
        else:
            raise ValueError(f'unsupported path command {cmd}')
        cur.append(pts)
        x, y = pts[-1]
    if cur:
        out.append(cur)
    return out


def _outline(m, contour):
    """One contour as path data in page units, its curves kept as curves.

    The outline must hold all of the mark's ink: the app cuts it out of the
    neighbouring line's band. A polygon through the curves' control points
    does not (a curve can bulge past it, by up to 1.8 units on page 298),
    and the ink outside it was drawn again with the neighbouring line."""
    def p(pt):
        x, y = B.apply(m, pt)
        return f'{x:.2f} {y:.2f}'
    parts = ['M ' + p(contour[0][0])]
    for seg in contour[1:]:
        op = 'L' if len(seg) == 1 else 'Q' if len(seg) == 2 else 'C'
        parts.append(op + ' ' + ' '.join(p(q) for q in seg))
    return ' '.join(parts) + ' Z'


def _outlines(svg, group, skip_class=None):
    """The outline of each contour of the paths in the element with id
    [group], in document order: the order of [B.read_page] and
    [marker_items]."""
    out = []

    def walk(el, m, inside):
        m = B.compose(m, B.parse_transform(el.get('transform')))
        inside = inside or el.get('id') == group
        if (el.tag == B.SVG_NS + 'path' and inside
                and (skip_class is None or el.get('class') != skip_class)):
            out.extend(_outline(m, c) for c in _segments(el.get('d')))
        for child in el:
            walk(child, m, inside)
    walk(ET.fromstring(svg), (1, 0, 0, 1, 0, 0), False)
    return out


def marker_items(svg):
    """(bbox, points) of the verse-end marker contours, a group apart from
    the page text; cuts must not split them either."""
    out = []

    def walk(el, m, inside):
        m = B.compose(m, B.parse_transform(el.get('transform')))
        inside = inside or el.get('id') == 'ayah_markers'
        if el.tag == B.SVG_NS + 'path' and inside:
            for c in B.contours(el.get('d')):
                pts = [B.apply(m, p) for p in c]
                xs, ys = [p[0] for p in pts], [p[1] for p in pts]
                out.append(((min(xs), min(ys), max(xs), max(ys)), pts))
        for child in el:
            walk(child, m, inside)
    walk(ET.fromstring(svg), (1, 0, 0, 1, 0, 0), False)
    return out


def svg_page_cuts(svg, first=FIRST, pitch=PITCH):
    """(cuts[14], overflow[(line, path_d)]) of one SVG page whose 15 lines
    are centred at first + j * pitch."""
    items, _ = B.read_page(svg)
    items = items + marker_items(svg)
    outlines = (_outlines(svg, 'content', skip_class='ayahPolygon')
                + _outlines(svg, 'ayah_markers'))
    assert len(outlines) == len(items), (len(outlines), len(items))
    cuts, overflow = [], []
    for j in range(LINES - 1):
        lo, hi = first + j * pitch + 6, first + (j + 1) * pitch - 6
        best, y = None, lo
        while y <= hi:
            n = sum(1 for b, _ in items if b[1] < y < b[3])
            if best is None or n < best[0]:
                best = (n, y)
            y += 0.25
        cut = best[1]
        cuts.append(cut)
        for (b, _), outline in zip(items, outlines):
            if b[1] < cut < b[3]:
                cy = (b[1] + b[3]) / 2
                line = min(range(LINES), key=lambda k: abs(first + k * pitch - cy))
                overflow.append((line, outline))
    return cuts, overflow


def new_edition():
    """Yields (page, cuts[14], overflow[(line, path_d)])."""
    with zipfile.ZipFile(B.SVG_ZIP) as z:
        for page in range(3, 605):
            svg = z.read(f'svg/{page:03d}.svg').decode()
            cuts, overflow = svg_page_cuts(svg)
            yield page, cuts, overflow


def _component(alpha, w, h, x, y, limit=20000):
    """Bounding box of the connected ink around (x, y)."""
    px = alpha
    seen = {(x, y)}
    stack = [(x, y)]
    x0 = x1 = x
    y0 = y1 = y
    while stack and len(seen) < limit:
        cx, cy = stack.pop()
        for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1),
                       (cx + 1, cy + 1), (cx - 1, cy - 1), (cx + 1, cy - 1), (cx - 1, cy + 1)):
            if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and px[nx, ny] > 60:
                seen.add((nx, ny))
                stack.append((nx, ny))
                x0, x1, y0, y1 = min(x0, nx), max(x1, nx), min(y0, ny), max(y1, ny)
    return x0, y0, x1 + 1, y1 + 1


def old_edition():
    """Yields (page, cuts[14], overflow[(line, (x0, y0, x1, y1))]) in image
    pixels. Ink that still crosses a cut is given whole to its own line."""
    with zipfile.ZipFile(IMAGES) as z:
        for page in range(3, 605):
            alpha = Image.open(io.BytesIO(z.read(f'width_1024/page{page:03d}.png'))).convert('RGBA').getchannel('A')
            w, h = alpha.size
            px = alpha.load()
            cuts, overflow = [], []
            for j in range(LINES - 1):
                mid = OLD_TOP + (j + 1) * OLD_PITCH
                rows = range(int(mid - 30), int(mid + 30))
                ink = {y: sum(1 for x in range(0, w, 2) if px[x, y] > 60) for y in rows}
                low = min(ink.values())
                best = [y for y in rows if ink[y] == low]
                cut = best[len(best) // 2]
                cuts.append(cut)
                done = []
                for x in range(w):
                    if px[x, cut] > 60 and not any(b[0] <= x < b[2] for b in done):
                        box = _component(px, w, h, x, cut)
                        done.append(box)
                        cy = (box[1] + box[3]) / 2
                        line = min(range(LINES), key=lambda k: abs(OLD_TOP + (k + 0.5) * OLD_PITCH - cy))
                        overflow.append((line, box))
            yield page, cuts, overflow
