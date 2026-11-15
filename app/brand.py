"""Channel art made on the server: banner (2560x1440), logo (800x800) and the subscribe watermark (150x150)."""
from pathlib import Path

from .media import FONTS

BLACK_FONT = FONTS / 'Montserrat_900Black.ttf'
BOLD_FONT = FONTS / 'Montserrat_800ExtraBold.ttf'
THEMES = {
    'blue': ('#2563ff', '#06b6d4'), 'fire': ('#ff3d00', '#ffb300'), 'purple': ('#7c3aed', '#ec4899'),
    'green': ('#059669', '#a3e635'), 'dark': ('#111827', '#4b5563'), 'red': ('#dc2626', '#111111'),
}


def _rgb(hex_color):
    h = hex_color.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def colors(theme, ai_colors=None):
    if theme == 'ai' and ai_colors and len(ai_colors) == 2:
        return _rgb(ai_colors[0]), _rgb(ai_colors[1])
    a, b = THEMES.get(theme, THEMES['blue'])
    return _rgb(a), _rgb(b)


def _gradient(size, c1, c2):
    from PIL import Image
    w, h = size
    small = Image.new('RGB', (64, 36))
    px = small.load()
    for x in range(64):
        for y in range(36):
            t = (x / 63) * 0.7 + (y / 35) * 0.3
            px[x, y] = tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))
    return small.resize((w, h), Image.BICUBIC)


def _fit(draw, text, font_path, max_w, start):
    from PIL import ImageFont
    size = start
    while size > 20:
        font = ImageFont.truetype(str(font_path), size)
        box = draw.textbbox((0, 0), text, font=font)
        if box[2] - box[0] <= max_w:
            return font, box
        size -= 6
    font = ImageFont.truetype(str(font_path), size)
    return font, draw.textbbox((0, 0), text, font=font)


def banner(name, tagline, c1, c2, out: Path):
    from PIL import Image, ImageDraw
    img = _gradient((2560, 1440), c1, c2)
    layer = Image.new('RGBA', img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for i, (x, y, r) in enumerate([(300, 250, 420), (2250, 1200, 520), (2100, 220, 260), (500, 1250, 300)]):
        d.ellipse((x - r, y - r, x + r, y + r), fill=(255, 255, 255, 18 + i * 4))
    img = Image.alpha_composite(img.convert('RGBA'), layer)
    draw = ImageDraw.Draw(img)
    title = name.upper()
    font, box = _fit(draw, title, BLACK_FONT, 1420, 190)
    th = box[3] - box[1]
    sub_font, sbox = _fit(draw, tagline or '', BOLD_FONT, 1300, 74) if tagline else (None, (0, 0, 0, 0))
    total = th + (sbox[3] - sbox[1] + 36 if tagline else 0)
    top = 720 - total // 2
    x = (2560 - (box[2] - box[0])) // 2 - box[0]
    draw.text((x + 6, top - box[1] + 8), title, font=font, fill=(0, 0, 0, 90))
    draw.text((x, top - box[1]), title, font=font, fill=(255, 255, 255, 255))
    if tagline:
        sx = (2560 - (sbox[2] - sbox[0])) // 2 - sbox[0]
        draw.text((sx, top + th + 36 - sbox[1]), tagline, font=sub_font, fill=(255, 255, 255, 230))
    img.convert('RGB').save(out, 'PNG', optimize=True)
    return out


def logo(name, c1, c2, out: Path):
    from PIL import Image, ImageDraw
    words = [w for w in name.replace('_', ' ').split() if w[:1].isalnum()]
    initials = (''.join(w[0] for w in words[:2]) or name[:2] or 'C').upper()
    img = _gradient((800, 800), c1, c2).convert('RGBA')
    mask = Image.new('L', (800, 800), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, 799, 799), fill=255)
    img.putalpha(mask)
    draw = ImageDraw.Draw(img)
    font, box = _fit(draw, initials, BLACK_FONT, 560, 400)
    x = (800 - (box[2] - box[0])) // 2 - box[0]
    y = (800 - (box[3] - box[1])) // 2 - box[1]
    draw.text((x + 6, y + 8), initials, font=font, fill=(0, 0, 0, 80))
    draw.text((x, y), initials, font=font, fill=(255, 255, 255, 255))
    img.save(out, 'PNG')
    return out


def watermark(out: Path):
    from PIL import Image, ImageDraw
    img = Image.new('RGBA', (300, 300), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((6, 6, 294, 294), fill=(230, 33, 23, 255))
    d.polygon([(118, 92), (118, 208), (214, 150)], fill=(255, 255, 255, 255))
    img.resize((150, 150), Image.LANCZOS).save(out, 'PNG')
    return out
