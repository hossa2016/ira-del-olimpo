"""Texturas procedurales (CC0, generadas aquí) para Ira del Olimpo."""
import numpy as np
from PIL import Image, ImageFilter
import sys, os
OUT = sys.argv[1]
rng = np.random.default_rng(7)
N = 1024

def pnoise(n, beta, seed):
    """Ruido periódico (tileable) por espectro 1/f^beta."""
    r = np.random.default_rng(seed)
    f = np.fft.fftfreq(n)
    fx, fy = np.meshgrid(f, f)
    k = np.sqrt(fx**2 + fy**2); k[0, 0] = 1
    spec = (r.normal(size=(n, n)) + 1j * r.normal(size=(n, n))) / k**beta
    spec[0, 0] = 0
    z = np.real(np.fft.ifft2(spec))
    return (z - z.mean()) / z.std()

def normal_from_h(h, strength):
    gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    nz = np.ones_like(h)
    l = np.sqrt(gx**2 + gy**2 + 1)
    n = np.stack([-gx / l, gy / l, nz / l], -1)
    return Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8))

def save(a, name, q=90):
    Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).save(os.path.join(OUT, name), quality=q)

def split_rects(x0, y0, x1, y1, minw, out, depth=0):
    w, h = x1 - x0, y1 - y0
    if (w < minw * 2 and h < minw * 2) or (depth > 2 and rng.random() < 0.28 and w < minw * 3.5 and h < minw * 3.5):
        out.append((x0, y0, x1, y1)); return
    if w >= h and w >= minw * 2:
        c = int(x0 + w * rng.uniform(0.33, 0.67))
        split_rects(x0, y0, c, y1, minw, out, depth + 1); split_rects(c, y0, x1, y1, minw, out, depth + 1)
    elif h >= minw * 2:
        c = int(y0 + h * rng.uniform(0.33, 0.67))
        split_rects(x0, y0, x1, c, minw, out, depth + 1); split_rects(x0, c, x1, y1, minw, out, depth + 1)
    else:
        out.append((x0, y0, x1, y1))

def slabs(rects, grout, bevel, base_rgb, var, seed, stain=0.35):
    yy, xx = np.mgrid[0:N, 0:N]
    d = np.full((N, N), 999.0)
    tone = np.zeros((N, N, 3))
    tilt = np.zeros((N, N))
    r2 = np.random.default_rng(seed)
    for (x0, y0, x1, y1) in rects:
        m = (xx >= x0) & (xx < x1) & (yy >= y0) & (yy < y1)
        dd = np.minimum.reduce([xx - x0, x1 - 1 - xx, yy - y0, y1 - 1 - yy]).astype(float)
        d[m] = dd[m]
        t = np.array(base_rgb) * (1 + r2.normal(0, var, 3) * 0.12 + r2.normal(0, var))
        tone[m] = t
        tilt[m] = r2.normal(0, 0.6) * (xx[m] - (x0 + x1) / 2) / N + r2.normal(0, 0.6) * (yy[m] - (y0 + y1) / 2) / N
    n1 = pnoise(N, 1.6, seed + 1); n2 = pnoise(N, 0.9, seed + 2); n3 = pnoise(N, 2.2, seed + 3)
    edge_wobble = n2 * 1.2
    dw = d + edge_wobble
    g = np.clip((dw - grout / 2) / 1.5, 0, 1)            # 0 junta, 1 losa
    b = np.clip((dw - grout / 2) / bevel, 0, 1) ** 0.6    # bisel desgastado
    chips = (n2 > 1.9) & (dw < bevel * 2.5)
    b[chips] *= 0.4
    col = tone * (1 + n1[..., None] * 0.07 + n3[..., None] * 0.035)
    col *= (1 - stain * np.clip(n3 * 0.5 + 0.2, 0, 1))[..., None] * 0 + 1
    dirt = np.clip(1 - dw / (bevel * 3), 0, 1)
    col *= (1 - 0.25 * dirt)[..., None]
    groutc = np.array(base_rgb) * 0.6
    col = col * g[..., None] + groutc * (1 - g[..., None])
    h = b * 1.0 + n1 * 0.04 + n2 * 0.015 + tilt * 3
    rough = 0.72 + 0.12 * n1 - 0.1 * (b > 0.98) + 0.2 * (1 - g)
    return col, h, rough

def gen_floor():
    rects = []
    for (x0, y0, x1, y1) in [(0, 0, 512, 512), (512, 0, 1024, 512), (0, 512, 512, 1024), (512, 512, 1024, 1024)]:
        split_rects(x0, y0, x1, y1, 110, rects)
    col, h, rough = slabs(rects, 2.5, 6.0, (150, 128, 101), 0.06, 11)
    save(col, "floor_c.jpg")
    normal_from_h(h, 2.2).save(os.path.join(OUT, "floor_n.jpg"), quality=92)
    save(np.repeat((np.clip(rough, 0, 1) * 255)[..., None], 3, -1), "floor_r.jpg")

def gen_stone():
    rects = []
    rows = 8
    rh = N // rows
    for r in range(rows):
        off = rng.integers(40, 200) if r % 2 else 0
        x = -off
        while x < N:
            w = int(rng.uniform(170, 300))
            x1 = min(x + w, N)
            if N - x1 < 90: x1 = N
            rects.append((max(x, 0), r * rh, x1, (r + 1) * rh))
            x = x1
    col, h, rough = slabs(rects, 4.0, 14.0, (128, 112, 92), 0.08, 21)
    save(col, "stone_c.jpg")
    normal_from_h(h, 3.0).save(os.path.join(OUT, "stone_n.jpg"), quality=92)

def gen_rock():
    n1 = pnoise(N, 1.4, 31); n2 = pnoise(N, 2.0, 32); n3 = pnoise(N, 0.8, 33)
    cr = np.abs(pnoise(N, 1.2, 34))
    cracks = np.clip(1 - cr * 6, 0, 1) ** 3
    n4 = pnoise(N, 0.5, 35)
    h = n2 * 0.6 + n1 * 0.25 + n4 * 0.12 - cracks * 0.8
    v = 0.62 + 0.11 * n1 + 0.05 * n4 + 0.06 * n2 - 0.3 * cracks
    col = np.stack([v * 92, v * 86, v * 84], -1)
    save(col, "rock_c.jpg")
    normal_from_h(h, 2.6).save(os.path.join(OUT, "rock_n.jpg"), quality=92)

def gen_fur():
    r = np.random.default_rng(41)
    z = r.normal(size=(N, N))
    img = Image.fromarray(((z * 0.2 + 0.5) * 255).clip(0, 255).astype(np.uint8))
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    a = np.asarray(img).astype(float) / 255
    # trazos alargados en vertical
    k = 25
    acc = np.zeros_like(a)
    for i in range(k):
        acc += np.roll(a, i, 0)
    acc /= k
    acc = (acc - acc.mean()) / acc.std()
    low = pnoise(N, 1.5, 42)
    v = 0.5 + 0.22 * acc + 0.12 * low
    col = np.stack([v * 70, v * 54, v * 44], -1)
    save(col, "fur_c.jpg")
    normal_from_h(acc * 0.5 + low * 0.2, 1.6).save(os.path.join(OUT, "fur_n.jpg"), quality=92)

def gen_pale(src):
    a = np.asarray(Image.open(src).convert("RGB")).astype(float)
    lum = a.mean(-1)
    lum = (lum - lum.mean()) * 1.3 + 150
    m = pnoise(1024, 1.8, 51)[: a.shape[0], : a.shape[1]] if a.shape[0] == 1024 else 0
    veins = np.clip(np.abs(pnoise(1024, 1.1, 52)) * -8 + 1, 0, 1) ** 2 if a.shape[0] == 1024 else 0
    lum = lum * (1 + 0.06 * m) - veins * 35
    col = np.stack([lum * 0.93, lum * 0.97, lum * 0.9], -1)
    col = col * 0.8 + a * np.array([0.2, 0.17, 0.15])
    save(col, "body_p.jpg")

def gen_bronze():
    """Bronce martillado: hoyuelos (normal), manchas de pátina y desgaste (color/rugosidad)."""
    M = 512
    r = np.random.default_rng(61)
    yy, xx = np.mgrid[0:M, 0:M]
    h = np.zeros((M, M))
    for k in range(900):  # golpes de martillo (tileables)
        cx, cy = r.uniform(0, M, 2)
        rad = r.uniform(7, 18)
        dx = (xx - cx + M / 2) % M - M / 2
        dy = (yy - cy + M / 2) % M - M / 2
        d2 = (dx * dx + dy * dy) / (rad * rad)
        h -= np.exp(-d2 * 2.0) * r.uniform(0.4, 1.0)
    def pn(beta, seed):
        rr = np.random.default_rng(seed)
        f = np.fft.fftfreq(M); fx, fy = np.meshgrid(f, f)
        kk = np.sqrt(fx**2 + fy**2); kk[0, 0] = 1
        z = np.real(np.fft.ifft2((rr.normal(size=(M, M)) + 1j * rr.normal(size=(M, M))) / kk**beta))
        return (z - z.mean()) / z.std()
    scratches = np.zeros((M, M))
    for k in range(60):
        x0, y0 = r.uniform(0, M, 2); a = r.uniform(0, np.pi); L = r.uniform(20, 120)
        for t in np.linspace(0, L, int(L)):
            x = int(x0 + np.cos(a) * t) % M; y = int(y0 + np.sin(a) * t) % M
            scratches[y, x] = 1.0
    h = h * 0.8 + pn(2.0, 62) * 0.15 - scratches * 0.6
    normal_from_h(h, 1.4).save(os.path.join(OUT, "bronze_n.jpg"), quality=92)
    blot = pn(1.6, 63)
    patina = np.clip(blot * 0.5 - 0.4, 0, 1)
    v = 0.86 + 0.08 * pn(1.2, 64) + 0.06 * (h - h.mean())
    col = np.stack([v * 230, v * 230, v * 225], -1)  # se tiñe con albedo_color del material
    col = col * (1 - patina[..., None] * 0.55) + np.array([110, 150, 120]) * patina[..., None] * 0.55
    col = col * (1 - scratches[..., None] * 0.0) + scratches[..., None] * 255 * 0.0
    save(col, "bronze_c.jpg")
    rough = np.clip(0.36 + 0.09 * pn(1.4, 65) + patina * 0.3 - scratches * 0.1, 0.22, 0.85)
    save(np.repeat((rough * 255)[..., None], 3, -1), "bronze_r.jpg")

def gen_water():
    M = 512
    def pn(beta, seed):
        rr = np.random.default_rng(seed)
        f = np.fft.fftfreq(M); fx, fy = np.meshgrid(f, f)
        kk = np.sqrt(fx**2 + fy**2); kk[0, 0] = 1
        z = np.real(np.fft.ifft2((rr.normal(size=(M, M)) + 1j * rr.normal(size=(M, M))) / kk**beta))
        return (z - z.mean()) / z.std()
    h = pn(2.2, 71) * 0.7 + pn(1.6, 72) * 0.3
    normal_from_h(h, 3.0).save(os.path.join(OUT, "water_n.jpg"), quality=92)

gen_floor(); gen_stone(); gen_rock(); gen_fur(); gen_bronze(); gen_water()
gen_pale(os.path.join(OUT, "body_c.jpg"))
print("ok")
