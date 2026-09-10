#!/usr/bin/env python3
"""Build seamless 2K glaze/mineral maps. Requires NumPy; writes PNG with stdlib."""
from pathlib import Path
import struct
import zlib
import numpy as np

SIZE = 2048
OUTPUT = Path(__file__).resolve().parents[2] / "assets" / "materials"
RNG = np.random.default_rng(304)


def noise(cells):
    grid = RNG.uniform(-1, 1, (cells, cells)).astype(np.float32)
    axis = np.arange(SIZE, dtype=np.float32) * cells / SIZE
    index = axis.astype(int)
    blend = axis - index
    blend = blend * blend * (3 - 2 * blend)
    lo = grid[index[:, None], index[None, :]]
    right = grid[index[:, None], (index[None, :] + 1) % cells]
    up = grid[(index[:, None] + 1) % cells, index[None, :]]
    diagonal = grid[(index[:, None] + 1) % cells, (index[None, :] + 1) % cells]
    return (lo * (1 - blend)[None, :] + right * blend[None, :]) * (1 - blend)[:, None] + (up * (1 - blend)[None, :] + diagonal * blend[None, :]) * blend[:, None]


def crackle(cells=11):
    points = RNG.uniform(0.15, 0.85, (cells, cells, 2)).astype(np.float32)
    axis = np.arange(SIZE, dtype=np.float32) * cells / SIZE
    whole = axis.astype(int)
    fraction = axis - whole
    first = np.full((SIZE, SIZE), 10.0, dtype=np.float32)
    second = first.copy()
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            selected = points[(whole[:, None] + dy) % cells, (whole[None, :] + dx) % cells]
            distance = (selected[:, :, 0] + dx - fraction[None, :]) ** 2 + (selected[:, :, 1] + dy - fraction[:, None]) ** 2
            second = np.minimum(second, np.maximum(first, distance))
            first = np.minimum(first, distance)
    return np.exp(-((second - first) / 0.024) ** 2)


def save(name, values):
    if values.ndim == 2:
        values = np.repeat(values[:, :, None], 3, axis=2)
    rgb = np.round(np.clip(values, 0, 1) * 255).astype(np.uint8)
    raw = b''.join(b'\0' + row.tobytes() for row in rgb)
    def chunk(kind, content):
        return struct.pack('>I', len(content)) + kind + content + struct.pack('>I', zlib.crc32(kind + content) & 0xffffffff)
    (OUTPUT / name).write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', SIZE, SIZE, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw, 7)) + chunk(b'IEND', b''))


def generate(kind):
    broad = noise(4) * 0.55 + noise(13) * 0.3 + noise(37) * 0.15
    fine = noise(140) * 0.7 + noise(390) * 0.3
    veins = crackle(9 if kind == 'ceramic' else 6)
    base = np.array([0.87, 0.847, 0.79] if kind == 'ceramic' else [0.46, 0.55, 0.48])
    shade = broad * (0.028 if kind == 'ceramic' else 0.065) + fine * 0.007
    color = base[None, None, :] + shade[:, :, None]
    color -= veins[:, :, None] * (np.array([0.065, 0.067, 0.062]) if kind == 'ceramic' else np.array([-0.035, -0.03, -0.019]))
    roughness = (0.25 if kind == 'ceramic' else 0.37) + broad * 0.045 + veins * 0.07
    relief = fine * 0.007 - veins * 0.008
    dx = (np.roll(relief, -1, axis=1) - np.roll(relief, 1, axis=1)) * 8
    dy = (np.roll(relief, -1, axis=0) - np.roll(relief, 1, axis=0)) * 8
    normals = np.stack([-dx, -dy, np.ones_like(dx)], axis=2)
    normals /= np.linalg.norm(normals, axis=2)[:, :, None]
    save(kind + '_albedo.png', color)
    save(kind + '_roughness.png', roughness)
    save(kind + '_normal.png', normals * 0.5 + 0.5)
    save(kind + '_height.png', 0.5 + relief)


if __name__ == '__main__':
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for kind in ('ceramic', 'jade'):
        generate(kind)
