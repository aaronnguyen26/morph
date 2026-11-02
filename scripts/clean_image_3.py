import numpy as np
from PIL import Image, ImageFilter
from scipy.ndimage import distance_transform_edt

img = Image.open('Resources/Mascot/morph_mascot_3_ribbon.jpg').convert('RGB')
arr = np.array(img).astype(np.float32)

# 1. Inspect text masks
# Background in text areas is dark gray/charcoal (~60 to 110), text is pure white (> 180)
# Let's create masks for the text areas:
# Area A: Top headers y in [70, 160], x in [40, 980]
# Area B: Center text inside hole y in [450, 545], x in [370, 650]

mask = np.zeros(arr.shape[:2], dtype=bool)

# Top area
top_slice = (slice(60, 165), slice(30, 990))
top_lum = 0.299 * arr[top_slice][:, :, 0] + 0.587 * arr[top_slice][:, :, 1] + 0.114 * arr[top_slice][:, :, 2]
top_mask = (top_lum > 140) & (arr[top_slice][:, :, 0] > 130)
mask[top_slice] = top_mask

# Center area
center_slice = (slice(460, 540), slice(370, 640))
center_lum = 0.299 * arr[center_slice][:, :, 0] + 0.587 * arr[center_slice][:, :, 1] + 0.114 * arr[center_slice][:, :, 2]
center_mask = (center_lum > 130) & (arr[center_slice][:, :, 0] > 120)
mask[center_slice] = center_mask

print(f"Masked text pixels: {np.sum(mask)}")

# Dilate mask slightly by 2 pixels
dist = distance_transform_edt(~mask)
dilated_mask = dist <= 2.5

# Inpaint: interpolate from nearest non-masked background pixels using distance transform or bi-harmonic/gaussian
cleaned = arr.copy()
# For the top and center text, the background is a smooth studio backdrop.
# Let's replace dilated_mask with smoothed local background
# We can do a Gaussian blur of non-masked pixels
blurred = np.array(img.filter(ImageFilter.GaussianBlur(radius=8))).astype(np.float32)

# To ensure the blur only samples background, fill mask in blurred with median local background
for s, bg_val in [(top_slice, np.array([72.0, 78.0, 82.0])), (center_slice, np.array([95.0, 102.0, 106.0]))]:
    temp = arr.copy()
    temp[dilated_mask] = bg_val
    temp_img = Image.fromarray(temp.astype(np.uint8)).filter(ImageFilter.GaussianBlur(radius=6))
    temp_arr = np.array(temp_img).astype(np.float32)
    cleaned[s][dilated_mask[s]] = temp_arr[s][dilated_mask[s]]

out = Image.fromarray(np.clip(cleaned, 0, 255).astype(np.uint8))
out.save('Resources/Mascot/morph_mascot_3_ribbon_clean.jpg', quality=95)
print("Saved clean Image 3")
