# Grietas de barro sobre la piel de los espartos (nacidos de dientes de dragón sembrados)
import numpy as np, sys
from PIL import Image, ImageFilter
src, dst = sys.argv[1], sys.argv[2]
im = np.asarray(Image.open(src).convert("RGB")).astype(np.float32) / 255.0
H, W = im.shape[:2]
rng = np.random.default_rng(7)
def voronoi_edges(n, w):
    pts = rng.random((n, 2)) * [W, H]
    yy, xx = np.mgrid[0:H, 0:W]
    d1 = np.full((H, W), 1e9, np.float32); d2 = np.full((H, W), 1e9, np.float32)
    for p in pts:
        d = np.hypot(xx - p[0], yy - p[1]).astype(np.float32)
        m = d < d1
        d2 = np.where(m, d1, np.minimum(d2, d))
        d1 = np.where(m, d, d1)
    e = np.clip(1.0 - (d2 - d1) / w, 0, 1)
    return e
small = Image.fromarray((im * 255).astype(np.uint8)).resize((W // 2, H // 2))
W2, H2 = small.size
W, H = W2, H2
e1 = voronoi_edges(260, 3.0)
e2 = voronoi_edges(900, 1.6) * 0.6
W, H = im.shape[1], im.shape[0]
e = np.maximum(e1, e2)
e = np.asarray(Image.fromarray((e * 255).astype(np.uint8)).resize((W, H), Image.BILINEAR).filter(ImageFilter.GaussianBlur(0.8))).astype(np.float32) / 255.0
# manchas de tierra
n = np.asarray(Image.fromarray((rng.random((H // 32, W // 32)) * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC)).astype(np.float32) / 255.0
earth = np.array([0.42, 0.36, 0.29])
out = im * (1 - 0.35 * n[..., None]) + earth * 0.35 * n[..., None]
out = out * (1 - 0.75 * e[..., None]) + np.array([0.12, 0.09, 0.07]) * 0.75 * e[..., None]
Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8)).save(dst, quality=90)
print("grietas", dst)
