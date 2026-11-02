import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import math

# Load base image: Character 1 (Curious Morphy)
base = Image.open('Resources/Mascot/character_1_curious.jpg').convert('RGBA')
w, h = base.size

# We will create an adorable 3D "Mini-Dot" companion hovering at (x=770, y=340)
# Mini-Dot is a tiny 3D pearl-white droplet with cute smiling eyes and a soft aura
dot_size = 140
dot_img = Image.new('RGBA', (dot_size * 2, dot_size * 2), (0, 0, 0, 0))
draw = ImageDraw.Draw(dot_img)

cx, cy = dot_size, dot_size
r = 52

# Render 3D pearl sphere with physically based gradient shading
for y in range(-r - 10, r + 15):
    for x in range(-r - 10, r + 10):
        # Droplet / slightly plump egg shape: narrower at top, plumper at bottom
        y_norm = (y + r) / (2.0 * r)
        scale_x = 1.0 + 0.15 * y_norm
        dist_sq = (x / scale_x)**2 + y**2
        if dist_sq <= r**2:
            # Sphere normal
            nz = math.sqrt(max(0.0, r**2 - dist_sq)) / r
            nx = (x / scale_x) / r
            ny = y / r
            
            # Key light from top-left
            lx, ly, lz = -0.5, -0.6, 0.62
            l_mag = math.sqrt(lx**2 + ly**2 + lz**2)
            lx, ly, lz = lx/l_mag, ly/l_mag, lz/l_mag
            
            # Diffuse
            diff = max(0.0, nx*lx + ny*ly + nz*lz)
            
            # Specular highlight
            # Halfway vector
            vx, vy, vz = 0.0, 0.0, 1.0
            hx, hy, hz = lx + vx, ly + vy, lz + vz
            h_mag = math.sqrt(hx**2 + hy**2 + hz**2)
            hx, hy, hz = hx/h_mag, hy/h_mag, hz/h_mag
            spec = max(0.0, nx*hx + ny*hy + nz*hz)**24
            
            # Rim light
            rim = (1.0 - nz)**2.8
            
            # Ambient occlusion / base pearl tone
            base_col = 210 + int(45 * diff)
            base_col = min(255, int(base_col + 180 * spec + 60 * rim))
            
            # Alpha feathering for anti-aliasing
            edge_dist = math.sqrt(dist_sq)
            alpha = 255
            if edge_dist > r - 1.5:
                alpha = int(255 * (r - edge_dist) / 1.5)
                alpha = max(0, min(255, alpha))
                
            dot_img.putpixel((cx + x, cy + y), (base_col, base_col, base_col, alpha))

# Draw adorable expressive face on the Mini-Dot!
dot_draw = ImageDraw.Draw(dot_img)
# Two cute smiling arc eyes or glossy dot eyes
eye_y = cy - 4
eye_spacing = 14
# Left eye
dot_draw.ellipse([cx - eye_spacing - 5, eye_y - 7, cx - eye_spacing + 5, eye_y + 7], fill=(12, 12, 14, 255))
dot_draw.ellipse([cx - eye_spacing + 1, eye_y - 5, cx - eye_spacing + 4, eye_y - 2], fill=(255, 255, 255, 240)) # catchlight
# Right eye
dot_draw.ellipse([cx + eye_spacing - 5, eye_y - 7, cx + eye_spacing + 5, eye_y + 7], fill=(12, 12, 14, 255))
dot_draw.ellipse([cx + eye_spacing + 1, eye_y - 5, cx + eye_spacing + 4, eye_y - 2], fill=(255, 255, 255, 240)) # catchlight

# Cute happy open smile
dot_draw.arc([cx - 8, cy + 4, cx + 8, cy + 16], start=10, end=170, fill=(20, 20, 24, 255), width=2)

# Tiny zero-g floating mini-halo above Mini-Dot!
halo_w, halo_h = 24, 6
halo_y = cy - r - 8
dot_draw.ellipse([cx - halo_w, halo_y - halo_h, cx + halo_w, halo_y + halo_h], outline=(240, 240, 245, 230), width=2)

# Soft volumetric aura / glow around Mini-Dot
aura_img = Image.new('RGBA', (dot_size * 2, dot_size * 2), (0, 0, 0, 0))
aura_draw = ImageDraw.Draw(aura_img)
for gr in range(r + 35, r, -2):
    intensity = int(28 * (1.0 - (gr - r) / 35.0)**1.5)
    aura_draw.ellipse([cx - gr, cy - gr, cx + gr, cy + gr], fill=(255, 255, 255, intensity))
aura_img = aura_img.filter(ImageFilter.GaussianBlur(radius=8))

# Composite aura and dot
full_dot = Image.alpha_composite(aura_img, dot_img)

# Also tiny orbital sparkle dots around Mini-Dot (OpenAI Dots style)
sparkle_draw = ImageDraw.Draw(full_dot)
for sx, sy, sr in [(cx + 48, cy - 28, 4), (cx - 42, cy + 32, 3), (cx + 36, cy + 40, 2.5), (cx - 35, cy - 38, 2)]:
    sparkle_draw.ellipse([sx - sr, sy - sr, sx + sr, sy + sr], fill=(255, 255, 255, 220))

# Place Mini-Dot in base image at (x=730, y=280)
final_img = base.copy()
final_img.alpha_composite(full_dot, (710, 240))

# Save
out_path = 'Resources/Mascot/character_4_dots_duo.jpg'
final_img.convert('RGB').save(out_path, quality=95)
print(f"Saved {out_path}")
