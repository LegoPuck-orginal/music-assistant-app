import os
import math
from PIL import Image, ImageDraw, ImageFilter

def create_base_icon(size=1024):
    # Create 1024x1024 RGB image
    img = Image.new("RGBA", (size, size), (10, 10, 10, 255))
    draw = ImageDraw.Draw(img)

    # 1. Background: Deep OLED gradient
    center_x, center_y = size / 2, size / 2
    max_radius = size * 0.75
    
    # Render smooth radial gradient
    for r in range(int(max_radius), 0, -3):
        factor = r / max_radius
        # Interpolate between deep green-tinted charcoal center and pure black edge
        # Center: #141f17 -> Edge: #050505
        cr = int(5 + (18 * (1 - factor)))
        cg = int(5 + (32 * (1 - factor)))
        cb = int(5 + (20 * (1 - factor)))
        draw.ellipse(
            [center_x - r, center_y - r, center_x + r, center_y + r],
            fill=(cr, cg, cb, 255)
        )

    # 2. Concentric Vinyl / Multiroom Ripple Rings (subtle)
    for ring_r in [180, 260, 340, 420]:
        draw.ellipse(
            [center_x - ring_r, center_y - ring_r, center_x + ring_r, center_y + ring_r],
            outline=(29, 185, 84, 18),
            width=2
        )

    # 3. Outer Glowing Ring / Bezel Accent
    draw.ellipse(
        [center_x - 440, center_y - 440, center_x + 440, center_y + 440],
        outline=(29, 185, 84, 45),
        width=3
    )

    # 4. Create Glow Layer for Center Emblem
    glow_img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow_img)

    # Spotify Soundwaves (3 distinct curved arcs)
    # Arc 1 (Top / Largest)
    glow_draw.arc(
        [center_x - 300, center_y - 280, center_x + 300, center_y + 240],
        start=205, end=335,
        fill=(29, 185, 84, 160),
        width=58
    )
    # Arc 2 (Middle)
    glow_draw.arc(
        [center_x - 220, center_y - 190, center_x + 220, center_y + 210],
        start=205, end=335,
        fill=(29, 185, 84, 200),
        width=50
    )
    # Arc 3 (Bottom)
    glow_draw.arc(
        [center_x - 140, center_y - 100, center_x + 140, center_y + 180],
        start=205, end=335,
        fill=(29, 185, 84, 230),
        width=42
    )

    # Center Music Note / Play Accent
    # Note head
    note_x, note_y = center_x + 20, center_y + 110
    glow_draw.ellipse(
        [note_x - 42, note_y - 28, note_x + 42, note_y + 28],
        fill=(29, 185, 84, 255)
    )
    # Note stem
    glow_draw.rounded_rectangle(
        [note_x + 24, note_y - 120, note_x + 42, note_y],
        radius=8,
        fill=(29, 185, 84, 255)
    )
    # Note flag
    glow_draw.arc(
        [note_x + 30, note_y - 140, note_x + 110, note_y - 60],
        start=270, end=70,
        fill=(29, 185, 84, 255),
        width=16
    )

    # Apply soft Gaussian blur for neon bloom
    bloom = glow_img.filter(ImageFilter.GaussianBlur(radius=22))
    img.paste(bloom, (0, 0), bloom)

    # 5. Crisp Foreground Layer
    fg_img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    fg_draw = ImageDraw.Draw(fg_img)

    # Arc 1
    fg_draw.arc(
        [center_x - 300, center_y - 280, center_x + 300, center_y + 240],
        start=205, end=335,
        fill=(29, 185, 84, 255),
        width=44
    )
    # Arc 2
    fg_draw.arc(
        [center_x - 220, center_y - 190, center_x + 220, center_y + 210],
        start=205, end=335,
        fill=(30, 215, 96, 255),
        width=38
    )
    # Arc 3
    fg_draw.arc(
        [center_x - 140, center_y - 100, center_x + 140, center_y + 180],
        start=205, end=335,
        fill=(32, 235, 105, 255),
        width=32
    )

    # Music note foreground (with bright highlight)
    fg_draw.ellipse(
        [note_x - 36, note_y - 24, note_x + 36, note_y + 24],
        fill=(32, 235, 105, 255)
    )
    fg_draw.rounded_rectangle(
        [note_x + 25, note_y - 116, note_x + 39, note_y],
        radius=7,
        fill=(32, 235, 105, 255)
    )
    fg_draw.arc(
        [note_x + 30, note_y - 138, note_x + 106, note_y - 62],
        start=270, end=70,
        fill=(32, 235, 105, 255),
        width=13
    )

    img.paste(fg_img, (0, 0), fg_img)

    # 6. Apple Glass Specular Gloss Highlight (top left curved gradient)
    gloss = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gloss_draw = ImageDraw.Draw(gloss)
    gloss_draw.arc(
        [-size * 0.2, -size * 0.4, size * 1.2, size * 0.8],
        start=180, end=360,
        fill=(255, 255, 255, 20),
        width=int(size * 0.4)
    )
    gloss = gloss.filter(ImageFilter.GaussianBlur(radius=40))
    img.paste(gloss, (0, 0), gloss)

    # Convert to pure RGB as required by Apple App Store (no alpha channel in marketing 1024)
    final_rgb = Image.new("RGB", (size, size), (10, 10, 10))
    final_rgb.paste(img, (0, 0), img)
    return final_rgb

def generate_all_icons(base_image, dest_dir):
    os.makedirs(dest_dir, exist_ok=True)
    
    sizes = {
        "Icon-App-20x20@1x.png": (20, 20),
        "Icon-App-20x20@2x.png": (40, 40),
        "Icon-App-20x20@3x.png": (60, 60),
        "Icon-App-29x29@1x.png": (29, 29),
        "Icon-App-29x29@2x.png": (58, 58),
        "Icon-App-29x29@3x.png": (87, 87),
        "Icon-App-40x40@1x.png": (40, 40),
        "Icon-App-40x40@2x.png": (80, 80),
        "Icon-App-40x40@3x.png": (120, 120),
        "Icon-App-60x60@2x.png": (120, 120),
        "Icon-App-60x60@3x.png": (180, 180),
        "Icon-App-76x76@1x.png": (76, 76),
        "Icon-App-76x76@2x.png": (152, 152),
        "Icon-App-83.5x83.5@2x.png": (167, 167),
        "Icon-App-1024x1024@1x.png": (1024, 1024),
    }

    for filename, (w, h) in sizes.items():
        resized = base_image.resize((w, h), Image.Resampling.LANCZOS)
        out_path = os.path.join(dest_dir, filename)
        resized.save(out_path, format="PNG")
        print(f"Generated {out_path} ({w}x{h})")

if __name__ == "__main__":
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    app_icon_dir = os.path.join(repo_root, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    base_icon = create_base_icon(1024)
    generate_all_icons(base_icon, app_icon_dir)
    print("All iOS App Icons successfully created!")
