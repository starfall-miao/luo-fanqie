"""生成落·番茄的应用图标（Android / iOS / Web）。

用法：python3 tools/generate_icons.py
依赖：pillow、numpy
"""

from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
WORK = 1536

TOMATO_TOP = np.array([255, 201, 120], dtype=np.float32)
TOMATO_MID = np.array([255, 122, 89], dtype=np.float32)
TOMATO_BOTTOM = np.array([232, 80, 54], dtype=np.float32)
LEAF = (120, 168, 139, 255)
LEAF_DARK = (86, 136, 111, 255)
CREAM = (255, 246, 238, 255)
PLUM = (42, 23, 34, 255)

_BACKGROUND_CACHE: Image.Image | None = None
_ICON_CACHE: dict[float, Image.Image] = {}


def _background(size: int = WORK) -> Image.Image:
    global _BACKGROUND_CACHE
    if _BACKGROUND_CACHE is not None:
        return _BACKGROUND_CACHE
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    x /= size - 1
    y /= size - 1
    # 深梅色夜幕，带一点对角提亮
    top = np.array([48, 26, 40], dtype=np.float32)
    bottom = np.array([27, 14, 22], dtype=np.float32)
    t = np.clip(x * 0.28 + y * 0.72, 0, 1)[..., None]
    rgb = top * (1 - t) + bottom * t
    # 中心落日余晖
    dist = np.sqrt((x - 0.5) ** 2 + (y - 0.62) ** 2)
    glow = np.clip(1 - dist / 0.62, 0, 1) ** 2.2
    warm = np.array([255, 132, 92], dtype=np.float32)
    rgb = rgb * (1 - 0.28 * glow[..., None]) + warm * 0.28 * glow[..., None]
    # 四角暗角
    vignette = np.clip(
        1.12 - 0.45 * np.sqrt((x - 0.5) ** 2 + (y - 0.5) ** 2), 0.55, 1.05
    )
    rgb *= vignette[..., None]
    _BACKGROUND_CACHE = Image.fromarray(
        np.clip(rgb, 0, 255).astype(np.uint8), "RGB"
    ).convert("RGBA")
    return _BACKGROUND_CACHE


def _tomato_body(center: tuple[float, float], radius: float) -> Image.Image:
    size = WORK
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    cx, cy = center
    radius_px = radius * size
    dx = (x - cx * size) / radius_px
    dy = (y - cy * size) / radius_px
    inside = (dx * dx + dy * dy) <= 1.0
    shade = np.clip((dy + 0.9) / 1.9, 0, 1)
    # 先在上半段从亮黄过渡到橙红，再向下压深
    lower = np.clip((shade - 0.55) / 0.45, 0, 1)[..., None]
    upper = np.clip(shade / 0.55, 0, 1)[..., None]
    upper_color = (
        TOMATO_TOP[None, None, :] * (1 - upper)
        + TOMATO_MID[None, None, :] * upper
    )
    rgb = upper_color * (1 - lower) + TOMATO_BOTTOM[None, None, :] * lower
    # 左上高光
    hl = np.exp(-(((dx + 0.35) ** 2) / 0.16 + ((dy + 0.42) ** 2) / 0.09))
    rgb = rgb + (255 - rgb) * np.clip(hl, 0, 1)[..., None] * 0.28
    alpha = inside.astype(np.uint8) * 255
    body = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    body.putalpha(Image.fromarray(alpha, "L"))
    return body


def _leaf(direction_deg: float, length: float, width: float, base: tuple[float, float]) -> Image.Image:
    layer = Image.new("RGBA", (WORK, WORK), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    angle = math.radians(direction_deg)
    dx, dy = math.sin(angle), -math.cos(angle)
    px, py = math.cos(angle), math.sin(angle)
    bx, by = base
    tip = (bx + dx * length, by + dy * length)
    samples = 18
    left_points = []
    right_points = []
    for i in range(samples + 1):
        t = i / samples
        # 叶形轮廓：中间宽，两端收尖
        bulge = math.sin(math.pi * t) * width * 0.5
        cx = bx + (tip[0] - bx) * t + px * bulge
        cy = by + (tip[1] - by) * t + py * bulge
        left_points.append((cx, cy))
        cx2 = bx + (tip[0] - bx) * t - px * bulge
        cy2 = by + (tip[1] - by) * t - py * bulge
        right_points.append((cx2, cy2))
    points = left_points + list(reversed(right_points))
    draw.polygon(points, fill=LEAF)
    # 叶脉
    draw.line(
        [(bx, by), (bx + dx * length * 0.86, by + dy * length * 0.86)],
        fill=LEAF_DARK,
        width=max(2, int(width * 0.08)),
    )
    return layer.filter(ImageFilter.GaussianBlur(0.8))


def _mark(size: int, scale: float = 1.0, with_glow: bool = True) -> Image.Image:
    """透明背景的番茄标记。"""
    layer = Image.new("RGBA", (WORK, WORK), (0, 0, 0, 0))
    cx, cy = 0.5, 0.585
    radius = 0.255 * scale
    if with_glow:
        glow = Image.new("RGBA", (WORK, WORK), (0, 0, 0, 0))
        gd = ImageDraw.Draw(glow)
        gr = radius * 1.8
        gd.ellipse(
            (
                (cx - gr) * WORK,
                (cy - gr) * WORK,
                (cx + gr) * WORK,
                (cy + gr) * WORK,
            ),
            fill=(255, 122, 89, 52),
        )
        glow = glow.filter(ImageFilter.GaussianBlur(WORK * 0.035))
        layer = Image.alpha_composite(layer, glow)

    body = _tomato_body((cx, cy), radius)
    layer = Image.alpha_composite(layer, body)

    # 高光小椭圆
    highlight = Image.new("RGBA", (WORK, WORK), (0, 0, 0, 0))
    hd = ImageDraw.Draw(highlight)
    hx = (cx - radius * 0.34) * WORK
    hy = (cy - radius * 0.40) * WORK
    hw, hh = radius * 0.46 * WORK, radius * 0.24 * WORK
    hd.ellipse((hx - hw / 2, hy - hh / 2, hx + hw / 2, hy + hh / 2), fill=(255, 255, 255, 90))
    highlight = highlight.rotate(-28, center=(hx, hy), resample=Image.BICUBIC)
    layer = Image.alpha_composite(layer, highlight)

    stem_base = ((cx) * WORK, (cy - radius * 0.93) * WORK)
    for angle, length_ratio, width_ratio in [
        (-64, 0.17, 0.060),
        (-32, 0.20, 0.066),
        (0, 0.22, 0.070),
        (32, 0.20, 0.066),
        (64, 0.17, 0.060),
    ]:
        layer = Image.alpha_composite(
            layer,
            _leaf(
                angle,
                length_ratio * scale * WORK,
                width_ratio * scale * WORK,
                stem_base,
            ),
        )

    stem = Image.new("RGBA", (WORK, WORK), (0, 0, 0, 0))
    sd = ImageDraw.Draw(stem)
    sx, sy = stem_base
    sd.line(
        [(sx, sy), (sx + radius * 0.30 * WORK, sy - radius * 0.38 * WORK)],
        fill=LEAF_DARK,
        width=max(3, int(radius * 0.075 * WORK)),
        joint="curve",
    )
    layer = Image.alpha_composite(layer, stem)

    final_size = size
    return layer.resize((final_size, final_size), Image.LANCZOS)


def icon(size: int, mark_scale: float = 1.0) -> Image.Image:
    key = round(mark_scale, 3)
    composed = _ICON_CACHE.get(key)
    if composed is None:
        base = _background().copy()
        mark = _mark(WORK, scale=mark_scale)
        composed = Image.alpha_composite(base, mark)
        _ICON_CACHE[key] = composed
    return composed.resize((size, size), Image.LANCZOS).convert("RGBA")


def foreground(size: int) -> Image.Image:
    if 0.86 not in _ICON_CACHE:
        _ICON_CACHE[0.86] = _mark(WORK, scale=0.86, with_glow=True)
    return _ICON_CACHE[0.86].resize((size, size), Image.LANCZOS)


def save(image: Image.Image, path: Path, *, rgb: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if rgb:
        flat = Image.new("RGB", image.size, (42, 23, 34))
        flat.paste(image, mask=image.getchannel("A"))
        flat.save(path, optimize=True)
    else:
        image.save(path, optimize=True)
    print(f"  {path.relative_to(ROOT)}  {image.size[0]}x{image.size[1]}")


def main() -> None:
    print("生成主图标…")
    master = icon(1024)
    save(master, ROOT / "assets/icon/app_icon.png")

    print("Android legacy icons…")
    for density, px in {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }.items():
        save(icon(px), ROOT / f"android/app/src/main/res/mipmap-{density}/ic_launcher.png")

    print("Android adaptive foreground…")
    for density, px in {
        "mdpi": 108,
        "hdpi": 162,
        "xhdpi": 216,
        "xxhdpi": 324,
        "xxxhdpi": 432,
    }.items():
        save(foreground(px), ROOT / f"android/app/src/main/res/mipmap-{density}/ic_launcher_foreground.png")

    adaptive_dir = ROOT / "android/app/src/main/res/mipmap-anydpi-v26"
    adaptive_dir.mkdir(parents=True, exist_ok=True)
    (adaptive_dir / "ic_launcher.xml").write_text(
        """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
""",
        encoding="utf-8",
    )
    values = ROOT / "android/app/src/main/res/values"
    values.mkdir(parents=True, exist_ok=True)
    (values / "colors.xml").write_text(
        """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#2A1722</color>
    <color name="launch_background">#2A1722</color>
</resources>
""",
        encoding="utf-8",
    )
    launch_logo = _mark(256, scale=1.0, with_glow=False)
    save(launch_logo, ROOT / "android/app/src/main/res/drawable-nodpi/launch_logo.png")

    launch_master = _mark(504, scale=1.0, with_glow=False)
    for suffix, px in [("", 168), ("@2x", 336), ("@3x", 504)]:
        launch_master.resize((px, px), Image.LANCZOS).save(
            ROOT
            / f"ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage{suffix}.png",
            optimize=True,
        )
        print(
            "  ios/Runner/Assets.xcassets/LaunchImage.imageset/"
            f"LaunchImage{suffix}.png  {px}x{px}"
        )

    print("iOS icons…")
    ios_dir = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((ios_dir / "Contents.json").read_text())
    for item in contents.get("images", []):
        filename = item.get("filename")
        size = item.get("size", "0x0")
        scale = item.get("scale", "1x")
        if not filename:
            continue
        try:
            base_px = float(size.split("x")[0])
            factor = float(scale.rstrip("x"))
        except ValueError:
            continue
        px = int(round(base_px * factor))
        save(icon(px), ios_dir / filename, rgb=True)

    print("Web icons…")
    web_dir = ROOT / "web"
    save(icon(192), web_dir / "icons/Icon-192.png")
    save(icon(512), web_dir / "icons/Icon-512.png")
    save(icon(192, mark_scale=0.78), web_dir / "icons/Icon-maskable-192.png")
    save(icon(512, mark_scale=0.78), web_dir / "icons/Icon-maskable-512.png")
    save(icon(32), web_dir / "favicon.png", rgb=True)


    print("macOS icons…")
    macos_dir = ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    macos_dir.mkdir(parents=True, exist_ok=True)
    for name, px in {
        "app_icon_16.png": 16,
        "app_icon_32.png": 32,
        "app_icon_64.png": 64,
        "app_icon_128.png": 128,
        "app_icon_256.png": 256,
        "app_icon_512.png": 512,
        "app_icon_1024.png": 1024,
    }.items():
        save(icon(px), macos_dir / name, rgb=True)

    print("Windows icon…")
    windows_icon = ROOT / "windows/runner/resources/app_icon.ico"
    windows_icon.parent.mkdir(parents=True, exist_ok=True)
    icon(256).save(
        windows_icon,
        format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )
    print(f"  {windows_icon.relative_to(ROOT)}")

    print("启动图…")
    (ROOT / "android/app/src/main/res/drawable/launch_background.xml").write_text(
        """<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/launch_background" />
    <item>
        <bitmap
            android:gravity="center"
            android:src="@drawable/launch_logo" />
    </item>
</layer-list>
""",
        encoding="utf-8",
    )
    (ROOT / "android/app/src/main/res/drawable-v21/launch_background.xml").write_text(
        """<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/launch_background" />
    <item>
        <bitmap
            android:gravity="center"
            android:src="@drawable/launch_logo" />
    </item>
</layer-list>
""",
        encoding="utf-8",
    )
    print("完成。")


if __name__ == "__main__":
    main()
