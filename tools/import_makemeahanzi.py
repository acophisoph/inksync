#!/usr/bin/env python3
"""
Import stroke data from the Makemeahanzi dataset into InkSync's
assets/characters/ directory.

Usage:
  1. Download graphics.txt from https://github.com/skishore/makemeahanzi
  2. Run: python import_makemeahanzi.py graphics.txt

The script reads the median paths for each character and converts them
from Makemeahanzi coordinates (0-1024, y flipped) to InkSync screen
coordinates (1280x720, character centered at 640x360).

Output: one JSON file per character in assets/characters/<hex>.json
"""

import json
import sys
import os

# Target screen space
SCREEN_W    = 1280
SCREEN_H    = 720
CENTER_X    = SCREEN_W // 2   # 640
CENTER_Y    = SCREEN_H // 2   # 360
CHAR_SIZE   = 420   # pixel size of the character in screen space
MH_SIZE     = 1024  # Makemeahanzi coordinate space (0..1023)

def mh_to_screen(x, y):
    """Convert Makemeahanzi [0,1023] (y up) to InkSync screen coords."""
    nx = (x / MH_SIZE - 0.5) * CHAR_SIZE + CENTER_X
    ny = (0.5 - y / MH_SIZE) * CHAR_SIZE + CENTER_Y   # flip Y
    return [round(nx, 1), round(ny, 1)]

def convert(graphics_path: str, out_dir: str) -> None:
    os.makedirs(out_dir, exist_ok=True)
    count = 0
    with open(graphics_path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue

            char     = entry.get("character", "")
            medians  = entry.get("medians", [])
            if not char or not medians:
                continue

            # Convert each stroke's median points
            strokes = []
            for stroke_median in medians:
                pts = [mh_to_screen(p[0], p[1]) for p in stroke_median]
                if len(pts) >= 2:
                    strokes.append(pts)

            if not strokes:
                continue

            hex_name = f"{ord(char):x}.json"
            out_path = os.path.join(out_dir, hex_name)
            with open(out_path, "w", encoding="utf-8") as out:
                json.dump({"character": char, "strokes": strokes},
                          out, ensure_ascii=False, indent=2)
            count += 1

    print(f"Exported {count} characters to {out_dir}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    graphics = sys.argv[1]
    out = os.path.join(os.path.dirname(__file__), "..",
                       "game", "assets", "characters")
    convert(graphics, out)
