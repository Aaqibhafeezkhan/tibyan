"""Scans SVG page packs (*.svg.xz) for anything that could escape the
reader's ink recolouring: fills other than the print ink #231f20,
strokes, inline styles, elements other than svg/g/path, text paths without
a fill, or pages whose text is not one compound path.

Usage: python3 -I tools/scan_page_fills.py assets/pages/hafs-1441
"""
import lzma,re,glob,collections,os,sys
root=sys.argv[1]
agg=collections.Counter(); odd=[]
for f in sorted(glob.glob(root+'/*.svg.xz')):
    s=lzma.open(f).read().decode()
    n=os.path.basename(f)[:3]
    fills=collections.Counter(re.findall(r'fill="([^"]*)"',s))
    strokes=re.findall(r'stroke[=:]"?([^";]*)',s)
    styles=re.findall(r'style="([^"]*)"',s)
    tags=collections.Counter(re.findall(r'<([a-zA-Z]+)[ >]',s))
    # content group paths without fill (inherit black)
    ci=s.find('<g id="content"')
    content=s[ci:] if ci>=0 else ''
    cpaths=re.findall(r'<path [^>]*>',content)
    nofill=[p for p in cpaths if 'fill=' not in p and 'fill-opacity="0"' not in p]
    opac=re.findall(r'(?:fill-)?opacity="([^"]*)"',s)
    for k in fills: agg['fill '+k]+=1
    for k in tags: agg['tag '+k]+=1
    flags=[]
    if set(fills)-{'#231f20'}: flags.append('fills=%s'%dict(fills))
    if strokes: flags.append('strokes=%s'%strokes[:3])
    if styles: flags.append('styles=%d'%len(styles))
    if set(tags)-{'svg','g','path'}: flags.append('tags=%s'%dict(tags))
    if nofill: flags.append('content-nofill=%d'%len(nofill))
    if ci<0: flags.append('no-content-group')
    textp=[p for p in cpaths if 'ayahPolygon' not in p]
    if len(textp)!=1: flags.append('text-paths=%d'%len(textp))
    if flags: odd.append((n,flags))
print(agg.most_common(20)); print(len(odd),'pages flagged')
for o in odd[:60]: print(o)
