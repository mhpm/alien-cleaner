"""World 6 (GENE VAULT): the SPECIMEN VAT frames, cut from tools/specimen_vat_ref.webp (5
frames side by side: intact, cracked, bursting, broken, remains).
  idle/image_01        the intact capsule (walk)
  hurt/image_01        the cracked glass, the specimen squeezing its eyes (crack)
  die/image_01..03     bursts, breaks apart, leaves the remains (splat: the last frame
                       stays on the floor)
-> assets/sprites/enemies/specimen_vat/<anim>/image_NN.png, then
   python tools/slice_sprites.py tools/reference_sheet.webp --only specimen_vat

Also the EGG CLUSTER (tools/egg_cluster_ref.webp: 6 frames, intact, cracking, hatching x3,
spent) and its OCTOLING (the baby octopus jumping out of the last frame):
  egg_cluster/idle, crack, hatch/image_01..03, spent (the empty nest)
  octoling/walk/image_01..06 from its own walk sheet tools/octoling_walk_ref.webp (6 frames)
-> python tools/slice_sprites.py tools/reference_sheet.webp --only egg_cluster,octoling

python tools/make_gene_vault_assets.py
"""
import os
import shutil

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "specimen_vat_ref.webp")
OUT = os.path.join(ROOT, "assets", "sprites", "enemies", "specimen_vat")
FRAMES = [("idle", 1), ("hurt", 1), ("die", 1), ("die", 2), ("die", 3)]


def columns(alpha):
    """x ranges of the frames: runs of columns with something in them."""
    on = alpha.any(0)
    runs, s = [], None
    for x, c in enumerate(on):
        if c and s is None:
            s = x
        if not c and s is not None:
            runs.append((s, x))
            s = None
    if s is not None:
        runs.append((s, len(on)))
    return [r for r in runs if r[1] - r[0] > 40]


EGG_SRC = os.path.join(ROOT, "tools", "egg_cluster_ref.webp")
EGG_OUT = os.path.join(ROOT, "assets", "sprites", "enemies", "egg_cluster")
OCTO_OUT = os.path.join(ROOT, "assets", "sprites", "enemies", "octoling")
OCTO_SRC = os.path.join(ROOT, "tools", "octoling_walk_ref.webp")
EGG_FRAMES = [("idle", 1), ("crack", 1), ("hatch", 1), ("hatch", 2), ("hatch", 3), ("spent", 1)]


def eggs():
    from scipy import ndimage
    a = np.array(Image.open(EGG_SRC).convert("RGBA"))
    a[a[..., 3] < 40] = 0  # the sheet's faint background
    im = Image.fromarray(a)
    runs = columns(a[..., 3] > 40)
    assert len(runs) == len(EGG_FRAMES), runs
    for d in (EGG_OUT, OCTO_OUT):
        if os.path.isdir(d):
            shutil.rmtree(d)
    for k, ((x0, x1), (anim, i)) in enumerate(zip(runs, EGG_FRAMES)):
        fr = np.array(im.crop((x0, 0, x1, im.height)))
        if anim == "spent":
            # the last frame: the nest is the biggest piece, the octoling the next one
            lab, n = ndimage.label(fr[..., 3] > 40)
            sizes = ndimage.sum(np.ones(lab.shape), lab, range(1, n + 1))
            order = np.argsort(sizes)[::-1] + 1
            nest = fr.copy()
            nest[lab != order[0], 3] = 0
            octo = fr.copy()
            octo[lab != order[1], 3] = 0
            fr = nest
        img = Image.fromarray(fr)
        img = img.crop(img.getbbox())
        d = os.path.join(EGG_OUT, anim)
        os.makedirs(d, exist_ok=True)
        img.save(os.path.join(d, "image_%02d.png" % i))
        print("egg", anim, i, img.size)
    # the octoling walking (its own sheet)
    a = np.array(Image.open(OCTO_SRC).convert("RGBA"))
    a[a[..., 3] < 40] = 0
    im = Image.fromarray(a)
    d = os.path.join(OCTO_OUT, "walk")
    os.makedirs(d, exist_ok=True)
    for i, (x0, x1) in enumerate(columns(a[..., 3] > 40)):
        fr = im.crop((x0, 0, x1, im.height))
        fr.crop(fr.getbbox()).save(os.path.join(d, "image_%02d.png" % (i + 1)))
    print("octoling walk frames", i + 1)


def main():
    a = np.array(Image.open(SRC).convert("RGBA"))
    a[a[..., 3] < 40] = 0  # the sheet's faint background
    im = Image.fromarray(a)
    runs = columns(a[..., 3] > 40)
    assert len(runs) == len(FRAMES), runs
    if os.path.isdir(OUT):
        shutil.rmtree(OUT)
    for (x0, x1), (anim, i) in zip(runs, FRAMES):
        fr = im.crop((x0, 0, x1, im.height))
        fr = fr.crop(fr.getbbox())
        d = os.path.join(OUT, anim)
        os.makedirs(d, exist_ok=True)
        fr.save(os.path.join(d, "image_%02d.png" % i))
        print(anim, i, fr.size)
    eggs()


if __name__ == "__main__":
    main()
