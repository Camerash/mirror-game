#!/usr/bin/env python3
"""Generate 2K cellular glaze maps for the reference blocks."""
from pathlib import Path
import struct
import zlib
import numpy as np

SIZE = 2048
OUTPUT = Path(__file__).resolve().parents[2] / "assets" / "reference"
RNG = np.random.default_rng(8912)

def noise(cells, seed):
	rng = np.random.default_rng(seed)
	grid = rng.random((cells, cells), dtype=np.float32)
	axis = np.arange(SIZE, dtype=np.float32) * cells / SIZE
	index = axis.astype(np.int32)
	blend = axis - index
	blend = blend * blend * (3.0 - 2.0 * blend)
	a = grid[index[:, None], index[None, :]]
	b = grid[index[:, None], (index[None, :] + 1) % cells]
	c = grid[(index[:, None] + 1) % cells, index[None, :]]
	d = grid[(index[:, None] + 1) % cells, (index[None, :] + 1) % cells]
	return (a * (1 - blend)[None, :] + b * blend[None, :]) * (1 - blend)[:, None] + (c * (1 - blend)[None, :] + d * blend[None, :]) * blend[:, None]

def cellular(cells):
	points = RNG.random((cells, cells, 2), dtype=np.float32)
	axis = np.arange(SIZE, dtype=np.float32) * cells / SIZE
	whole = axis.astype(np.int32)
	fraction = axis - whole
	first = np.full((SIZE, SIZE), 9.0, dtype=np.float32)
	second = first.copy()
	for vertical in (-1, 0, 1):
		for horizontal in (-1, 0, 1):
			point = points[(whole[:, None] + vertical) % cells, (whole[None, :] + horizontal) % cells]
			distance = (point[:, :, 0] + horizontal - fraction[None, :]) ** 2 + (point[:, :, 1] + vertical - fraction[:, None]) ** 2
			second = np.minimum(second, np.maximum(first, distance))
			first = np.minimum(first, distance)
	return np.exp(-((second - first) / 0.016) ** 2)

def save(name, values):
	if values.ndim == 2:
		values = np.repeat(values[:, :, None], 3, axis=2)
	rgb = np.round(np.clip(values, 0.0, 1.0) * 255).astype(np.uint8)
	raw = b"".join(b"\0" + row.tobytes() for row in rgb)
	def chunk(kind, data):
		return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)
	(OUTPUT / name).write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 8)) + chunk(b"IEND", b""))

def maps(kind):
	broad = noise(5, 17) * 0.62 + noise(16, 29) * 0.38
	fine = noise(93, 41)
	cracks = cellular(25 if kind == "ceramic" else 17)
	yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32) / SIZE
	warp = noise(7, 59) * 0.8 + noise(19, 61) * 0.2
	veins = np.exp(-((np.sin((xx * 13.0 + yy * 4.5 + warp * 4.0) * np.pi) + 0.42) / 0.13) ** 2)
	if kind == "ceramic":
		base = np.array([0.84, 0.77, 0.63], dtype=np.float32)
		colour = base + (broad[:, :, None] - 0.5) * np.array([0.09, 0.07, 0.035]) + (fine[:, :, None] - 0.5) * 0.018
		colour -= cracks[:, :, None] * np.array([0.12, 0.105, 0.07])
		roughness = 0.22 + broad * 0.12 + cracks * 0.19
		height = fine * 0.018 - cracks * 0.08
	else:
		base = np.array([0.25, 0.50, 0.34], dtype=np.float32)
		colour = base + (broad[:, :, None] - 0.5) * np.array([0.12, 0.20, 0.13])
		colour += veins[:, :, None] * np.array([0.10, 0.17, 0.11]) - cracks[:, :, None] * np.array([0.035, 0.075, 0.045])
		roughness = 0.19 + broad * 0.15 + cracks * 0.18 - veins * 0.07
		height = fine * 0.015 - cracks * 0.065 + veins * 0.028
	dx = np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)
	dy = np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)
	normal = np.stack((-dx * 20.0, -dy * 20.0, np.ones_like(height)), axis=2)
	normal /= np.linalg.norm(normal, axis=2)[:, :, None]
	save("surface_%s_albedo.png" % kind, colour)
	save("surface_%s_roughness.png" % kind, roughness)
	save("surface_%s_normal.png" % kind, normal * 0.5 + 0.5)
	save("surface_%s_height.png" % kind, 0.5 + height)

if __name__ == "__main__":
	OUTPUT.mkdir(parents=True, exist_ok=True)
	maps("ceramic")
	maps("jade")
