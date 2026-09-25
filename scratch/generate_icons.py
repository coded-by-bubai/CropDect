"""
Replace ALL app icons with app_logo.jpg:
- Android launcher icons (mipmap-*): 48, 72, 96, 144, 192 px
- Android notification icon (drawable): 24px white silhouette
- Web icons: favicon 32px, Icon-192, Icon-512, maskable versions
"""
from PIL import Image, ImageDraw, ImageOps
import os
import shutil

BASE = r"c:\Users\Bubai Das\Desktop\programming\Project\CropDect_AI\cropdect"
LOGO_SRC = os.path.join(BASE, "assets", "app_logo.jpg")

img = Image.open(LOGO_SRC).convert("RGBA")

def make_square(im, size, bg=(0,0,0,0)):
    """Resize and crop to square, then resize to target."""
    w, h = im.size
    min_side = min(w, h)
    left = (w - min_side) // 2
    top = (h - min_side) // 2
    im = im.crop((left, top, left + min_side, top + min_side))
    im = im.resize((size, size), Image.LANCZOS)
    return im

def make_circle(im, size):
    """Make a round launcher icon (standard Android style)."""
    im = make_square(im, size)
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse((0, 0, size, size), fill=255)
    result = Image.new("RGBA", (size, size), (0,0,0,0))
    result.paste(im, mask=mask)
    return result

# ─── Android Launcher Icons ───────────────────────────────────────────────────
mipmap_dirs = {
    "mipmap-mdpi":    48,
    "mipmap-hdpi":    72,
    "mipmap-xhdpi":   96,
    "mipmap-xxhdpi":  144,
    "mipmap-xxxhdpi": 192,
}

res_path = os.path.join(BASE, "android", "app", "src", "main", "res")

for folder, size in mipmap_dirs.items():
    out_dir = os.path.join(res_path, folder)
    os.makedirs(out_dir, exist_ok=True)
    icon = make_square(img, size)
    icon.save(os.path.join(out_dir, "ic_launcher.png"), "PNG")
    icon.save(os.path.join(out_dir, "ic_launcher_round.png"), "PNG")
    print(f"  ✓ {folder}/ic_launcher.png ({size}x{size})")

# ─── Android Notification Icon (white silhouette) ─────────────────────────────
# Android notifications look best with a solid white icon on transparent bg
def make_notification_icon(im, size=96):
    """Create a white monochrome silhouette for notification bar."""
    im = make_square(im, size)
    # Convert to grayscale, threshold, make white on transparent
    gray = im.convert("L")
    result = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    pixels = result.load()
    gray_pixels = gray.load()
    for y in range(size):
        for x in range(size):
            brightness = gray_pixels[x, y]
            # Non-background pixels become white
            if brightness < 240:
                pixels[x, y] = (255, 255, 255, 255)
    return result

drawable_dir = os.path.join(res_path, "drawable")
os.makedirs(drawable_dir, exist_ok=True)
notif_icon = make_notification_icon(img, 96)
notif_icon.save(os.path.join(drawable_dir, "ic_notification.png"), "PNG")
print(f"  ✓ drawable/ic_notification.png (96x96 white)")

# ─── Web Icons ────────────────────────────────────────────────────────────────
web_icons_dir = os.path.join(BASE, "web", "icons")
os.makedirs(web_icons_dir, exist_ok=True)

# favicon
favicon = make_square(img, 32)
favicon.save(os.path.join(BASE, "web", "favicon.png"), "PNG")
print(f"  ✓ web/favicon.png (32x32)")

# Standard icons
for size, name in [(192, "Icon-192.png"), (512, "Icon-512.png")]:
    icon = make_square(img, size)
    icon.save(os.path.join(web_icons_dir, name), "PNG")
    print(f"  ✓ web/icons/{name} ({size}x{size})")

# Maskable icons (add padding 10% for safe zone)
for size, name in [(192, "Icon-maskable-192.png"), (512, "Icon-maskable-512.png")]:
    padding = int(size * 0.1)
    inner_size = size - padding * 2
    inner = make_square(img, inner_size)
    # Green background matching app theme
    maskable = Image.new("RGBA", (size, size), (4, 105, 56, 255))
    maskable.paste(inner, (padding, padding), inner)
    maskable.save(os.path.join(web_icons_dir, name), "PNG")
    print(f"  ✓ web/icons/{name} ({size}x{size} maskable)")

print("\n✅ All icons replaced with app_logo.jpg!")
print("   → Now update main.dart notification icon to 'ic_notification'")
