"""Combine the review renders into docs/art/her/blockout/blockout-NN.jpg (needs PIL).

    python contact_sheet.py [NN]
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
DIR = ROOT / 'docs/art/her/blockout'
CONCEPT = ROOT / 'docs/art/her/beanie_b.jpg'
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'


def figure_height(img):
    """Pixels of the figure: saturated or dark, unlike the snow and background."""
    ys = [y for y in range(img.height) for x in range(img.width)
          if (lambda p: max(p) - min(p) > 18 or max(p) < 150)(img.getpixel((x, y)))]
    return max(ys) - min(ys) + 1, (min(ys) + max(ys)) // 2


def main(tag='01', subtitle=''):
    try:
        f, fs = ImageFont.truetype(FONT, 20), ImageFont.truetype(FONT, 16)
    except OSError:
        f = fs = ImageFont.load_default()
    sheet = Image.new('RGB', (1600, 1240), (236, 237, 240))
    d = ImageDraw.Draw(sheet)
    d.text((20, 14), 'Her - shape blockout %s (flat colours, no rig)   %s' % (tag, subtitle),
           fill=(40, 40, 45), font=f)
    tiles = [('front', 'Front'), ('side', 'Side (her left)'), ('back', 'Back'),
             ('three_quarter', 'Three-quarter (her front right)')]
    for i, (name, label) in enumerate(tiles):
        im = Image.open(DIR / (name + '.png')).convert('RGB').resize((390, 390), Image.LANCZOS)
        x = 10 + i * 397
        sheet.paste(im, (x, 50))
        d.text((x + 6, 446), label, fill=(60, 60, 65), font=fs)
    sheet.paste(Image.open(DIR / 'game.png').convert('RGB').resize((740, 740), Image.LANCZOS), (10, 474))
    d.text((16, 1216), 'Game angle (ortho, 30 deg elevation, 45 deg yaw), large', fill=(60, 60, 65), font=fs)
    small = Image.open(DIR / 'game_small.png').convert('RGB')
    h, cy = figure_height(small)
    sheet.paste(small, (770, 474))
    d.text((776, 840), 'Game size: 1:1 pixels, %d px tall on a 1-unit cube' % h, fill=(60, 60, 65), font=fs)
    cx = small.width // 2
    sheet.paste(small.crop((cx - 55, cy - 55, cx + 55, cy + 55)).resize((330, 330), Image.NEAREST), (1150, 474))
    d.text((1156, 810), 'Game size, 3x nearest', fill=(60, 60, 65), font=fs)
    c = Image.open(CONCEPT).convert('RGB')
    c = c.resize((820, int(820 * c.height / c.width)), Image.LANCZOS).crop((0, 0, 820, 340))
    sheet.paste(c, (770, 870))
    d.text((776, 1216), 'Concept: beanie_b.jpg (its mitten side is wrong)', fill=(60, 60, 65), font=fs)
    out = DIR / ('blockout-%s.jpg' % tag)
    sheet.save(out, quality=90)
    print('### sheet', out, 'figure height px', h)


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else '01', ' '.join(sys.argv[2:]))
