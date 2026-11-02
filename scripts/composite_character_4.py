import numpy as np
from PIL import Image, ImageFilter
from scipy.ndimage import binary_fill_holes, gaussian_filter

morphy = Image.open('Resources/Mascot/character_3_floating.jpg').convert('RGBA')
rings_front = Image.open('rings_front.png').convert('RGBA')
rings_back = Image.open('rings_back.png').convert('RGBA')

# To place rings_back behind Morphy, we create a mask of Morphy's central body
# In character_3_floating.jpg, Morphy is centered around (512, 530)
# Morphy's body is light ceramic / obsidian with bright highlights
# Let's create an elliptical exclusion mask for Morphy's body
m_arr = np.array(morphy)[:, :, :3]
y_idx, x_idx = np.ogrid[:1024, :1024]

# Body center ~ (510, 520), rx ~ 250, ry ~ 270
dist = ((x_idx - 510) / 245.0)**2 + ((y_idx - 520) / 265.0)**2
body_mask = dist <= 1.0

# Smooth the body mask
body_mask_smooth = gaussian_filter(body_mask.astype(float), sigma=4.0)

# rings_back alpha should be multiplied by (1 - body_mask_smooth)
rb_arr = np.array(rings_back).astype(float)
rb_arr[:, :, 3] *= (1.0 - body_mask_smooth)
rings_back_clean = Image.fromarray(np.clip(rb_arr, 0, 255).astype(np.uint8))

# Composite: base Morphy + rings_back + rings_front
comp = Image.alpha_composite(morphy, rings_back_clean)
comp = Image.alpha_composite(comp, rings_front)

out_path = 'Resources/Mascot/character_4_orbital.jpg'
comp.convert('RGB').save(out_path, quality=95)
print(f"Saved {out_path}")
