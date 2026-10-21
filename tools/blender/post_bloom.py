"""Lueur (bloom) en post-traitement, le compositeur de Blender 5 exigeant un GPU : python tools/blender/post_bloom.py image.jpg [seuil 0.72] [force 0.9] [rayon 14]"""
import sys
import numpy as np
from PIL import Image, ImageFilter
def bloom(path, thr=0.72, k=0.9, radius=14):
    im = Image.open(path).convert("RGB")
    a = np.asarray(im).astype(np.float32) / 255.0
    lum = a.max(axis=2)
    mask = np.clip((lum - thr) / (1 - thr), 0, 1)[..., None]
    bright = Image.fromarray((a * mask * 255).astype(np.uint8))
    glow = np.zeros_like(a)
    for r, w in ((radius, 0.6), (radius * 2.6, 0.4)):
        glow += np.asarray(bright.filter(ImageFilter.GaussianBlur(r))).astype(np.float32) / 255.0 * w
    out = 1 - (1 - a) * (1 - np.clip(glow * k, 0, 1))
    Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8)).save(path, quality=90)
if __name__ == "__main__":
    bloom(sys.argv[1], *[float(x) for x in sys.argv[2:]])
