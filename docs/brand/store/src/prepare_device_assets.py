#!/usr/bin/env python3
"""Prepare high-resolution transparent device mockups for App Store promotional graphics:
1. iPhone Duo (Landscape open fold with two facing Mushaf pages)
2. iPhone Portrait (Modern iPhone showing listening & reading)
3. Apple Watch Ultra (Titanium watch showing smart misbaha / wird)
"""
import os, subprocess
from PIL import Image, ImageChops, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../../..'))
STORE = os.path.join(ROOT, 'docs/brand/store')
ASSETS_OUT = os.path.join(STORE, 'graphics/assets')
CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'

os.makedirs(ASSETS_OUT, exist_ok=True)

def make_iphone_duo():
    canvas_w, canvas_h = 2853, 2007
    frame_path = os.path.join(STORE, 'templates/iphone_duo/2853x2007/layers/frame.png')
    mask_path = os.path.join(STORE, 'templates/iphone_duo/2853x2007/layers/screen_mask.png')
    spread_path = os.path.join(STORE, 'src/screens/spread_604.png')
    
    frame = Image.open(frame_path).convert('RGBA')
    mask = Image.open(mask_path).convert('L')
    spread = Image.open(spread_path).convert('RGBA')
    
    # Screen area: x=409, y=463, w=2036, h=1432
    screen_w, screen_h = 2036, 1432
    spread_resized = spread.resize((screen_w, screen_h), Image.Resampling.LANCZOS)
    
    # Add fold shadow in the center of the spread
    fold_shadow = Image.new('RGBA', (screen_w, screen_h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(fold_shadow)
    cx = screen_w // 2
    # Gradient fold shadow
    for offset in range(-25, 26):
        alpha = int(45 * (1 - abs(offset) / 25))
        draw.line([(cx + offset, 0), (cx + offset, screen_h)], fill=(0, 0, 0, alpha))
    spread_composite = Image.alpha_composite(spread_resized, fold_shadow)
    
    screen_layer = Image.new('RGBA', (canvas_w, canvas_h), (0, 0, 0, 0))
    screen_layer.paste(spread_composite, (409, 463))
    screen_layer.putalpha(ImageChops.multiply(screen_layer.getchannel('A'), mask))
    
    duo = Image.alpha_composite(screen_layer, frame)
    bbox = frame.getbbox()
    duo_cropped = duo.crop((bbox[0]-10, bbox[1]-10, bbox[2]+10, bbox[3]+10))
    
    out_path = os.path.join(ASSETS_OUT, 'device_duo_landscape.png')
    duo_cropped.save(out_path)
    print(f"Generated {out_path} ({duo_cropped.size})")

def make_iphone_portrait():
    canvas_w, canvas_h = 1206, 2622
    frame_path = os.path.join(STORE, 'templates/iphone_6.3/1206x2622/layers/frame.png')
    mask_path = os.path.join(STORE, 'templates/iphone_6.3/1206x2622/layers/screen_mask.png')
    screen_path = os.path.join(STORE, 'src/screens/01_listen.png')
    
    frame = Image.open(frame_path).convert('RGBA')
    mask = Image.open(mask_path).convert('L')
    screen_img = Image.open(screen_path).convert('RGBA')
    
    # Screen area: x=170, y=626, w=866, h=1881
    screen_resized = screen_img.resize((866, 1881), Image.Resampling.LANCZOS)
    screen_layer = Image.new('RGBA', (canvas_w, canvas_h), (0, 0, 0, 0))
    screen_layer.paste(screen_resized, (170, 626))
    screen_layer.putalpha(ImageChops.multiply(screen_layer.getchannel('A'), mask))
    
    iphone = Image.alpha_composite(screen_layer, frame)
    bbox = frame.getbbox()
    iphone_cropped = iphone.crop((bbox[0]-10, bbox[1]-10, bbox[2]+10, bbox[3]+10))
    
    out_path = os.path.join(ASSETS_OUT, 'device_iphone_portrait.png')
    iphone_cropped.save(out_path)
    print(f"Generated {out_path} ({iphone_cropped.size})")

def make_apple_watch():
    watch_screen = os.path.abspath(os.path.join(STORE, 'screenshots/apple_watch/ar/422x514/02_misbaha.png'))
    w, h = 900, 1100
    
    html = f'''<!doctype html><html><head><meta charset="utf-8"><style>
* {{ margin:0; padding:0; box-sizing:border-box; }}
body {{ width: {w}px; height: {h}px; background: transparent; overflow: hidden; display: flex; align-items: center; justify-content: center; }}

.watch-case {{
  position: relative;
  width: 720px;
  height: 870px;
  border-radius: 140px;
  background: linear-gradient(145deg, #ddd8d0 0%, #a8a197 45%, #6a635a 100%);
  box-shadow: 
    0 40px 90px -20px rgba(0,0,0,0.8),
    inset 0 3px 6px rgba(255,255,255,0.7),
    inset 0 -4px 8px rgba(0,0,0,0.5);
  display: flex;
  align-items: center;
  justify-content: center;
}}

.watch-case::before {{
  content: '';
  position: absolute;
  top: 6px; left: 6px; right: 6px; bottom: 6px;
  border-radius: 134px;
  border: 2px solid rgba(255,255,255,0.45);
  pointer-events: none;
}}

/* Digital Crown */
.crown {{
  position: absolute;
  right: -35px;
  top: 185px;
  width: 38px;
  height: 150px;
  border-radius: 12px 18px 18px 12px;
  background: linear-gradient(to right, #7a7369, #d0cac4, #6b645b);
  box-shadow: 4px 0 15px rgba(0,0,0,0.4);
}}
.crown::after {{
  content: '';
  position: absolute;
  left: 9px; top: 16px; bottom: 16px; width: 18px;
  border-radius: 6px;
  background: repeating-linear-gradient(to bottom, #333, #333 4px, #aaa 4px, #aaa 9px);
}}

/* Side Button */
.side-btn {{
  position: absolute;
  right: -15px;
  top: 390px;
  width: 17px;
  height: 130px;
  border-radius: 6px 12px 12px 6px;
  background: linear-gradient(to right, #6b645b, #b5afa7);
}}

/* Action Button (Orange Ultra accent) */
.action-btn {{
  position: absolute;
  left: -18px;
  top: 260px;
  width: 20px;
  height: 160px;
  border-radius: 12px 6px 6px 12px;
  background: linear-gradient(to left, #d85020, #ff7b47, #b23a10);
  box-shadow: -3px 0 12px rgba(0,0,0,0.3);
}}

/* Inner Black Bezel */
.screen-bezel {{
  width: 642px;
  height: 782px;
  border-radius: 110px;
  background: #000;
  padding: 16px;
  box-shadow: inset 0 0 18px rgba(0,0,0,0.95), 0 0 0 3px rgba(0,0,0,0.4);
  display: flex;
  align-items: center;
  justify-content: center;
}}

/* Screen */
.screen {{
  width: 610px;
  height: 750px;
  border-radius: 94px;
  overflow: hidden;
  background: url('file://{watch_screen}') center/cover no-repeat;
  box-shadow: inset 0 0 10px rgba(0,0,0,0.7);
}}
</style></head><body>
<div class="watch-case">
  <div class="action-btn"></div>
  <div class="crown"></div>
  <div class="side-btn"></div>
  <div class="screen-bezel">
    <div class="screen"></div>
  </div>
</div>
</body></html>'''
    
    tmp_html = os.path.join(STORE, 'src/_tmp_watch_hi.html')
    with open(tmp_html, 'w') as f:
        f.write(html)
        
    raw_watch = os.path.join(ASSETS_OUT, '_raw_watch.png')
    subprocess.run([
        CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars',
        '--allow-file-access-from-files', '--force-device-scale-factor=1',
        '--default-background-color=00000000',
        f'--window-size={w},{h}', f'--screenshot={raw_watch}',
        'file://' + tmp_html
    ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    
    if os.path.exists(tmp_html):
        os.remove(tmp_html)
        
    im = Image.open(raw_watch)
    bbox = im.getbbox()
    im_cropped = im.crop((bbox[0]-10, bbox[1]-10, bbox[2]+10, bbox[3]+10))
    out_path = os.path.join(ASSETS_OUT, 'device_watch_ultra.png')
    im_cropped.save(out_path)
    os.remove(raw_watch)
    print(f"Generated {out_path} ({im_cropped.size})")

if __name__ == '__main__':
    make_iphone_duo()
    make_iphone_portrait()
    make_apple_watch()
