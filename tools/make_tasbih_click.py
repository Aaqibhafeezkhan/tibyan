"""Synthesizes the misbaha's bead click (assets/tasbih/click.wav).

Made here from nothing but math (two damped partials and a short noise
burst), so the sound is the project's own work: CC0 1.0. Deterministic.

    python3 -I tools/make_tasbih_click.py
"""

import math
import pathlib
import random
import struct
import wave

RATE = 44100
LENGTH = 0.045  # seconds

ROOT = pathlib.Path(__file__).resolve().parent.parent


def main() -> None:
    rnd = random.Random(33)
    n = int(RATE * LENGTH)
    samples = []
    for i in range(n):
        t = i / RATE
        body = 0.55 * math.sin(2 * math.pi * 2350 * t) * math.exp(-t * 160)
        ring = 0.25 * math.sin(2 * math.pi * 4100 * t) * math.exp(-t * 260)
        tick = (rnd.random() * 2 - 1) * 0.5 * math.exp(-t * 900)
        attack = min(1.0, i / 24)
        samples.append(max(-1.0, min(1.0, (body + ring + tick) * attack)))
    path = ROOT / "assets/tasbih/click.wav"
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(s * 26000)) for s in samples))
    print(f"wrote {path} ({n} samples)")


if __name__ == "__main__":
    main()
