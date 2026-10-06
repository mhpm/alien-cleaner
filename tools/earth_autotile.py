"""Seamless textures and corner autotiles from the user's Earth tiles (make_earth_assets.py).

The painted tiles on tools/earth_terrain_ref.webp do not join: hard square borders and
visible seams. This turns them into:

  seamless(img)   a texture that repeats without a visible joint (the classic offset-and-
                  blend trick: the middle of the tile, cross-faded with itself shifted by
                  half, at the borders)
  wang(land, other, style)
                  the 16 corner-transition tiles between two textures (Godot terrain,
                  MATCH_CORNERS). Corner k of tile i is `other` when bit k of i is set
                  (TL=1, TR=2, BL=4, BR=8). The border between them follows the bilinear
                  blend of the four corners (rounded corners, exactly halfway along any
                  edge so neighbours always meet) plus a wobble that fades out at the
                  tile's edges, so curves look hand-painted but always connect.
                  Styles add a rim: "water" = wet sand, a dark waterline and foam;
                  "path" = a soft trodden edge; "infested" = a dark creeping fringe.
                  Also returns, per tile, the polygon(s) where the `other` side is solid
                  (water collision that follows the shore).
"""
import cv2
import numpy as np
from PIL import Image

T = 64  # final tile
W = 128  # working size (drawn big, scaled down: smooth edges)


def to_array(img, size=W):
    return np.asarray(img.convert("RGB").resize((size, size), Image.LANCZOS)).astype(np.float32)


def seamless(img, size=W):
    """Tile-able version of `img` (RGB float array, size x size)."""
    a = to_array(img, size)
    n = size
    r = np.roll(np.roll(a, n // 2, 0), n // 2, 1)
    y, x = np.mgrid[0:n, 0:n]
    d = np.minimum(np.minimum(x, n - 1 - x), np.minimum(y, n - 1 - y)) / (n / 2.0)
    w = np.clip(d * 1.7 - 0.1, 0.0, 1.0)[..., None]
    return a * w + r * (1.0 - w)


def inner(img, share=0.12):
    """The middle of a painted tile (drops its ragged border)."""
    w, h = img.size
    return img.crop((int(w * share), int(h * share), int(w * (1 - share)), int(h * (1 - share))))


def _noise(seed, size=W, cells=4):
    """Smooth value noise in [-1, 1]."""
    rnd = np.random.RandomState(seed)
    g = rnd.uniform(-1, 1, (cells + 1, cells + 1)).astype(np.float32)
    return cv2.resize(g, (size, size), interpolation=cv2.INTER_CUBIC)


def _field(i, seed):
    """0 = land .. 1 = other, for tile i (corner bits), border at 0.5."""
    tl, tr, bl, br = (i & 1), (i >> 1) & 1, (i >> 2) & 1, (i >> 3) & 1
    n = W
    v, u = np.mgrid[0:n, 0:n].astype(np.float32) / (n - 1)
    f = tl * (1 - u) * (1 - v) + tr * u * (1 - v) + bl * (1 - u) * v + br * u * v
    env = np.sin(np.pi * u) * np.sin(np.pi * v)
    # a light wobble: strong enough to look painted, weak enough that a long straight
    # shore never turns into a row of identical scallops
    f = f + (_noise(seed) * 0.035 + _noise(seed + 50, cells=9) * 0.025) * env
    return f


def _shade(a, k):
    return np.clip(a * k, 0, 255)


def wang(land, other, style, seed=1, rim=None, variants=3):
    """16 x `variants` tiles [PIL RGBA 64px] (tile v*16+i = corner case i, variant v; the
    painter picks variants at random so long edges never repeat) and their solid polygons
    (tile-centred, 64 px units)."""
    tiles, polys = [], []
    rim_tex = rim if rim is not None else land
    for n in range(16 * variants):
        i = n % 16
        f = _field(i, seed + n * 7)
        out = land.copy()
        o = other.copy()
        if style == "water":
            depth = np.clip((f - 0.5) * 3.0, 0, 1)[..., None]
            o = o * (1 - depth * 0.22)  # deeper water a little darker
        m_other = (f > 0.5)[..., None]
        out = np.where(m_other, o, out)
        if style == "water":
            sand = (f > 0.38) & (f <= 0.5)
            wet = (f > 0.46) & (f <= 0.5)
            foam = (f > 0.5) & (f <= 0.555)
            out[sand] = rim_tex[sand]
            out[wet] = _shade(rim_tex[wet], 0.72)
            out[foam] = out[foam] * 0.45 + np.array([235, 250, 255], np.float32) * 0.55
        elif style == "path":
            edge = (f > 0.44) & (f <= 0.52)
            out[edge] = _shade(out[edge], 0.85)
            tufts = edge & (_noise(seed + n, cells=24) > 0.55)
            out[tufts] = land[tufts]
        elif style == "infested":
            edge = (f > 0.42) & (f <= 0.5)
            out[edge] = _shade(out[edge], 0.6) * 0.6 + np.array([90, 20, 110], np.float32) * 0.4
            veins = (f > 0.3) & (f <= 0.5) & (np.abs(_noise(seed + 3 * n, cells=12)) < 0.06)
            out[veins] = np.array([199, 91, 214], np.float32)
        img = Image.fromarray(out.astype(np.uint8)).resize((T, T), Image.LANCZOS).convert("RGBA")
        tiles.append(img)
        # solid where the other side starts (water past the foam)
        mask = cv2.resize((f > 0.53).astype(np.uint8) * 255, (T, T), interpolation=cv2.INTER_AREA)
        mask = (mask > 127).astype(np.uint8)
        found = []
        if mask.all():
            found = [[[-32, -32], [32, -32], [32, 32], [-32, 32]]]
        elif mask.any():
            padded = cv2.copyMakeBorder(mask, 1, 1, 1, 1, cv2.BORDER_CONSTANT, value=0)
            cs, _ = cv2.findContours(padded, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
            for c in cs:
                if cv2.contourArea(c) < 6:
                    continue
                c = cv2.approxPolyDP(c, 1.2, True)
                pts = [[float(np.clip(p[0][0] - 1, 0, T)) - 32, float(np.clip(p[0][1] - 1, 0, T)) - 32] for p in c]
                if len(pts) >= 3:
                    found.append(pts)
        polys.append(found)
    return tiles, polys


def finish(a):
    """Float RGB array -> 64 px RGBA tile."""
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).resize((T, T), Image.LANCZOS).convert("RGBA")
