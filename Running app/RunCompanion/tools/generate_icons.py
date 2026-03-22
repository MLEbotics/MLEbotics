"""
Regenerate all app icons from MLE.png source logo.
Run from the project root: python tools/generate_icons.py
"""
from PIL import Image
import os
import struct
import zlib

SRC = "MLE.png"

def make_ico(src_image, output_path, sizes=(16,32,48,64,128,256)):
    """Create a proper multi-size ICO file."""
    imgs = []
    for s in sizes:
        img = src_image.resize((s, s), Image.LANCZOS)
        imgs.append(img)
    
    # ICO format: ICONDIR header + ICONDIRENTRY * n + image data
    num_images = len(imgs)
    header = struct.pack("<HHH", 0, 1, num_images)  # reserved, type=1(ICO), count
    
    # Each entry is 16 bytes; data starts after header + entries
    data_offset = 6 + 16 * num_images
    
    entries = b""
    image_data_list = []
    
    for img in imgs:
        import io
        buf = io.BytesIO()
        img.save(buf, format="PNG")
        png_data = buf.getvalue()
        w, h = img.size
        
        entry = struct.pack(
            "<BBBBHHII",
            w if w < 256 else 0,   # width (0 = 256)
            h if h < 256 else 0,   # height (0 = 256)
            0,    # color count (0 = no palette)
            0,    # reserved
            1,    # color planes
            32,   # bits per pixel
            len(png_data),
            data_offset
        )
        entries += entry
        image_data_list.append(png_data)
        data_offset += len(png_data)
    
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "wb") as f:
        f.write(header + entries)
        for data in image_data_list:
            f.write(data)
    print(f"  Written: {output_path} ({os.path.getsize(output_path)} bytes)")

def save_png(src_image, path, size):
    os.makedirs(os.path.dirname(path) if os.path.dirname(path) else ".", exist_ok=True)
    img = src_image.resize((size, size), Image.LANCZOS)
    img.save(path, "PNG")
    print(f"  Written: {path} ({size}x{size})")

def main():
    if not os.path.exists(SRC):
        print(f"ERROR: {SRC} not found. Run from project root.")
        return
    
    src = Image.open(SRC).convert("RGBA")
    print(f"Source: {SRC} {src.size}")

    # ── Windows ICO ──────────────────────────────────────────────────
    print("\n[Windows]")
    make_ico(src, r"windows\runner\resources\app_icon.ico", (16,32,48,64,128,256))

    # ── Android mipmaps ──────────────────────────────────────────────
    print("\n[Android]")
    android_sizes = {
        "mipmap-mdpi":    48,
        "mipmap-hdpi":    72,
        "mipmap-xhdpi":   96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi":192,
    }
    for folder, size in android_sizes.items():
        path = os.path.join("android", "app", "src", "main", "res", folder, "ic_launcher.png")
        save_png(src, path, size)
        # Also write round launcher
        round_path = os.path.join("android", "app", "src", "main", "res", folder, "ic_launcher_round.png")
        save_png(src, round_path, size)

    # ── iOS AppIcon ───────────────────────────────────────────────────
    print("\n[iOS]")
    ios_base = os.path.join("ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    ios_sizes = [20,29,40,58,60,76,80,87,120,152,167,180,1024]
    for s in ios_sizes:
        path = os.path.join(ios_base, f"Icon-App-{s}x{s}@1x.png")
        save_png(src, path, s)

    # ── macOS AppIcon ─────────────────────────────────────────────────
    print("\n[macOS]")
    macos_base = os.path.join("macos", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    macos_sizes = [16,32,64,128,256,512,1024]
    for s in macos_sizes:
        save_png(src, os.path.join(macos_base, f"app_icon_{s}.png"), s)

    # ── Web ───────────────────────────────────────────────────────────
    print("\n[Web]")
    save_png(src, os.path.join("web", "favicon.png"), 32)
    save_png(src, os.path.join("web", "icons", "Icon-192.png"), 192)
    save_png(src, os.path.join("web", "icons", "Icon-512.png"), 512)
    save_png(src, os.path.join("web", "icons", "Icon-maskable-192.png"), 192)
    save_png(src, os.path.join("web", "icons", "Icon-maskable-512.png"), 512)

    # ── Assets ────────────────────────────────────────────────────────
    print("\n[Assets]")
    os.makedirs("assets", exist_ok=True)
    save_png(src, os.path.join("assets", "mle_logo.png"), 1024)

    print("\nDone! All icons regenerated.")

if __name__ == "__main__":
    os.chdir(os.path.dirname(os.path.abspath(__file__)) + "\\..")
    main()
