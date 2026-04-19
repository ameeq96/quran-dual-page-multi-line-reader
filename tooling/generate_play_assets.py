from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
ANDROID_RES = ROOT / "android" / "app" / "src" / "main" / "res"
BRANDING_DIR = ROOT / "assets" / "branding"
MASTER_ICON_PATH = ROOT / "branding" / "user_app_icon_master.png"
PLAY_FEATURE_BACKGROUND_PATH = BRANDING_DIR / "play_feature_background.png"
PLAY_ASSETS_DIR = ROOT / "play_store" / "assets"

PARCHMENT_TOP = (246, 241, 228)
PARCHMENT_BOTTOM = (234, 224, 198)
PARCHMENT_SOFT = (252, 249, 241)
EMERALD = (12, 87, 78)
EMERALD_DARK = (7, 56, 50)
GOLD = (191, 144, 64)
GOLD_LIGHT = (222, 186, 112)
INK = (27, 43, 39)


def _ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def _lerp_channel(start: int, end: int, factor: float) -> int:
    return int(round(start + ((end - start) * factor)))


def _vertical_gradient(size: tuple[int, int], top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    width, height = size
    image = Image.new("RGB", size, bottom)
    draw = ImageDraw.Draw(image)
    denominator = max(height - 1, 1)
    for y in range(height):
        factor = y / denominator
        color = tuple(_lerp_channel(top[i], bottom[i], factor) for i in range(3))
        draw.line((0, y, width, y), fill=color)
    return image


def _load_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    font_candidates = [
        Path("C:/Windows/Fonts/segoeuib.ttf" if bold else "C:/Windows/Fonts/segoeui.ttf"),
        Path("C:/Windows/Fonts/arialbd.ttf" if bold else "C:/Windows/Fonts/arial.ttf"),
        Path("C:/Windows/Fonts/calibrib.ttf" if bold else "C:/Windows/Fonts/calibri.ttf"),
    ]
    for font_path in font_candidates:
        if font_path.exists():
            return ImageFont.truetype(str(font_path), size=size)
    return ImageFont.load_default()


def _draw_book_mark(canvas: Image.Image, bounds: tuple[int, int, int, int], include_shadow: bool = True) -> None:
    draw = ImageDraw.Draw(canvas)
    left, top, right, bottom = bounds
    width = right - left
    height = bottom - top
    center_x = left + (width / 2)
    center_y = top + (height / 2)

    if include_shadow:
        shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        shadow_draw = ImageDraw.Draw(shadow)
        shadow_draw.ellipse(bounds, fill=(0, 0, 0, 80))
        shadow_draw.rounded_rectangle(
            (
                int(left + (width * 0.08)),
                int(top + (height * 0.1)),
                int(right - (width * 0.08)),
                int(bottom - (height * 0.08)),
            ),
            radius=int(width * 0.22),
            fill=(0, 0, 0, 0),
            outline=(0, 0, 0, 0),
        )
        shadow = shadow.filter(ImageFilter.GaussianBlur(radius=max(width // 32, 8)))
        canvas.alpha_composite(shadow)
        draw = ImageDraw.Draw(canvas)

    draw.ellipse(bounds, fill=EMERALD)
    ring_bounds = (
        int(left + (width * 0.06)),
        int(top + (height * 0.06)),
        int(right - (width * 0.06)),
        int(bottom - (height * 0.06)),
    )
    draw.ellipse(ring_bounds, outline=GOLD_LIGHT, width=max(width // 48, 6))

    page_margin_x = width * 0.19
    page_top = top + (height * 0.28)
    page_bottom = bottom - (height * 0.20)
    spine_width = width * 0.05
    spine_left = center_x - (spine_width / 2)
    spine_right = center_x + (spine_width / 2)

    left_page = [
        (left + page_margin_x, page_top + (height * 0.04)),
        (center_x - (width * 0.06), page_top),
        (center_x - (width * 0.03), page_bottom - (height * 0.02)),
        (left + (width * 0.22), page_bottom),
    ]
    right_page = [
        (center_x + (width * 0.06), page_top),
        (right - page_margin_x, page_top + (height * 0.04)),
        (right - (width * 0.22), page_bottom),
        (center_x + (width * 0.03), page_bottom - (height * 0.02)),
    ]
    draw.polygon(left_page, fill=PARCHMENT_SOFT, outline=GOLD)
    draw.polygon(right_page, fill=PARCHMENT_SOFT, outline=GOLD)
    draw.rounded_rectangle(
        (spine_left, page_top - (height * 0.02), spine_right, page_bottom + (height * 0.02)),
        radius=max(int(spine_width / 2), 4),
        fill=GOLD,
    )

    for index in range(4):
        offset_y = page_top + (height * (0.06 + (index * 0.10)))
        draw.line(
            (
                left + (width * 0.27),
                offset_y,
                center_x - (width * 0.10),
                offset_y - (height * 0.015),
            ),
            fill=EMERALD_DARK,
            width=max(width // 90, 3),
        )
        draw.line(
            (
                center_x + (width * 0.10),
                offset_y - (height * 0.015),
                right - (width * 0.27),
                offset_y,
            ),
            fill=EMERALD_DARK,
            width=max(width // 90, 3),
        )

    arch_bounds = (
        int(left + (width * 0.28)),
        int(top + (height * 0.12)),
        int(right - (width * 0.28)),
        int(top + (height * 0.42)),
    )
    draw.arc(arch_bounds, start=185, end=355, fill=GOLD_LIGHT, width=max(width // 52, 5))
    draw.ellipse(
        (
            int(center_x - (width * 0.035)),
            int(top + (height * 0.18)),
            int(center_x + (width * 0.035)),
            int(top + (height * 0.25)),
        ),
        fill=GOLD_LIGHT,
    )


def _create_generated_icon_source() -> Image.Image:
    canvas = _vertical_gradient((1024, 1024), PARCHMENT_TOP, PARCHMENT_BOTTOM).convert("RGBA")
    draw = ImageDraw.Draw(canvas)

    glow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.ellipse((108, 122, 916, 930), fill=(255, 255, 255, 74))
    glow = glow.filter(ImageFilter.GaussianBlur(radius=58))
    canvas.alpha_composite(glow)

    _draw_book_mark(canvas, (182, 180, 842, 840))

    draw.rounded_rectangle(
        (124, 124, 900, 900),
        radius=220,
        outline=(255, 255, 255, 92),
        width=4,
    )
    return canvas


def _load_icon_source() -> Image.Image:
    if MASTER_ICON_PATH.exists():
        return Image.open(MASTER_ICON_PATH).convert("RGBA")
    return _create_generated_icon_source()


def _create_foreground_source(icon_source: Image.Image) -> Image.Image:
    canvas = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    safe_size = 336
    padded_icon = icon_source.resize((safe_size, safe_size), Image.Resampling.LANCZOS)
    offset = (432 - safe_size) // 2
    canvas.alpha_composite(padded_icon, dest=(offset, offset))
    return canvas


def _create_feature_graphic(icon_source: Image.Image) -> Image.Image:
    width = 1024
    height = 500
    canvas = _vertical_gradient((width, height), (248, 242, 228), (232, 223, 199)).convert("RGBA")
    draw = ImageDraw.Draw(canvas)

    soft_blob = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    blob_draw = ImageDraw.Draw(soft_blob)
    blob_draw.ellipse((-40, 250, 380, 700), fill=(255, 255, 255, 105))
    blob_draw.ellipse((660, -40, 1100, 330), fill=(255, 255, 255, 80))
    soft_blob = soft_blob.filter(ImageFilter.GaussianBlur(radius=60))
    canvas.alpha_composite(soft_blob)

    card_bounds = (64, 58, 408, 442)
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle(card_bounds, radius=42, fill=(0, 0, 0, 70))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=28))
    canvas.alpha_composite(shadow)

    draw.rounded_rectangle(card_bounds, radius=42, fill=(255, 252, 246, 236))
    inset_icon = icon_source.resize((232, 232), Image.Resampling.LANCZOS)
    canvas.alpha_composite(inset_icon, dest=(120, 134))

    title_font = _load_font(40, bold=True)
    subtitle_font = _load_font(24, bold=False)
    caption_font = _load_font(19, bold=False)

    text_x = 446
    draw.text((text_x, 108), "Quran Pak", font=title_font, fill=INK)
    draw.text((text_x, 152), "Dual Page Reader", font=title_font, fill=INK)
    draw.text(
        (text_x, 206),
        "Offline multi-line Mushaf reader",
        font=subtitle_font,
        fill=EMERALD,
    )
    draw.text(
        (text_x, 242),
        "Edition-aware navigation, dual-page reading,",
        font=caption_font,
        fill=(70, 73, 67),
    )
    draw.text(
        (text_x, 273),
        "audio support, and smooth offline Quran study.",
        font=caption_font,
        fill=(70, 73, 67),
    )
    draw.text(
        (text_x, 304),
        "Built for reliable daily reading.",
        font=caption_font,
        fill=(70, 73, 67),
    )

    chip_font = _load_font(20, bold=True)
    chips = ["Offline", "Multi-line", "Smooth Reader"]
    chip_x = text_x
    for chip in chips:
        bbox = draw.textbbox((0, 0), chip, font=chip_font)
        chip_w = (bbox[2] - bbox[0]) + 34
        draw.rounded_rectangle(
            (chip_x, 356, chip_x + chip_w, 398),
            radius=22,
            fill=(255, 250, 240, 214),
            outline=(191, 144, 64, 130),
            width=2,
        )
        draw.text((chip_x + 17, 367), chip, font=chip_font, fill=EMERALD_DARK)
        chip_x += chip_w + 14

    return canvas


def _crop_to_ratio(image: Image.Image, target_width: int, target_height: int) -> Image.Image:
    source = image.convert("RGBA")
    src_w, src_h = source.size
    src_ratio = src_w / src_h
    target_ratio = target_width / target_height
    if src_ratio > target_ratio:
        next_w = int(src_h * target_ratio)
        left = (src_w - next_w) // 2
        source = source.crop((left, 0, left + next_w, src_h))
    elif src_ratio < target_ratio:
        next_h = int(src_w / target_ratio)
        top = (src_h - next_h) // 2
        source = source.crop((0, top, src_w, top + next_h))
    return source.resize((target_width, target_height), Image.Resampling.LANCZOS)


def _wrap_text(
    draw: ImageDraw.ImageDraw,
    text: str,
    font: ImageFont.FreeTypeFont | ImageFont.ImageFont,
    max_width: int,
) -> list[str]:
    words = text.split()
    if not words:
        return []

    lines: list[str] = []
    current = words[0]
    for word in words[1:]:
        candidate = f"{current} {word}"
        bbox = draw.textbbox((0, 0), candidate, font=font)
        if (bbox[2] - bbox[0]) <= max_width:
            current = candidate
            continue
        lines.append(current)
        current = word
    lines.append(current)
    return lines


def _compose_feature_graphic(background: Image.Image) -> Image.Image:
    canvas = _crop_to_ratio(background, 1024, 500)

    panel = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    panel_draw = ImageDraw.Draw(panel)
    panel_bounds = (508, 52, 978, 448)
    panel_draw.rounded_rectangle(
        panel_bounds,
        radius=34,
        fill=(4, 34, 31, 176),
        outline=(225, 191, 110, 224),
        width=3,
    )
    panel_glow = panel.filter(ImageFilter.GaussianBlur(radius=18))
    canvas.alpha_composite(panel_glow)
    canvas.alpha_composite(panel)
    draw = ImageDraw.Draw(canvas)

    title_font = _load_font(38, bold=True)
    subtitle_font = _load_font(18, bold=False)
    chip_font = _load_font(15, bold=True)
    feature_font = _load_font(20, bold=True)
    detail_font = _load_font(15, bold=False)

    chip_bounds = (548, 84, 766, 122)
    draw.rounded_rectangle(
        chip_bounds,
        radius=19,
        fill=(228, 192, 110, 238),
    )
    draw.text((566, 93), "OFFLINE QURAN READER", font=chip_font, fill=EMERALD_DARK)

    draw.text((544, 128), "Quran Pak", font=title_font, fill=(255, 247, 227))
    draw.text((544, 170), "Dual Page Reader", font=title_font, fill=(255, 247, 227))
    subtitle_lines = _wrap_text(
        draw,
        "Smooth Mushaf reading with powerful daily-study tools.",
        subtitle_font,
        max_width=388,
    )
    subtitle_y = 220
    for line in subtitle_lines:
        draw.text((544, subtitle_y), line, font=subtitle_font, fill=(226, 235, 229))
        subtitle_y += 22

    features = [
        ("Dual-Page Reading", "Natural open-book Mushaf flow"),
        ("Multi-Line Editions", "10, 13, 14, 15, 16, and 17 line support"),
        ("Surah & Sipara Search", "Edition-aware jumps for fast navigation"),
        ("Audio, Notes & Bookmarks", "Study, save progress, and revisit easily"),
    ]

    bullet_x = 548
    title_x = 582
    start_y = 226 + (len(subtitle_lines) * 20)
    row_gap = 40
    for index, (heading, detail) in enumerate(features):
        row_y = start_y + (index * row_gap)
        draw.ellipse(
            (bullet_x, row_y + 7, bullet_x + 18, row_y + 25),
            fill=(225, 191, 110, 244),
        )
        draw.text((title_x, row_y), heading, font=feature_font, fill=(255, 248, 232))
        draw.text((title_x, row_y + 22), detail, font=detail_font, fill=(216, 226, 221))

    return canvas


def _write_png(path: Path, image: Image.Image, size: tuple[int, int] | None = None) -> None:
    _ensure_dir(path.parent)
    output = image.resize(size, Image.Resampling.LANCZOS) if size else image
    output.save(path, format="PNG")


def main() -> None:
    icon = _load_icon_source()
    foreground = _create_foreground_source(icon)
    if PLAY_FEATURE_BACKGROUND_PATH.exists():
        background = Image.open(PLAY_FEATURE_BACKGROUND_PATH)
        feature = _compose_feature_graphic(background)
    else:
        feature = _create_feature_graphic(icon)

    _write_png(BRANDING_DIR / "adaptive_foreground.png", foreground)
    _write_png(PLAY_ASSETS_DIR / "google-play-icon-512.png", icon, size=(512, 512))
    _write_png(PLAY_ASSETS_DIR / "google-play-feature-graphic.png", feature)

    densities = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for directory, size in densities.items():
        _write_png(ANDROID_RES / directory / "ic_launcher.png", icon, size=(size, size))
        _write_png(ANDROID_RES / directory / "ic_launcher_round.png", icon, size=(size, size))

    _write_png(
        ANDROID_RES / "drawable-nodpi" / "ic_launcher_foreground.png",
        foreground,
    )


if __name__ == "__main__":
    main()
