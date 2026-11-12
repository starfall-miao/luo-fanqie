"""从 assets/icon/app_icon.png 生成各平台应用图标。

用法：python3 tools/generate_icons.py
依赖：pillow
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets/icon/app_icon.png"
ADAPTIVE_BACKGROUND = (240, 238, 238)
ICON_INSET = 0.78


def load_master() -> Image.Image:
    image = Image.open(SOURCE).convert("RGB")
    side = min(image.size)
    left = (image.width - side) // 2
    top = (image.height - side) // 2
    return image.crop((left, top, left + side, top + side)).resize(
        (1024, 1024), Image.LANCZOS
    )


def resize(master: Image.Image, size: int) -> Image.Image:
    return master.resize((size, size), Image.LANCZOS)


def rounded(master: Image.Image, size: int, ratio: float = 0.22) -> Image.Image:
    image = resize(master, size).convert("RGBA")
    factor = 4
    mask = Image.new("L", (size * factor, size * factor), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle(
        (0, 0, size * factor - 1, size * factor - 1),
        radius=int(size * factor * ratio),
        fill=255,
    )
    image.putalpha(mask.resize((size, size), Image.LANCZOS))
    return image


def padded_icon(
    master: Image.Image,
    size: int,
    *,
    transparent: bool,
    ratio: float = ICON_INSET,
    radius: float = 0.2,
) -> Image.Image:
    inner = max(1, int(size * ratio))
    icon = rounded(master, inner, radius)
    canvas = Image.new(
        "RGBA", (size, size), (0, 0, 0, 0) if transparent else (*ADAPTIVE_BACKGROUND, 255)
    )
    offset = ((size - inner) // 2, (size - inner) // 2)
    canvas.alpha_composite(icon, offset)
    return canvas


def save(image: Image.Image, path: Path, *, flatten: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if flatten and image.mode == "RGBA":
        background = Image.new("RGB", image.size, "white")
        background.paste(image, mask=image.getchannel("A"))
        image = background
    image.save(path, optimize=True)
    print(f"  {path.relative_to(ROOT)}  {image.width}x{image.height}")


def main() -> None:
    master = load_master()
    print("源图:", SOURCE.relative_to(ROOT), master.size)
    save(master, ROOT / "assets/icon/app_icon.png")

    print("Android legacy…")
    for density, px in {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }.items():
        save(resize(master, px), ROOT / f"android/app/src/main/res/mipmap-{density}/ic_launcher.png")

    print("Android adaptive foreground…")
    for density, px in {
        "mdpi": 108,
        "hdpi": 162,
        "xhdpi": 216,
        "xxhdpi": 324,
        "xxxhdpi": 432,
    }.items():
        save(
            padded_icon(master, px, transparent=True),
            ROOT / f"android/app/src/main/res/mipmap-{density}/ic_launcher_foreground.png",
        )

    print("Android splash logo…")
    save(
        rounded(master, 256, 0.22),
        ROOT / "android/app/src/main/res/drawable-nodpi/launch_logo.png",
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
        save(resize(master, px), ios_dir / filename, flatten=True)

    print("macOS icons…")
    macos_dir = ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    for name, px in {
        "app_icon_16.png": 16,
        "app_icon_32.png": 32,
        "app_icon_64.png": 64,
        "app_icon_128.png": 128,
        "app_icon_256.png": 256,
        "app_icon_512.png": 512,
        "app_icon_1024.png": 1024,
    }.items():
        save(rounded(master, px, 0.18), macos_dir / name, flatten=True)

    print("Windows icon…")
    ico = ROOT / "windows/runner/resources/app_icon.ico"
    resize(master, 256).save(
        ico,
        format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )
    print("  windows/runner/resources/app_icon.ico")

    print("Web icons…")
    save(resize(master, 192), ROOT / "web/icons/Icon-192.png")
    save(resize(master, 512), ROOT / "web/icons/Icon-512.png")
    save(padded_icon(master, 192, transparent=False), ROOT / "web/icons/Icon-maskable-192.png")
    save(padded_icon(master, 512, transparent=False), ROOT / "web/icons/Icon-maskable-512.png")
    save(resize(master, 32), ROOT / "web/favicon.png", flatten=True)

    print("完成。")


if __name__ == "__main__":
    main()
