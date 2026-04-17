"""
Generate placeholder ink-wash silhouette PNGs for the Cang Jie story.
Mirrors the logic in StoryAssetGen.gd exactly.
Run: python gen_cangjie_layers.py
"""

from PIL import Image, ImageDraw
import math, os

W, H = 1280, 720
OUT = os.path.join(os.path.dirname(__file__), "game/assets/stories/cangjie")
os.makedirs(OUT, exist_ok=True)

INK = (20, 15, 10)   # RGB of Color(0.08, 0.06, 0.04)

def new_img():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))

def ink(alpha=1.0):
    return (*INK, int(alpha * 255))

def save(img, name):
    path = os.path.join(OUT, name)
    img.save(path)
    print(f"  wrote {path}")

def fill_ellipse(img, cx, cy, rx, ry, col):
    draw = ImageDraw.Draw(img)
    draw.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=col)

def fill_rect(img, x, y, w, h, col):
    draw = ImageDraw.Draw(img)
    draw.rectangle([x, y, x + w, y + h], fill=col)

def fill_triangle(img, ax, ay, bx, by, cx_, cy_, col):
    draw = ImageDraw.Draw(img)
    draw.polygon([(ax, ay), (bx, by), (cx_, cy_)], fill=col)

# ── Layer generators ──────────────────────────────────────────────────────────

def gen_sun():
    img = new_img()
    col  = ink(0.92)
    halo = ink(0.18)
    # Halo first (under disc)
    fill_ellipse(img, 970, 150, 140, 140, halo)
    # Sun disc
    fill_ellipse(img, 970, 150, 100, 100, col)
    # Sky wash across top
    pix = img.load()
    for y in range(280):
        a = (1.0 - y / 280.0) * 0.22
        ai = int(a * 255)
        for x in range(W):
            if pix[x, y][3] < 25:
                pix[x, y] = (*INK, ai)
    save(img, "layer_sun.png")

def gen_mountain():
    img = new_img()
    col  = ink(0.88)
    # Three peaks
    fill_triangle(img,  40, 620, 340, 200, 640, 620, col)
    fill_triangle(img, 240, 620, 480, 120, 720, 620, col)
    fill_triangle(img, 500, 620, 680, 240, 860, 620, col)
    # Soft mist at base
    pix = img.load()
    for y in range(560, min(H, 680)):
        a = (y - 560) / 120.0 * 0.25
        ai = int(a * 255)
        for x in range(W):
            if pix[x, y][3] < 25:
                pix[x, y] = (*INK, ai)
    save(img, "layer_mountain.png")

def gen_water():
    img = new_img()
    pix = img.load()
    for y in range(480, H):
        for x in range(W):
            wave = math.sin(x * 0.025 + y * 0.08) * 12.0
            dist = abs(y - 580.0 + wave)
            a = max(0.0, min(1.0, 1.0 - dist / 120.0))
            if y > 480:
                a *= max(0.0, min(1.0, (y - 480) / 60.0))
            if a > 0.02:
                pix[x, y] = (*INK, int(a * 0.85 * 255))
    save(img, "layer_water.png")

def gen_tree():
    img = new_img()
    col  = ink(0.90)
    root = ink(0.55)
    # Trunk
    fill_rect(img, 688, 380, 28, 220, col)
    # Canopy
    fill_ellipse(img, 702, 320, 80, 70, col)
    fill_ellipse(img, 702, 270, 60, 55, col)
    fill_ellipse(img, 702, 230, 40, 40, col)
    # Roots
    fill_triangle(img, 680, 580, 640, 650, 702, 590, root)
    fill_triangle(img, 720, 580, 760, 650, 702, 590, root)
    save(img, "layer_tree.png")

def gen_person():
    img = new_img()
    col = ink(0.92)
    fill_ellipse(img, 600, 390, 22, 24, col)          # head
    fill_rect(img, 592, 412, 16, 70, col)              # body
    fill_triangle(img, 592, 478, 565, 560, 598, 480, col)  # left leg
    fill_triangle(img, 608, 478, 635, 560, 602, 480, col)  # right leg
    fill_triangle(img, 592, 430, 558, 480, 596, 445, col)  # left arm
    fill_triangle(img, 608, 430, 642, 480, 604, 445, col)  # right arm
    save(img, "layer_person.png")

def gen_moon():
    img = new_img()
    col  = ink(0.88)
    glow = ink(0.12)
    # Glow behind disc
    fill_ellipse(img, 1110, 150, 120, 120, glow)
    # Full disc
    fill_ellipse(img, 1110, 150, 88, 88, col)
    # Crescent bite (transparent)
    fill_ellipse(img, 1145, 140, 72, 72, (0, 0, 0, 0))
    # Night sky wash top-right
    pix = img.load()
    for y in range(240):
        for x in range(900, W):
            if pix[x, y][3] < 13:
                a = (1.0 - y / 240.0) * ((x - 900) / 380.0) * 0.15
                pix[x, y] = (*INK, int(a * 255))
    save(img, "layer_moon.png")

if __name__ == "__main__":
    gen_sun()
    gen_mountain()
    gen_water()
    gen_tree()
    gen_person()
    gen_moon()
    print("Done — all layer images written to", OUT)
