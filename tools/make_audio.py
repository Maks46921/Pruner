#!/usr/bin/env python3
"""Синтезирует музыку и звуки «Секатора» (без сторонних сэмплов, всё своё).

Запуск: python3 tools/make_audio.py  →  assets/audio/*.wav
"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(1122)


def note(n):
    """MIDI-нота → частота."""
    return 440.0 * 2 ** ((n - 69) / 12)


def t_axis(sec):
    return np.arange(int(sec * SR)) / SR


def env_adsr(n, a=0.01, d=0.1, s=0.6, r=0.2):
    e = np.ones(n) * s
    ai, di, ri = int(a * SR), int(d * SR), int(r * SR)
    ai = max(ai, 1)
    e[:ai] = np.linspace(0, 1, ai)
    e[ai:ai + di] = np.linspace(1, s, len(e[ai:ai + di]))
    if ri > 0:
        e[-ri:] *= np.linspace(1, 0, ri)
    return e


def pluck(freq, sec, bright=0.5):
    t = t_axis(sec)
    tone = np.sin(2 * np.pi * freq * t) + bright * 0.3 * np.sin(4 * np.pi * freq * t)
    return tone * np.exp(-t * 4.0)


def pad(freqs, sec, vib=0.3):
    t = t_axis(sec)
    out = np.zeros_like(t)
    for f in freqs:
        for det in (-0.6, 0.0, 0.6):
            out += np.sin(2 * np.pi * (f + det) * t + vib * np.sin(2 * np.pi * 0.2 * t))
    out /= len(freqs) * 3
    return out * env_adsr(len(t), a=sec * 0.3, d=0.1, s=1.0, r=sec * 0.3)


def lowpass(x, alpha):
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += alpha * (x[i] - acc)
        y[i] = acc
    return y


def echo(x, delay, fb=0.35, mix=0.35):
    d = int(delay * SR)
    y = x.copy()
    for i in range(d, len(y)):
        y[i] += y[i - d] * fb
    return x * (1 - mix) + y * mix


def place(track, clip, at):
    i = int(at * SR)
    j = min(len(track), i + len(clip))
    track[i:j] += clip[:j - i]


def heartbeat(sec=0.5, pitch=55.0):
    t = t_axis(sec)
    f = pitch * (1 + 1.5 * np.exp(-t * 30))
    thump = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 14)
    return thump


def make_loopable(x, fade=1.5):
    """Хвост плавно переходит в начало, чтобы трек зацикливался без щелчка."""
    n = int(fade * SR)
    head = x[:n].copy()
    tail = x[-n:].copy()
    w = np.linspace(0, 1, n)
    x = x[:-n].copy()
    x[:n] = head * w + tail * (1 - w)
    return x


def normalize(x, peak=0.8):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def save(name, x):
    x = np.clip(x, -1, 1)
    data = (x * 32767).astype(np.int16)
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f"{name}: {len(x) / SR:.1f} c")


# --- Музыка --------------------------------------------------------------------

def music_day():
    bar = 4.0
    chords = [[60, 64, 67, 71], [57, 60, 64, 67], [53, 57, 60, 64], [55, 59, 62, 64]]
    length = bar * len(chords) * 3 + 1.5
    track = np.zeros(int(length * SR))
    for rep in range(3):
        for ci, ch in enumerate(chords):
            start = (rep * len(chords) + ci) * bar
            place(track, pad([note(n - 12) for n in ch[:3]], bar + 1.0) * 0.35, start)
            pattern = [0, 2, 1, 3, 2, 1, 3, 2]
            for k, idx in enumerate(pattern):
                if rng.random() < 0.82:
                    place(track, pluck(note(ch[idx] + 12), 1.2) * 0.22, start + k * bar / 8)
    track = echo(track, 0.375, 0.3, 0.3)
    return normalize(make_loopable(track), 0.7)


def music_night():
    length = 49.5
    t = t_axis(length)
    drone = (np.sin(2 * np.pi * note(33) * t) + 0.5 * np.sin(2 * np.pi * note(40) * t)) * 0.35
    drone *= 0.7 + 0.3 * np.sin(2 * np.pi * t / 12.0)
    breath = lowpass(rng.standard_normal(len(t)) * 0.4, 0.02) * (0.5 + 0.5 * np.sin(2 * np.pi * t / 8.0))
    track = drone + breath
    scale = [57, 60, 62, 64, 67, 69, 72]
    beat = 0.75
    for k in range(int(48 / beat)):
        if rng.random() < 0.28:
            place(track, pluck(note(scale[rng.integers(len(scale))]), 2.0, 0.2) * 0.25, k * beat)
    for k in range(int(48 / 4.0)):
        place(track, heartbeat(0.5, 48) * 0.35, k * 4.0)
        place(track, heartbeat(0.4, 44) * 0.25, k * 4.0 + 0.35)
    track = echo(track, 0.75, 0.4, 0.4)
    return normalize(make_loopable(track), 0.7)


def music_final():
    length = 33.5
    t = t_axis(length)
    rise = np.linspace(0.6, 1.0, len(t))
    cluster = [note(n) for n in (45, 46, 52, 53)]
    track = pad(cluster, length, 0.6) * 0.5 * rise
    track += lowpass(rng.standard_normal(len(t)), 0.05) * 0.15
    for k in range(int(32 / 0.9)):
        place(track, heartbeat(0.45, 52) * 0.5, k * 0.9)
        place(track, heartbeat(0.35, 47) * 0.35, k * 0.9 + 0.28)
    for k in range(16):
        place(track, pluck(note([69, 70, 76, 77][k % 4]), 1.6) * 0.18, k * 2.0 + 0.5)
    track = echo(track, 0.45, 0.35, 0.35)
    return normalize(make_loopable(track), 0.75)


# --- Звуки ----------------------------------------------------------------------

def sfx_cut():
    out = np.zeros(int(0.25 * SR))
    for at in (0.0, 0.07):
        t = t_axis(0.05)
        click = rng.standard_normal(len(t)) * np.exp(-t * 120)
        click += np.sin(2 * np.pi * 3200 * t) * np.exp(-t * 80) * 0.5
        place(out, click, at)
    return normalize(out, 0.7)


def sfx_hit():
    t = t_axis(0.18)
    whoosh = lowpass(rng.standard_normal(len(t)), 0.3) * np.exp(-t * 25)
    thump = np.sin(2 * np.pi * 140 * t * (1 - t)) * np.exp(-t * 30)
    return normalize(whoosh * 0.6 + thump, 0.7)


def sfx_hurt():
    t = t_axis(0.35)
    f = 180 * np.exp(-t * 4)
    tone = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * 0.4 * np.exp(-t * 9)
    return normalize(lowpass(tone, 0.25), 0.7)


def sfx_grow():
    t = t_axis(0.6)
    f = 90 + 160 * t
    creak = np.sin(2 * np.pi * np.cumsum(f) / SR) * (0.6 + 0.4 * np.sin(2 * np.pi * 23 * t))
    return normalize(creak * env_adsr(len(t), 0.15, 0.1, 0.8, 0.3), 0.45)


def sfx_close():
    t = t_axis(0.8)
    f = 70 - 30 * t
    groan = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.3 * lowpass(rng.standard_normal(len(t)), 0.05)
    return normalize(groan * env_adsr(len(t), 0.05, 0.2, 0.7, 0.4), 0.55)


def sfx_pickup():
    out = np.zeros(int(0.6 * SR))
    for k, n in enumerate((76, 81, 88)):
        place(out, pluck(note(n), 0.5, 0.8) * 0.5, k * 0.07)
    return normalize(out, 0.6)


def sfx_ui():
    t = t_axis(0.06)
    return normalize(np.sin(2 * np.pi * 880 * t) * np.exp(-t * 60), 0.4)


def sfx_bite():
    t = t_axis(0.3)
    snap = rng.standard_normal(len(t)) * np.exp(-t * 40)
    low = np.sin(2 * np.pi * 90 * t) * np.exp(-t * 12)
    return normalize(lowpass(snap, 0.4) * 0.6 + low, 0.7)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    save("music_day.wav", music_day())
    save("music_night.wav", music_night())
    save("music_final.wav", music_final())
    for name, fn in [("sfx_cut", sfx_cut), ("sfx_hit", sfx_hit), ("sfx_hurt", sfx_hurt),
                     ("sfx_grow", sfx_grow), ("sfx_close", sfx_close), ("sfx_pickup", sfx_pickup),
                     ("sfx_ui", sfx_ui), ("sfx_bite", sfx_bite)]:
        save(name + ".wav", fn())
