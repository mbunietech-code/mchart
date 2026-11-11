"""Regenerate the iOS and macOS app icons from the MChart branding.

Run from the app/ directory (needs Pillow):  python tool/generate_apple_icons.py

- iOS uses the full-bleed square artwork (web/icons/Icon-maskable-512.png):
  iOS rounds the corners itself, and App Store icons must have no alpha.
- macOS uses assets/branding/mchart_logo.png (already a rounded tile) scaled
  to Apple's 824/1024 content area, so it sits like other Mac app icons.
"""
import json
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IOS_SRC = os.path.join(ROOT, "web", "icons", "Icon-maskable-512.png")
MAC_SRC = os.path.join(ROOT, "assets", "branding", "mchart_logo.png")
IOS_SET = os.path.join(ROOT, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
MAC_SET = os.path.join(ROOT, "macos", "Runner", "Assets.xcassets", "AppIcon.appiconset")
BACKGROUND = (0x18, 0x29, 0x85)  # matches ic_launcher_background on Android


def ios_icons():
    src = Image.open(IOS_SRC).convert("RGBA")
    flat = Image.new("RGB", src.size, BACKGROUND)
    flat.paste(src, mask=src.split()[3])
    with open(os.path.join(IOS_SET, "Contents.json")) as f:
        contents = json.load(f)
    for img in contents["images"]:
        base = float(img["size"].split("x")[0])
        px = round(base * int(img["scale"].rstrip("x")))
        out = flat.resize((px, px), Image.LANCZOS)
        out.save(os.path.join(IOS_SET, img["filename"]))
        print("ios", img["filename"], px)


def mac_icons():
    src = Image.open(MAC_SRC).convert("RGBA")
    master = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    tile = src.resize((824, 824), Image.LANCZOS)
    master.paste(tile, (100, 100), tile)
    for px in (16, 32, 64, 128, 256, 512, 1024):
        name = f"app_icon_{px}.png"
        master.resize((px, px), Image.LANCZOS).save(os.path.join(MAC_SET, name))
        print("macos", name, px)


ios_icons()
mac_icons()
