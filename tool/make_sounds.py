"""Writes the alert sounds to android/app/src/main/res/raw.

Same tones as ShinePlatform/tray_app.py:
  grid_on      rising chime
  grid_off     falling tones
  low_battery  ~2.8 s two-tone siren

Run from the project folder:  python tool/make_sounds.py
"""
import math
import os
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "android", "app", "src", "main", "res", "raw")

GRID_ON = [(523, 140), (659, 140), (784, 140), (1047, 360)]
GRID_OFF = [(1047, 220), (784, 220), (587, 220), (392, 500)]
LOW_BATTERY = [(880, 350), (660, 350)] * 4


def tone(freq, ms, volume=0.6):
    n = int(RATE * ms / 1000)
    fade = int(RATE * 0.008)  # 8 ms fade in/out to avoid clicks
    out = []
    for i in range(n):
        env = min(1.0, i / fade, (n - i) / fade)
        out.append(volume * env * math.sin(2 * math.pi * freq * i / RATE))
    return out


def write(name, tones, gap_ms=30):
    samples = []
    for freq, ms in tones:
        samples += tone(freq, ms)
        samples += [0.0] * int(RATE * gap_ms / 1000)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, f"{name}.wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(s * 32767)) for s in samples))
    print("wrote", os.path.normpath(path))


KEEP_XML = """<?xml version="1.0" encoding="utf-8"?>
<!-- The sounds are referenced by name from Dart (notification channels), so the
     release resource shrinker can't see them. Keep them. -->
<resources xmlns:tools="http://schemas.android.com/tools"
    tools:keep="@raw/grid_on,@raw/grid_off,@raw/low_battery" />
"""


if __name__ == "__main__":
    write("grid_on", GRID_ON)
    write("grid_off", GRID_OFF)
    write("low_battery", LOW_BATTERY)
    keep = os.path.join(OUT, "keep.xml")
    with open(keep, "w", encoding="utf-8", newline="\n") as f:
        f.write(KEEP_XML)
    print("wrote", os.path.normpath(keep))
