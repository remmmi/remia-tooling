#!/usr/bin/env python3
"""Empile une section de maquette, la même section du site, et leur différence, dans une image.

    python3 superposer.py maquette.png site.png [--y-maquette N] [--y-site N] [--hauteur N]
                          [--echelle 0.5] -o sortie.png

Les deux images sont rendues à la même largeur (1x). --y-maquette / --y-site : ordonnée du haut de la
section dans chaque image (0 par défaut) ; --hauteur : hauteur de la section (par défaut jusqu'au bas
de la plus courte). La différence est |maquette - site| : noir = identique, clair = décalé.
Dépendance : Pillow.
"""
import argparse
import sys

try:
    from PIL import Image, ImageChops
except ImportError:
    sys.exit("Pillow manquant : pip install Pillow")


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("maquette")
    p.add_argument("site")
    p.add_argument("--y-maquette", type=int, default=0)
    p.add_argument("--y-site", type=int, default=0)
    p.add_argument("--hauteur", type=int, default=0, help="hauteur de la section (0 = jusqu'au bas)")
    p.add_argument("--echelle", type=float, default=1.0, help="réduction de l'image de sortie (0.5 = moitié)")
    p.add_argument("-o", "--sortie", required=True)
    a = p.parse_args()

    m = Image.open(a.maquette).convert("RGB")
    s = Image.open(a.site).convert("RGB")
    if m.width != s.width:
        sys.exit(f"largeurs différentes : maquette {m.width}, site {s.width} (rendre les deux à la même largeur)")
    h = a.hauteur or min(m.height - a.y_maquette, s.height - a.y_site)
    if h <= 0:
        sys.exit("hauteur nulle : vérifier --y-maquette / --y-site")
    cm = m.crop((0, a.y_maquette, m.width, min(m.height, a.y_maquette + h)))
    cs = s.crop((0, a.y_site, s.width, min(s.height, a.y_site + h)))
    hh = max(cm.height, cs.height)
    fond = Image.new("RGB", (m.width, hh), (255, 0, 255))
    pm, ps = fond.copy(), fond.copy()
    pm.paste(cm, (0, 0))
    ps.paste(cs, (0, 0))
    diff = ImageChops.difference(pm, ps)

    sep = 12
    out = Image.new("RGB", (m.width, hh * 3 + sep * 2), (255, 0, 255))
    out.paste(pm, (0, 0))
    out.paste(ps, (0, hh + sep))
    out.paste(diff, (0, 2 * (hh + sep)))
    if a.echelle != 1.0:
        out = out.resize((round(out.width * a.echelle), round(out.height * a.echelle)))
    out.save(a.sortie)
    print(f"{a.sortie} : {out.width}x{out.height} (section de {h} px ; maquette y={a.y_maquette}, site y={a.y_site})")


if __name__ == "__main__":
    main()
