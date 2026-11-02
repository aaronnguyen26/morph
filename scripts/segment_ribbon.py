import numpy as np
from PIL import Image, ImageFilter
from scipy.ndimage import binary_fill_holes, gaussian_filter

img = Image.open('Resources/Mascot/morph_mascot_3_ribbon.jpg').convert('RGB')
arr = np.array(img).astype(np.float32)

# The ribbon is dark titanium with specular highlights.
# Inside and outside the ribbon, there is the background grid/HUD screens.
# Let's see: can we create a pristine version of Image 3, or can we render a pure 3D ribbon with Metal?
print("Image dimensions:", arr.shape)
