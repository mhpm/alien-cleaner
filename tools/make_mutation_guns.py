"""Datos de las 5 armas de mutación (MUTATION LAB) para el juego.

python tools/make_mutation_guns.py
Lee assets/sprites/mutations_player/mutation_guns/guns_elements/gun_<n>.png (el arma
mirando a la derecha, empuñadura abajo a la izquierda) y shoot_<n>.png (su disparo,
hacia la derecha) y escribe mutation_guns/guns.json con, por arma, `grip` (donde la
sujeta la mano: arriba de la empuñadura) y `tip` (la boca del cañón), y por disparo
`size` y `head` (el frente del proyectil), en px de la imagen. Lo lee Astronaut para
colocar y girar el arma del mutante y InfShot para el proyectil.
"""
import json
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIR = os.path.join(ROOT, "assets", "sprites", "mutations_player", "mutation_guns")
SRC = os.path.join(DIR, "guns_elements")
# arriba de la empuñadura, puestas a mano (las armas 4-5 tienen tentáculos más abajo)
GRIPS = [(45, 100), (58, 102), (62, 112), (55, 122), (52, 170)]


def gun_points(img: Image.Image) -> dict:
    a = np.array(img)[..., 3] > 128
    h, w = a.shape
    ys, xs = np.nonzero(a)
    # boca: la columna más a la derecha, a la altura media del final del cañón
    right = xs > xs.max() - max(4, w * 0.05)
    tip = (float(xs.max()), float(ys[right].mean()))
    return {"size": [w, h], "grip": [0, 0],
            "tip": [round(tip[0], 1), round(tip[1], 1)]}


def shot_points(img: Image.Image) -> dict:
    a = np.array(img)[..., 3] > 60
    ys, xs = np.nonzero(a)
    right = xs > xs.max() - 6
    return {"size": [img.width, img.height], "head": [float(xs.max()), round(float(ys[right].mean()), 1)]}


def main() -> None:
    data = {"guns": [], "shots": []}
    for n in range(1, 6):
        g = gun_points(Image.open(os.path.join(SRC, "gun_%d.png" % n)).convert("RGBA"))
        g["grip"] = list(GRIPS[n - 1])
        data["guns"].append(g)
        data["shots"].append(shot_points(Image.open(os.path.join(SRC, "shoot_%d.png" % n)).convert("RGBA")))
    with open(os.path.join(DIR, "guns.json"), "w") as f:
        json.dump(data, f, indent=1)
    print(json.dumps(data))


if __name__ == "__main__":
    main()
