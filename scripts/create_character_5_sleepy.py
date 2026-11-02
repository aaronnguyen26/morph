import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy.ndimage import gaussian_filter

base = Image.open('Resources/Mascot/character_1_curious.jpg').convert('RGB')
arr = np.array(base).astype(np.float32)

# Copy array
out_arr = arr.copy()

# 1. Seamlessly blend eyelids over the large eyes
# Left eye center ~ (456, 436), radius ~ 58
# Right eye center ~ (660, 436), radius ~ 52

# We sample the smooth skin surface gradient across the face
for (cx, cy, rx, ry, skin_tone) in [
    (456, 435, 60, 68, np.array([215.0, 215.0, 216.0])),
    (660, 435, 54, 62, np.array([195.0, 192.0, 188.0]))
]:
    # Smooth elliptical blend
    y_indices, x_indices = np.ogrid[:1024, :1024]
    dist = ((x_indices - cx) / rx)**2 + ((y_indices - cy) / ry)**2
    mask = dist <= 1.0
    
    # Generate smooth 3D shaded eyelid
    # Gradient from top (slightly shadowed by brow) to bottom (highlighted)
    for y in range(cy - ry, cy + ry + 1):
        if y < 0 or y >= 1024: continue
        # Gradient factor based on Y
        y_fac = (y - (cy - ry)) / (2.0 * ry)
        shade = skin_tone * (0.92 + 0.16 * y_fac)
        for x in range(cx - rx, cx + rx + 1):
            if x < 0 or x >= 1024: continue
            d_val = ((x - cx) / rx)**2 + ((y - cy) / ry)**2
            if d_val <= 1.0:
                edge_alpha = np.clip((1.0 - d_val) * 8.0, 0.0, 1.0)
                out_arr[y, x] = out_arr[y, x] * (1.0 - edge_alpha) + shade * edge_alpha

# Convert back to PIL Image for crisp vector line drawing
img_sleepy = Image.fromarray(np.clip(out_arr, 0, 255).astype(np.uint8))
draw = ImageDraw.Draw(img_sleepy)

# Draw gentle, peaceful sleeping curved eyes ("︶  ︶")
# Left eye sleeping arc
draw.arc([418, 420, 496, 456], start=20, end=160, fill=(38, 38, 42), width=5)
# Eyelash accent
draw.arc([416, 418, 498, 458], start=30, end=150, fill=(20, 20, 24), width=3)

# Right eye sleeping arc
draw.arc([628, 420, 696, 456], start=20, end=160, fill=(35, 34, 38), width=5)
draw.arc([626, 418, 698, 458], start=30, end=150, fill=(18, 18, 22), width=3)

# Floating gentle "Z z z" sleep bubbles in monochrome luxury
font_path = "/System/Library/Fonts/SFNS.ttf"
from PIL import ImageFont
try:
    f_lg = ImageFont.truetype(font_path, 42)
    f_md = ImageFont.truetype(font_path, 30)
    f_sm = ImageFont.truetype(font_path, 20)
except:
    f_lg = f_md = f_sm = ImageFont.load_default()

# Z z z text with soft glow
z_layer = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0))
z_draw = ImageDraw.Draw(z_layer)
z_draw.text((750, 260), "Z", font=f_lg, fill=(255, 255, 255, 220))
z_draw.text((790, 230), "z", font=f_md, fill=(255, 255, 255, 170))
z_draw.text((820, 205), "z", font=f_sm, fill=(255, 255, 255, 120))

# Soft blur to give ethereal float
z_glow = z_layer.filter(ImageFilter.GaussianBlur(radius=3))
z_final = Image.alpha_composite(z_glow, z_layer)

img_final = Image.alpha_composite(img_sleepy.convert('RGBA'), z_final)
out_path = 'Resources/Mascot/character_5_sleepy.jpg'
img_final.convert('RGB').save(out_path, quality=95)
print(f"Saved {out_path}")
