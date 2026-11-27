"""Piel final: color horneado + barba incipiente + cejas + variación de tono."""
import sys, numpy as np
from PIL import Image, ImageFilter
pref, out = sys.argv[1], sys.argv[2]
tone = [float(x) for x in sys.argv[3].split(",")] if len(sys.argv) > 3 else [1, 1, 1]
c = np.asarray(Image.open(pref + "_skin_c.png").convert("RGB")).astype(float) / 255
m = np.asarray(Image.open(pref + "_mask.png").convert("RGB").filter(ImageFilter.GaussianBlur(3))).astype(float) / 255
H, W = c.shape[:2]
rng = np.random.default_rng(5)
n = rng.random((H, W))
stub = Image.fromarray((n * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.7))
st = np.asarray(stub).astype(float) / 255
bs = float(sys.argv[4]) if len(sys.argv) > 4 else 0.55
bm_ = (1.0 + bs) if len(sys.argv) > 4 else 1.0
beard = np.clip(m[..., 0] * bm_, 0, 1) * (0.55 + 0.45 * st)
brow = np.clip(m[..., 1] * 1.6, 0, 1) * (0.6 + 0.4 * st)
c = c * np.array(tone)
c = c * (1 - bs * beard[..., None]) + np.array([0.12, 0.09, 0.08]) * bs * beard[..., None]
c = c * (1 - 0.85 * brow[..., None]) + np.array([0.09, 0.06, 0.04]) * 0.85 * brow[..., None]
low = np.asarray(Image.fromarray((rng.random((H // 32, W // 32)) * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC)).astype(float) / 255
c = c * (0.94 + 0.12 * low[..., None])
Image.fromarray((np.clip(c, 0, 1) * 255).astype(np.uint8)).save(out, quality=92)
print("piel", out)
