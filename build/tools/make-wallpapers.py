#!/usr/bin/env python3
"""Generate Kora 4K wallpapers: soft color fields + flowing translucent waves + fine grain."""
import sys, os, numpy as np
from PIL import Image, ImageFilter
OUT = sys.argv[1] if len(sys.argv) > 1 else 'wallpapers'; os.makedirs(OUT, exist_ok=True)
W, H = 1920, 1080
T = {  # name: (bg top, bg bottom, [blob colors], wave color, wave alpha)
 'night':   ((18,16,40),(6,6,14),   [(124,92,255),(34,211,238),(70,40,160)], (180,170,255), .10),
 'ocean':   ((6,40,72),(2,10,24),   [(0,140,220),(0,200,190),(30,60,160)],   (150,220,255), .10),
 'forest':  ((14,48,36),(4,14,10),  [(40,170,110),(160,200,80),(10,90,90)],  (170,240,200), .09),
 'sunset':  ((70,24,60),(16,8,24),  [(255,110,90),(250,170,80),(150,50,140)],(255,200,170), .10),
 'graphite':((44,46,52),(12,13,16), [(96,100,112),(70,74,84),(110,116,130)],  (210,215,225), .10),
 'day':     ((240,242,250),(206,214,236),[(150,170,255),(120,220,235),(255,190,210)],(255,255,255), .35),
 'dawn':    ((252,240,232),(236,214,220),[(255,180,150),(255,214,160),(210,170,240)],(255,255,255),.35),
 'mist':    ((232,242,246),(200,222,232),[(130,200,230),(170,230,210),(160,180,240)],(255,255,255),.35),
}
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
rng = np.random.default_rng(7)
for name, (top, bot, blobs, wc, wa) in T.items():
    t = (yy / H)[..., None]
    img = np.array(top, np.float32) * (1 - t) + np.array(bot, np.float32) * t
    for i, c in enumerate(blobs):
        cx, cy = rng.uniform(.15, .85) * W, rng.uniform(.2, .8) * H
        r = rng.uniform(.28, .45) * W
        m = np.exp(-(((xx - cx) ** 2 + ((yy - cy) * 1.4) ** 2) / (2 * r * r)))[..., None] * (.75 if top[0]>150 else .5)
        img = img * (1 - m) + np.array(c, np.float32) * m
    for k in range(4):  # layered translucent dunes
        ph, amp, fr = rng.uniform(0, 6.28), rng.uniform(.05, .10) * H, rng.uniform(.6, 1.3)
        base = (.52 + .12 * k) * H
        curve = base + amp * np.sin(xx / W * 6.28 * fr + ph) + .35 * amp * np.sin(xx / W * 6.28 * fr * 2.1 + ph * 1.3)
        below = np.clip((yy - curve) / (.02 * H), 0, 1)
        shade = np.array(bot if top[0] < 150 else wc, np.float32) * (.55 if top[0] < 150 else 1)
        a = below[..., None] * (.18 + .06 * k) * (1 if top[0] < 150 else 1.2)
        img = img * (1 - a) + shade * a
        edge = np.exp(-((yy - curve) / (.004 * H)) ** 2)[..., None] * wa * .9
        img = img * (1 - edge) + np.array(wc, np.float32) * edge
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6))
    im = im.resize((3840, 2160), Image.LANCZOS)
    a = np.asarray(im).astype(np.int16) + rng.normal(0, 2.2, (2160, 3840, 1)).astype(np.int16)
    Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).save(f'{OUT}/{name}.jpg', quality=92, optimize=True)
    print(name)
