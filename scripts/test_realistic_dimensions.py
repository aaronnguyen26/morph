import os
from PIL import Image, ImageDraw, ImageFont

# Canvas size: exactly 640 x 225 pt at Retina 2x = 1280 x 450 px
W, H = 1280, 450
print(f"Target realistic dimension: {W}x{H} px ({W//2}x{H//2} pt), aspect ratio: {W/H:.3f}")
