#!/usr/bin/env python3
"""Feature-promo reel (1080x1920): hook card, the app's screen recording in a
phone frame with short text pills, end card; audio is the recitation itself.

    python3 tools/video/feature_reel.py spec.json

Adapted from the hclinic reels-kit build.py. Layers are drawn by
feature_reel.html (via stills.mjs), then one ffmpeg pass composes them.

spec: {"out", "work", "rec": screen recording, "in", "out_t": footage range (s),
       "hook": text, "end": text, "pills": [{"text", "t0", "t1"}] (reel time),
       "audio": mp3, "audio_in": seconds into the mp3 that match footage "in",
       "zoom": optional {"t0", "dur", "scale", "cx", "cy"}: one ease-in-out zoom of the
       footage inside the static frame, starting t0 s into the footage, towards the
       recording pixel (cx, cy), then held}
Pill times are reel times; footage starts at HOOK - X1 in the reel.
Quran text never passes through here: it is only in the app's own recording.
"""
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
W, H, FPS = 1080, 1920, 30
HOOK, END, X1, X2 = 2.6, 3.5, 0.4, 0.5
R, PAD = 64, 16  # screen corner radius, phone bezel


def main():
    sp = json.load(open(sys.argv[1]))
    wd = sp['work']
    os.makedirs(wd, exist_ok=True)
    rw, rh = map(int, subprocess.check_output(
        ['ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_entries', 'stream=width,height',
         '-of', 'csv=p=0', sp['rec']], text=True).strip().split(','))
    fh = 1400
    fw = round(fh * rw / rh / 2) * 2
    f = dict(x=(W - fw) // 2, y=280, w=fw, h=fh)
    L = [dict(name='bg', kind='bg', W=W, H=H, frame=f, r=R, pad=PAD, logoY=96),
         dict(name='mask', kind='mask', W=fw, H=fh, frame=f, r=R),
         dict(name='hook', kind='hook', W=W, H=H, text=sp['hook']),
         dict(name='end', kind='end', W=W, H=H, text=sp['end'])]
    for i, p in enumerate(sp['pills']):
        L.append(dict(name=f'pill{i}', kind='pill', W=W, H=H, text=p['text'], y=f['y'] + fh + PAD + 16, fs=58))
    json.dump(L, open(f'{wd}/layers.json', 'w'), ensure_ascii=False)
    subprocess.run(['node', f'{HERE}/stills.mjs', f'{wd}/layers.json', wd], check=True)

    F = sp['out_t'] - sp['in']
    T = HOOK + F + END - X1 - X2
    loop = lambda n: ['-loop', '1', '-framerate', str(FPS), '-t', f'{T + 1:.3f}', '-i', f'{wd}/{n}.png']
    inp = ['-i', sp['rec']]
    for n in ['bg', 'mask', 'hook', 'end']:
        inp += loop(n)
    for i in range(len(sp['pills'])):
        inp += loop(f'pill{i}')
    inp += ['-i', sp['audio']]
    z = sp.get('zoom')
    if z:  # zoompan on a 4x upscale (less sub-pixel jitter); k(it): smoothstep 0..1, zoom 1 -> scale towards (cx, cy)
        u = f"clip((it-{z['t0']})/{z['dur']},0,1)"
        k = f"({u}*{u}*(3-2*{u}))"
        zf = f"(1+{z['scale'] - 1}*{k})"
        cx, cy = f"(iw/2+({z['cx'] / rw}*iw-iw/2)*{k})", f"(ih/2+({z['cy'] / rh}*ih-ih/2)*{k})"
        zoom = (f"scale={fw * 4}:{fh * 4}:flags=lanczos,zoompan=z='{zf}':d=1:fps={FPS}:s={fw}x{fh}:"
                f"x='clip({cx}-iw/zoom/2,0,iw-iw/zoom)':y='clip({cy}-ih/zoom/2,0,ih-ih/zoom)',")
    else:
        zoom = f"scale={fw}:{fh}:flags=lanczos,"
    fc = [f"[0:v]trim={sp['in']}:{sp['out_t']},setpts=PTS-STARTPTS,fps={FPS},{zoom}setsar=1,format=rgba[foot]",
          f'[2:v]format=gray,trim=0:{F:.3f}[m]', '[foot][m]alphamerge[fr]',
          f"[1:v]trim=0:{F:.3f},format=rgba[b];[b][fr]overlay={f['x']}:{f['y']}:shortest=1,format=yuv420p,setsar=1[main]",
          f'[3:v]trim=0:{HOOK},format=yuv420p,setsar=1[hk];[4:v]trim=0:{END},format=yuv420p,setsar=1[en]',
          f'[hk][main]xfade=transition=fade:duration={X1}:offset={HOOK - X1:.3f}[hm]',
          f'[hm][en]xfade=transition=fade:duration={X2}:offset={HOOK + F - X1 - X2:.3f}[v0]']
    prev = 'v0'
    for i, p in enumerate(sp['pills']):
        k = 5 + i
        fc.append(f"[{k}:v]format=rgba,fade=t=in:st={p['t0']}:d=0.35:alpha=1,fade=t=out:st={p['t1'] - .35:.3f}:d=0.35:alpha=1[l{i}]")
        fc.append(f"[{prev}][l{i}]overlay=0:0:enable='between(t,{p['t0']},{p['t1']})'[v{i + 1}]")
        prev = f'v{i + 1}'
    ai = 5 + len(sp['pills'])
    d = int(round((HOOK - X1) * 1000))
    fc.append(f'[{prev}]trim=0:{T:.3f},format=yuv420p[vo]')
    fc.append(f"[{ai}:a]atrim={sp.get('audio_in', 0)},asetpts=PTS-STARTPTS,adelay={d}|{d},apad,atrim=0:{T:.3f},"
              f"afade=t=out:st={T - 1.0:.3f}:d=1.0,loudnorm=I=-16:TP=-1.5:LRA=11,aresample=48000[ao]")
    subprocess.run(['ffmpeg', '-v', 'error', '-y'] + inp + ['-filter_complex', ';'.join(fc), '-map', '[vo]', '-map', '[ao]',
                    '-c:v', 'libx264', '-preset', 'slow', '-crf', '19', '-pix_fmt', 'yuv420p', '-r', str(FPS),
                    '-c:a', 'aac', '-b:a', '160k', '-movflags', '+faststart', '-t', f'{T:.3f}', sp['out']], check=True)
    print('duration', round(T, 2), 'footage', round(F, 2))


if __name__ == '__main__':
    main()
