"""Música, efectos y ambientes procedurales (CC0, generados aquí) para Ira del Olimpo.
Uso: python3 gen_audio.py <carpeta_salida>
"""
import numpy as np, os, sys, subprocess
from scipy import signal

SR = 44100
OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
TMP = "/tmp/ira_audio"
os.makedirs(TMP, exist_ok=True)

def mtof(m):
    return 440.0 * 2 ** ((m - 69) / 12)

def env_adsr(n, a, d, s, r, sr=SR):
    a, d, r = int(a * sr), int(d * sr), int(r * sr)
    e = np.ones(n) * s
    a = min(a, n)
    e[:a] = np.linspace(0, 1, a, endpoint=False) if a else e[:a]
    d2 = min(d, n - a)
    if d2 > 0:
        e[a:a + d2] = np.linspace(1, s, d2, endpoint=False)
    if r > 0:
        r2 = min(r, n)
        e[n - r2:] *= np.linspace(1, 0, r2)
    return e

def lp(x, fc, order=2):
    b, a = signal.butter(order, min(fc, SR * 0.45) / (SR / 2), "low")
    return signal.lfilter(b, a, x)

def hp(x, fc, order=2):
    b, a = signal.butter(order, fc / (SR / 2), "high")
    return signal.lfilter(b, a, x)

def bp(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), min(hi, SR * 0.45) / (SR / 2)], "band")
    return signal.lfilter(b, a, x)

rng = np.random.default_rng(3)

def saw(f, n, ph=0.0):
    t = np.arange(n) / SR
    return 2 * ((f * t + ph) % 1.0) - 1

# ---------------- instrumentos ----------------
def pluck(f, dur, bright=0.5, decay=0.996):
    n = int(dur * SR)
    N = max(2, int(round(SR / f)))
    x = np.zeros(n)
    burst = rng.uniform(-1, 1, N)
    burst = lp(burst, 1500 + bright * 6000)
    x[:N] = burst
    a = np.zeros(N + 2)
    a[0] = 1
    a[N] = -0.5 * decay
    a[N + 1] = -0.5 * decay
    y = signal.lfilter([1], a, x)
    y *= env_adsr(n, 0.002, 0.0, 1.0, min(0.05, dur * 0.3))
    return y / (np.max(np.abs(y)) + 1e-9)

def supersaw(f, dur, cutoff=2500, a=0.08, r=0.3, voices=5, det=0.006):
    n = int(dur * SR)
    y = sum(saw(f * (1 + det * (i - voices // 2) / (voices // 2 or 1)), n, rng.random()) for i in range(voices)) / voices
    y = lp(y, cutoff, 2)
    return y * env_adsr(n, a, 0.1, 0.85, r)

def spicc(f, dur):
    n = int(dur * SR)
    y = (saw(f, n) + saw(f * 1.004, n, 0.3) + saw(f * 0.996, n, 0.6)) / 3
    y = lp(y, 2200, 2)
    return y * env_adsr(n, 0.005, 0.06, 0.35, min(0.06, dur * 0.4))

def brass(f, dur, a=0.04):
    n = int(dur * SR)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.2 * np.arange(n) / SR) * np.clip(np.arange(n) / SR - 0.2, 0, 1)
    ph = np.cumsum(f * vib) / SR
    y = 2 * (ph % 1.0) - 1 + 0.5 * (2 * ((ph * 1.003 + 0.2) % 1.0) - 1)
    dark = lp(y, 700, 2)
    bright = lp(y, 3200, 2)
    e = env_adsr(n, a, 0.15, 0.7, 0.12)
    fe = np.clip(env_adsr(n, a * 1.5, 0.35, 0.35, 0.1), 0, 1)
    return (dark * (1 - fe) + bright * fe) * e

def choir(f, dur, vowel="a"):
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    forms = {"a": [(700, 1), (1150, 0.5), (2700, 0.25)], "o": [(450, 1), (800, 0.5), (2800, 0.15)], "u": [(350, 1), (700, 0.35), (2500, 0.1)]}[vowel]
    for k in range(3):
        vib = 1 + 0.006 * np.sin(2 * np.pi * (5.0 + k * 0.4) * t + k)
        ph = np.cumsum(f * (1 + (k - 1) * 0.004) * vib) / SR
        src = 2 * (ph % 1.0) - 1
        for fc, g in forms:
            out += bp(src, fc * 0.85, fc * 1.15) * g
    return out / 3 * env_adsr(n, 0.25, 0.2, 0.9, 0.4)

def bass(f, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    y = lp(saw(f, n), 380, 2) * 0.8 + np.sin(2 * np.pi * f * t) * 0.6
    return y * env_adsr(n, 0.005, 0.1, 0.8, 0.05)

def taiko(dur=0.9, f0=95, f1=48, gain=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = f1 + (f0 - f1) * np.exp(-t * 18)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 5.5)
    hit = lp(rng.uniform(-1, 1, n), 1800) * np.exp(-t * 45) * 0.6
    return (body + hit) * gain

def tom(f0=160):
    return taiko(0.45, f0, f0 * 0.6, 0.7)

def snare():
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    nz = bp(rng.uniform(-1, 1, n), 900, 7000) * np.exp(-t * 22)
    tone = np.sin(2 * np.pi * 190 * t) * np.exp(-t * 30)
    return nz * 0.9 + tone * 0.5

def frame():
    n = int(0.25 * SR)
    t = np.arange(n) / SR
    return (bp(rng.uniform(-1, 1, n), 400, 2500) * np.exp(-t * 30) + np.sin(2 * np.pi * 120 * t) * np.exp(-t * 25) * 0.6) * 0.8

def hat(open_=False):
    n = int((0.25 if open_ else 0.06) * SR)
    t = np.arange(n) / SR
    return hp(rng.uniform(-1, 1, n), 7000) * np.exp(-t * (14 if open_ else 70)) * 0.35

def cymbal():
    n = int(2.2 * SR)
    t = np.arange(n) / SR
    return hp(rng.uniform(-1, 1, n), 4000) * np.exp(-t * 2.2) * 0.35

def anvil():
    n = int(0.8 * SR)
    t = np.arange(n) / SR
    y = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * d) * g for f, d, g in [(1250, 7, 1), (2730, 9, 0.6), (4105, 12, 0.4), (5420, 15, 0.25)])
    return y * 0.5

# ---------------- secuenciador ----------------
class Song:
    def __init__(self, bpm, bars):
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.bars = bars
        self.n = int(bars * 4 * self.beat * SR)
        self.bus = {}

    def add(self, bus, clip, beat, gain=1.0, pan=0.0):
        if bus not in self.bus:
            self.bus[bus] = np.zeros((2, self.n + SR * 4))
        i = int(beat * self.beat * SR)
        L = len(clip)
        b = self.bus[bus]
        if i >= self.n:
            return
        lg = np.cos((pan + 1) * np.pi / 4)
        rg = np.sin((pan + 1) * np.pi / 4)
        e = min(i + L, b.shape[1])
        b[0, i:e] += clip[: e - i] * gain * lg
        b[1, i:e] += clip[: e - i] * gain * rg

    def mix(self, sends, master=0.9):
        out = np.zeros((2, self.n + SR * 4))
        rev_in = np.zeros_like(out)
        for k, b in self.bus.items():
            out += b
            rev_in += b * sends.get(k, 0.2)
        ir = make_ir(2.4)
        for c in range(2):
            out[c] += signal.fftconvolve(rev_in[c], ir[c])[: out.shape[1]] * 0.35
        # bucle sin cortes: la cola vuelve al principio
        tail = out[:, self.n:]
        res = out[:, : self.n].copy()
        k = min(tail.shape[1], self.n)
        res[:, :k] += tail[:, :k]
        res = hp(res, 30)
        res = np.tanh(res * 1.2) / np.tanh(1.2)
        res *= master / (np.max(np.abs(res)) + 1e-9)
        return res

def make_ir(dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    irs = []
    for c in range(2):
        nz = rng.uniform(-1, 1, n) * np.exp(-t * 3.0)
        nz = lp(nz, 5000)
        nz[: int(0.012 * SR)] *= np.linspace(0, 1, int(0.012 * SR))
        irs.append(nz / np.sqrt(np.sum(nz ** 2)) * 6)
    return np.array(irs)

def save(name, x, q=4):
    import wave
    x = np.atleast_2d(x)
    if x.shape[0] > x.shape[1]:
        x = x.T
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    wp = os.path.join(TMP, name + ".wav")
    with wave.open(wp, "wb") as w:
        w.setnchannels(pcm.shape[0])
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.T.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wp, "-c:a", "libvorbis", "-q:a", str(q), os.path.join(OUT, name + ".ogg")], check=True)

# ---------------- composición ----------------
SCALES = {"aeolian": [0, 2, 3, 5, 7, 8, 10], "phrygian": [0, 1, 3, 5, 7, 8, 10], "harm": [0, 2, 3, 5, 7, 8, 11], "mixo": [0, 2, 4, 5, 7, 9, 10], "dorian": [0, 2, 3, 5, 7, 9, 10]}

def chord(root, kind):
    return [root, root + (3 if kind == "m" else 4), root + 7]

def compose(name, bpm, key, scale, prog, style, bars=32, seed=1):
    global rng
    rng = np.random.default_rng(seed)
    S = Song(bpm, bars)
    sc = SCALES[scale]
    for bar in range(bars):
        ci = (bar // 2) % len(prog)
        deg, kind = prog[ci]
        root = key + deg
        ch = chord(root, kind)
        sec_b = bar >= bars // 2
        b0 = bar * 4
        # ---- percusión ----
        if style != "menu":
            pat = [0, 1.5, 2, 3, 3.5] if style in ("battle", "boss", "hero") else [0, 2.5, 3]
            for p in pat:
                S.add("drums", taiko(gain=1.0 if p in (0, 2) else 0.7), b0 + p, 0.9)
            for p in ([1, 3] if style != "dark" else [2]):
                S.add("drums", snare() if style in ("boss", "hero") else frame(), b0 + p, 0.55, 0.1)
            if style in ("battle", "boss", "hero") or sec_b:
                for k in range(8 if style != "boss" else 16):
                    st = 0.5 if style != "boss" else 0.25
                    S.add("perc", hat(k % 4 == 2), b0 + k * st, 0.6 if k % 2 == 0 else 0.4, 0.4)
            if sec_b and bar % 4 == 3:
                for k, p in enumerate([2, 2.5, 3, 3.25, 3.5, 3.75]):
                    S.add("drums", tom(200 - k * 15), b0 + p, 0.6, -0.3 + k * 0.12)
            if bar % 8 == 0 and bar > 0:
                S.add("perc", cymbal(), b0, 0.6, 0.2)
            if style == "boss" and bar % 2 == 1:
                S.add("perc", anvil(), b0 + 2, 0.25, -0.4)
        else:
            if bar % 2 == 0:
                S.add("drums", taiko(1.2, 80, 45, 0.6), b0, 0.6)
        # ---- bajo ----
        if style != "menu":
            for k in range(8):
                S.add("bass", bass(mtof(root - 24 + (7 if k in (3, 7) and style != "dark" else 0)), S.beat * 0.45), b0 + k * 0.5, 0.55)
        else:
            S.add("bass", bass(mtof(root - 24), S.beat * 3.8), b0, 0.4)
        # ---- ostinato de cuerdas ----
        if style != "menu":
            osti = [0, 7, 12, 7, 3 if kind == "m" else 4, 7, 12, 15 if kind == "m" else 16] if style != "dark" else [0, 0, 7, 0, 1, 0, 7, 3]
            step = 0.5 if style != "boss" else 0.25
            for k in range(int(4 / step)):
                note = root - 12 + osti[k % len(osti)]
                S.add("strings", spicc(mtof(note), S.beat * step * 0.9), b0 + k * step, 0.32 if style != "boss" else 0.26, -0.35 if k % 2 else 0.35)
        # ---- colchón ----
        if bar % 2 == 0:
            for i, nt in enumerate(ch):
                S.add("pad", supersaw(mtof(nt), S.beat * 8, 1800 if style != "dark" else 1100, a=0.4, r=0.8), b0, 0.12, (i - 1) * 0.5)
            if style in ("dark", "menu") or (sec_b and style != "battle"):
                S.add("choir", choir(mtof(ch[0]), S.beat * 8, "o" if style == "dark" else "a"), b0, 0.16, -0.3)
                S.add("choir", choir(mtof(ch[2]), S.beat * 8, "o" if style == "dark" else "a"), b0, 0.13, 0.3)
        # ---- lira / arpegio ----
        if style in ("battle", "menu", "hero") and (not sec_b or style == "menu"):
            arp = [ch[0], ch[1], ch[2], ch[1] + 12, ch[2], ch[1], ch[0] + 12, ch[2]]
            for k in range(8):
                S.add("lyre", pluck(mtof(arp[k] + 12), 1.2, 0.6) , b0 + k * 0.5, 0.35, 0.3 - k * 0.08)
        # ---- melodía de metales (sección B) ----
        if sec_b and style != "menu":
            mel_rng = np.random.default_rng(seed * 100 + (bar % 8))
            pos = 0.0
            while pos < 4:
                dur = mel_rng.choice([1, 1, 0.5, 2, 1.5]) if style != "boss" else mel_rng.choice([0.5, 1, 0.5])
                tones = [ch[0] + 12, ch[1] + 12, ch[2] + 12, ch[0] + 24]
                nt = tones[mel_rng.integers(0, len(tones))]
                if mel_rng.random() < 0.25:
                    nt = key + 12 + sc[mel_rng.integers(0, 7)]
                S.add("brass", brass(mtof(nt), dur * S.beat), b0 + pos, 0.3, 0.05)
                pos += dur
        if style == "dark" and bar % 4 == 0:
            S.add("pad", supersaw(mtof(key - 24), S.beat * 16, 400, a=1.0, r=1.0, voices=3), b0, 0.25)
    mix = S.mix({"drums": 0.12, "perc": 0.15, "bass": 0.02, "strings": 0.25, "pad": 0.5, "choir": 0.7, "lyre": 0.4, "brass": 0.35}, 0.85)
    save("mus_" + name, mix, 4)
    print("música", name, round(S.n / SR, 1), "s")

def stinger(name, key, major, up=True):
    global rng
    rng = np.random.default_rng(9)
    S = Song(100, 2)
    third = 4 if major else 3
    notes = [key, key + third, key + 7, key + 12] if up else [key + 12, key + 7, key + third, key]
    for i, n in enumerate(notes):
        S.add("brass", brass(mtof(n), 0.25 if i < 3 else 2.4), i * 0.33, 0.4)
        S.add("pad", supersaw(mtof(n - 12), 2.5, 1600, a=0.05, r=1.0), 1.0, 0.15)
    S.add("drums", taiko(1.6, 90, 40, 1.0), 0, 1.0)
    S.add("drums", taiko(1.6, 90, 40, 1.0), 1.0, 1.0)
    S.add("perc", cymbal(), 1.0, 0.7)
    mix = S.mix({"brass": 0.4, "pad": 0.5, "drums": 0.2, "perc": 0.3}, 0.8)
    save("mus_" + name, mix[:, : int(4.5 * SR)], 4)

# ---------------- efectos ----------------
def nz(n):
    return rng.uniform(-1, 1, n)

def fx_whoosh(i):
    n = int(0.32 * SR)
    t = np.arange(n) / SR
    x = nz(n)
    out = np.zeros(n)
    seg = 64
    for k in range(0, n, seg):
        fc = 500 + 3500 * np.sin(np.pi * k / n) ** 2 * (0.8 + i * 0.15)
        out[k:k + seg] = 1
    # filtro barrido aproximado con dos bandas mezcladas
    lo = bp(x, 300, 1200)
    hi = bp(x, 1500, 5000 + i * 800)
    m = np.sin(np.pi * t / t[-1]) ** 2
    y = (lo * (1 - m) + hi * m) * np.sin(np.pi * t / t[-1]) ** 1.5
    return y / np.max(np.abs(y)) * 0.7

def fx_hit(i):
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    thump = np.sin(2 * np.pi * (90 + i * 15) * t * (1 - t)) * np.exp(-t * 18)
    crunch = bp(nz(n), 600, 3500) * np.exp(-t * 35)
    slice_ = bp(nz(n), 3000, 9000) * np.exp(-t * 60) * 0.5
    y = thump * 0.9 + crunch * 0.8 + slice_
    return y / np.max(np.abs(y)) * 0.9

def fx_clang(base, damp):
    n = int(1.0 * SR)
    t = np.arange(n) / SR
    parts = [(1.0, 1.0), (2.76, 0.6), (5.4, 0.4), (8.93, 0.25), (13.3, 0.15)]
    y = sum(np.sin(2 * np.pi * base * r * t + rng.random() * 6) * np.exp(-t * damp * (1 + r * 0.3)) * g for r, g in parts)
    y += bp(nz(n), 2000, 8000) * np.exp(-t * 80) * 0.6
    return y / np.max(np.abs(y)) * 0.85

def fx_parry():
    a = fx_clang(980, 4)
    n = len(a)
    t = np.arange(n) / SR
    shimmer = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * 3) for f in (2093, 2637, 3136)) * 0.15
    y = a + shimmer
    return y / np.max(np.abs(y)) * 0.9

def fx_boom(dur=1.6, f0=70):
    n = int(dur * SR)
    t = np.arange(n) / SR
    body = np.sin(2 * np.pi * np.cumsum(f0 * 0.5 + f0 * np.exp(-t * 6)) / SR) * np.exp(-t * 3)
    rumble = lp(nz(n), 250) * np.exp(-t * 2.5) * 1.5
    crack = bp(nz(n), 800, 4000) * np.exp(-t * 25) * 0.5
    y = body + rumble + crack
    return y / np.max(np.abs(y)) * 0.95

def fx_roar(dur=1.8, f=70, rough=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    pitch = f * (1 + 0.25 * np.sin(np.pi * t / dur)) * (1 + 0.03 * np.sin(2 * np.pi * 23 * t) * rough)
    ph = np.cumsum(pitch) / SR
    src = (2 * (ph % 1) - 1) + lp(nz(n), 1500) * 0.8 * rough
    y = bp(src, 200, 600) * 1.0 + bp(src, 700, 1300) * 0.7 + bp(src, 2200, 3200) * 0.25
    e = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 0.6
    y = y * e * (1 + 0.4 * np.sin(2 * np.pi * 11 * t))
    return y / np.max(np.abs(y)) * 0.9

def fx_bite():
    n = int(0.25 * SR)
    t = np.arange(n) / SR
    y = bp(nz(n), 1500, 6000) * np.exp(-t * 60) + np.sin(2 * np.pi * 150 * t) * np.exp(-t * 40) * 0.8
    return y / np.max(np.abs(y)) * 0.9

def fx_fire(dur=2.2):
    n = int(dur * SR)
    t = np.arange(n) / SR
    roar = lp(nz(n), 900) * 1.2 + bp(nz(n), 1000, 4000) * 0.4
    crackle = np.zeros(n)
    for k in rng.integers(0, n - 2000, 120):
        crackle[k:k + 400] += bp(nz(400), 2000, 8000) * np.exp(-np.arange(400) / 60) * rng.uniform(0.3, 1)
    e = np.clip(t / 0.15, 0, 1) * np.clip((dur - t) / 0.3, 0, 1)
    y = (roar + crackle * 0.6) * e
    return y / np.max(np.abs(y)) * 0.8

def fx_warn():
    n = int(0.7 * SR)
    y = brass(mtof(38), 0.7, 0.03) + brass(mtof(45), 0.7, 0.03) * 0.6
    return y / np.max(np.abs(y)) * 0.6

def fx_rise():
    n = int(1.0 * SR)
    t = np.arange(n) / SR
    y = lp(nz(n), 300) * np.sin(np.pi * t) * 1.4 + bp(nz(n), 1000, 3000) * np.exp(-t * 4) * 0.2
    return y / np.max(np.abs(y)) * 0.7

def fx_roll():
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    y = bp(nz(n), 300, 2500) * np.sin(np.pi * t / t[-1]) * 0.6
    y += np.sin(2 * np.pi * 70 * t) * np.exp(-((t - 0.3) * 30) ** 2) * 0.8
    return y / np.max(np.abs(y)) * 0.6

def fx_hurt():
    n = int(0.4 * SR)
    t = np.arange(n) / SR
    y = np.sin(2 * np.pi * 80 * t) * np.exp(-t * 14) + bp(nz(n), 400, 2000) * np.exp(-t * 25) * 0.6
    return y / np.max(np.abs(y)) * 0.9

def fx_click():
    n = int(0.08 * SR)
    t = np.arange(n) / SR
    y = np.sin(2 * np.pi * 1400 * t) * np.exp(-t * 60) + np.sin(2 * np.pi * 700 * t) * np.exp(-t * 40) * 0.5
    return y * 0.5

def fx_ira():
    a = fx_whoosh(3)
    b = fx_boom(1.8, 60)
    c = fx_fire(1.6)
    n = len(b)
    y = np.zeros(n)
    y[: len(a)] += a * 0.8
    off = int(0.4 * SR)
    y[off:] += b[: n - off]
    y[off:off + len(c)] += c[: n - off] * 0.6
    return y / np.max(np.abs(y)) * 0.95

def fx_death():
    n = int(0.6 * SR)
    t = np.arange(n) / SR
    y = np.sin(2 * np.pi * 60 * t) * np.exp(-t * 10) + lp(nz(n), 600) * np.exp(-t * 12) * 0.8
    return y / np.max(np.abs(y)) * 0.7

# ---------------- ambientes ----------------
def amb(name, dur=24.0):
    global rng
    rng = np.random.default_rng(len(name))
    n = int(dur * SR)
    t = np.arange(n) / SR
    L = np.zeros(n)
    R = np.zeros(n)
    def wind(lo, hi, g, rate):
        m = 0.55 + 0.45 * np.sin(2 * np.pi * rate * t + rng.random() * 6) * np.sin(2 * np.pi * rate * 0.37 * t + 1)
        return bp(nz(n), lo, hi) * m * g
    if name == "tebas":
        L += wind(200, 900, 0.5, 0.11); R += wind(200, 900, 0.5, 0.13)
        for k in range(8):  # olas
            c = k * dur / 8 + rng.uniform(0, 1.5)
            w = np.exp(-((t - c) / 1.1) ** 2)
            wv = lp(nz(n), 700) * w * 0.9
            L += wv * (0.6 + 0.4 * (k % 2)); R += wv * (1.0 - 0.4 * (k % 2))
    elif name == "laberinto":
        tone = lp(nz(n), 120) * 0.8
        L += tone; R += tone
        for k in rng.integers(0, n - 4000, 90):  # chisporroteo de antorchas
            s = bp(nz(300), 2000, 7000) * np.exp(-np.arange(300) / 40) * rng.uniform(0.1, 0.4)
            (L if rng.random() < 0.5 else R)[k:k + 300] += s
        for k in rng.integers(0, n - 20000, 7):  # gotas
            d = np.sin(2 * np.pi * (1800 - np.arange(6000) * 0.15) * np.arange(6000) / SR) * np.exp(-np.arange(6000) / 900) * 0.25
            L[k:k + 6000] += d * 0.7; R[k:k + 6000] += d
    elif name == "inframundo":
        drone = np.sin(2 * np.pi * 41 * t) * 0.3 + np.sin(2 * np.pi * 61.5 * t + 1) * 0.15
        L += drone + wind(150, 500, 0.4, 0.07); R += drone + wind(150, 500, 0.4, 0.09)
        for k in range(10):  # susurros
            c = rng.uniform(1, dur - 1)
            w = np.exp(-((t - c) / 0.6) ** 2)
            s = bp(nz(n), 1800, 3800) * w * 0.25 * (1 + np.sin(2 * np.pi * 7 * t))
            (L if k % 2 else R)[:] += s
        for k in rng.integers(0, n - 8000, 40):  # burbujas del Estigia
            f = rng.uniform(200, 500)
            b = np.sin(2 * np.pi * f * (1 + np.arange(3000) / 3000) * np.arange(3000) / SR) * np.exp(-np.arange(3000) / 600) * 0.15
            L[k:k + 3000] += b; R[k:k + 3000] += b * 0.8
    elif name == "olimpo":
        L += wind(800, 3000, 0.25, 0.15); R += wind(800, 3000, 0.25, 0.17)
        L += wind(150, 500, 0.3, 0.05); R += wind(150, 500, 0.3, 0.06)
        for k in range(12):  # destellos
            c = int(rng.uniform(0, dur - 3) * SR)
            f = mtof(rng.choice([79, 83, 86, 91, 95]))
            s = np.sin(2 * np.pi * f * np.arange(SR * 3) / SR) * np.exp(-np.arange(SR * 3) / (SR * 0.7)) * 0.06
            L[c:c + SR * 3] += s; R[c:c + SR * 3] += s * 0.7
    # fundido circular para bucle
    xf = SR
    st = np.array([L, R])
    st[:, :xf] = st[:, :xf] * np.linspace(0, 1, xf) + st[:, -xf:] * np.linspace(1, 0, xf)
    st = st[:, :-xf]
    st = st / np.max(np.abs(st)) * 0.7
    save("amb_" + name, st, 2)

if __name__ == "__main__":
    what = sys.argv[2] if len(sys.argv) > 2 else "all"
    if what in ("all", "sfx"):
        for i in range(3):
            save("whoosh%d" % i, fx_whoosh(i), 4)
            save("hit%d" % i, fx_hit(i), 4)
        save("clang0", fx_clang(620, 6), 4)
        save("clang1", fx_clang(540, 8), 4)
        save("parry", fx_parry(), 4)
        save("guard_break", fx_clang(380, 3), 4)
        save("boom", fx_boom(), 4)
        save("roar", fx_roar(), 4)
        save("growl", fx_roar(1.2, 55, 1.6), 4)
        save("bite", fx_bite(), 4)
        save("fire", fx_fire(), 4)
        save("warn", fx_warn(), 4)
        save("rise", fx_rise(), 4)
        save("roll", fx_roll(), 4)
        save("hurt", fx_hurt(), 4)
        save("click", fx_click(), 4)
        save("ira", fx_ira(), 4)
        save("death", fx_death(), 4)
        print("efectos ok")
    if what in ("all", "amb"):
        for a in ["tebas", "laberinto", "inframundo", "olimpo"]:
            amb(a)
        print("ambientes ok")
    if what in ("all", "music"):
        compose("menu", 84, 50, "aeolian", [(0, "m"), (-4, "M"), (-2, "M"), (0, "m")], "menu", 16, 11)
        compose("tebas", 140, 50, "aeolian", [(0, "m"), (-4, "M"), (-2, "M"), (0, "m")], "battle", 32, 1)
        compose("laberinto", 132, 52, "phrygian", [(0, "m"), (1, "M"), (0, "m"), (-2, "m")], "battle", 32, 2)
        compose("inframundo", 120, 48, "harm", [(0, "m"), (-4, "M"), (-7, "m"), (-5, "M")], "dark", 32, 3)
        compose("olimpo", 146, 55, "mixo", [(0, "M"), (-2, "M"), (-7, "M"), (0, "M")], "hero", 32, 4)
        compose("jefe", 156, 45, "harm", [(0, "m"), (-4, "M"), (-2, "M"), (-5, "M")], "boss", 32, 5)
        stinger("victoria", 50, True, True)
        stinger("derrota", 45, False, False)
