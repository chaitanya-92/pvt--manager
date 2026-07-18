#!/usr/bin/env python3
"""Generate a monogram app-icon set for a brand.
Usage: icon_gen.py <res_dir> "<Display Name>"
Writes ic_launcher/round/foreground .webp across densities + adaptive background.
Colored background + white initials (first letters of up to two words).
"""
import sys, hashlib
from PIL import Image, ImageDraw, ImageFont

FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
PALETTE = [  # pleasant, distinct backgrounds
    "#1E88E5", "#8E24AA", "#00897B", "#E53935", "#3949AB",
    "#F4511E", "#43A047", "#6D4C41", "#00ACC1", "#5E35B1",
    "#C0392B", "#2E7D32", "#37474F", "#AD1457", "#EF6C00",
]

def initials(name):
    words = [w for w in name.replace("_", " ").split() if w]
    if not words:
        return "?"
    if len(words) == 1:
        return words[0][:2].upper()
    return (words[0][0] + words[1][0]).upper()

def bg_color(name):
    h = int(hashlib.sha256(name.encode()).hexdigest(), 16)
    return PALETTE[h % len(PALETTE)]

def draw(size, text, bg, fg=(255, 255, 255, 255), transparent_bg=False, scale=0.5):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0) if transparent_bg else bg)
    d = ImageDraw.Draw(img)
    fs = int(size * scale)
    try:
        font = ImageFont.truetype(FONT, fs)
    except Exception:
        font = ImageFont.load_default()
    bb = d.textbbox((0, 0), text, font=font)
    w, hh = bb[2] - bb[0], bb[3] - bb[1]
    d.text(((size - w) / 2 - bb[0], (size - hh) / 2 - bb[1]), text, font=font, fill=fg)
    return img

def circle(img):
    s = img.size[0]
    m = Image.new("L", (s, s), 0); ImageDraw.Draw(m).ellipse((0, 0, s, s), fill=255)
    o = Image.new("RGBA", (s, s), (0, 0, 0, 0)); o.paste(img, (0, 0), m); return o

def main():
    res, name = sys.argv[1], sys.argv[2]
    text = initials(name); bg = bg_color(name)
    r, g, b = int(bg[1:3], 16), int(bg[3:5], 16), int(bg[5:7], 16)
    bg_rgba = (r, g, b, 255)
    legacy = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    fg = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
    for d, s in legacy.items():
        sq = draw(s, text, bg_rgba, scale=0.52)
        sq.save(f"{res}/mipmap-{d}/ic_launcher.webp", "WEBP", quality=95)
        circle(sq).save(f"{res}/mipmap-{d}/ic_launcher_round.webp", "WEBP", quality=95)
    for d, s in fg.items():
        # adaptive foreground: white initials on transparent, smaller (safe zone)
        draw(s, text, bg_rgba, transparent_bg=True, scale=0.40).save(
            f"{res}/mipmap-{d}/ic_launcher_foreground.webp", "WEBP", quality=95)
    open(f"{res}/drawable/ic_launcher_background.xml", "w").write(
        '<?xml version="1.0" encoding="utf-8"?>\n<vector android:height="108dp" '
        'android:width="108dp" android:viewportHeight="108" android:viewportWidth="108" '
        'xmlns:android="http://schemas.android.com/apk/res/android">\n'
        f'    <path android:fillColor="{bg}" android:pathData="M0,0h108v108h-108z"/>\n</vector>\n')
    print(f"icon: initials={text} bg={bg}")

if __name__ == "__main__":
    main()
