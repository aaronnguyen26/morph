import re

path = '/Users/minhnguyen/Desktop/Coding/morph/scripts/generate_spotlight_hybrid_images.py'
with open(path) as f:
    text = f.read()

# Replace any color tuples with unequal RGB
text = text.replace('(12, 12, 14, 255)', '(12, 12, 12, 255)')
text = text.replace('(20, 20, 22, 255)', '(20, 20, 20, 255)')
text = text.replace('(16, 16, 18, 255)', '(16, 16, 16, 255)')
text = text.replace('(28, 28, 30, 255)', '(28, 28, 28, 255)')
text = text.replace('(10, 10, 12, 255)', '(10, 10, 10, 255)')

# Ensure perfect monochrome conversion before every canvas.save
text = text.replace('canvas.save(os.path.join(OUTPUT_DIR,', 'canvas = canvas.convert("L").convert("RGBA")\n    canvas.save(os.path.join(OUTPUT_DIR,')

with open(path, 'w') as f:
    f.write(text)

print("Updated script with guaranteed pure monochrome conversion!")
