#!/usr/bin/python3
"""Kiln Linux: draws the shortcuts shown on the empty desktop, for this 5120x1440 screen.

Run after changing a key in hyprland.lua: python3 config/desktop/make-shortcuts.py
Writes shortcuts.png beside this file. Black background, because the screen is OLED,
where black pixels are off.
"""
import os
import subprocess

from PIL import Image, ImageDraw, ImageFont

WIDTH, HEIGHT = 5120, 1440
COLUMNS = (
    (("Super + Enter", "Terminal"),
     ("Super + B", "Browser"),
     ("Super + R", "Apps"),
     ("Super + Space", "Claude"),
     ("Super + W", "Close window"),
     ("Super + F", "Full screen")),
    (("Super + 1 to 0", "Go to workspace"),
     ("Super + Shift + 1 to 0", "Move window there"),
     ("Super + arrows", "Move between windows"),
     ("Super + C / V", "Copy / paste"),
     ("Super + T", "Float window"),
     ("Super + Shift + E", "Log out")),
)
KEY_COLOUR = "#7aa2f7"
WORDS_COLOUR = "#9099b8"
KEY_SIZE, WORDS_SIZE = 60, 60
ROW = 110
INNER_GAP, COLUMN_GAP = 70, 260


def font(pattern, size):
    path = subprocess.run(["fc-match", "-f", "%{file}", pattern], capture_output=True,
                          text=True, check=True).stdout
    return ImageFont.truetype(path, size)


def main():
    image = Image.new("RGB", (WIDTH, HEIGHT), "#000000")
    draw = ImageDraw.Draw(image)
    bold, plain = font("DejaVu Sans:bold", KEY_SIZE), font("DejaVu Sans", WORDS_SIZE)

    sizes = []
    for column in COLUMNS:
        key_width = max(draw.textlength(key, font=bold) for key, _ in column)
        words_width = max(draw.textlength(words, font=plain) for _, words in column)
        sizes.append((key_width, words_width))

    total = sum(k + INNER_GAP + w for k, w in sizes) + COLUMN_GAP * (len(COLUMNS) - 1)
    top = (HEIGHT - ROW * max(len(c) for c in COLUMNS)) / 2
    x = (WIDTH - total) / 2
    for column, (key_width, words_width) in zip(COLUMNS, sizes):
        for row, (key, words) in enumerate(column):
            y = top + ROW * row
            draw.text((x, y), key, font=bold, fill=KEY_COLOUR)
            draw.text((x + key_width + INNER_GAP, y), words, font=plain, fill=WORDS_COLOUR)
        x += key_width + INNER_GAP + words_width + COLUMN_GAP

    image.save(os.path.join(os.path.dirname(os.path.realpath(__file__)), "shortcuts.png"),
               optimize=True)


if __name__ == "__main__":
    main()
