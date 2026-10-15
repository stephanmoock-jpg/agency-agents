#!/usr/bin/env python3
"""Erzeugt das App-Icon nach brand.md (drei steigende Kreidestriche auf warmem Schwarz). Nur Standardbibliothek.

    python3 -I make_icon.py OUT.png [SIZE]
"""
import math, random, struct, sys, zlib

BG = (0x24, 0x21, 0x1D)
CHALK = (0xF1, 0xED, 0xE4)

def png(path, w, h, px):
    raw = bytearray()
    for y in range(h):
        raw.append(0); raw.extend(px[y * w * 3:(y + 1) * w * 3])
    def ch(k, b):
        return struct.pack(">I", len(b)) + k + b + struct.pack(">I", zlib.crc32(k + b) & 0xFFFFFFFF)
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + ch(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
                           + ch(b"IDAT", zlib.compress(bytes(raw), 9)) + ch(b"IEND", b""))

def main():
    out = sys.argv[1]; n = int(sys.argv[2]) if len(sys.argv) > 2 else 1024
    rnd = random.Random(42)
    s = n / 1024.0
    # drei Striche: (x0, y0, x1, y1) in 1024er Koordinaten, steigend von links unten nach rechts oben
    strokes = [(250, 720, 430, 700), (430, 545, 610, 525), (610, 370, 790, 350)]
    half = 46 * s
    px = bytearray(BG * (n * n))
    noise = [rnd.random() for _ in range(4096)]
    for (x0, y0, x1, y1) in strokes:
        x0, y0, x1, y1 = (v * s for v in (x0, y0, x1, y1))
        dx, dy = x1 - x0, y1 - y0; L2 = dx * dx + dy * dy
        for y in range(int(min(y0, y1) - half - 2), int(max(y0, y1) + half + 3)):
            for x in range(int(min(x0, x1) - half - 2), int(max(x0, x1) + half + 3)):
                t = max(0.0, min(1.0, ((x - x0) * dx + (y - y0) * dy) / L2))
                d = math.hypot(x - (x0 + t * dx), y - (y0 + t * dy))
                if d > half + 1:
                    continue
                cov = max(0.0, min(1.0, half + 0.5 - d))           # Antialiasing
                edge = d / half
                if n >= 128:                                          # Kreidetextur, zum Rand hin stärker
                    k = max(0.0, min(1.0, (edge - 0.3) / 0.7)) ** 1.5 * 0.85
                    nz = noise[((x // 2) * 31 + (y // 2) * 17) % 4096]
                    cov *= 1 - k * (1 - nz)
                i = (y * n + x) * 3
                for c in range(3):
                    px[i + c] = int(px[i + c] * (1 - cov) + CHALK[c] * cov)
    png(out, n, n, px)

if __name__ == "__main__":
    main()
