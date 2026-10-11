#!/usr/bin/env python3
"""Íconos pixel art de la comida y la tienda de campaña (no existen oficiales con ese
estilo; los demás vienen de PokeAPI). Mismo tamaño que los demás íconos (art/items/).
Uso: python3 tools/food_icons.py"""
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "art" / "items"
S = 30
INK = (40, 30, 30, 255)


def canvas():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))


def outline(im):
    px = im.load()
    out = im.copy()
    po = out.load()
    for y in range(S):
        for x in range(S):
            if px[x, y][3] == 0 and any(0 <= x + dx < S and 0 <= y + dy < S and px[x + dx, y + dy][3] > 0 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                po[x, y] = INK
    return out


def tent():
    im = canvas(); d = ImageDraw.Draw(im)
    d.polygon([(15, 5), (26, 24), (4, 24)], fill=(70, 160, 90, 255))
    d.polygon([(15, 5), (15, 24), (4, 24)], fill=(55, 130, 75, 255))
    d.polygon([(15, 12), (19, 24), (11, 24)], fill=(35, 30, 35, 255))
    d.line([(15, 3), (15, 6)], fill=(120, 80, 45, 255))
    return outline(im)


def bread():
    im = canvas(); d = ImageDraw.Draw(im)
    d.rounded_rectangle([4, 10, 26, 22], 5, fill=(214, 150, 70, 255))
    d.rounded_rectangle([5, 9, 25, 14], 4, fill=(232, 178, 95, 255))
    for x in (9, 14, 19):
        d.line([(x, 11), (x + 2, 13)], fill=(170, 105, 45, 255))
    return outline(im)


def sandwich(full=False):
    im = canvas(); d = ImageDraw.Draw(im)
    if full:
        d.ellipse([2, 18, 28, 27], fill=(235, 235, 240, 255))
    d.polygon([(4, 20), (26, 20), (15, 8)], fill=(238, 205, 150, 255))
    d.line([(5, 18), (25, 18)], fill=(90, 180, 70, 255), width=2)
    d.line([(6, 16), (24, 16)], fill=(220, 70, 60, 255), width=1)
    d.polygon([(6, 15), (24, 15), (15, 6)], fill=(245, 215, 160, 255))
    return outline(im)


def can():
    im = canvas(); d = ImageDraw.Draw(im)
    d.rectangle([8, 7, 22, 25], fill=(200, 60, 50, 255))
    d.rectangle([8, 12, 22, 19], fill=(245, 200, 70, 255))
    d.ellipse([8, 5, 22, 9], fill=(190, 190, 200, 255))
    return outline(im)


def plate(food):
    im = canvas(); d = ImageDraw.Draw(im)
    d.ellipse([2, 12, 28, 26], fill=(240, 240, 245, 255))
    d.ellipse([5, 14, 25, 24], fill=(225, 225, 232, 255))
    if food == "curry":
        d.ellipse([6, 14, 18, 23], fill=(250, 250, 250, 255))
        d.ellipse([12, 14, 24, 23], fill=(200, 120, 40, 255))
        d.point([(16, 17), (19, 19)], fill=(120, 170, 60, 255))
    elif food == "stew":
        d.ellipse([5, 9, 25, 22], fill=(150, 70, 60, 255))
        d.ellipse([7, 10, 23, 17], fill=(190, 80, 90, 255))
        for p in [(10, 12), (15, 13), (19, 12)]:
            d.ellipse([p[0] - 1, p[1] - 1, p[0] + 1, p[1] + 1], fill=(90, 160, 220, 255))
    return outline(im)


def fish(cooked):
    im = canvas(); d = ImageDraw.Draw(im)
    body = (180, 110, 60, 255) if cooked else (120, 170, 210, 255)
    d.ellipse([4, 10, 22, 20], fill=body)
    d.polygon([(21, 15), (27, 10), (27, 20)], fill=body)
    d.point([(8, 13)], fill=INK)
    if cooked:
        for x in (10, 14, 18):
            d.line([(x, 11), (x - 2, 19)], fill=(110, 60, 30, 255))
        d.line([(2, 24), (28, 24)], fill=(140, 100, 60, 255), width=2)
    else:
        d.line([(9, 15), (19, 15)], fill=(200, 220, 240, 255))
    return outline(im)


def cake():
    im = canvas(); d = ImageDraw.Draw(im)
    d.rectangle([6, 14, 24, 24], fill=(245, 225, 190, 255))
    d.rectangle([6, 12, 24, 15], fill=(255, 245, 245, 255))
    d.rectangle([6, 19, 24, 20], fill=(230, 120, 140, 255))
    d.ellipse([13, 6, 18, 11], fill=(220, 40, 60, 255))
    return outline(im)


def apple():
    im = canvas(); d = ImageDraw.Draw(im)
    d.ellipse([6, 9, 24, 26], fill=(220, 50, 50, 255))
    d.ellipse([9, 11, 13, 15], fill=(255, 140, 140, 255))
    d.line([(15, 5), (15, 10)], fill=(110, 70, 40, 255), width=2)
    d.polygon([(16, 7), (22, 5), (19, 9)], fill=(80, 170, 70, 255))
    return outline(im)


def skewer():
    im = canvas(); d = ImageDraw.Draw(im)
    d.line([(4, 26), (26, 4)], fill=(200, 170, 120, 255), width=2)
    for i, col in enumerate([(190, 90, 50, 255), (90, 170, 70, 255), (200, 100, 60, 255), (240, 200, 80, 255)]):
        c = 8 + i * 5
        d.ellipse([c - 3, 30 - c - 7, c + 3, 30 - c - 1], fill=col)
    return outline(im)


def spoiled():
    im = canvas(); d = ImageDraw.Draw(im)
    d.ellipse([3, 14, 27, 26], fill=(230, 230, 235, 255))
    d.ellipse([7, 13, 22, 22], fill=(120, 140, 70, 255))
    d.ellipse([12, 15, 18, 19], fill=(90, 100, 50, 255))
    for p in [(6, 6), (20, 4), (25, 10)]:
        d.point([p], fill=INK)
        d.point([(p[0] + 1, p[1] - 1), (p[0] - 1, p[1] - 1)], fill=(160, 160, 170, 255))
    for x in (10, 15, 20):
        d.line([(x, 12), (x + 1, 8)], fill=(150, 170, 100, 255))
    return outline(im)


def main():
    icons = {"tent": tent(), "bread": bread(), "sandwich-shop": sandwich(), "sandwich-dish": sandwich(True),
             "curry-can": can(), "curry-dish": plate("curry"), "berry-stew": plate("stew"),
             "raw-fish": fish(False), "grilled-fish": fish(True),
             "house-curry": plate("curry"), "chef-stew": plate("stew"), "fisher-plate": fish(True), "house-dessert": cake(),
             "stall-fruit": apple(), "stall-sandwich": sandwich(), "stall-skewer": skewer(), "spoiled-food": spoiled()}
    for name, im in icons.items():
        im.save(OUT / f"{name}.png")
    print(f"{len(icons)} íconos en {OUT}")


if __name__ == "__main__":
    main()
