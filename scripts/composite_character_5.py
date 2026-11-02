import numpy as np
from PIL import Image, ImageFilter
from scipy.ndimage import gaussian_filter

morphy = Image.open('Resources/Mascot/character_1_curious.jpg').convert('RGBA')
stage = Image.open('stage_pedestal.png').convert('RGBA')

# In character_1_curious.jpg, Morphy's feet are around y = 840, x = 400..620
# The stage in stage_pedestal.png is at the bottom y = 780..980
# Let's adjust stage position so Morphy's feet touch the top surface of the stage
# Top surface of the stage in stage_pedestal.png is around y = 770
# Morphy's feet in character_1 are at y = 835

# Let's shift the stage down slightly to y = 825
stage_shifted = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0))
stage_shifted.paste(stage, (0, 75))

# Add soft contact shadow under Morphy's feet on the stage
shadow_layer = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0))
from PIL import ImageDraw
s_draw = ImageDraw.Draw(shadow_layer)
# Two foot contact shadows
s_draw.ellipse([380, 840, 480, 875], fill=(0, 0, 0, 200))
s_draw.ellipse([530, 840, 630, 875], fill=(0, 0, 0, 200))
# Body ambient occlusion pool
s_draw.ellipse([320, 850, 690, 915], fill=(0, 0, 0, 160))
shadow_blurred = shadow_layer.filter(ImageFilter.GaussianBlur(radius=10))

# Composite: base Morphy + stage_shifted + shadow under feet
# Wait, Morphy's feet should be in FRONT of the stage top!
# Morphy's feet are at y <= 845. The stage is at y >= 830.
# We composite stage_shifted onto the background, then Morphy over it
# Since Morphy's background in character_1 is dark, we extract Morphy or blend
comp = Image.alpha_composite(stage_shifted, shadow_blurred)

# Composite stage into morphy image
# The stage is only visible below Morphy's feet and to the sides
stage_arr = np.array(stage_shifted)
morphy_arr = np.array(morphy)

# Where stage has alpha > 0, blend into morphy
alpha = stage_arr[:, :, 3].astype(float) / 255.0
# Mask out Morphy's body so stage doesn't cover Morphy
y_idx, x_idx = np.ogrid[:1024, :1024]
morphy_body = ((x_idx - 512) / 260.0)**2 + ((y_idx - 510) / 330.0)**2 <= 1.0
alpha[morphy_body] = 0.0

alpha_3d = np.expand_dims(alpha, axis=2)
result_arr = morphy_arr[:, :, :3] * (1.0 - alpha_3d) + stage_arr[:, :, :3] * alpha_3d

out = Image.fromarray(np.clip(result_arr, 0, 255).astype(np.uint8))
out_path = 'Resources/Mascot/character_5_stage.jpg'
out.save(out_path, quality=95)
print(f"Saved {out_path}")
